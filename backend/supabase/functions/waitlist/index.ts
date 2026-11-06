// POST /functions/v1/waitlist - e-mail waitlist for the public demo page (D62). Public: deploy with verify_jwt=false.
import { extraOriginsFromEnv, withCors } from "../_shared/cors.ts";
import { SupabaseRateLimiter } from "../_shared/ratelimit.ts";
import { restDbFromEnv } from "../_shared/restdb.ts";
import { createWaitlistHandler } from "./handler.ts";

const db = restDbFromEnv();
Deno.serve(withCors(
  createWaitlistHandler({
    rateLimiter: new SupabaseRateLimiter(db),
    insert: (row) => db.insertIgnoreDuplicate("waitlist", row, "email"),
  }),
  extraOriginsFromEnv(),
));
