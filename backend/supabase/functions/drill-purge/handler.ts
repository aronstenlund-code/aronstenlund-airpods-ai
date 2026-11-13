/**
 * K53 (B4): `POST /drill-purge`, called every 15 minutes by pg_cron. Deletes photos in the private bucket
 * drill_material that are older than one hour. Normally /exam drill deletes them right after the analysis; this only
 * catches uploads that never reached an analysis. Needs no login: it can only delete old material, never read it.
 */
export interface PurgeStore {
  /** Top-level folders (one per user) and, per folder, its files with their creation time. */
  folders(): Promise<string[]>;
  files(folder: string): Promise<{ name: string; created_at: string }[]>;
  remove(paths: string[]): Promise<void>;
}
export const PURGE_AFTER_MS = 60 * 60 * 1000;

export function createPurgeHandler(store: PurgeStore, now: () => number = Date.now) {
  return async (req: Request): Promise<Response> => {
    if (req.method !== "POST") return new Response(null, { status: 405 });
    const old: string[] = [];
    for (const folder of await store.folders()) {
      for (const f of await store.files(folder)) {
        const t = Date.parse(f.created_at);
        if (Number.isFinite(t) && now() - t > PURGE_AFTER_MS) old.push(`${folder}/${f.name}`);
      }
    }
    for (let i = 0; i < old.length; i += 500) await store.remove(old.slice(i, i + 500));
    if (old.length) console.log("drill_material_purged", old.length);
    return Response.json({ deleted: old.length });
  };
}
