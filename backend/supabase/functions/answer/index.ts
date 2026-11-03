// POST /functions/v1/answer  - streamed (SSE) answer for the Lumen app. See backend/README.md.
import { createJwtAuthenticator } from "../_shared/auth.ts";
import { serviceClient, SupabaseRateLimiter } from "../_shared/ratelimit.ts";
import { envInt, supabaseUsageSink } from "../_shared/usage.ts";
import { createHandler, DEFAULT_CONFIG } from "./handler.ts";
import { providerFromEnv } from "./llm/factory.ts";

const env = Deno.env;
const supabaseUrl = env.get("SUPABASE_URL")!;
const db = serviceClient();

const handler = createHandler({
  authenticate: createJwtAuthenticator({
    supabaseUrl,
    hs256Secret: env.get("SUPABASE_JWT_SECRET"),
  }),
  rateLimiter: new SupabaseRateLimiter(db),
  provider: providerFromEnv(env),
  recordUsage: supabaseUsageSink(db),
  config: {
    ...DEFAULT_CONFIG,
    confidenceThreshold: Number(
      env.get("CONFIDENCE_THRESHOLD") ?? DEFAULT_CONFIG.confidenceThreshold,
    ),
    priceInPerMTok: Number(env.get("PRICE_IN_PER_MTOK") ?? DEFAULT_CONFIG.priceInPerMTok),
    priceOutPerMTok: Number(env.get("PRICE_OUT_PER_MTOK") ?? DEFAULT_CONFIG.priceOutPerMTok),
    limits: {
      perMinute: envInt(env, "ANSWER_PER_MINUTE", DEFAULT_CONFIG.limits.perMinute),
      perDay: envInt(env, "ANSWER_PER_DAY", DEFAULT_CONFIG.limits.perDay),
      globalPerDay: envInt(env, "ANSWER_GLOBAL_PER_DAY", DEFAULT_CONFIG.limits.globalPerDay),
    },
  },
});

Deno.serve(handler);
