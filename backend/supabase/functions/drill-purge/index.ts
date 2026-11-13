// POST /functions/v1/drill-purge - K53: deletes uploaded photos older than one hour (pg_cron every 15 min). See handler.ts.
import { createPurgeHandler } from "./handler.ts";

const base = (Deno.env.get("SUPABASE_URL") ?? "").replace(/\/+$/, "");
const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const BUCKET = "drill_material";
const sh = (extra: Record<string, string> = {}) => ({ apikey: key, authorization: `Bearer ${key}`, ...extra });

async function list(prefix: string): Promise<{ name: string; id: string | null; created_at: string }[]> {
  const out: { name: string; id: string | null; created_at: string }[] = [];
  for (let offset = 0; offset < 50_000; offset += 1000) {
    const r = await fetch(`${base}/storage/v1/object/list/${BUCKET}`, {
      method: "POST",
      headers: sh({ "content-type": "application/json" }),
      body: JSON.stringify({ prefix, limit: 1000, offset, sortBy: { column: "name", order: "asc" } }),
    });
    if (!r.ok) throw new Error(`storage list ${r.status}`);
    const page = await r.json() as { name: string; id: string | null; created_at: string }[];
    out.push(...page);
    if (page.length < 1000) break;
  }
  return out;
}

Deno.serve(createPurgeHandler({
  folders: async () => (await list("")).filter((x) => x.id === null).map((x) => x.name),
  files: async (folder) => (await list(`${folder}/`)).filter((x) => x.id !== null),
  remove: async (paths) => {
    const r = await fetch(`${base}/storage/v1/object/${BUCKET}`, {
      method: "DELETE",
      headers: sh({ "content-type": "application/json" }),
      body: JSON.stringify({ prefixes: paths }),
    });
    if (!r.ok) throw new Error(`storage delete ${r.status}`);
    await r.body?.cancel();
  },
}));
