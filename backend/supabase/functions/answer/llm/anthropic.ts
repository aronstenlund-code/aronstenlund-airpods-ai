import { type LLMChunk, type LLMProvider, LLMProviderError, type LLMRequest } from "./types.ts";

export interface AnthropicConfig {
  apiKey: string;
  model: string; // default claude-haiku-5-5
  effort: "low" | "medium" | "high";
  disableThinking: boolean;
  /** Override for tests/proxies; default https://api.anthropic.com */
  baseUrl?: string;
}

/** Classifies an SDK error. Credit exhaustion arrives as 402 billing_error or as a 400
 *  invalid_request_error whose message mentions the credit balance - both must fail closed. */
export function classifyAnthropicError(
  status: number | undefined,
  message: string,
): LLMProviderError {
  const m = message.toLowerCase();
  if (status === 402 || m.includes("credit balance") || m.includes("billing")) {
    return new LLMProviderError("quota", "Provider credits exhausted", status);
  }
  if (status === 401 || status === 403) {
    return new LLMProviderError("auth", "Provider rejected key", status);
  }
  if (status === 429) return new LLMProviderError("rate_limited", "Provider rate limited", status);
  if (status === 400 || status === 404 || status === 413 || status === 422) {
    return new LLMProviderError(
      "bad_request",
      `Provider rejected request: ${message.slice(0, 200)}`,
      status,
    );
  }
  return new LLMProviderError("unavailable", "Provider unavailable", status);
}

/** Maps raw Messages API stream events to LLMChunks (pure, unit-tested). */
export function mapAnthropicEvent(ev: {
  type: string;
  // deno-lint-ignore no-explicit-any
  [k: string]: any;
}): LLMChunk | null {
  switch (ev.type) {
    case "message_start": {
      const u = ev.message?.usage;
      // Cached prompt tokens are billed at a different rate but still count as input for logging.
      const input = u?.input_tokens === undefined
        ? undefined
        : u.input_tokens + (u.cache_read_input_tokens ?? 0) + (u.cache_creation_input_tokens ?? 0);
      return {
        type: "usage",
        inputTokens: input,
        outputTokens: u?.output_tokens,
        cacheReadTokens: u?.cache_read_input_tokens,
        cacheWriteTokens: u?.cache_creation_input_tokens,
      };
    }
    case "content_block_delta":
      if (ev.delta?.type === "text_delta" && typeof ev.delta.text === "string" && ev.delta.text) {
        return { type: "text", text: ev.delta.text };
      }
      return null;
    case "message_delta":
      // Input tokens come from message_start only (message_delta may report a cache-exclusive count).
      return { type: "usage", outputTokens: ev.usage?.output_tokens };
    default:
      return null;
  }
}

/** Parses an SSE byte stream into JSON `data:` payloads (Anthropic sends one JSON object per event). */
export async function* sseJson(
  body: ReadableStream<Uint8Array>,
): AsyncGenerator<{ type: string; [k: string]: unknown }> {
  const reader = body.pipeThrough(new TextDecoderStream()).getReader();
  let buf = "";
  try {
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      buf += value;
      let i;
      while ((i = buf.indexOf("\n\n")) !== -1) {
        const frame = buf.slice(0, i);
        buf = buf.slice(i + 2);
        const data = frame.split("\n").filter((l) => l.startsWith("data:")).map((l) =>
          l.slice(5).trimStart()
        ).join("\n");
        if (!data) continue;
        try {
          yield JSON.parse(data);
        } catch { /* ignore a malformed frame */ }
      }
    }
  } finally {
    try {
      await reader.cancel();
    } catch { /* already closed */ }
  }
}

export const ANTHROPIC_BASE = "https://api.anthropic.com";
export const ANTHROPIC_URL = `${ANTHROPIC_BASE}/v1/messages`;
/** Same API version the official SDK 1.3.0 sends (read from its source). */
export const ANTHROPIC_VERSION = "2026-10-21";

/**
 * Talks to the Messages API with plain fetch. We dropped the official SDK on purpose: importing it
 * costs ~70 ms of isolate boot, and every request here may run in a fresh isolate (measured: 29 of 30
 * calls were "cold"). Request shape = what the SDK sent (verified live with SDK 1.3.0).
 */
export class AnthropicProvider implements LLMProvider {
  readonly name = "anthropic";
  readonly model: string;

  constructor(private cfg: AnthropicConfig, private fetchImpl: typeof fetch = fetch) {
    this.model = cfg.model;
  }

  async *stream(req: LLMRequest): AsyncIterable<LLMChunk> {
    // maxRetries 0: a retry would double latency; the app has its own fallback.
    const signal = req.signal
      ? AbortSignal.any([req.signal, AbortSignal.timeout(20_000)])
      : AbortSignal.timeout(20_000);
    try {
      const res = await this.fetchImpl(
        this.cfg.baseUrl ? `${this.cfg.baseUrl}/v1/messages` : ANTHROPIC_URL,
        {
          method: "POST",
          headers: {
            "x-api-key": this.cfg.apiKey,
            "anthropic-version": ANTHROPIC_VERSION,
            "content-type": "application/json",
          },
          // Haiku 5.5: temperature/top_p/top_k must be omitted. Thinking off + low effort = lowest latency.
          body: JSON.stringify({
            model: this.cfg.model,
            max_tokens: req.maxTokens,
            stream: true,
            system: req.cacheSystem
              ? [{ type: "text", text: req.system, cache_control: { type: "ephemeral" } }]
              : req.system,
            messages: [{ role: "user", content: req.user }],
            output_config: { effort: this.cfg.effort },
            ...(this.cfg.disableThinking ? { thinking: { type: "disabled" } } : {}),
          }),
          signal,
        },
      );
      if (!res.ok || !res.body) {
        let message = "";
        try {
          message = (await res.json())?.error?.message ?? "";
        } catch { /* body is not JSON */ }
        throw classifyAnthropicError(res.status, message || `HTTP ${res.status}`);
      }
      for await (const ev of sseJson(res.body)) {
        if (ev.type === "error") {
          const err = ev.error as { type?: string; message?: string } | undefined;
          throw classifyAnthropicError(
            err?.type === "overloaded_error" ? 529 : 500,
            err?.message ?? "stream error",
          );
        }
        if (
          ev.type === "message_delta" &&
          (ev.delta as { stop_reason?: string } | undefined)?.stop_reason === "refusal"
        ) {
          throw new LLMProviderError("bad_request", "Provider refused the request");
        }
        const chunk = mapAnthropicEvent(ev);
        if (chunk) yield chunk;
      }
    } catch (e) {
      if (e instanceof LLMProviderError) throw e;
      if (req.signal?.aborted) throw e;
      const status = (e as { status?: number }).status;
      throw classifyAnthropicError(status, e instanceof Error ? e.message : String(e));
    }
  }
}
