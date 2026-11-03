import { type Authenticator } from "../_shared/auth.ts";
import { CORS_HEADERS, errorResponse, HttpError, toHttpError } from "../_shared/errors.ts";
import { enforceLimits, type Limits, type RateLimiter } from "../_shared/ratelimit.ts";
import { SSE_HEADERS, sseFrame } from "../_shared/sse.ts";
import { type LLMChunk, type LLMProvider, LLMProviderError } from "./llm/types.ts";
import { type ParserEvent, ResponseParser } from "./parser.ts";
import { buildUserMessage, SYSTEM_PROMPT } from "./prompt.ts";
import { LIMITS, readLimitedJson, validateAnswerRequest } from "./validate.ts";

export interface UsageRecord {
  user_id: string;
  endpoint: "answer";
  mode: string;
  language: string;
  provider: string;
  model: string;
  is_question: boolean | null;
  confidence: number | null;
  input_tokens: number | null;
  output_tokens: number | null;
  ttft_ms: number | null;
  total_ms: number;
  est_cost_usd: number | null;
  status: string;
}

export interface HandlerConfig {
  confidenceThreshold: number;
  maxTokens: number;
  maxAnswerChars: number;
  limits: Limits;
  /** USD per million tokens, for the cost estimate only (prices as stated in the assignment). */
  priceInPerMTok: number;
  priceOutPerMTok: number;
}

export const DEFAULT_CONFIG: HandlerConfig = {
  confidenceThreshold: 0.6,
  maxTokens: 256,
  maxAnswerChars: 600,
  limits: { perMinute: 20, perDay: 400, globalPerDay: 5000 },
  priceInPerMTok: 0.10,
  priceOutPerMTok: 0.50,
};

export interface Deps {
  authenticate: Authenticator;
  rateLimiter: RateLimiter;
  /** null = no provider configured -> 503 provider_unconfigured (fail closed). */
  provider: LLMProvider | null;
  recordUsage: (rec: UsageRecord) => void | Promise<void>;
  config: HandlerConfig;
  now?: () => number;
}

export function providerErrorToHttp(e: unknown): HttpError {
  if (e instanceof LLMProviderError) {
    switch (e.kind) {
      case "quota":
        return new HttpError(503, "provider_quota", "LLM credits exhausted", { fallback: true });
      case "rate_limited":
        return new HttpError(503, "provider_busy", "LLM rate limited", {
          fallback: true,
          retryAfterSec: 5,
        });
      case "unconfigured":
        return new HttpError(503, "provider_unconfigured", "LLM provider not configured", {
          fallback: true,
        });
      case "auth":
        return new HttpError(503, "provider_misconfigured", "LLM provider credentials rejected", {
          fallback: true,
        });
      case "bad_request":
        return new HttpError(502, "provider_error", "LLM rejected the request", { fallback: true });
      default:
        return new HttpError(502, "provider_unavailable", "LLM provider unavailable", {
          fallback: true,
        });
    }
  }
  return new HttpError(502, "provider_unavailable", "LLM provider unavailable", { fallback: true });
}

