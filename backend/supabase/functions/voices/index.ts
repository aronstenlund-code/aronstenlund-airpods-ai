// GET /functions/v1/voices - the Swedish voices the app may offer (from secret ELEVENLABS_VOICES).
import { createJwtAuthenticator } from "../_shared/auth.ts";
import { serviceClient, SupabaseRateLimiter } from "../_shared/ratelimit.ts";
import { parseVoices } from "../tts/voices.ts";
import { createVoicesHandler } from "./handler.ts";

const env = Deno.env;
const { voices, errors } = parseVoices(env.get("ELEVENLABS_VOICES"));
if (errors.length) console.error("ELEVENLABS_VOICES problems:", errors.join("; "));

Deno.serve(createVoicesHandler({
  authenticate: createJwtAuthenticator({
    supabaseUrl: env.get("SUPABASE_URL")!,
    hs256Secret: env.get("SUPABASE_JWT_SECRET"),
  }),
  rateLimiter: new SupabaseRateLimiter(serviceClient()),
  voices,
  defaultVoiceId: env.get("ELEVENLABS_VOICE_ID") ?? null,
}));
