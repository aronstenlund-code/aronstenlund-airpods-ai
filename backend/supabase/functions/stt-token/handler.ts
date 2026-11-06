import { type Authenticator } from "../_shared/auth.ts";
import { CORS_HEADERS, errorResponse, HttpError, toHttpError } from "../_shared/errors.ts";
import { enforceLimits, type Limits, type RateLimiter } from "../_shared/ratelimit.ts";
import { DEFAULT_DEMO_CAPS, type DemoCaps, enforceDemo, networkKey } from "../_shared/demo.ts";
import { readLimitedJson } from "../answer/validate.ts";

/**
 * D44: `GET /stt-token` mints a single-use ElevenLabs token for Scribe v2 Realtime so the client can open
 * the speech-to-text WebSocket itself; the API key never leaves the backend.
 * ElevenLabs docs (2026-11-04): token type `realtime_scribe`, single use, expires after 15 minutes;
 * mint call `POST /v1/single-use-token/realtime_scribe` (verified live: it answers 401
 * `missing_permissions: speech_to_text` until the API key has that permission); model `scribe_v2_realtime`.
 * `POST /stt-token` with {seconds} logs the seconds the client actually streamed (billing is per second).
 */
export const STT_MODEL = "scribe_v2_realtime";
export const STT_PRICE_PER_HOUR_USD = 0.39; // pricing page (D44); plan allowance unverified
export const STT_TOKEN_TTL_SEC = 900;

export interface SttConfig {
  baseUrl?: string;
  /** Token mints per user/minute, per user/day, global/day. */
  limits: Limits;
}
export const DEFAULT_STT_CONFIG: SttConfig = {
  limits: { perMinute: 6, perDay: 120, globalPerDay: 600 },
};

export interface SttDeps {
  authenticate: Authenticator;
  rateLimiter: RateLimiter;
  apiKey: string | null;
  config: SttConfig;
  recordUsage: (rec: Record<string, unknown>) => void | Promise<void>;
  fetchImpl?: typeof fetch;
  /** D62 demo caps (defaults in _shared/demo.ts). */
  demo?: DemoCaps;
}

export function classifySttMint(status: number, body: string): HttpError {
  const b = body.toLowerCase();
  if (status === 401 && b.includes("missing_permissions")) {
    return new HttpError(503, "provider_misconfigured", "STT key lacks speech_to_text permission", {
      fallback: true,
    });
  }
  if (status === 401 || status === 403) {
    return new HttpError(503, "provider_misconfigured", "STT credentials rejected", {
      fallback: true,
    });
  }
  if (status === 402 || b.includes("quota")) {
    return new HttpError(503, "provider_quota", "STT credits exhausted", { fallback: true });
  }
  if (status === 429) {
    return new HttpError(503, "provider_busy", "STT rate limited", {
      fallback: true,
      retryAfterSec: 5,
    });
  }
  return new HttpError(502, "provider_unavailable", "STT provider unavailable", { fallback: true });
}

export function createSttHandler(deps: SttDeps) {
  const doFetch = deps.fetchImpl ?? fetch;
  return async (req: Request): Promise<Response> => {
    if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS_HEADERS });
    const t0 = performance.now();
    try {
      if (req.method !== "GET" && req.method !== "POST") {
        throw new HttpError(405, "method_not_allowed", "Use GET (mint) or POST (report seconds)");
      }
      const user = await deps.authenticate(req);
      if (req.method === "POST") {
        const raw = await readLimitedJson(req, 1024) as Record<string, unknown>;
        const sec = Number(raw?.seconds);
        if (!Number.isFinite(sec) || sec < 0 || sec > 3600) {
          throw new HttpError(
            400,
            "invalid_request",
            "seconds must be a number between 0 and 3600",
          );
        }
        const rl = await enforceLimits(deps.rateLimiter, "stt-report", user.id, {
          perMinute: 30,
          perDay: 2000,
          globalPerDay: 20000,
        });
        if (!rl.allowed) {
          throw new HttpError(429, "rate_limited", "Too many reports", {
            retryAfterSec: rl.retryAfterSec,
          });
        }
        await Promise.resolve(deps.recordUsage({
          user_id: user.id,
          endpoint: "stt",
          language: "sv",
          provider: "elevenlabs",
          model: STT_MODEL,
          total_ms: Math.round(sec * 1000),
          est_cost_usd: (sec / 3600) * STT_PRICE_PER_HOUR_USD,
          status: "ok",
        })).catch(() => {});
        return new Response(JSON.stringify({ ok: true }), {
          status: 200,
          headers: { "content-type": "application/json", ...CORS_HEADERS },
        });
      }
      // D62: `GET /stt-token?source=demo` is the public demo page: its own small daily caps.
      if (new URL(req.url).searchParams.get("source") === "demo") {
        await enforceDemo(
          deps.rateLimiter,
          "stt",
          user.id,
          await networkKey(req),
          deps.demo ?? DEFAULT_DEMO_CAPS,
        );
      }
      if (!deps.apiKey) {
        throw new HttpError(503, "provider_unconfigured", "STT provider not configured", {
          fallback: true,
        });
      }
      const rl = await enforceLimits(deps.rateLimiter, "stt", user.id, deps.config.limits);
      if (!rl.allowed) {
        throw new HttpError(429, "rate_limited", "Too many token requests", {
          fallback: true,
          retryAfterSec: rl.retryAfterSec,
        });
      }
      let res: Response;
      try {
        res = await doFetch(
          `${
            deps.config.baseUrl ?? "https://api.elevenlabs.io"
          }/v1/single-use-token/realtime_scribe`,
          {
            method: "POST",
            headers: { "xi-api-key": deps.apiKey },
            signal: AbortSignal.timeout(8000),
          },
        );
      } catch (_e) {
        throw new HttpError(502, "provider_unavailable", "STT provider unreachable", {
          fallback: true,
        });
      }
      const text = await res.text().catch(() => "");
      const rec = (status: string) => ({
        user_id: user.id,
        endpoint: "stt-token",
        language: "sv",
        provider: "elevenlabs",
        model: STT_MODEL,
        total_ms: Math.round(performance.now() - t0),
        status,
      });
      if (!res.ok) {
        const err = classifySttMint(res.status, text);
        await Promise.resolve(deps.recordUsage(rec(err.code))).catch(() => {});
        throw err;
      }
      let token = "";
      try {
        token = String(JSON.parse(text).token ?? "");
      } catch { /* handled below */ }
      if (!token) {
        throw new HttpError(502, "provider_error", "STT token missing in reply", {
          fallback: true,
        });
      }
      await Promise.resolve(deps.recordUsage(rec("ok"))).catch(() => {});
      return new Response(
        JSON.stringify({
          token,
          expires_in: STT_TOKEN_TTL_SEC,
          model_id: STT_MODEL,
          ws_url: "wss://api.elevenlabs.io/v1/speech-to-text/realtime",
          language_code: "swe",
          // D48/D44: privacy + noise params verified to be accepted (zero retention itself needs an
          // enterprise/trial plan: the socket then answers with a warning and carries on).
          extra_query: "enable_logging=false&filter_background_audio=true",
        }),
        {
          status: 200,
          headers: {
            "content-type": "application/json",
            "cache-control": "no-store",
            ...CORS_HEADERS,
          },
        },
      );
    } catch (e) {
      return errorResponse(toHttpError(e));
    }
  };
}