export function createHandler(deps: Deps): (req: Request) => Promise<Response> {
  const now = deps.now ?? (() => performance.now());
  const cfg = deps.config;

  return async (req: Request): Promise<Response> => {
    if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS_HEADERS });
    const t0 = now();
    try {
      if (req.method !== "POST") throw new HttpError(405, "method_not_allowed", "Use POST");
      const declared = Number(req.headers.get("content-length") ?? "0");
      if (declared > LIMITS.bodyBytes) {
        throw new HttpError(413, "payload_too_large", "Body too large");
      }

      const user = await deps.authenticate(req);

      const rl = await enforceLimits(deps.rateLimiter, "answer", user.id, cfg.limits);
      if (!rl.allowed) {
        throw new HttpError(429, "rate_limited", "Too many requests", {
          fallback: true,
          retryAfterSec: rl.retryAfterSec,
        });
      }

      const body = validateAnswerRequest(await readLimitedJson(req, LIMITS.bodyBytes));
      const provider = deps.provider;
      if (!provider) {
        throw new HttpError(503, "provider_unconfigured", "LLM provider not configured", {
          fallback: true,
        });
      }

      const parser = new ResponseParser(body.mode, body.fragment, cfg.confidenceThreshold);
      let inputTokens: number | null = null;
      let outputTokens: number | null = null;
      let llmFirstTokenMs: number | null = null;
      let metaMs: number | null = null;
      let ttftMs: number | null = null;
      let answerChars = 0;
      let closed = false;
      let status = "ok";

      function usage(s: string): UsageRecord {
        const m = parser.meta;
        const cost = inputTokens !== null || outputTokens !== null
          ? ((inputTokens ?? 0) * cfg.priceInPerMTok + (outputTokens ?? 0) * cfg.priceOutPerMTok) /
            1e6
          : null;
        return {
          user_id: user.id,
          endpoint: "answer",
          mode: body.mode,
          language: body.language,
          provider: provider!.name,
          model: provider!.model,
          is_question: m?.is_question ?? null,
          confidence: m?.confidence ?? null,
          input_tokens: inputTokens,
          output_tokens: outputTokens,
          ttft_ms: ttftMs === null ? null : Math.round(ttftMs),
          total_ms: Math.round(now() - t0),
          est_cost_usd: cost,
          status: s,
        };
      }

      const ac = new AbortController();
      req.signal.addEventListener("abort", () => ac.abort());
      const iterator = provider
        .stream({
          system: SYSTEM_PROMPT,
          user: buildUserMessage(body, cfg.confidenceThreshold),
          maxTokens: cfg.maxTokens,
          signal: ac.signal,
        })[Symbol.asyncIterator]();

      // Wait for the first chunk before committing to a 200: quota/auth errors become real HTTP errors.
      let first: IteratorResult<LLMChunk>;
      try {
        first = await iterator.next();
      } catch (e) {
        ac.abort();
        try {
          await deps.recordUsage(usage("provider_error"));
        } catch (le) {
          console.error("usage_log_failed", le instanceof Error ? le.message : String(le));
        }
        throw providerErrorToHttp(e);
      }

      const stream = new ReadableStream<Uint8Array>({
        async start(controller) {
          const send = (event: string, data: unknown) => {
            if (closed) return;
            try {
              controller.enqueue(sseFrame(event, data));
            } catch {
              closed = true;
              ac.abort();
            }
          };
          let stop = false;
          const emit = (ev: ParserEvent) => {
            if (ev.type === "meta") {
              metaMs = now() - t0;
              send("meta", {
                reconstructed_question: ev.meta.reconstructed_question,
                confidence: ev.meta.confidence,
                is_question: ev.meta.is_question,
                needs_confirmation: ev.meta.needs_confirmation,
              });
              if (!ev.meta.is_question) {
                status = "not_question";
                stop = true;
              }
            } else {
              if (ttftMs === null) ttftMs = now() - t0;
              answerChars += ev.text.length;
              send("delta", { text: ev.text });
              if (answerChars >= cfg.maxAnswerChars) {
                status = "truncated";
                stop = true;
              }
            }
          };
          const handle = (chunk: LLMChunk) => {
            if (chunk.type === "usage") {
              if (chunk.inputTokens !== undefined) inputTokens = chunk.inputTokens;
              if (chunk.outputTokens !== undefined) outputTokens = chunk.outputTokens;
              return;
            }
            if (llmFirstTokenMs === null) llmFirstTokenMs = now() - t0;
            for (const ev of parser.push(chunk.text)) emit(ev);
          };

          try {
            let r = first;
            while (!r.done && !stop && !closed) {
              handle(r.value);
              if (stop || closed) break;
              r = await iterator.next();
            }
            if (!stop) { for (const ev of parser.finish()) emit(ev); }
            if (stop) ac.abort();
            if (parser.headerFailed) {
              console.warn(JSON.stringify({ evt: "header_parse_failed", mode: body.mode }));
            }
            if (status === "ok" && parser.meta?.is_question && ttftMs === null) {
              status = "empty_answer";
              send("error", {
                code: "empty_answer",
                message: "Model returned no answer",
                fallback: true,
              });
            }
            const r2 = (n: number | null) => (n === null ? null : Math.round(n));
            send("done", {
              answered: status === "ok" || status === "truncated",
              timing: {
                meta_ms: r2(metaMs),
                ttft_ms: r2(ttftMs),
                llm_first_token_ms: r2(llmFirstTokenMs),
                total_ms: Math.round(now() - t0),
              },
              usage: {
                input_tokens: inputTokens,
                output_tokens: outputTokens,
                model: provider.model,
              },
            });
          } catch (e) {
            if (!closed) {
              const he = providerErrorToHttp(e);
              status = he.code;
              send("error", { code: he.code, message: he.message, fallback: true });
            }
          } finally {
            ac.abort(); // no-op if already finished; releases the upstream connection otherwise
            try {
              await iterator.return?.();
            } catch { /* provider already failed */ }
            const rec = usage(status);
            console.log(JSON.stringify({ evt: "answer", ...rec, user_id: undefined }));
            try {
              await deps.recordUsage(rec);
            } catch (e) {
              console.error("usage_log_failed", e instanceof Error ? e.message : String(e));
            }
            if (!closed) {
              closed = true;
              try {
                controller.close();
              } catch { /* already closed */ }
            }
          }
        },
        cancel() {
          closed = true;
          ac.abort();
        },
      });

      return new Response(stream, { status: 200, headers: { ...SSE_HEADERS, ...CORS_HEADERS } });
    } catch (e) {
      return errorResponse(toHttpError(e));
    }
  };
}
