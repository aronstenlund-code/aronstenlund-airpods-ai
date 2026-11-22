import { LLMProviderError } from "../answer/llm/types.ts";

/** Errors that map 1:1 to an HTTP response. Every body is `{ error: { code, message, fallback } }`.
 *  `fallback: true` tells the app to switch to Apple TTS / the on-device answer engine. */
export class HttpError extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    message: string,
    readonly opts: { fallback?: boolean; retryAfterSec?: number } = {},
  ) {
    super(message);
    this.name = "HttpError";
  }
}

export const CORS_HEADERS: Record<string, string> = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, apikey, content-type, x-client-info",
  "access-control-allow-methods": "POST, OPTIONS",
};

export function errorBody(e: HttpError): string {
  return JSON.stringify({
    error: { code: e.code, message: e.message, fallback: e.opts.fallback ?? false },
  });
}

export function errorResponse(e: HttpError): Response {
  const headers: Record<string, string> = {
    "content-type": "application/json; charset=utf-8",
    ...CORS_HEADERS,
  };
  if (e.opts.retryAfterSec !== undefined) headers["retry-after"] = String(e.opts.retryAfterSec);
  return new Response(errorBody(e), { status: e.status, headers });
}

/** The model provider's errors as HTTP (D46: fail closed, the app falls back). One mapping for /answer, /exam and
 *  /drill (O97: /exam answered 500 "internal" when Anthropic's credits were gone, so the app could not say why). */
export const PROVIDER_DOWN = "EarMind är nere en stund. Försök igen senare.";
export const PROVIDER_BUSY = "EarMind har mycket att göra just nu. Försök igen om en stund.";
/** The codes say what happened (Diagnostik, evals); the message is for the user (the web shows it as it is), in
 *  Swedish here and in English through _shared/i18n.ts after the chosen language (K114). */
export function providerHttpError(e: LLMProviderError): HttpError {
  switch (e.kind) {
    case "quota":
      return new HttpError(503, "provider_quota", PROVIDER_DOWN, { fallback: true });
    case "rate_limited":
      return new HttpError(503, "provider_busy", PROVIDER_BUSY, { fallback: true, retryAfterSec: 5 });
    case "unconfigured":
      return new HttpError(503, "provider_unconfigured", PROVIDER_DOWN, { fallback: true });
    case "auth":
      return new HttpError(503, "provider_misconfigured", PROVIDER_DOWN, { fallback: true });
    case "bad_request":
      return new HttpError(502, "provider_error", PROVIDER_DOWN, { fallback: true });
    default:
      return new HttpError(502, "provider_unavailable", PROVIDER_DOWN, { fallback: true });
  }
}

export function toHttpError(e: unknown): HttpError {
  if (e instanceof HttpError) return e;
  if (e instanceof LLMProviderError) {
    console.error("provider_error", e.kind, e.status ?? "");
    return providerHttpError(e);
  }
  console.error("unexpected_error", e instanceof Error ? e.message : String(e));
  // K112 (D227): the app shows /drill's message, so a reviewer could see it: Swedish
  return new HttpError(500, "internal", "Något gick fel hos EarMind. Försök igen om en stund.", { fallback: true });
}
