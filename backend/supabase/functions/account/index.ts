// POST /functions/v1/account/delete - K101: the signed-in user deletes their own account. See handler.ts.
import { extraOriginsFromEnv, withCors } from "../_shared/cors.ts";
import { createJwtAuthenticator } from "../_shared/auth.ts";
import { SupabaseRateLimiter } from "../_shared/ratelimit.ts";
import { restDbFromEnv } from "../_shared/restdb.ts";
import { audioHash, audioPath, CUES, voiceText } from "../drill/handler.ts";
import { createAccountHandler } from "./handler.ts";

const env = Deno.env;
const db = restDbFromEnv();
const base = env.get("SUPABASE_URL")!.replace(/\/+$/, "");
const key = env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const sh = (extra: Record<string, string> = {}) => ({ apikey: key, authorization: `Bearer ${key}`, ...extra });
const q = encodeURIComponent;
const list = (xs: string[]) => xs.map((x) => `"${x.replace(/"/g, "")}"`).join(",");
const uuid = (u: string) => {
  if (!/^[0-9a-f-]{36}$/i.test(u)) throw new Error("not a user id");
  return u;
};

async function chunked<T>(xs: string[], n: number, f: (part: string[]) => Promise<T[]>): Promise<T[]> {
  const out: T[] = [];
  for (let i = 0; i < xs.length; i += n) out.push(...await f(xs.slice(i, i + n)));
  return out;
}

Deno.serve(withCors(createAccountHandler({
  authenticate: createJwtAuthenticator({ supabaseUrl: base, hs256Secret: env.get("SUPABASE_JWT_SECRET") }),
  rateLimiter: new SupabaseRateLimiter(db),
  audioPath,
  cueHashes: async (pairs) => {
    const out = new Set<string>();
    for (const p of pairs) for (const t of Object.values(CUES)) out.add(await audioHash(voiceText(t), p.model, p.voice_id));
    return out;
  },
  removeObjects: async (bucket, paths) => {
    if (!paths.length) return;
    const r = await fetch(`${base}/storage/v1/object/${bucket}`, { method: "DELETE", headers: sh({ "content-type": "application/json" }), body: JSON.stringify({ prefixes: paths }) });
    if (!r.ok) throw new Error(`storage delete ${r.status}`);
    await r.body?.cancel();
  },
  store: {
    drillFiles: async (u) => {
      const items = (await db.select("drill_items", `select=question_hash,long_hash&user_id=eq.${uuid(u)}&limit=20000`)) as { question_hash: string; long_hash: string }[];
      const hashes = [...new Set(items.flatMap((i) => [i.question_hash, i.long_hash]).filter(Boolean))];
      return await chunked(hashes, 100, async (p) => (await db.select("drill_audio_files", `select=hash,model,voice_id&hash=in.(${list(p)})`)) as { hash: string; model: string; voice_id: string }[]);
    },
    usedByOthers: async (hashes, u) => {
      const rows = await chunked(hashes, 50, async (p) =>
        (await db.select("drill_items", `select=question_hash,long_hash&user_id=neq.${uuid(u)}&or=(question_hash.in.(${list(p)}),long_hash.in.(${list(p)}))&limit=10000`)) as { question_hash: string; long_hash: string }[]);
      const wanted = new Set(hashes);
      return new Set(rows.flatMap((r) => [r.question_hash, r.long_hash]).filter((h) => wanted.has(h)));
    },
    deleteAudioRows: async (hashes) => void await db.deleteWhere("drill_audio_files", `hash=in.(${list(hashes)})`),
    debugAudioPaths: async (u) =>
      ((await db.select("debug_turns", `select=audio_path&user_id=eq.${uuid(u)}&audio_path=not.is.null&limit=5000`)) as { audio_path: string }[]).map((r) => r.audio_path),
    subscription: async (u) => {
      const rows = (await db.select("store_subscriptions", `select=expires_at&user_id=eq.${uuid(u)}&status=eq.active&expires_at=gt.${q(new Date().toISOString())}&order=expires_at.desc&limit=1`)) as { expires_at: string }[];
      return { active: rows.length > 0, until: rows[0]?.expires_at ?? null };
    },
    deleteOwnRows: async (u) => {
      const id = uuid(u);
      // tables whose user column has no foreign key to auth.users (the rest cascade with the account)
      await Promise.all([
        ...["answer_usage", "feedback", "shared_history", "logo_votes", "connections", "debug_turns", "debug_testers", "drill_reports", "app_attest_challenges"]
          .map((t) => db.deleteWhere(t, `user_id=eq.${id}`)),
        db.deleteWhere("invite_claims", `inviter_id=eq.${id}`),
        db.deleteWhere("rate_limits", `key=like.${q(`*:u:${id}:*`)}`),
      ]);
    },
    deleteAuthUser: async (u) => {
      const r = await fetch(`${base}/auth/v1/admin/users/${uuid(u)}`, { method: "DELETE", headers: sh() });
      if (!r.ok && r.status !== 404) throw new Error(`auth delete ${r.status}`);
      await r.body?.cancel();
    },
  },
}), extraOriginsFromEnv()));
