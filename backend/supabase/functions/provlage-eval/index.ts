// POST /functions/v1/provlage-eval - D87 Provläge test bank: answers on a chosen model + grading by a stronger model.
import { extraOriginsFromEnv, withCors } from "../_shared/cors.ts";
import { createJwtAuthenticator } from "../_shared/auth.ts";
import { SupabaseRateLimiter } from "../_shared/ratelimit.ts";
import { restDbFromEnv } from "../_shared/restdb.ts";
import { secret } from "../_shared/secrets.ts";
import { supabaseUsageSink } from "../_shared/usage.ts";
import { providerFromEnv } from "../answer/llm/factory.ts";
import { DEFAULT_CONFIG } from "../answer/handler.ts";
import { createEvalHandler } from "./handler.ts";
import { CORS_HEADERS } from "../_shared/errors.ts";
import { FAKE_TRANSCRIPT, guardedFetch, withTestMode } from "../_shared/testmode.ts";

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
  elevenLabsKey: secret(env, "ELEVENLABS_API_KEY"),
  fetchImpl: guardedFetch(fetch, "provlage-eval"), // K62b: a test request that gets this far throws
});

// K62b (D180): the eval is test traffic: "transcribe" gets a fake transcript, never Scribe
const fake = async (req: Request) => {
  const b = (await req.clone().json().catch(() => null)) as Record<string, unknown> | null;
  return b?.action === "transcribe"
    ? new Response(JSON.stringify({ text: FAKE_TRANSCRIPT, model: "fake", fake: true }), { status: 200, headers: { "content-type": "application/json", ...CORS_HEADERS } })
    : null;
};
Deno.serve(withCors(withTestMode("provlage-eval", handler, { fake }), extraOriginsFromEnv()));
