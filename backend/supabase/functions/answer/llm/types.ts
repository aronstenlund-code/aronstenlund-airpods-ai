export interface LLMRequest {
  system: string;
  user: string;
  maxTokens: number;
  /** Mark the (static) system prompt cacheable (prompt caching; ignored by providers without it). */
  cacheSystem?: boolean;
  signal?: AbortSignal;
}

export type LLMChunk =
  | { type: "text"; text: string }
  | {
    type: "usage";
    inputTokens?: number;
    outputTokens?: number;
    cacheReadTokens?: number;
    cacheWriteTokens?: number;
  };

/** Provider-agnostic streaming LLM. Implementations must yield `text` chunks as they arrive and a
 *  `usage` chunk (possibly several, last wins per field) so cost per answer can be measured. */
export interface LLMProvider {
  readonly name: string;
  readonly model: string;
  stream(req: LLMRequest): AsyncIterable<LLMChunk>;
}

export type LLMErrorKind =
  | "quota" // out of credits / billing problem -> app must fall back (fail closed)
  | "rate_limited" // upstream 429
  | "auth" // bad/missing key
  | "unavailable" // 5xx / overloaded / network
  | "bad_request"
  | "unconfigured";

export class LLMProviderError extends Error {
  constructor(readonly kind: LLMErrorKind, message: string, readonly status?: number) {
    super(message);
    this.name = "LLMProviderError";
  }
}
