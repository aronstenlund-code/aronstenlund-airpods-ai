// POST /functions/v1/provlage-eval - D87 Provläge test bank: answers on a chosen model + grading by a stronger model.
import { extraOriginsFromEnv, withCors } from "../_shared/cors.ts";
import { createJwtAuthenticator } from "../_shared/auth.ts";
import { SupabaseRateLimiter } from "../_shared/ratelimit.ts";
import { restDbFromEnv } from "../_shared/restdb.ts";
import { supabaseUsageSink } from "../_shared/usage.ts";
import { providerFromEnv } from "../answer/llm/factory.ts";
import { DEFAULT_CONFIG } from "../answer/handler.ts";
import { createEvalHandler } from "./handler.ts";

const env = Deno.env;
const db = restDbFromEnv();

const handler = createEvalHandler({
  authenticate: createJwtAuthenticator({
    supabaseUrl: env.get("SUPABASE_URL")!,
    hs256Secret: env.get("SUPABASE_JWT_SECRET"),
  }),
  rateLimiter: new SupabaseRateLimiter(db),
  provider: providerFromEnv(env),
  // usage rows are written so the eval's cost is visible, marked by the model and mode
  recordUsage: supabaseUsageSink(db),
  answerConfig: { ...DEFAULT_CONFIG, directModes: env.get("DIRECT_MODES") !== "0" },
  elevenLabsKey: env.get("ELEVENLABS_API_KEY") ?? null,
});

Deno.serve(withCors(handler, extraOriginsFromEnv()));
