// GET /functions/v1/stt-token  - single-use ElevenLabs Scribe realtime token (D44). POST {seconds} logs usage.
import { demoCapsFromEnv } from "../_shared/demo.ts";
import { extraOriginsFromEnv, withCors } from "../_shared/cors.ts";
import { createJwtAuthenticator } from "../_shared/auth.ts";
import { SupabaseRateLimiter } from "../_shared/ratelimit.ts";
import { restDbFromEnv } from "../_shared/restdb.ts";
import { envInt, supabaseUsageSink } from "../_shared/usage.ts";
import { createSttHandler, DEFAULT_STT_CONFIG } from "./handler.ts";

const env = Deno.env;
const db = restDbFromEnv();

const handler = createSttHandler({
  authenticate: createJwtAuthenticator({
    supabaseUrl: env.get("SUPABASE_URL")!,
    hs256Secret: env.get("SUPABASE_JWT_SECRET"),
  }),
  rateLimiter: new SupabaseRateLimiter(db),
  apiKey: env.get("ELEVENLABS_API_KEY") ?? null,
  recordUsage: supabaseUsageSink(db),
  demo: demoCapsFromEnv(env),
  config: {
    baseUrl: env.get("ELEVENLABS_BASE_URL") || undefined,
    limits: {
      perMinute: envInt(env, "STT_TOKENS_PER_MINUTE", DEFAULT_STT_CONFIG.limits.perMinute),
      perDay: envInt(env, "STT_TOKENS_PER_DAY", DEFAULT_STT_CONFIG.limits.perDay),
      globalPerDay: envInt(
        env,
        "STT_GLOBAL_TOKENS_PER_DAY",
        DEFAULT_STT_CONFIG.limits.globalPerDay,
      ),
    },
  },
});

Deno.serve(withCors(handler, extraOriginsFromEnv()));
