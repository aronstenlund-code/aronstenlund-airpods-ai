// GET /functions/v1/voices - the Swedish voices the app may offer (from secret ELEVENLABS_VOICES).
import { extraOriginsFromEnv, withCors } from "../_shared/cors.ts";
import { createJwtAuthenticator } from "../_shared/auth.ts";
import { SupabaseRateLimiter } from "../_shared/ratelimit.ts";
import { restDbFromEnv } from "../_shared/restdb.ts";
import { secret } from "../_shared/secrets.ts";
import { parseVoices } from "../tts/voices.ts";
import { type CatalogVoice, createVoicesHandler } from "./handler.ts";

const env = Deno.env;
const db = restDbFromEnv();
const xi = secret(env, "ELEVENLABS_API_KEY") ?? "";
const { voices, errors } = parseVoices(env.get("ELEVENLABS_VOICES"));
if (errors.length) console.error("ELEVENLABS_VOICES problems:", errors.join("; "));

const handler = createVoicesHandler({
  authenticate: createJwtAuthenticator({
    supabaseUrl: env.get("SUPABASE_URL")!,
    hs256Secret: env.get("SUPABASE_JWT_SECRET"),
  }),
  rateLimiter: new SupabaseRateLimiter(db),
  voices,
  defaultVoiceId: env.get("ELEVENLABS_VOICE_ID") ?? null,
  // K96 (D220): the curated list, sorted; only enabled voices
  catalog: async () => (await db.select("voice_catalog", "select=voice_id,name,gender,age,accent,language,preview_url,description,review&enabled=eq.true&order=sort.asc,name.asc&limit=40")) as CatalogVoice[],
  isAdmin: async (u) => (await db.rpc("is_credit_admin", { p_user: u }).catch(() => false)) === true,
  // K96: ElevenLabs' voice library, Swedish (listing costs no credits; no audio is made)
  searchLibrary: xi
    ? async (q) => {
      const p = new URLSearchParams({ page_size: "30", page: String(q.page ?? 0), ...(q.anyLanguage ? {} : { language: q.language ?? "sv" }) });
      if (q.search) p.set("search", q.search);
      if (q.accent) p.set("accent", q.accent);
      if (q.gender) p.set("gender", q.gender);
      const r = await fetch(`https://api.elevenlabs.io/v1/shared-voices?${p}`, { headers: { "xi-api-key": xi }, signal: AbortSignal.timeout(8000) });
      if (!r.ok) throw new Error(`shared-voices ${r.status}`);
      const j = await r.json() as { voices?: Record<string, unknown>[] };
      return (j.voices ?? []).slice(0, 30).map((v) => ({
        // K114: whether the library voice is a native speaker of its language (the library's own metadata)
        ...(v.verified_languages ? { verified_languages: (v.verified_languages as Record<string, unknown>[]).map((x) => `${x.language}:${x.accent ?? ""}`).slice(0, 4) } : {}),
        voice_id: String(v.voice_id ?? ""), name: String(v.name ?? "").slice(0, 60), gender: (v.gender as string) ?? null, age: (v.age as string) ?? null,
        accent: (v.accent as string) ?? null, language: (v.language as string) ?? null, preview_url: (v.preview_url as string) ?? null,
        description: String(v.description ?? "").slice(0, 200) || null,
      }));
    }
    : undefined,
});

Deno.serve(withCors(handler, extraOriginsFromEnv()));
