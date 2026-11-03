// POST /functions/v1/answer  - streamed (SSE) answer for the Lumen app. See backend/README.md.
import { createJwtAuthenticator } from "../_shared/auth.ts";
import { MemoryRateLimiter, SupabaseRateLimiter } from "../_shared/ratelimit.ts";
import { restDbFromEnv } from "../_shared/restdb.ts";
import { envInt, supabaseUsageSink } from "../_shared/usage.ts";
import { createHandler, DEFAULT_CONFIG } from "./handler.ts";
import { providerFromEnv } from "./llm/factory.ts";

const env = Deno.env;

// Open the TLS connection to Anthropic while the isolate boots (unauthenticated GET -> 401, free and
// not billed). The connection pool then reuses it for the first real request.
const warmUpstream = () =>
  void fetch("https://api.anthropic.com/v1/models").then((r) => r.body?.cancel()).catch(() => {});
warmUpstream();
const supabaseUrl = env.get("SUPABASE_URL")!;
const db = restDbFromEnv();

const handler = createHandler({
  authenticate: createJwtAuthenticator({
    supabaseUrl,
    hs256Secret: env.get("SUPABASE_JWT_SECRET"),
  }),
  rateLimiter: new SupabaseRateLimiter(db),
  localLimiter: new MemoryRateLimiter(),
  warm: warmUpstream,
  provider: providerFromEnv(env),
  recordUsage: supabaseUsageSink(db),
  config: {
    ...DEFAULT_CONFIG,
    directModes: env.get("DIRECT_MODES") !== "0",
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
