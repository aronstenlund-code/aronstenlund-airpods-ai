// POST /functions/v1/drill - K46 (D142-D145): Repetitionsläget, drills and their audio per account. See handler.ts.
import { extraOriginsFromEnv, withCors } from "../_shared/cors.ts";
import { createJwtAuthenticator } from "../_shared/auth.ts";
import { SupabaseRateLimiter } from "../_shared/ratelimit.ts";
import { restDbFromEnv } from "../_shared/restdb.ts";
import { secret } from "../_shared/secrets.ts";
import { parseVoices } from "../tts/voices.ts";
import { type AudioRow, createDrillHandler, type DrillRow, type ItemRow, type PublicationRow, type SchoolRow, type ShareRow } from "./handler.ts";

const env = Deno.env;
const db = restDbFromEnv();
const base = env.get("SUPABASE_URL")!.replace(/\/+$/, "");
const key = env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const xi = secret(env, "ELEVENLABS_API_KEY");
const xiBase = env.get("ELEVENLABS_BASE_URL") || "https://api.elevenlabs.io";
const BUCKET = "drill_audio";
const sh = (extra: Record<string, string> = {}) => ({ apikey: key, authorization: `Bearer ${key}`, ...extra });
const enc = (p: string) => p.split("/").map(encodeURIComponent).join("/");
const list = (xs: string[]) => xs.map((x) => encodeURIComponent(x)).join(",");
const envInt = (k: string, d: number) => {
  const n = Number(env.get(k));
  return Number.isFinite(n) && n > 0 ? n : d;
};
// D151: the default is A (Multilingual v2); a drill may choose B (v3) or C (Flash) before its audio is made
const model = env.get("DRILL_TTS_MODEL") || "eleven_multilingual_v2";

let creditsLogged = false;
async function logCredits() {
  // K46: Aron's plan and credits, in the function log only (never the key, never to the app)
  if (creditsLogged || !xi) return;
  creditsLogged = true;
  try {
    const r = await fetch(`${xiBase}/v1/user/subscription`, { headers: { "xi-api-key": xi } });
    const j = await r.json().catch(() => ({})) as Record<string, unknown>;
    console.log("elevenlabs_subscription", JSON.stringify({
      status: r.status, tier: j.tier, character_count: j.character_count, character_limit: j.character_limit,
      next_reset_unix: j.next_character_count_reset_unix, can_extend: j.can_extend_character_limit,
    }));
  } catch (e) {
    console.warn("elevenlabs_subscription_failed", e instanceof Error ? e.message.slice(0, 120) : String(e));
  }
}

async function chunked<T>(xs: string[], n: number, f: (part: string[]) => Promise<T[]>): Promise<T[]> {
  const out: T[] = [];
  for (let i = 0; i < xs.length; i += n) out.push(...await f(xs.slice(i, i + n)));
  return out;
}

const rt = (globalThis as { EdgeRuntime?: { waitUntil?: (p: Promise<unknown>) => void } }).EdgeRuntime;

