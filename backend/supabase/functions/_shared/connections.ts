import type { RestDb } from "./restdb.ts";
import type { ConnectionRow, ConnectionStore } from "./spotify.ts";

/** K36: the `connections` table through PostgREST (service role). Tokens arrive already encrypted. */
export function restConnectionStore(db: RestDb): ConnectionStore {
  const key = (u: string, p: string) => `user_id=eq.${encodeURIComponent(u)}&provider=eq.${encodeURIComponent(p)}`;
  return {
    async get(u, p) {
      const rows = await db.select("connections", `select=user_id,provider,access_enc,refresh_enc,expires_at,scope,premium&${key(u, p)}&limit=1`);
      return (rows[0] as ConnectionRow | undefined) ?? null;
    },
    upsert: (row) => db.upsert("connections", { ...row, updated_at: new Date().toISOString() }, "user_id,provider"),
    remove: (u, p) => db.deleteWhere("connections", key(u, p)),
    async list(u) {
      return await db.select("connections", `select=provider,premium,updated_at&user_id=eq.${encodeURIComponent(u)}`) as {
        provider: string;
        premium: boolean | null;
        updated_at?: string;
      }[];
    },
  };
}
