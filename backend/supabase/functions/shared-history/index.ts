// POST / DELETE /functions/v1/shared-history - opt-in shared history (D57).
import { extraOriginsFromEnv, withCors } from "../_shared/cors.ts";
import { createJwtAuthenticator } from "../_shared/auth.ts";
import { SupabaseRateLimiter } from "../_shared/ratelimit.ts";
import { restDbFromEnv } from "../_shared/restdb.ts";
import { createSharedHandler } from "./handler.ts";

const env = Deno.env;
const db = restDbFromEnv();

const handler = createSharedHandler({
  authenticate: createJwtAuthenticator({
    supabaseUrl: env.get("SUPABASE_URL")!,
    hs256Secret: env.get("SUPABASE_JWT_SECRET"),
  }),
  rateLimiter: new SupabaseRateLimiter(db),
  insertMany: (rows) => db.insertMany("shared_history", rows),
  deleteWhere: (filter) => db.deleteWhere("shared_history", filter),
});

Deno.serve(withCors(handler, extraOriginsFromEnv()));
