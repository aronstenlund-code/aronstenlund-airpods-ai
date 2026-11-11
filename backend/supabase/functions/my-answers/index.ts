// POST /functions/v1/my-answers - K37 (D126) "Mina svar": suggest, proofread, compress. See handler.ts.
import { extraOriginsFromEnv, withCors } from "../_shared/cors.ts";
import { createJwtAuthenticator } from "../_shared/auth.ts";
import { SupabaseRateLimiter } from "../_shared/ratelimit.ts";
import { restDbFromEnv } from "../_shared/restdb.ts";
import { supabaseUsageSink } from "../_shared/usage.ts";
import { providerFromEnv } from "../answer/llm/factory.ts";
import { createMyAnswersHandler, DEFAULT_MY_ANSWERS_CONFIG } from "./handler.ts";

const env = Deno.env;
const db = restDbFromEnv();

const handler = createMyAnswersHandler({
  authenticate: createJwtAuthenticator({ supabaseUrl: env.get("SUPABASE_URL")!, hs256Secret: env.get("SUPABASE_JWT_SECRET") }),
  rateLimiter: new SupabaseRateLimiter(db),
  provider: providerFromEnv(env),
  recordUsage: supabaseUsageSink(db),
  config: DEFAULT_MY_ANSWERS_CONFIG,
});

Deno.serve(withCors(handler, extraOriginsFromEnv()));
