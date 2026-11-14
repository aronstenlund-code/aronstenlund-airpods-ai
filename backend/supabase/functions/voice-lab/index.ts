// POST /functions/v1/voice-lab - K6 voice design previews, service role only (no voice is saved to the account).
import { extraOriginsFromEnv, withCors } from "../_shared/cors.ts";
import { secret } from "../_shared/secrets.ts";
import { createVoiceLabHandler } from "./handler.ts";
import { parseVoices } from "../tts/voices.ts";
import { CORS_HEADERS } from "../_shared/errors.ts";
import { guardedFetch, runWithTest, silentMp3 } from "../_shared/testmode.ts";

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
  fetchImpl: guardedFetch(fetch, "voice-lab"),
});

/**
 * K62b (D180): voice-lab is only ever called by scripts and workflows, so it is a test unless the caller sends
 * x-earmind-real-audio equal to the secret VOICE_LAB_REAL_AUDIO_TOKEN, which only Aron sets (his yes in chat first).
 */
const realToken = secret(Deno.env, "VOICE_LAB_REAL_AUDIO_TOKEN");
const b64 = (u: Uint8Array) => {
  let s = "";
  for (let i = 0; i < u.length; i += 0x8000) s += String.fromCharCode(...u.subarray(i, i + 0x8000));
  return btoa(s);
};
Deno.serve(withCors(async (req: Request) => {
  if (req.method === "OPTIONS") return handler(req);
  const real = !!realToken && req.headers.get("x-earmind-real-audio") === realToken;
  if (real) return handler(req);
  const b = (await req.clone().json().catch(() => null)) as Record<string, unknown> | null;
  console.log("test_request", JSON.stringify({ fn: "voice-lab", reason: "script", action: b?.action ?? null }));
  const ok = (body: unknown) =>
    new Response(JSON.stringify({ ...(body as object), fake: true }), { status: 200, headers: { "content-type": "application/json", "cache-control": "no-store", ...CORS_HEADERS } });
  const audio = b64(silentMp3(1));
  if (b?.action === "sample") return ok({ audio_base_64: audio, media_type: "audio/mpeg", model: b.model ?? null, chars: String(b.text ?? "").length, character_cost: 0 });
  if (b?.action === "previews") return ok({ previews: [{ generated_voice_id: "fake", audio_base_64: audio, media_type: "audio/mpeg", duration_secs: 1 }], text: b.text ?? "" });
  return runWithTest({ test: true, reason: "script", userId: null }, () => handler(req));
}, extraOriginsFromEnv()));
