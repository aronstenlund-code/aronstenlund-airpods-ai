import { type Authenticator } from "../_shared/auth.ts";
import { CORS_HEADERS, errorResponse, HttpError, toHttpError } from "../_shared/errors.ts";
import { appChecks, enforceLimits, type Limits, type RateLimiter } from "../_shared/ratelimit.ts";
import { readLimitedJson } from "../answer/validate.ts";
import { DEFAULT_DEMO_CAPS, type DemoCaps, enforceDemo, networkKey } from "../_shared/demo.ts";
import { type Voice, VOICE_ID_RE } from "./voices.ts";

/** D46 item 9: models the app/webtest may ask for (A/B by ear). multilingual costs 2 credits per character. */
export const TTS_MODELS: Record<string, number> = {
  eleven_flash_v2_5: 1,
  eleven_turbo_v2_5: 1,
  eleven_multilingual_v2: 2,
};
/**
 * D48: ask ElevenLabs for zero retention (`enable_logging=false`). Verified live 2026-11-05: the parameter is
 * accepted (HTTP 200) on the current plan; the STT socket answers with a warning that zero retention is only
 * applied for enterprise/trial plans. If a plan ever REJECTS the parameter we drop it silently (once).
 */
let zeroRetention = true;
export function _resetZeroRetention(v = true) {
  zeroRetention = v;
}
/**
 * D67: optional ElevenLabs `voice_settings` (all numbers, validated): stability 0-1 (lower = more varied, can
 * stretch or slur long words; higher = steadier), similarity_boost 0-1, style 0-1, speed 0.7-1.2.
 * Not available in the demo (default settings only).
 */
export function parseVoiceSettings(v: unknown): Record<string, number | boolean> | null {
  if (v === undefined || v === null) return null;
  if (typeof v !== "object" || Array.isArray(v)) {
    throw new HttpError(400, "invalid_request", "voice_settings must be an object");
  }
  const o = v as Record<string, unknown>;
  const out: Record<string, number | boolean> = {};
  const ranges: Record<string, [number, number]> = {
    stability: [0, 1],
    similarity_boost: [0, 1],
    style: [0, 1],
    speed: [0.7, 1.2],
  };
  for (const [k, val] of Object.entries(o)) {
    if (k === "use_speaker_boost") {
      if (typeof val !== "boolean") {
        throw new HttpError(400, "invalid_request", "use_speaker_boost must be a boolean");
      }
      out[k] = val;
    } else if (k in ranges) {
      const [lo, hi] = ranges[k];
      if (typeof val !== "number" || !Number.isFinite(val) || val < lo || val > hi) {
        throw new HttpError(
          400,
          "invalid_request",
          `voice_settings.${k} must be a number between ${lo} and ${hi}`,
        );
      }
      out[k] = val;
    } else {
      throw new HttpError(400, "invalid_request", `unsupported voice_settings field: ${k}`);
    }
  }
  return Object.keys(out).length ? out : null;
}

export const TTS_LIMITS = { bodyBytes: 4 * 1024, text: 500 } as const;
const OUTPUT_FORMATS = new Set(["mp3_22050_32", "mp3_44100_64", "pcm_16000", "pcm_24000"]);
const CONTENT_TYPES: Record<string, string> = { mp3: "audio/mpeg", pcm: "audio/L16" };

export interface TtsConfig {
  /** Default voice (secret ELEVENLABS_VOICE_ID). Falls back to the first allowlisted voice. */
  voiceId: string | null;
  /** Allowlist (secret ELEVENLABS_VOICES). A requested voice_id must be one of these or the default. */
  voices: Voice[];
  /** Override for tests/proxies; default https://api.elevenlabs.io */
  baseUrl?: string;
  modelId: string; // eleven_flash_v2_5: low latency, supports Swedish [docs]
  /** Limits are in CHARACTERS (ElevenLabs bills credits per character). */
  limits: Limits;
  /** D79: characters per network (hashed IP) and UTC day for the app; 0 = off. */
  networkCharsPerDay?: number;
}

export const DEFAULT_TTS_CONFIG: Omit<TtsConfig, "voiceId" | "voices"> = {
  modelId: "eleven_flash_v2_5",
  limits: { perMinute: 1500, perDay: 15000, globalPerDay: 100000 },
  networkCharsPerDay: 30000,
};

