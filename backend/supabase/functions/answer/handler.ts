import { type Authenticator } from "../_shared/auth.ts";
import { CORS_HEADERS, errorResponse, HttpError, toHttpError } from "../_shared/errors.ts";
import { enforceLimits, type Limits, type RateLimiter } from "../_shared/ratelimit.ts";
import { SSE_HEADERS, sseFrame } from "../_shared/sse.ts";
import { type LLMChunk, type LLMProvider, LLMProviderError } from "./llm/types.ts";
import { type ParserEvent, ResponseParser } from "./parser.ts";
import { classifyAnswerType, detectContinuation } from "./length.ts";
import { buildPersonaUserMessage, personaPlan, personaSystemPrompt } from "./personas.ts";
import {
  buildDirectUserMessage,
  buildUserMessage,
  SYSTEM_PROMPT,
  systemPromptFor,
} from "./prompt.ts";
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
  /** Token budget / spoken-length cap for developed "study" answers (D35). */
  maxTokensStudy: number;
  maxAnswerChars: number;
  maxAnswerCharsStudy: number;
  limits: Limits;
  /** push_to_talk/text: headerless prompt, meta synthesised up front (lowest latency). */
  directModes: boolean;
  /** USD per million tokens, for the cost estimate only (prices as stated in the assignment). */
  priceInPerMTok: number;
  priceOutPerMTok: number;
}

export const DEFAULT_CONFIG: HandlerConfig = {
  confidenceThreshold: 0.45,
  maxTokens: 256,
  maxTokensStudy: 800,
  maxAnswerChars: 600,
  maxAnswerCharsStudy: 1800,
  limits: { perMinute: 20, perDay: 400, globalPerDay: 5000 },
  directModes: true,
  priceInPerMTok: 0.10,
  priceOutPerMTok: 0.50,
};

export interface Deps {
  authenticate: Authenticator;
  /** Authoritative (shared, Postgres) limiter. Checked IN PARALLEL with the LLM call. */
  rateLimiter: RateLimiter;
  /**
   * Cheap per-isolate guard checked BEFORE the LLM call starts (0 ms). Bounds how many speculative
   * LLM starts one user can trigger while the shared limiter is still answering.
   */
  localLimiter?: RateLimiter;
  /** null = no provider configured -> 503 provider_unconfigured (fail closed). */
  provider: LLMProvider | null;
  recordUsage: (rec: UsageRecord) => void | Promise<void>;
  config: HandlerConfig;
  now?: () => number;
  /** Called for `GET` + `x-warm: 1` (keep-alive ping): open the upstream connection ahead of time. */
  warm?: () => void;
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
  let served = 0; // requests served by this isolate (0 => the first one is "cold")

