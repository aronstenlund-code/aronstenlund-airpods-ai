// GET/POST /functions/v1/qa-log - K30 (D116): Aron's private question-and-answer log. See handler.ts.
import { createJwtAuthenticator } from "../_shared/auth.ts";
import { restDbFromEnv } from "../_shared/restdb.ts";
import { createQaLogHandler } from "./handler.ts";

const env = Deno.env;
const db = restDbFromEnv();

Deno.serve(createQaLogHandler({
  authenticate: createJwtAuthenticator({ supabaseUrl: env.get("SUPABASE_URL")!, hs256Secret: env.get("SUPABASE_JWT_SECRET") }),
  ownerEmails: (env.get("OWNER_EMAIL") ?? "").split(","),
  select: (q) => db.select("qa_log", q),
  deleteWhere: (f) => db.deleteWhere("qa_log", f),
}));
