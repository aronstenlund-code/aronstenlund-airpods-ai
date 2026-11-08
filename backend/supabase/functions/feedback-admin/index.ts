// GET /functions/v1/feedback-admin - owner view of feedback (D57), service role only.
import { extraOriginsFromEnv, withCors } from "../_shared/cors.ts";
import { restDbFromEnv } from "../_shared/restdb.ts";
import { secret } from "../_shared/secrets.ts";
import { createAdminHandler } from "./handler.ts";

const db = restDbFromEnv();
const handler = createAdminHandler({
  serviceKey: secret(Deno.env, "SUPABASE_SERVICE_ROLE_KEY"),
  select: (q) => db.select("feedback_admin", q),
  markProcessed: async (id) => (await db.rpc("mark_feedback_processed", { p_id: id })) === true,
});

Deno.serve(withCors(handler, extraOriginsFromEnv()));
