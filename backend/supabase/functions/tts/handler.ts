import { type Authenticator } from "../_shared/auth.ts";
import { CORS_HEADERS, errorResponse, HttpError, toHttpError } from "../_shared/errors.ts";
import { enforceLimits, type Limits, type RateLimiter } from "../_shared/ratelimit.ts";
import { readLimitedJson } from "../answer/validate.ts";

export const TTS_LIMITS = { bodyBytes: 4 * 1024, text: 500 } as const;
const OUTPUT_FORMATS = new Set(["mp3_22050_32", "mp3_44100_64", "pcm_16000", "pcm_24000"]);
const CONTENT_TYPES: Record<string, string> = { mp3: "audio/mpeg", pcm: "audio/L16" };

export interface TtsConfig {
  voiceId: string | null;
  modelId: string; // eleven_flash_v2_5: low latency, supports Swedish [docs]
  /** Limits are in CHARACTERS (ElevenLabs bills credits per character). */
  limits: Limits;
}

export const DEFAULT_TTS_CONFIG: Omit<TtsConfig, "voiceId"> = {
  modelId: "eleven_flash_v2_5",
  limits: { perMinute: 1500, perDay: 15000, globalPerDay: 100000 },
};

export interface TtsDeps {
  authenticate: Authenticator;
  rateLimiter: RateLimiter;
  apiKey: string | null;
  config: TtsConfig;
  recordUsage: (rec: Record<string, unknown>) => void | Promise<void>;
  fetchImpl?: typeof fetch;
}

export function classifyElevenLabs(status: number, body: string): HttpError {
  const b = body.toLowerCase();
  if (status === 401 && (b.includes("quota") || b.includes("exceeded"))) {
    return new HttpError(503, "provider_quota", "TTS credits exhausted", { fallback: true });
  }
  if (status === 402 || b.includes("quota_exceeded") || b.includes("credits")) {
    return new HttpError(503, "provider_quota", "TTS credits exhausted", { fallback: true });
  }
  if (status === 401 || status === 403) {
    return new HttpError(503, "provider_misconfigured", "TTS credentials rejected", {
      fallback: true,
    });
  }
  if (status === 429) {
    return new HttpError(503, "provider_busy", "TTS rate limited", {
      fallback: true,
      retryAfterSec: 5,
    });
  }
  if (status === 400 || status === 422) {
    return new HttpError(502, "provider_error", "TTS rejected the request", { fallback: true });
  }
  return new HttpError(502, "provider_unavailable", "TTS provider unavailable", { fallback: true });
}

export function createTtsHandler(deps: TtsDeps): (req: Request) => Promise<Response> {
  const doFetch = deps.fetchImpl ?? fetch;
  return async (req) => {
    if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS_HEADERS });
    const t0 = performance.now();
    try {
      if (req.method !== "POST") throw new HttpError(405, "method_not_allowed", "Use POST");
      const user = await deps.authenticate(req);
      const raw = await readLimitedJson(req, TTS_LIMITS.bodyBytes) as Record<string, unknown>;
      const text = typeof raw?.text === "string" ? raw.text.trim() : "";
      if (!text) throw new HttpError(400, "invalid_request", "text is required");
      if (text.length > TTS_LIMITS.text) {
        throw new HttpError(413, "payload_too_large", `text exceeds ${TTS_LIMITS.text} characters`);
      }
      const language = raw.language === "en" ? "en" : "sv";
      const format = typeof raw.output_format === "string" ? raw.output_format : "mp3_44100_64";
      if (!OUTPUT_FORMATS.has(format)) {
        throw new HttpError(400, "invalid_request", "unsupported output_format");
      }
      const voiceId = typeof raw.voice_id === "string" ? raw.voice_id : deps.config.voiceId;
      if (!voiceId || !/^[A-Za-z0-9]{10,40}$/.test(voiceId)) {
        throw new HttpError(503, "provider_unconfigured", "No TTS voice configured", {
          fallback: true,
        });
      }
      if (!deps.apiKey) {
        throw new HttpError(503, "provider_unconfigured", "TTS not configured", { fallback: true });
      }

      // Charge characters before calling ElevenLabs (fail closed on our own budget).
      const rl = await enforceLimits(
        deps.rateLimiter,
        "tts",
        user.id,
        deps.config.limits,
        text.length,
      );
      if (!rl.allowed) {
        throw new HttpError(429, "rate_limited", "TTS budget reached", {
          fallback: true,
          retryAfterSec: rl.retryAfterSec,
        });
      }

      let upstream: Response;
      try {
        upstream = await doFetch(
          `https://api.elevenlabs.io/v1/text-to-speech/${voiceId}/stream?output_format=${format}`,
          {
            method: "POST",
            headers: {
              "xi-api-key": deps.apiKey,
              "content-type": "application/json",
              accept: "audio/*",
            },
            body: JSON.stringify({ text, model_id: deps.config.modelId, language_code: language }),
            signal: req.signal,
          },
        );
      } catch (_e) {
        throw new HttpError(502, "provider_unavailable", "TTS provider unreachable", {
          fallback: true,
        });
      }
      if (!upstream.ok) {
        const body = await upstream.text().catch(() => "");
        const err = classifyElevenLabs(upstream.status, body);
        await Promise.resolve(deps.recordUsage(rec(err.code))).catch(() => {});
        throw err;
      }
      await Promise.resolve(deps.recordUsage(rec("ok"))).catch(() => {});
      return new Response(upstream.body, {
        status: 200,
        headers: {
          "content-type": CONTENT_TYPES[format.split("_")[0]] ?? "application/octet-stream",
          "cache-control": "no-store",
          "x-audio-format": format,
          ...CORS_HEADERS,
        },
      });

      function rec(status: string) {
        return {
          user_id: user.id,
          endpoint: "tts",
          language,
          provider: "elevenlabs",
          model: deps.config.modelId,
          chars: text.length,
          total_ms: Math.round(performance.now() - t0),
          status,
        };
      }
    } catch (e) {
      return errorResponse(toHttpError(e));
    }
  };
}
