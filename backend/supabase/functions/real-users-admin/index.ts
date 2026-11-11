// GET/POST /functions/v1/real-users-admin - K38: Aron's review of the weekly K22 candidates. See handler.ts.
import { createJwtAuthenticator } from "../_shared/auth.ts";
import { restDbFromEnv } from "../_shared/restdb.ts";
import { createRealUsersAdminHandler } from "./handler.ts";

const env = Deno.env;
const db = restDbFromEnv();

Deno.serve(createRealUsersAdminHandler({
  authenticate: createJwtAuthenticator({ supabaseUrl: env.get("SUPABASE_URL")!, hs256Secret: env.get("SUPABASE_JWT_SECRET") }),
  ownerEmails: (env.get("OWNER_EMAIL") ?? "").split(","),
  select: (q) => db.select("real_user_candidates", q),
  updateWhere: (f, p) => db.updateWhere("real_user_candidates", f, p),
}));
