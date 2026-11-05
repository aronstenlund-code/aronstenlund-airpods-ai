// GET /functions/v1/usage-stats?days=14[&format=html] - owner view, service role only (D49).
import { restDbFromEnv } from "../_shared/restdb.ts";
import { createStatsHandler } from "./handler.ts";

const db = restDbFromEnv();
Deno.serve(createStatsHandler({
  serviceKey: Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? null,
  rpc: (fn, args) => db.rpc(fn, args),
}));
