// GET /functions/v1/feedback-admin - owner view of feedback (D57), service role only.
import { extraOriginsFromEnv, withCors } from "../_shared/cors.ts";
import { restDbFromEnv } from "../_shared/restdb.ts";
import { createAdminHandler } from "./handler.ts";

const db = restDbFromEnv();
const handler = createAdminHandler({
  serviceKey: Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? null,
  select: (q) => db.select("feedback_admin", q),
});

Deno.serve(withCors(handler, extraOriginsFromEnv()));
