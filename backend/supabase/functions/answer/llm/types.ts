export interface LLMRequest {
  system: string;
  user: string;
  maxTokens: number;
  /** Mark the (static) system prompt cacheable (prompt caching; ignored by providers without it). */
  cacheSystem?: boolean;
  /** Anthropic server tools (web search / fetch). Only set for requests that need the web. */
  tools?: unknown[];
  /** Forces a tool call (Anthropic `tool_choice`), e.g. `{type: "any"}` for an ordinal fact (D72). */
  toolChoice?: unknown;
  /** D87: no thinking even on models where it is on by default (Sonnet 5.5: `between_tools`). */
  noThinking?: boolean;
  /** K7.6: think before answering (adaptive thinking at effort high, room for it in max_tokens): word problems. */
  think?: boolean;
  /** K10.3: a per-user block after the cached system prompt (the profile), cached on its own. */
  systemTail?: string;
  /** Overrides the provider's default model for this request (D52: Rizz uses a stronger model). */
  model?: string;
  signal?: AbortSignal;
  /** K15: a longer limit for a slow, non-interactive call (Lumen's own exam answers); default by request kind. */
  timeoutMs?: number;
  /** K35: hold text until a tool call (then dropped) or the end (then released): Haiku may reason aloud first. */
  holdTextBeforeTool?: boolean;
  /** K35: the whole conversation instead of one user turn (a tool round: user, assistant tool_use, tool_result). */
  messages?: unknown[];
  /** D84: page images sent before the text (exam upload). base64 without the data: prefix. */
  images?: { mediaType: "image/jpeg" | "image/png" | "image/webp"; data: string }[];
}

export type LLMChunk =
  | { type: "text"; text: string }
  /** K11: text a web search result gave for a citation (`cited_text`), to check verbatim quotes. */
  | { type: "cite"; cited: string }
  /** K35: a client tool call the app runs (input null = the model's JSON did not parse). */
  | { type: "tool_use"; id: string; name: string; input: unknown }
  | {
    type: "usage";
    inputTokens?: number;
    outputTokens?: number;
    cacheReadTokens?: number;
    cacheWriteTokens?: number;
    /** web_search requests billed for this answer (server_tool_use.web_search_requests). */
    webSearches?: number;
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
