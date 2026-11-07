// POST /functions/v1/memory - D80 memory extraction (Haiku, outside the answer path). See backend/README.md.
import { extraOriginsFromEnv, withCors } from "../_shared/cors.ts";
import { createJwtAuthenticator } from "../_shared/auth.ts";
import { SupabaseRateLimiter } from "../_shared/ratelimit.ts";
import { restDbFromEnv } from "../_shared/restdb.ts";
import { envInt, supabaseUsageSink } from "../_shared/usage.ts";
import { providerFromEnv } from "../answer/llm/factory.ts";
import { createMemoryHandler, DEFAULT_MEMORY_CONFIG } from "./handler.ts";

const env = Deno.env;
const db = restDbFromEnv();
const d = DEFAULT_MEMORY_CONFIG;

const handler = createMemoryHandler({
  authenticate: createJwtAuthenticator({
    supabaseUrl: env.get("SUPABASE_URL")!,
    hs256Secret: env.get("SUPABASE_JWT_SECRET"),
  }),
  rateLimiter: new SupabaseRateLimiter(db),
  provider: providerFromEnv(env),
  recordUsage: supabaseUsageSink(db),
  config: {
    ...d,
    model: env.get("MEMORY_MODEL") || undefined,
    networkPerDay: envInt(env, "MEMORY_PER_NETWORK_PER_DAY", d.networkPerDay),
    limits: {
      perMinute: envInt(env, "MEMORY_PER_MINUTE", d.limits.perMinute),
      perDay: envInt(env, "MEMORY_PER_DAY", d.limits.perDay),
      globalPerDay: envInt(env, "MEMORY_GLOBAL_PER_DAY", d.limits.globalPerDay),
    },
  },
});

Deno.serve(withCors(handler, extraOriginsFromEnv()));
