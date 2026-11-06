// POST /functions/v1/feedback - user-triggered report / app feedback / suggestion (D57).
import { createJwtAuthenticator } from "../_shared/auth.ts";
import { SupabaseRateLimiter } from "../_shared/ratelimit.ts";
import { restDbFromEnv } from "../_shared/restdb.ts";
import { createFeedbackHandler } from "./handler.ts";

const env = Deno.env;
const db = restDbFromEnv();

Deno.serve(createFeedbackHandler({
  authenticate: createJwtAuthenticator({
    supabaseUrl: env.get("SUPABASE_URL")!,
    hs256Secret: env.get("SUPABASE_JWT_SECRET"),
  }),
  rateLimiter: new SupabaseRateLimiter(db),
  insert: (row) => db.insert("feedback", row),
}));
