// GET /functions/v1/usage-stats?days=14[&format=html] - owner view, service role only (D49).
import { extraOriginsFromEnv, withCors } from "../_shared/cors.ts";
import { restDbFromEnv } from "../_shared/restdb.ts";
import { secret } from "../_shared/secrets.ts";
import { createStatsHandler } from "./handler.ts";

const db = restDbFromEnv();
const handler = createStatsHandler({
  serviceKey: secret(Deno.env, "SUPABASE_SERVICE_ROLE_KEY"),
  rpc: (fn, args) => db.rpc(fn, args),
});

Deno.serve(withCors(handler, extraOriginsFromEnv()));