Deno.serve(withCors(
  createDrillHandler({
    authenticate: createJwtAuthenticator({ supabaseUrl: base, hs256Secret: env.get("SUPABASE_JWT_SECRET") }),
    rateLimiter: new SupabaseRateLimiter(db),
    model,
    voiceId: secret(env, "ELEVENLABS_VOICE_ID") ?? parseVoices(env.get("ELEVENLABS_VOICES")).voices[0]?.id ?? null,
    usdPer1kChars: 0.08,
    charLimits: {
      perMinute: envInt("DRILL_TTS_CHARS_PER_MINUTE", 60_000),
      perDay: envInt("DRILL_TTS_CHARS_PER_DAY", 60_000),
      globalPerDay: envInt("DRILL_TTS_GLOBAL_CHARS_PER_DAY", 600_000),
    },
    background: rt?.waitUntil ? (p) => rt.waitUntil!(p) : undefined,
    ownerEmails: (env.get("OWNER_EMAIL") ?? "").split(","),
    db: {
      drill: async (id) => ((await db.select("drills", `select=*&id=eq.${encodeURIComponent(id)}&limit=1`)) as DrillRow[])[0] ?? null,
      drills: async (u) => (await db.select("drills", `select=*&user_id=eq.${encodeURIComponent(u)}&order=updated_at.desc&limit=500`)) as DrillRow[],
      saveDrill: async (row) => {
        await db.upsert("drills", { ...row, updated_at: new Date().toISOString() }, "id");
      },
      items: (ids) => chunked(ids, 50, async (p) => (await db.select("drill_items", `select=*&drill_id=in.(${list(p)})&order=position.asc`)) as (ItemRow & { id: string })[]),
      replaceItems: async (drillId, keepIds, rows) => {
        const d = `drill_id=eq.${encodeURIComponent(drillId)}`;
        await db.deleteWhere("drill_items", keepIds.length ? `${d}&id=not.in.(${list(keepIds)})` : d);
        const now = new Date().toISOString();
        const kept = rows.filter((r) => r.id).map((r) => ({ ...r, updated_at: now }));
        const fresh = rows.filter((r) => !r.id);
        if (kept.length) await db.upsert("drill_items", kept, "id");
        if (fresh.length) await db.insertMany("drill_items", fresh);
      },
      deleteDrill: async (id) => {
        await db.deleteWhere("drills", `id=eq.${encodeURIComponent(id)}`);
      },
      audio: (hashes) =>
        chunked(hashes, 100, async (p) =>
          (await db.select(
            "drill_audio_files",
            `select=hash,kind,text,short_chars,model,voice_id,status,attempts,bytes,duration_ms,short_end_ms&hash=in.(${list(p)})`,
          )) as AudioRow[]),
      enqueue: (rows) => db.insertManyIgnoreDuplicates("drill_audio_files", rows, "hash"),
      claim: async (n) => {
        void logCredits();
        return (await db.rpc("claim_drill_audio", { n })) as AudioRow[];
      },
      finish: async (hash, patch) => {
        await db.updateWhere("drill_audio_files", `hash=eq.${encodeURIComponent(hash)}`, patch);
      },
      shareOf: async (id) =>
        ((await db.select("drill_shares", `select=*&drill_id=eq.${encodeURIComponent(id)}&revoked_at=is.null&order=created_at.desc&limit=1`)) as ShareRow[])[0] ?? null,
      shareByCode: async (code) => ((await db.select("drill_shares", `select=*&code=eq.${encodeURIComponent(code)}&limit=1`)) as ShareRow[])[0] ?? null,
      createShare: (row) => db.insert("drill_shares", row),
      revokeShares: (id) => db.updateWhere("drill_shares", `drill_id=eq.${encodeURIComponent(id)}&revoked_at=is.null`, { revoked_at: new Date().toISOString() }),
      // ---------- K49 ----------
      schools: async (q, limit) => {
        // name or locality, active units only; the name match first (PostgREST "or" with ilike)
        const like = encodeURIComponent(`*${q.replace(/[*,()]/g, " ").trim()}*`);
        return (await db.select("schools", `select=code,name,locality,status&status=eq.AKTIV&or=(name.ilike.${like},locality.ilike.${like})&order=name.asc&limit=${limit}`)) as SchoolRow[];
      },
      school: async (code) => ((await db.select("schools", `select=code,name,locality,status&code=eq.${encodeURIComponent(code)}&limit=1`)) as SchoolRow[])[0] ?? null,
      publicationOf: async (id) => ((await db.select("drill_publications", `select=*&drill_id=eq.${encodeURIComponent(id)}&limit=1`)) as PublicationRow[])[0] ?? null,
      publication: async (id) => ((await db.select("drill_publications", `select=*&id=eq.${encodeURIComponent(id)}&limit=1`)) as PublicationRow[])[0] ?? null,
      savePublication: (row) => db.upsert("drill_publications", { ...row, updated_at: new Date().toISOString() }, "drill_id"),
      deletePublication: async (id) => {
        await db.deleteWhere("drill_publications", `drill_id=eq.${encodeURIComponent(id)}`);
      },
      searchPublications: async (f) => {
        const q = ["select=*", "hidden=eq.false", "order=exam_date.desc", "limit=200"];
        if (f.school) q.push(`school_code=eq.${encodeURIComponent(f.school)}`);
        if (f.subject) q.push(`subject=ilike.${encodeURIComponent(`*${f.subject.replace(/[*,()]/g, " ").trim()}*`)}`);
        if (f.from) q.push(`exam_date=gte.${f.from}`);
        if (f.to) q.push(`exam_date=lte.${f.to}`);
        return (await db.select("drill_publications", q.join("&"))) as PublicationRow[];
      },
      report: async (id, u, reason) => {
        const r = (await db.rpc("report_publication", { p_id: id, p_user: u, p_reason: reason })) as { reports: number; hidden: boolean }[];
        return r[0] ?? { reports: 0, hidden: false };
      },
      bump: async (id, field) => {
        await db.rpc("bump_publication", { p_id: id, p_field: field });
      },
      useQuota: async (u, n) => {
        const r = (await db.rpc("use_drill_quota", { p_user: u, p_n: n })) as { ok: boolean; used: number; lim: number }[];
        return r[0] ?? { ok: false, used: 0, lim: 0 };
      },
      setHidden: async (id, hidden) => {
        await db.updateWhere("drill_publications", `id=eq.${encodeURIComponent(id)}`, { hidden });
      },
      countImport: async (code) => {
        const r = (await db.select("drill_shares", `select=imports&code=eq.${encodeURIComponent(code)}&limit=1`)) as { imports: number }[];
        await db.updateWhere("drill_shares", `code=eq.${encodeURIComponent(code)}`, { imports: (r[0]?.imports ?? 0) + 1 });
      },
    },
    storage: {
      upload: async (path, bytes) => {
        const r = await fetch(`${base}/storage/v1/object/${BUCKET}/${enc(path)}`, {
          method: "POST",
          headers: sh({ "content-type": "audio/mpeg", "x-upsert": "true" }),
          body: new Uint8Array(bytes),
        });
        if (!r.ok) throw new Error(`storage upload ${r.status}`);
        await r.body?.cancel();
      },
      sign: async (paths) => {
        const out: Record<string, string> = {};
        for (let i = 0; i < paths.length; i += 100) {
          const r = await fetch(`${base}/storage/v1/object/sign/${BUCKET}`, {
            method: "POST",
            headers: sh({ "content-type": "application/json" }),
            body: JSON.stringify({ expiresIn: 3600, paths: paths.slice(i, i + 100) }),
          });
          if (!r.ok) throw new Error(`storage sign ${r.status}`);
          for (const s of await r.json() as { path: string; signedURL?: string }[]) {
            if (s.signedURL) out[s.path] = `${base}/storage/v1${s.signedURL.startsWith("/") ? "" : "/"}${s.signedURL}`;
          }
        }
        return out;
      },
    },
    synth: xi
      ? {
        speak: async (text, m, voice) => {
          const r = await fetch(`${xiBase}/v1/text-to-speech/${voice}/with-timestamps?output_format=mp3_44100_64&enable_logging=false`, {
            method: "POST",
            headers: { "xi-api-key": xi, "content-type": "application/json" },
            // v3 takes no language_code (the blind test's voice-lab call sent none for it)
            body: JSON.stringify({ text, model_id: m, ...(m === "eleven_v3" ? {} : { language_code: "sv" }) }),
            signal: AbortSignal.timeout(60_000),
          });
          if (!r.ok) throw new Error(`elevenlabs ${r.status}: ${(await r.text().catch(() => "")).slice(0, 200)}`);
          const j = await r.json() as {
            audio_base64: string;
            alignment?: { character_start_times_seconds: number[]; character_end_times_seconds: number[] };
          };
          const audio = Uint8Array.from(atob(j.audio_base64), (c) => c.charCodeAt(0));
          const cost = Number(r.headers.get("character-cost"));
          return {
            audio,
            starts: j.alignment?.character_start_times_seconds ?? [],
            ends: j.alignment?.character_end_times_seconds ?? [],
            credits: r.headers.has("character-cost") && Number.isFinite(cost) ? cost : null,
          };
        },
      }
      : null,
  }),
  extraOriginsFromEnv(),
));
