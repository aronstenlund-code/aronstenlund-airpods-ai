// POST /functions/v1/tts  - streams ElevenLabs audio (TTS only; never ElevenLabs Agents).
import { demoCapsFromEnv } from "../_shared/demo.ts";
import { extraOriginsFromEnv, withCors } from "../_shared/cors.ts";
import { createJwtAuthenticator } from "../_shared/auth.ts";
import { MemoryRateLimiter, SupabaseRateLimiter } from "../_shared/ratelimit.ts";
import { restDbFromEnv } from "../_shared/restdb.ts";
import { envInt, supabaseUsageSink } from "../_shared/usage.ts";
import { createTtsHandler, DEFAULT_TTS_CONFIG } from "./handler.ts";
import { parseVoices } from "./voices.ts";

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
  apiKey: env.get("ELEVENLABS_API_KEY") ?? null,
  recordUsage: supabaseUsageSink(db),
  demo: demoCapsFromEnv(env),
  config: {
    voiceId: env.get("ELEVENLABS_VOICE_ID") ?? null,
    voices,
    baseUrl: env.get("ELEVENLABS_BASE_URL") || undefined,
    modelId: env.get("ELEVENLABS_MODEL_ID") ?? DEFAULT_TTS_CONFIG.modelId,
    limits: {
      perMinute: envInt(env, "TTS_CHARS_PER_MINUTE", DEFAULT_TTS_CONFIG.limits.perMinute),
      perDay: envInt(env, "TTS_CHARS_PER_DAY", DEFAULT_TTS_CONFIG.limits.perDay),
      globalPerDay: envInt(env, "TTS_GLOBAL_CHARS_PER_DAY", DEFAULT_TTS_CONFIG.limits.globalPerDay),
    },
    networkCharsPerDay: envInt(env, "TTS_CHARS_PER_NETWORK_PER_DAY", DEFAULT_TTS_CONFIG.networkCharsPerDay!),
  },
});

Deno.serve(withCors(handler, extraOriginsFromEnv()));
