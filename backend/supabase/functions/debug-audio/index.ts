// GET/POST /functions/v1/debug-audio - K43 (D140): test mode audio and turn data. See handler.ts.
import { extraOriginsFromEnv, withCors } from "../_shared/cors.ts";
import { createJwtAuthenticator } from "../_shared/auth.ts";
import { SupabaseRateLimiter } from "../_shared/ratelimit.ts";
import { restDbFromEnv } from "../_shared/restdb.ts";
import { createDebugAudioHandler, type DebugTurnRow } from "./handler.ts";

const env = Deno.env;
const db = restDbFromEnv();
const base = env.get("SUPABASE_URL")!;
const key = env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const BUCKET = "debug_audio";
const sh = (extra: Record<string, string> = {}) => ({ apikey: key, authorization: `Bearer ${key}`, ...extra });
const enc = (p: string) => p.split("/").map(encodeURIComponent).join("/");

async function list(prefix: string): Promise<{ name: string; id: string | null }[]> {
  const out: { name: string; id: string | null }[] = [];
  for (let offset = 0; offset < 20_000; offset += 1000) {
    const r = await fetch(`${base}/storage/v1/object/list/${BUCKET}`, {
      method: "POST", headers: sh({ "content-type": "application/json" }),
      body: JSON.stringify({ prefix, limit: 1000, offset, sortBy: { column: "name", order: "asc" } }),
    });
    if (!r.ok) throw new Error(`storage list ${r.status}`);
    const page = await r.json() as { name: string; id: string | null }[];
    out.push(...page);
    if (page.length < 1000) break;
  }
  return out;
}

Deno.serve(withCors(
  createDebugAudioHandler({
    authenticate: createJwtAuthenticator({ supabaseUrl: base, hs256Secret: env.get("SUPABASE_JWT_SECRET") }),
    rateLimiter: new SupabaseRateLimiter(db),
    ownerEmails: (env.get("OWNER_EMAIL") ?? "").split(","),
    isTester: async (u) => (await db.select("debug_testers", `select=user_id&user_id=eq.${encodeURIComponent(u)}&limit=1`)).length > 0,
    setTester: async (u, on) => {
      if (on) await db.upsert("debug_testers", { user_id: u }, "user_id");
      else await db.deleteWhere("debug_testers", `user_id=eq.${encodeURIComponent(u)}`);
    },
    putAudio: async (path, bytes, mime) => {
      const r = await fetch(`${base}/storage/v1/object/${BUCKET}/${enc(path)}`, { method: "POST", headers: sh({ "content-type": mime, "x-upsert": "false" }), body: bytes });
      if (!r.ok) throw new Error(`storage upload ${r.status}`);
    },
    signUrl: async (path) => {
      const r = await fetch(`${base}/storage/v1/object/sign/${BUCKET}/${enc(path)}`, { method: "POST", headers: sh({ "content-type": "application/json" }), body: JSON.stringify({ expiresIn: 3600 }) });
      if (!r.ok) return null;
      const j = await r.json() as { signedURL?: string; signedUrl?: string };
      const u = j.signedURL ?? j.signedUrl;
      return u ? `${base}/storage/v1${u.startsWith("/") ? "" : "/"}${u}` : null;
    },
    folders: async () => (await list("")).filter((x) => x.id === null).map((x) => x.name),
    removeFolder: async (folder) => {
      const paths: string[] = [];
      for (const user of (await list(`${folder}/`)).filter((x) => x.id === null)) {
        for (const f of await list(`${folder}/${user.name}/`)) if (f.id !== null) paths.push(`${folder}/${user.name}/${f.name}`);
      }
      for (let i = 0; i < paths.length; i += 500) {
        const r = await fetch(`${base}/storage/v1/object/${BUCKET}`, { method: "DELETE", headers: sh({ "content-type": "application/json" }), body: JSON.stringify({ prefixes: paths.slice(i, i + 500) }) });
        if (!r.ok) throw new Error(`storage delete ${r.status}`);
      }
      return paths.length;
    },
    insertTurn: async (row) => {
      const r = await fetch(`${base}/rest/v1/debug_turns?select=id`, { method: "POST", headers: sh({ "content-type": "application/json", prefer: "return=representation" }), body: JSON.stringify(row) });
      if (!r.ok) throw new Error(`debug_turns insert ${r.status}`);
      return ((await r.json()) as { id: number }[])[0]?.id ?? 0;
    },
    listTurns: async (limit) =>
      await db.select("debug_turns", `select=id,created_at,user_id,turn_id,mode,audio_path,audio_bytes,transcript,words,decision,answer,meta&order=created_at.desc&limit=${limit}`) as (DebugTurnRow & { id: number; created_at: string })[],
  }),
  extraOriginsFromEnv(),
));
