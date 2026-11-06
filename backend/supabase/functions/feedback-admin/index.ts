// GET /functions/v1/feedback-admin - owner view of feedback (D57), service role only.
import { restDbFromEnv } from "../_shared/restdb.ts";
import { createAdminHandler } from "./handler.ts";

const db = restDbFromEnv();
Deno.serve(createAdminHandler({
  serviceKey: Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? null,
  select: (q) => db.select("feedback_admin", q),
}));
