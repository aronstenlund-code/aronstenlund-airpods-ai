// POST /functions/v1/drill - K46 (D142-D145): Repetitionsläget, drills and their audio per account. See handler.ts.
import { extraOriginsFromEnv, withCors } from "../_shared/cors.ts";
import { createJwtAuthenticator } from "../_shared/auth.ts";
import { SupabaseRateLimiter } from "../_shared/ratelimit.ts";
import { useQuotaFromDb } from "../_shared/wallet_db.ts";
import { providerFromEnv } from "../answer/llm/factory.ts";
import { haikuStyler, haikuVoicePicker } from "./style.ts";
import { onFirstPlay } from "../_shared/rewards.ts";
import { rewardStore } from "../_shared/rewards_db.ts";
import { restDbFromEnv } from "../_shared/restdb.ts";
import { secret } from "../_shared/secrets.ts";
import { parseVoices } from "../tts/voices.ts";
import { currentTest, silentMp3, TEST_VOICE_ID, withTestMode } from "../_shared/testmode.ts";
import { AsyncLocalStorage } from "node:async_hooks";
import { type AudioRow, createDrillHandler, type DrillRow, type ItemRow, type PublicationRow, type SchoolRow, type ShareRow } from "./handler.ts";

const env = Deno.env;

/** T50: what a slow request spent its time on: the outbound calls per kind (count, summed ms; parallel calls overlap). */
type Spent = { kinds: Record<string, { n: number; ms: number }>; steps?: string[]; t0: number };
const spent = new AsyncLocalStorage<Spent>();
const realFetch = globalThis.fetch;
globalThis.fetch = (async (input: Request | URL | string, init?: RequestInit) => {
  const st = spent.getStore();
  if (!st) return realFetch(input, init);
  const url = typeof input === "string" ? input : input instanceof URL ? input.href : input.url;
  const k = url.includes("/rest/v1/rpc/") ? "db_rpc" : url.includes("/rest/v1/") ? "db" : url.includes("/storage/v1/") ? "storage"
    : url.includes("anthropic") ? "claude" : url.includes("/auth/v1/") ? "auth" : url.includes("elevenlabs") ? "tts" : "other";
  const t0 = Date.now();
  try {
    return await realFetch(input, init);
  } finally {
    const e = (st.kinds[k] ??= { n: 0, ms: 0 });
    e.n++;
    e.ms += Date.now() - t0;
    // the step list (test requests only): table, rpc or storage path without the query, start offset and duration
    if (st.steps && st.steps.length < 80) {
      const path = new URL(url).pathname.replace(/^\/(rest|storage)\/v1\//, "").replace(/\/[0-9a-f]{2}\/[0-9a-f]{64}\.mp3$/, "/<file>").slice(0, 40);
      st.steps.push(`${t0 - st.t0}+${Date.now() - t0} ${init?.method ?? "GET"} ${path}`);
    }
  }
}) as typeof fetch;

const db = restDbFromEnv(); // after the fetch above, so its calls are counted
const stylerProvider = providerFromEnv(Deno.env);
const rewards = rewardStore(db);
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

/** K62: what is known about the ElevenLabs credits, for the morning report's warning under 20 % (service role only). */
function saveStatus(row: Record<string, unknown>) {
  return db.upsert("provider_status", { provider: "elevenlabs", ...row, updated_at: new Date().toISOString() }, "provider")
    .catch((e) => console.warn("provider_status_failed", e instanceof Error ? e.message.slice(0, 80) : String(e)));
}

let creditsLogged = false;
async function logCredits() {
  // K46: Aron's plan and credits, in the function log only (never the key, never to the app)
  // K62b (Oscar O61): never from a test request (free, but still a call to ElevenLabs)
  if (creditsLogged || !xi || currentTest()?.test) return;
  creditsLogged = true;
  try {
    const r = await fetch(`${xiBase}/v1/user/subscription`, { headers: { "xi-api-key": xi } });
    const j = await r.json().catch(() => ({})) as Record<string, unknown>;
    console.log("elevenlabs_subscription", JSON.stringify({
      status: r.status, tier: j.tier, character_count: j.character_count, character_limit: j.character_limit,
      next_reset_unix: j.next_character_count_reset_unix, can_extend: j.can_extend_character_limit,
    }));
    await saveStatus(r.ok
      ? { status: r.status, used: j.character_count ?? null, lim: j.character_limit ?? null, reset_unix: j.next_character_count_reset_unix ?? null }
      : { status: r.status });
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

/** T50 (Toby): a request slower than 3 s says which action it was and how long it took (no text, no ids). */
function timed(h: (req: Request) => Promise<Response>): (req: Request) => Promise<Response> {
  return async (req) => {
    const t0 = Date.now();
    const action = req.method === "POST" ? await req.clone().json().then((b) => String(b?.action ?? "").slice(0, 20)).catch(() => "") : req.method;
    const test = req.headers.has("x-earmind-test");
    const calls: Spent = { kinds: {}, t0, ...(test ? { steps: [] } : {}) };
    const r = await spent.run(calls, () => h(req));
    const ms = Date.now() - t0;
    if (ms > 3000 || test) console.log("drill_slow", JSON.stringify({ action, ms, status: r.status, calls: calls.kinds, ...(test ? { steps: calls.steps } : {}) }));
    return r;
  };
}
/** the same for each Haiku tagging call (K95), the likely slow part of a save with a style */
const timedStyler = (f: ReturnType<typeof haikuStyler>): ReturnType<typeof haikuStyler> => async (t, s) => {
  const t0 = Date.now();
  try {
    return await f(t, s);
  } finally {
    const ms = Date.now() - t0;
    if (ms > 1000) console.log("drill_styler_slow", JSON.stringify({ ms, chars: t.length }));
  }
};

Deno.serve(withCors(withTestMode("drill", timed(
  createDrillHandler({
    authenticate: createJwtAuthenticator({ supabaseUrl: base, hs256Secret: env.get("SUPABASE_JWT_SECRET") }),
    rateLimiter: new SupabaseRateLimiter(db),
    // K95 (D220): Haiku adds v3 tags for "Hur ska det låta?" (only for files that are made new)
    styler: stylerProvider ? timedStyler(haikuStyler(stylerProvider)) : undefined,
    // K98 (D224): the first Starta prov / Spela rewards the inviter
    onStarted: (u) => onFirstPlay(rewards, u),
    // K99 (D223): Haiku picks the catalog voice that fits "Hur ska det låta?"
    voicePicker: stylerProvider ? haikuVoicePicker(stylerProvider) : undefined,
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
    // K77 (D197): Repetitionsläget in Aron's analysis, the same table as qa-log (deleted after delivery, 14 days at most)
    analysis: (rows) => db.insertMany("qa_log", rows.map((r) => ({ mode: r.mode, persona: r.persona, question: r.question, answer: r.answer }))),
    db: {
      drill: async (id) => ((await db.select("drills", `select=*&id=eq.${encodeURIComponent(id)}&limit=1`)) as DrillRow[])[0] ?? null,
      drills: async (u) => (await db.select("drills", `select=*&user_id=eq.${encodeURIComponent(u)}&order=updated_at.desc&limit=500`)) as DrillRow[],
      drillByClient: async (u, c) =>
        ((await db.select("drills", `select=*&user_id=eq.${encodeURIComponent(u)}&client_id=eq.${encodeURIComponent(c)}&limit=1`)) as DrillRow[])[0] ?? null,
      saveDrill: async (row) => {
        const r = { ...row, updated_at: new Date().toISOString() };
        try {
          await db.upsert("drills", r, "id");
        } catch (e) {
          // until the migration adding drills.said has run, a Säg text is still saved (without the mark)
          if (!("said" in r)) throw e;
          console.warn("drill_said_column_missing", String(e).slice(0, 80));
          const { said: _s, ...rest } = r;
          await db.upsert("drills", rest, "id");
        }
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
            `select=hash,kind,text,short_chars,model,voice_id,status,attempts,bytes,duration_ms,short_end_ms,credits,error,done_at,queued_at,sentence_ends,sentences,words&hash=in.(${list(p)})`,
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
      pending: async () => (await db.select("drill_audio_files", "select=hash&status=in.(pending,working)&attempts=lt.3&limit=1")).length > 0,
      // K78 (D200)
      refundQuota: async (u, n) => {
        await db.rpc("refund_drill_chars", { p_user: u, p_n: n }); // K90 (D213): characters
      },
      recentUnavailable: async (since, test) =>
        (await db.select("drill_audio_files", `select=hash&status=eq.failed&error=like.audio_unavailable*&voice_id=${test ? "eq" : "neq"}.${TEST_VOICE_ID}&done_at=gte.${encodeURIComponent(since)}&limit=1`)).length > 0,
      setRefunded: async (id, n) => {
        await db.updateWhere("drills", `id=eq.${encodeURIComponent(id)}`, { refunded_chars: n }); // K90: characters given back
      },
      requeue: async (hashes) => {
        if (!hashes.length) return;
        await db.updateWhere("drill_audio_files", `status=eq.failed&hash=in.(${list(hashes)})`, { status: "pending", attempts: 0, error: null });
      },
      // K94 (D218): admin, subscription week, the month's free credits, bought credits (_shared/wallet.ts)
      useQuota: useQuotaFromDb(db),
      // ---------- K64 ----------
      referenced: async (hashes) => {
        if (!hashes.length) return [];
        const out = new Set<string>();
        for (let i = 0; i < hashes.length; i += 50) {
          const p = list(hashes.slice(i, i + 50));
          const r = (await db.select("drill_items", `select=question_hash,long_hash&or=(question_hash.in.(${p}),long_hash.in.(${p}))&limit=1000`)) as { question_hash: string; long_hash: string }[];
          for (const x of r) out.add(x.question_hash).add(x.long_hash);
        }
        return hashes.filter((h) => out.has(h));
      },
      // ---------- K61 ----------
      // K99 (D223): the catalog voices everyone may use (not under review) for mixing and the AI's choice
      catalogVoices: async () => (await db.select("voice_catalog", "select=voice_id,name,description,accent,gender,age&enabled=eq.true&review=eq.false&limit=40").catch(() => [])) as { voice_id: string; name: string }[],
      // K96 (D220): a voice may be chosen only from the curated catalog
      voiceAllowed: async (id) => ((await db.select("voice_catalog", `select=voice_id&voice_id=eq.${encodeURIComponent(id)}&enabled=eq.true&limit=1`).catch(() => [])) as unknown[]).length > 0,
      settings: async () => Object.fromEntries(((await db.select("drill_settings", "select=key,value")) as { key: string; value: number }[]).map((r) => [r.key, Number(r.value)])),
      tryCredits: async (u, keys) => {
        if (!keys.length) return [];
        const r = (await db.select("drill_try_credits", `select=question_key&user_id=eq.${encodeURIComponent(u)}&question_key=in.(${keys.map((k) => `"${k.replace(/["\\]/g, "")}"`).map(encodeURIComponent).join(",")})`)) as { question_key: string }[];
        return r.map((x) => x.question_key);
      },
      dropTryCredits: async (u, keys) => {
        if (!keys.length) return;
        await db.deleteWhere("drill_try_credits", `user_id=eq.${encodeURIComponent(u)}&question_key=in.(${keys.map((k) => `"${k.replace(/["\\]/g, "")}"`).map(encodeURIComponent).join(",")})`);
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
          if (voice === TEST_VOICE_ID) {
            // K62b (D180): a test account's file: silent audio with even timings, no ElevenLabs, no credits
            const secs = Math.min(10, Math.max(1, text.length * 0.02));
            const audio = silentMp3(secs);
            const step = (audio.length / 417 * 0.026122) / Math.max(1, text.length);
            return { audio, starts: [...text].map((_, i) => i * step), ends: [...text].map((_, i) => (i + 1) * step), credits: 0 };
          }
          if (!voice || voice.startsWith("earmind-test")) throw new Error("D180: a test file reached ElevenLabs");
          const r = await fetch(`${xiBase}/v1/text-to-speech/${voice}/with-timestamps?output_format=mp3_44100_64&enable_logging=false`, {
            method: "POST",
            headers: { "xi-api-key": xi, "content-type": "application/json" },
            // v3 takes no language_code (the blind test's voice-lab call sent none for it)
            body: JSON.stringify({ text, model_id: m, ...(m === "eleven_v3" || m === "eleven_v4" ? {} : { language_code: "sv" }) }),
            signal: AbortSignal.timeout(60_000),
          });
          if (!r.ok) {
            const t = (await r.text().catch(() => "")).slice(0, 300);
            // K62: "exceeds your quota of 65000. You have 183 credits remaining": the only count the key may read
            const m = /quota of (\d+)\. You have (\d+) credits remaining/.exec(t);
            if (m) await saveStatus({ lim: Number(m[1]), remaining_hint: Number(m[2]) });
            throw new Error(`elevenlabs ${r.status}: ${t.slice(0, 200)}`);
          }
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
  }))),
  extraOriginsFromEnv(),
));
