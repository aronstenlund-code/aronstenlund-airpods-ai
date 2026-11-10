// POST /functions/v1/voice-lab - K6 voice design previews, service role only (no voice is saved to the account).
import { extraOriginsFromEnv, withCors } from "../_shared/cors.ts";
import { secret } from "../_shared/secrets.ts";
import { createVoiceLabHandler } from "./handler.ts";

const handler = createVoiceLabHandler({
  serviceKey: secret(Deno.env, "SUPABASE_SERVICE_ROLE_KEY"),
  elevenLabsKey: secret(Deno.env, "ELEVENLABS_API_KEY"),
  baseUrl: Deno.env.get("ELEVENLABS_BASE_URL") || undefined,
});

Deno.serve(withCors(handler, extraOriginsFromEnv()));
