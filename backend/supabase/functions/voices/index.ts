// GET /functions/v1/voices - the Swedish voices the app may offer (from secret ELEVENLABS_VOICES).
import { extraOriginsFromEnv, withCors } from "../_shared/cors.ts";
import { createJwtAuthenticator } from "../_shared/auth.ts";
import { SupabaseRateLimiter } from "../_shared/ratelimit.ts";
import { restDbFromEnv } from "../_shared/restdb.ts";
import { parseVoices } from "../tts/voices.ts";
import { createVoicesHandler } from "./handler.ts";

const env = Deno.env;
const { voices, errors } = parseVoices(env.get("ELEVENLABS_VOICES"));
if (errors.length) console.error("ELEVENLABS_VOICES problems:", errors.join("; "));

const handler = createVoicesHandler({
  authenticate: createJwtAuthenticator({
    supabaseUrl: env.get("SUPABASE_URL")!,
    hs256Secret: env.get("SUPABASE_JWT_SECRET"),
  }),
  rateLimiter: new SupabaseRateLimiter(restDbFromEnv()),
  voices,
  defaultVoiceId: env.get("ELEVENLABS_VOICE_ID") ?? null,
});

Deno.serve(withCors(handler, extraOriginsFromEnv()));
