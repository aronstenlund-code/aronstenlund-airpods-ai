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

export function toHttpError(e: unknown): HttpError {
  if (e instanceof HttpError) return e;
  console.error("unexpected_error", e instanceof Error ? e.message : String(e));
  return new HttpError(500, "internal", "Internal error", { fallback: true });
}
