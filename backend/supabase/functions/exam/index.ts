// POST /functions/v1/exam - D84 exam session: parse (page images, once), hint, grade, summary.
import { extraOriginsFromEnv, withCors } from "../_shared/cors.ts";
import { createJwtAuthenticator } from "../_shared/auth.ts";
import { SupabaseRateLimiter } from "../_shared/ratelimit.ts";
import { restDbFromEnv } from "../_shared/restdb.ts";
import { supabaseUsageSink } from "../_shared/usage.ts";
import { providerFromEnv } from "../answer/llm/factory.ts";
import { createExamHandler, DEFAULT_EXAM_CONFIG } from "./handler.ts";

const env = Deno.env;
const db = restDbFromEnv();
const base = (env.get("SUPABASE_URL") ?? "").replace(/\/+$/, "");
const key = env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const BUCKET = "drill_material";
const sh = (extra: Record<string, string> = {}) => ({ apikey: key, authorization: `Bearer ${key}`, ...extra });
const enc = (p: string) => p.split("/").map(encodeURIComponent).join("/");
function b64(bytes: Uint8Array): string {
  let bin = "";
  for (let i = 0; i < bytes.length; i += 0x8000) bin += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  return btoa(bin);
}

const handler = createExamHandler({
  authenticate: createJwtAuthenticator({
    supabaseUrl: env.get("SUPABASE_URL")!,
    hs256Secret: env.get("SUPABASE_JWT_SECRET"),
  }),
  rateLimiter: new SupabaseRateLimiter(db),
  provider: providerFromEnv(env),
  recordUsage: supabaseUsageSink(db),
  // K53: photos uploaded one by one to the private bucket drill_material, deleted after the analysis
  material: key
    ? {
      sign: async (paths) =>
        await Promise.all(paths.map(async (path) => {
          const r = await fetch(`${base}/storage/v1/object/upload/sign/${BUCKET}/${enc(path)}`, {
            method: "POST",
            headers: sh({ "content-type": "application/json" }),
            body: JSON.stringify({ expiresIn: 7200 }),
          });
          if (!r.ok) throw new Error(`storage sign ${r.status}`);
          const j = await r.json() as { url: string };
          return { path, url: `${base}/storage/v1${j.url.startsWith("/") ? "" : "/"}${j.url}` };
        })),
      get: async (path) => {
        const r = await fetch(`${base}/storage/v1/object/${BUCKET}/${enc(path)}`, { headers: sh() });
        if (!r.ok) {
          await r.body?.cancel();
          return null;
        }
        return b64(new Uint8Array(await r.arrayBuffer()));
      },
      remove: async (paths) => {
        if (!paths.length) return;
        const r = await fetch(`${base}/storage/v1/object/${BUCKET}`, {
          method: "DELETE",
          headers: sh({ "content-type": "application/json" }),
          body: JSON.stringify({ prefixes: paths }),
        });
        if (!r.ok) throw new Error(`storage delete ${r.status}`);
        await r.body?.cancel();
      },
    }
    : null,
  config: { ...DEFAULT_EXAM_CONFIG, model: env.get("EXAM_MODEL") || undefined },
});

Deno.serve(withCors(handler, extraOriginsFromEnv()));