export interface TtsDeps {
  authenticate: Authenticator;
  rateLimiter: RateLimiter;
  /** Cheap per-isolate guard (characters/minute) checked before ElevenLabs is called. */
  localLimiter?: RateLimiter;
  apiKey: string | null;
  config: TtsConfig;
  recordUsage: (rec: Record<string, unknown>) => void | Promise<void>;
  fetchImpl?: typeof fetch;
  /** Called for `GET` + `x-warm: 1`: open the upstream connection ahead of time. */
  warm?: () => void;
  /** D62 demo caps (defaults in _shared/demo.ts). */
  demo?: DemoCaps;
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
    if (req.method === "GET" && req.headers.get("x-warm") === "1") {
      deps.warm?.();
      return new Response(null, { status: 204 });
    }
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
      // D62: the public demo gets the default voice and model only, short text, and its own daily caps.
      const demo = raw.source === "demo";
      if (demo) {
        const caps = deps.demo ?? DEFAULT_DEMO_CAPS;
        if (text.length > caps.ttsCharsPerRequest) {
          throw new HttpError(
            413,
            "demo_text_too_long",
            `Demon läser högst ${caps.ttsCharsPerRequest} tecken åt gången.`,
          );
        }
        await enforceDemo(
          deps.rateLimiter,
          "tts",
          user.id,
          await networkKey(req),
          caps,
          text.length,
        );
      }
      const language = raw.language === "en" ? "en" : "sv";
      const modelId = demo || raw.model === undefined || raw.model === null
        ? deps.config.modelId
        : typeof raw.model === "string" && raw.model in TTS_MODELS
        ? raw.model
        : null;
      if (modelId === null) throw new HttpError(400, "invalid_request", "unsupported model");
      const weight = TTS_MODELS[modelId] ?? 1;
      const cost = text.length * weight;
      const voiceSettings = demo ? null : parseVoiceSettings(raw.voice_settings);
      const format = !demo && typeof raw.output_format === "string"
        ? raw.output_format
        : "mp3_44100_64";
      if (!OUTPUT_FORMATS.has(format)) {
        throw new HttpError(400, "invalid_request", "unsupported output_format");
      }
      const requested = demo || raw.voice_id === undefined || raw.voice_id === null
        ? null
        : raw.voice_id;
      if (requested !== null) {
        const allowed = typeof requested === "string" &&
          (deps.config.voices.some((v) => v.id === requested) || requested === deps.config.voiceId);
        if (!allowed) {
          throw new HttpError(
            400,
            "invalid_voice",
            "voice_id is not one of the allowed voices (see GET /voices)",
          );
        }
      }
      const voiceId = (requested as string | null) ?? deps.config.voiceId ??
        deps.config.voices[0]?.id ?? null;
      if (!voiceId || !VOICE_ID_RE.test(voiceId)) {
        throw new HttpError(503, "provider_unconfigured", "No TTS voice configured", {
          fallback: true,
        });
      }
      if (!deps.apiKey) {
        throw new HttpError(503, "provider_unconfigured", "TTS not configured", { fallback: true });
      }

      // Local guard first (0 ms), then the shared character budget IN PARALLEL with the ElevenLabs
      // request: the audio response is only released once the budget check has passed, so a denied
      // request never returns audio (it costs at most the aborted upstream start).
      if (deps.localLimiter) {
        const lr = await deps.localLimiter.check(
          `tts:u:${user.id}:m`,
          deps.config.limits.perMinute,
          60,
          cost,
        );
        if (!lr.allowed) {
          throw new HttpError(429, "rate_limited", "TTS budget reached", {
            fallback: true,
            retryAfterSec: lr.retryAfterSec,
          });
        }
      }
      const ac = new AbortController();
      req.signal.addEventListener("abort", () => ac.abort());
      // D79: the app's characters are also capped per network (the demo has its own caps above).
      const ttsExtra = demo ? [] : appChecks("tts", await networkKey(req), user, {
        networkPerDay: deps.config.networkCharsPerDay ?? DEFAULT_TTS_CONFIG.networkCharsPerDay!,
        newUserAgeSec: 0,
        newUserPerHour: 0,
      });
      const limitsP = enforceLimits(
        deps.rateLimiter,
        "tts",
        user.id,
        deps.config.limits,
        cost,
        ttsExtra,
      );
      const callUpstream = (zr: boolean) =>
        doFetch(
          `${
            deps.config.baseUrl ?? "https://api.elevenlabs.io"
          }/v1/text-to-speech/${voiceId}/stream?output_format=${format}${
            zr ? "&enable_logging=false" : ""
          }`,
          {
            method: "POST",
            headers: {
              "xi-api-key": deps.apiKey!,
              "content-type": "application/json",
              accept: "audio/*",
            },
            body: JSON.stringify({
              text,
              model_id: modelId,
              language_code: language,
              ...(voiceSettings ? { voice_settings: voiceSettings } : {}),
            }),
            signal: ac.signal,
          },
        );
      const usedZr = zeroRetention;
      const upstreamP = callUpstream(usedZr);
      upstreamP.catch(() => {}); // handled below, or deliberately dropped when the budget denies

      const rl = await limitsP;
      if (!rl.allowed) {
        ac.abort();
        upstreamP.then((r) => r.body?.cancel()).catch(() => {});
        throw new HttpError(429, "rate_limited", "TTS budget reached", {
          fallback: true,
          retryAfterSec: rl.retryAfterSec,
        });
      }

      let upstream: Response;
      try {
        upstream = await upstreamP;
      } catch (_e) {
        throw new HttpError(502, "provider_unavailable", "TTS provider unreachable", {
          fallback: true,
        });
      }
      if (!upstream.ok && usedZr && upstream.status >= 400 && upstream.status < 500) {
        const peek = await upstream.text().catch(() => "");
        if (/logging|retention/i.test(peek)) {
          zeroRetention = false; // the plan rejects it: continue without, silently
          upstream = await callUpstream(false);
        } else {
          upstream = new Response(peek, { status: upstream.status });
        }
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
          model: modelId,
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