  return async (req: Request): Promise<Response> => {
    if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS_HEADERS });
    if (req.method === "GET" && req.headers.get("x-warm") === "1") {
      deps.warm?.();
      return new Response(null, { status: 204 });
    }
    const t0 = now();
    const cold = served++ === 0;
    try {
      if (req.method !== "POST") throw new HttpError(405, "method_not_allowed", "Use POST");
      const declared = Number(req.headers.get("content-length") ?? "0");
      if (declared > LIMITS.bodyBytes) {
        throw new HttpError(413, "payload_too_large", "Body too large");
      }

      const user = await deps.authenticate(req);
      const tAuth = now() - t0;

      if (deps.localLimiter) {
        const lr = await deps.localLimiter.check(`answer:u:${user.id}:m`, cfg.limits.perMinute, 60);
        if (!lr.allowed) {
          throw new HttpError(429, "rate_limited", "Too many requests", {
            fallback: true,
            retryAfterSec: lr.retryAfterSec,
          });
        }
      }

      const body = validateAnswerRequest(await readLimitedJson(req, LIMITS.bodyBytes));
      const tBody = now() - t0;
      const provider = deps.provider;
      if (!provider) {
        throw new HttpError(503, "provider_unconfigured", "LLM provider not configured", {
          fallback: true,
        });
      }

      const direct = (cfg.directModes && body.mode !== "auto") || !!personaPlan(body);
      // 'mer' / 'fortsätt' / 'förklara enklare' continue the last answer (needs history).
      const plan = personaPlan(body); // D42 persona / interview prep (null = ordinary flows)
      const continuation = !plan && body.context.recent_qa.length
        ? detectContinuation(body.fragment)
        : null;
      const tutor = body.mode === "tutor";
      const answerType = plan?.answerType ??
        classifyAnswerType(body.fragment, body.length, continuation, {
          tutor,
          commands: body.commands.length > 0,
        });
      const maxChars = plan?.maxChars ??
        (answerType === "study" ? cfg.maxAnswerCharsStudy : cfg.maxAnswerChars);
      const parser = new ResponseParser(
        body.mode,
        body.fragment,
        cfg.confidenceThreshold,
        direct,
        answerType,
      );
      let inputTokens: number | null = null;
      let outputTokens: number | null = null;
      let cacheRead = 0;
      let cacheWrite = 0;
      let llmFirstTokenMs: number | null = null;
      let metaMs: number | null = null;
      let ttftMs: number | null = null;
      let limitsMs: number | null = null;
      let answerChars = 0;
      let closed = false;
      let status = "ok";

      function usage(s: string): UsageRecord {
        const m = parser.meta;
        const total = inputTokens ?? 0;
        const plain = Math.max(0, total - cacheRead - cacheWrite);
        const cost = inputTokens !== null || outputTokens !== null
          ? ((plain + cacheRead * 0.1 + cacheWrite * 1.25) * cfg.priceInPerMTok +
            (outputTokens ?? 0) * cfg.priceOutPerMTok) / 1e6
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

      // Start the shared-limit check and the LLM call at the same time. No byte is sent to the client
      // before BOTH have succeeded, so a denied request never leaks an answer; it only costs the
      // aborted LLM start (bounded by the local guard above).
      const ac = new AbortController();
      req.signal.addEventListener("abort", () => ac.abort());
      const limitsP = enforceLimits(deps.rateLimiter, "answer", user.id, cfg.limits).then((r) => {
        limitsMs = now() - t0;
        return r;
      });
      const iterator = provider
        .stream({
          system: plan
            ? personaSystemPrompt(plan.kind)
            : direct
            ? systemPromptFor(answerType, tutor)
            : SYSTEM_PROMPT,
          user: plan
            ? buildPersonaUserMessage(body, plan.task)
            : direct
            ? buildDirectUserMessage(body, continuation)
            : buildUserMessage(body, cfg.confidenceThreshold, answerType, continuation),
          maxTokens: plan?.maxTokens ??
            (answerType === "study" ? cfg.maxTokensStudy : cfg.maxTokens),
          cacheSystem: true,
          signal: ac.signal,
        })[Symbol.asyncIterator]();
      const firstP = iterator.next().then((r) => {
        llmFirstTokenMs = now() - t0;
        return r;
      });
      firstP.catch(() => {}); // handled below, or deliberately dropped when the limiter denies

      const rl = await limitsP;
      if (!rl.allowed) {
        ac.abort();
        iterator.return?.()?.catch?.(() => {});
        throw new HttpError(429, "rate_limited", "Too many requests", {
          fallback: true,
          retryAfterSec: rl.retryAfterSec,
        });
      }

      // Wait for the first chunk before committing to a 200: quota/auth errors become real HTTP errors.
      let first: IteratorResult<LLMChunk>;
      try {
        first = await firstP;
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
                answer_type: ev.meta.answer_type,
              });
              if (!ev.meta.is_question) {
                status = "not_question";
                stop = true;
              }
            } else {
              if (ttftMs === null) ttftMs = now() - t0;
              answerChars += ev.text.length;
              send("delta", { text: ev.text });
              if (answerChars >= maxChars) {
                status = "truncated";
                stop = true;
              }
            }
          };
          const handle = (chunk: LLMChunk) => {
            if (chunk.type === "usage") {
              if (chunk.inputTokens !== undefined) inputTokens = chunk.inputTokens;
              if (chunk.outputTokens !== undefined) outputTokens = chunk.outputTokens;
              if (chunk.cacheReadTokens !== undefined) cacheRead = chunk.cacheReadTokens;
              if (chunk.cacheWriteTokens !== undefined) cacheWrite = chunk.cacheWriteTokens;
              return;
            }
            for (const ev of parser.push(chunk.text)) emit(ev);
          };

          try {
            if (parser.presetMeta) emit({ type: "meta", meta: parser.presetMeta });
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
              breakdown: {
                auth_ms: r2(tAuth),
                body_ms: r2(tBody),
                limits_ms: r2(limitsMs),
                llm_first_chunk_ms: r2(llmFirstTokenMs),
                direct,
                cold,
                answer_type: answerType,
                continuation,
              },
              usage: {
                input_tokens: inputTokens,
                output_tokens: outputTokens,
                cache_read_tokens: cacheRead,
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
            console.log(JSON.stringify({
              evt: "answer",
              ...rec,
              user_id: undefined,
              auth_ms: Math.round(tAuth),
              limits_ms: limitsMs === null ? null : Math.round(limitsMs),
              llm_first_chunk_ms: llmFirstTokenMs === null ? null : Math.round(llmFirstTokenMs),
              cache_read: cacheRead,
              direct,
              cold,
              answer_type: answerType,
              continuation,
            }));
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
