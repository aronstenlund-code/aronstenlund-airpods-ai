// POST /functions/v1/tts  - streams ElevenLabs audio (TTS only; never ElevenLabs Agents).
import { demoCapsFromEnv } from "../_shared/demo.ts";
import { secret } from "../_shared/secrets.ts";
import { extraOriginsFromEnv, withCors } from "../_shared/cors.ts";
import { createJwtAuthenticator } from "../_shared/auth.ts";
import { MemoryRateLimiter, SupabaseRateLimiter } from "../_shared/ratelimit.ts";
import { restDbFromEnv } from "../_shared/restdb.ts";
import { envInt, supabaseUsageSink } from "../_shared/usage.ts";
import { createTtsHandler, DEFAULT_TTS_CONFIG } from "./handler.ts";
import { parseVoices } from "./voices.ts";
import { CORS_HEADERS } from "../_shared/errors.ts";
import { guardedFetch, silentMp3, withTestMode } from "../_shared/testmode.ts";

const env = Deno.env;

// Open the TLS connection to ElevenLabs while the isolate boots (unauthenticated GET; no credits used).
const warmUpstream = () =>
  void fetch(`${env.get("ELEVENLABS_BASE_URL") || "https://api.elevenlabs.io"}/v1/models`).then((
    r,
  ) => r.body?.cancel()).catch(() => {});
warmUpstream();
const db = restDbFromEnv();
const { voices, errors: voiceErrors } = parseVoices(env.get("ELEVENLABS_VOICES"));
if (voiceErrors.length) console.error("ELEVENLABS_VOICES problems:", voiceErrors.join("; "));

const handler = createTtsHandler({
  authenticate: createJwtAuthenticator({
    supabaseUrl: env.get("SUPABASE_URL")!,
    hs256Secret: env.get("SUPABASE_JWT_SECRET"),
  }),
  rateLimiter: new SupabaseRateLimiter(db),
  localLimiter: new MemoryRateLimiter(),
  warm: warmUpstream,
  apiKey: secret(env, "ELEVENLABS_API_KEY"),
  recordUsage: supabaseUsageSink(db),
  demo: demoCapsFromEnv(env),
  fetchImpl: guardedFetch(fetch, "tts"), // K62b: a test request that gets this far throws
  config: {
    voiceId: env.get("ELEVENLABS_VOICE_ID") ?? null,
    voices,
    baseUrl: env.get("ELEVENLABS_BASE_URL") || undefined,
    modelId: env.get("ELEVENLABS_MODEL_ID") ?? DEFAULT_TTS_CONFIG.modelId,
    fallbackModelId: env.get("ELEVENLABS_FALLBACK_MODEL_ID") ?? DEFAULT_TTS_CONFIG.fallbackModelId,
    limits: {
      perMinute: envInt(env, "TTS_CHARS_PER_MINUTE", DEFAULT_TTS_CONFIG.limits.perMinute),
      perDay: envInt(env, "TTS_CHARS_PER_DAY", DEFAULT_TTS_CONFIG.limits.perDay),
      globalPerDay: envInt(env, "TTS_GLOBAL_CHARS_PER_DAY", DEFAULT_TTS_CONFIG.limits.globalPerDay),
    },
    networkCharsPerDay: envInt(env, "TTS_CHARS_PER_NETWORK_PER_DAY", DEFAULT_TTS_CONFIG.networkCharsPerDay!),
  },
});

// K62b (D180): test traffic gets one second of silence, never ElevenLabs
const fake = (req: Request) =>
  req.method === "POST"
    ? new Response(silentMp3(1), { status: 200, headers: { "content-type": "audio/mpeg", "cache-control": "no-store", "x-earmind-fake": "1", ...CORS_HEADERS } })
    : null;
Deno.serve(withCors(withTestMode("tts", handler, { fake }), extraOriginsFromEnv()));
