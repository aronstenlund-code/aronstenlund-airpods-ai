import { redactSecrets } from "../../_shared/secrets.ts";
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
  errorName?: string,
  log: (line: string) => void = console.error,
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
  // K0: say why, so a bad key paste or a network error is visible in the function log (never the key).
  log(JSON.stringify({
    event: "provider_unavailable",
    status: status ?? null,
    error: errorName ?? null,
    message: redactSecrets(message).slice(0, 200),
  }));
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
      return {
        type: "usage",
        outputTokens: ev.usage?.output_tokens,
        ...(ev.usage?.server_tool_use?.web_search_requests === undefined ? {} : {
          webSearches: ev.usage.server_tool_use.web_search_requests,
        }),
      };
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

/**
 * With web tools on, the model may write a sentence BEFORE it searches ("Jag söker ..."). Text that comes
 * before the first tool block is therefore held back and dropped if a tool call follows; text after a tool
 * result streams live. Without any tool call the held text is released when the message ends.
 */
export class WebTextGate {
  private toolUsed = false;
  private held = "";

  /** Returns the chunks to pass on for this event. */
  filter(ev: { type: string; [k: string]: unknown }, mapped: LLMChunk | null): LLMChunk[] {
    if (ev.type === "content_block_start") {
      const t = (ev.content_block as { type?: string } | undefined)?.type;
      if (
        t === "server_tool_use" || t === "web_search_tool_result" || t === "web_fetch_tool_result"
      ) {
        this.toolUsed = true;
        this.held = "";
      }
      return [];
    }
    if (ev.type === "message_stop") {
      const h = this.held;
      this.held = "";
      return h ? [{ type: "text", text: h }] : [];
    }
    if (mapped?.type === "text") {
      if (this.toolUsed) return [mapped];
      this.held += mapped.text;
      return [];
    }
    return mapped ? [mapped] : [];
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
/** Removes domains from every web_search `allowed_domains` list. */
export function withoutDomains(tools: unknown[], drop: Set<string>): unknown[] {
  return tools.map((t) => {
    const o = t as { allowed_domains?: string[] };
    return Array.isArray(o.allowed_domains)
      ? { ...o, allowed_domains: o.allowed_domains.filter((d) => !drop.has(d)) }
      : t;
  });
}

export class AnthropicProvider implements LLMProvider {
  readonly name = "anthropic";
  readonly model: string;

  constructor(private cfg: AnthropicConfig, private fetchImpl: typeof fetch = fetch) {
    this.model = cfg.model;
  }

  async *stream(req: LLMRequest): AsyncIterable<LLMChunk> {
    // maxRetries 0: a retry would double latency; the app has its own fallback.
    const timeoutMs = req.images?.length ? 120_000 : req.tools?.length ? 45_000 : 20_000; // a web search turn takes several seconds
    const signal = req.signal
      ? AbortSignal.any([req.signal, AbortSignal.timeout(timeoutMs)])
      : AbortSignal.timeout(timeoutMs);
    const gate = req.tools?.length ? new WebTextGate() : null;
    let emitted = false;
    try {
      const model = req.model ?? this.cfg.model;
      let tools = req.tools;
      let toolChoice = req.tools?.length ? req.toolChoice : undefined;
      // Only Haiku is known to take thinking:disabled; other models (Sonnet/Opus 5.5) reject it with a 400,
      // so it is sent for Haiku only and dropped on a "thinking" 400 (effort stays low either way).
      const send = (withThinking: boolean) =>
        this.fetchImpl(
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
              model,
              max_tokens: req.think ? req.maxTokens + 6000 : req.maxTokens,
              stream: true,
              system: req.cacheSystem
                ? [{ type: "text", text: req.system, cache_control: { type: "ephemeral" } }]
                : req.system,
              messages: [{
                role: "user",
                content: req.images?.length
                  ? [
                    ...req.images.map((im) => ({
                      type: "image",
                      source: { type: "base64", media_type: im.mediaType, data: im.data },
                    })),
                    { type: "text", text: req.user },
                  ]
                  : req.user,
              }],
              output_config: { effort: req.think ? "high" : this.cfg.effort },
              ...(req.think ? { thinking: { type: "adaptive" } } : {}),
              ...(withThinking && !req.think
                ? { thinking: { type: /sonnet-5-5/i.test(model) ? "between_tools" : "disabled" } }
                : {}),
              ...(tools?.length ? { tools } : {}),
              ...(tools?.length && toolChoice ? { tool_choice: toolChoice } : {}),
            }),
            signal,
          },
        );
      // D87: Sonnet 5.5 takes no `disabled`; `between_tools` turns thinking off (at effort high or below)
      const wantThinkingOff = this.cfg.disableThinking &&
        (/haiku/i.test(model) || (req.noThinking === true && /sonnet-5-5/i.test(model)));
      let res = await send(wantThinkingOff);
      if (res.status === 400 && wantThinkingOff) {
        const peek = await res.clone().text().catch(() => "");
        if (/thinking/i.test(peek)) res = await send(false);
      }
      if (res.status === 400 && toolChoice) {
        // A model that does not take a forced tool choice: send the same request without it (D72).
        const peek = await res.clone().text().catch(() => "");
        if (/tool_choice/i.test(peek)) {
          toolChoice = undefined;
          res = await send(wantThinkingOff);
        }
      }
      if (res.status === 400 && tools?.length) {
        // A domain on the allow-list started blocking Anthropic's crawler: drop it and retry once.
        const peek = await res.clone().text().catch(() => "");
        const bad = /not accessible to our user agent: \[([^\]]*)\]/.exec(peek)?.[1];
        if (bad) {
          const drop = new Set(bad.match(/[a-z0-9][a-z0-9.-]*\.[a-z]{2,}/gi) ?? []);
          tools = withoutDomains(tools, drop);
          res = await send(wantThinkingOff);
        }
      }
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
            err?.type ?? "stream_error",
          );
        }
        const stop = ev.type === "message_delta"
          ? (ev.delta as { stop_reason?: string } | undefined)?.stop_reason
          : undefined;
        if (stop === "refusal") {
          throw new LLMProviderError("bad_request", "Provider refused the request");
        }
        if (stop === "pause_turn" && !emitted) {
          // A long search turn the API paused; continuing needs the encrypted blocks back. Fail closed.
          throw new LLMProviderError("unavailable", "Search turn paused", 529);
        }
        const chunk = mapAnthropicEvent(ev);
        const out = gate ? gate.filter(ev, chunk) : chunk ? [chunk] : [];
        for (const c of out) {
          if (c.type === "text") emitted = true;
          yield c;
        }
      }
    } catch (e) {
      if (e instanceof LLMProviderError) throw e;
      if (req.signal?.aborted) throw e;
      const status = (e as { status?: number }).status;
      const err = e instanceof Error ? e : undefined;
      const cause = (err as { cause?: unknown } | undefined)?.cause;
      const causeText = cause instanceof Error ? ` (cause: ${cause.name}: ${cause.message})` : "";
      const message = redactSecrets((err?.message ?? String(e)) + causeText, this.cfg.apiKey);
      throw classifyAnthropicError(status, message, err?.name);
    }
  }
}
