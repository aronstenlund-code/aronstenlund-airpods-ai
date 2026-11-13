// POST /functions/v1/voice-lab - K6 voice design previews, service role only (no voice is saved to the account).
import { extraOriginsFromEnv, withCors } from "../_shared/cors.ts";
import { secret } from "../_shared/secrets.ts";
import { createVoiceLabHandler } from "./handler.ts";
import { parseVoices } from "../tts/voices.ts";

const base = (Deno.env.get("SUPABASE_URL") ?? "").replace(/\/+$/, "");
const verified = new Map<string, boolean>();
/** A table only service keys can read (RLS on, no grants to anon/authenticated): 200 = a service key. */
async function verifyServiceKey(key: string): Promise<boolean> {
  if (verified.has(key)) return verified.get(key)!;
  const headers: Record<string, string> = { apikey: key };
  if (key.startsWith("eyJ")) headers.authorization = `Bearer ${key}`;
  const r = await fetch(`${base}/rest/v1/drill_audio_files?select=hash&limit=1`, { headers });
  await r.body?.cancel();
  const ok = r.status === 200;
  verified.set(key, ok);
  return ok;
}

const handler = createVoiceLabHandler({
  verifyServiceKey,
  serviceKey: secret(Deno.env, "SUPABASE_SERVICE_ROLE_KEY"),
  elevenLabsKey: secret(Deno.env, "ELEVENLABS_API_KEY"),
  baseUrl: Deno.env.get("ELEVENLABS_BASE_URL") || undefined,
  // K48: the app's default voice, as /tts picks it (the secret, else the first allowlisted voice)
  voiceId: secret(Deno.env, "ELEVENLABS_VOICE_ID") ?? parseVoices(Deno.env.get("ELEVENLABS_VOICES")).voices[0]?.id ?? null,
});

Deno.serve(withCors(handler, extraOriginsFromEnv()));
