// POST /functions/v1/study-profile - D84 spoken study profile + subject term list (Haiku).
import { extraOriginsFromEnv, withCors } from "../_shared/cors.ts";
import { createJwtAuthenticator } from "../_shared/auth.ts";
import { SupabaseRateLimiter } from "../_shared/ratelimit.ts";
import { restDbFromEnv } from "../_shared/restdb.ts";
import { supabaseUsageSink } from "../_shared/usage.ts";
import { providerFromEnv } from "../answer/llm/factory.ts";
import { createProfileHandler, DEFAULT_PROFILE_CONFIG } from "./handler.ts";

const env = Deno.env;
const db = restDbFromEnv();

const handler = createProfileHandler({
  authenticate: createJwtAuthenticator({
    supabaseUrl: env.get("SUPABASE_URL")!,
    hs256Secret: env.get("SUPABASE_JWT_SECRET"),
  }),
  rateLimiter: new SupabaseRateLimiter(db),
  provider: providerFromEnv(env),
  recordUsage: supabaseUsageSink(db),
  config: { ...DEFAULT_PROFILE_CONFIG, model: env.get("PROFILE_MODEL") || undefined },
});

Deno.serve(withCors(handler, extraOriginsFromEnv()));
