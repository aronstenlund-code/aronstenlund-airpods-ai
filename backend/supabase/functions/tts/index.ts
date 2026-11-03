// POST /functions/v1/tts  - streams ElevenLabs audio (TTS only; never ElevenLabs Agents).
import { createJwtAuthenticator } from "../_shared/auth.ts";
import { serviceClient, SupabaseRateLimiter } from "../_shared/ratelimit.ts";
import { envInt, supabaseUsageSink } from "../_shared/usage.ts";
import { createTtsHandler, DEFAULT_TTS_CONFIG } from "./handler.ts";
import { parseVoices } from "./voices.ts";

const env = Deno.env;
const db = serviceClient();
const { voices, errors: voiceErrors } = parseVoices(env.get("ELEVENLABS_VOICES"));
if (voiceErrors.length) console.error("ELEVENLABS_VOICES problems:", voiceErrors.join("; "));

Deno.serve(createTtsHandler({
  authenticate: createJwtAuthenticator({
    supabaseUrl: env.get("SUPABASE_URL")!,
    hs256Secret: env.get("SUPABASE_JWT_SECRET"),
  }),
  rateLimiter: new SupabaseRateLimiter(db),
  apiKey: env.get("ELEVENLABS_API_KEY") ?? null,
  recordUsage: supabaseUsageSink(db),
  config: {
    voiceId: env.get("ELEVENLABS_VOICE_ID") ?? null,
    voices,
    modelId: env.get("ELEVENLABS_MODEL_ID") ?? DEFAULT_TTS_CONFIG.modelId,
    limits: {
      perMinute: envInt(env, "TTS_CHARS_PER_MINUTE", DEFAULT_TTS_CONFIG.limits.perMinute),
      perDay: envInt(env, "TTS_CHARS_PER_DAY", DEFAULT_TTS_CONFIG.limits.perDay),
      globalPerDay: envInt(env, "TTS_GLOBAL_CHARS_PER_DAY", DEFAULT_TTS_CONFIG.limits.globalPerDay),
    },
  },
}));
