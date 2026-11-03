import { type Authenticator } from "../_shared/auth.ts";
import { CORS_HEADERS, errorResponse, HttpError, toHttpError } from "../_shared/errors.ts";
import { enforceLimits, type Limits, type RateLimiter } from "../_shared/ratelimit.ts";
import { type Voice } from "../tts/voices.ts";

export const VOICES_LIMITS: Limits = { perMinute: 30, perDay: 1000, globalPerDay: 20000 };

export interface VoicesDeps {
  authenticate: Authenticator;
  rateLimiter: RateLimiter;
  voices: Voice[];
  defaultVoiceId: string | null;
}

/** GET /voices -> { voices: [{name,id}], default_id }. Names and ids only; no secrets, no API calls. */
export function createVoicesHandler(deps: VoicesDeps): (req: Request) => Promise<Response> {
  return async (req) => {
    if (req.method === "OPTIONS") {
      return new Response(null, {
        status: 204,
        headers: { ...CORS_HEADERS, "access-control-allow-methods": "GET, OPTIONS" },
      });
    }
    try {
      if (req.method !== "GET") throw new HttpError(405, "method_not_allowed", "Use GET");
      const user = await deps.authenticate(req);
      const rl = await enforceLimits(deps.rateLimiter, "voices", user.id, VOICES_LIMITS);
      if (!rl.allowed) {
        throw new HttpError(429, "rate_limited", "Too many requests", {
          retryAfterSec: rl.retryAfterSec,
        });
      }
      const def = deps.defaultVoiceId ?? deps.voices[0]?.id ?? null;
      return new Response(
        JSON.stringify({
          voices: deps.voices.map((v) => ({ name: v.name, id: v.id })),
          default_id: def,
        }),
        {
          status: 200,
          headers: {
            "content-type": "application/json; charset=utf-8",
            "cache-control": "private, max-age=300",
            ...CORS_HEADERS,
          },
        },
      );
    } catch (e) {
      return errorResponse(toHttpError(e));
    }
  };
}
