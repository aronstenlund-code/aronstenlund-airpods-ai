import Anthropic from "npm:@anthropic-ai/sdk@1.3.0";
import { type LLMChunk, type LLMProvider, LLMProviderError, type LLMRequest } from "./types.ts";

export interface AnthropicConfig {
  apiKey: string;
  model: string; // default claude-haiku-5-5
  effort: "low" | "medium" | "high";
  disableThinking: boolean;
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
    case "message_start":
      return {
        type: "usage",
        inputTokens: ev.message?.usage?.input_tokens,
        outputTokens: ev.message?.usage?.output_tokens,
      };
    case "content_block_delta":
      if (ev.delta?.type === "text_delta" && typeof ev.delta.text === "string" && ev.delta.text) {
        return { type: "text", text: ev.delta.text };
      }
      return null;
    case "message_delta":
      return {
        type: "usage",
        outputTokens: ev.usage?.output_tokens,
        inputTokens: ev.usage?.input_tokens,
      };
    default:
      return null;
  }
}

export class AnthropicProvider implements LLMProvider {
  readonly name = "anthropic";
  readonly model: string;
  private client: Anthropic;

  constructor(private cfg: AnthropicConfig) {
    this.model = cfg.model;
    // maxRetries 0: a retry would double latency; the app has its own fallback.
    this.client = new Anthropic({ apiKey: cfg.apiKey, maxRetries: 0, timeout: 20_000 });
  }

  async *stream(req: LLMRequest): AsyncIterable<LLMChunk> {
    try {
      // Haiku 5.5: temperature/top_p/top_k must be omitted. Thinking off + low effort = lowest latency.
      const stream = await this.client.messages.create({
        model: this.cfg.model,
        max_tokens: req.maxTokens,
        stream: true,
        system: req.system,
        messages: [{ role: "user", content: req.user }],
        output_config: { effort: this.cfg.effort },
        ...(this.cfg.disableThinking ? { thinking: { type: "disabled" as const } } : {}),
      }, { signal: req.signal });
      for await (const ev of stream) {
        if (ev.type === "message_delta" && ev.delta?.stop_reason === "refusal") {
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
