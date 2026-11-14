// GET /functions/v1/stt-token  - single-use ElevenLabs Scribe realtime token (D44). POST {seconds} logs usage.
import { demoCapsFromEnv } from "../_shared/demo.ts";
import { extraOriginsFromEnv, withCors } from "../_shared/cors.ts";
import { createJwtAuthenticator } from "../_shared/auth.ts";
import { SupabaseRateLimiter } from "../_shared/ratelimit.ts";
import { restDbFromEnv } from "../_shared/restdb.ts";
import { secret } from "../_shared/secrets.ts";
import { envInt, supabaseUsageSink } from "../_shared/usage.ts";
import { createSttHandler, DEFAULT_STT_CONFIG } from "./handler.ts";
import { CORS_HEADERS } from "../_shared/errors.ts";
import { FAKE_TRANSCRIPT, guardedFetch, withTestMode } from "../_shared/testmode.ts";

const env = Deno.env;
const db = restDbFromEnv();

const handler = createSttHandler({
  authenticate: createJwtAuthenticator({
    supabaseUrl: env.get("SUPABASE_URL")!,
    hs256Secret: env.get("SUPABASE_JWT_SECRET"),
  }),
  rateLimiter: new SupabaseRateLimiter(db),
  apiKey: secret(env, "ELEVENLABS_API_KEY"),
  recordUsage: supabaseUsageSink(db),
  demo: demoCapsFromEnv(env),
  fetchImpl: guardedFetch(fetch, "stt-token"), // K62b: a test request that gets this far throws
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

// K62b (D180): a test account gets no Scribe token; the app uses its recorded transcripts (fake: true)
const fake = (req: Request) =>
  req.method === "GET"
    ? new Response(JSON.stringify({
      fake: true, token: null, ws_url: null, expires_in: 0, model_id: "fake", language_code: "swe", transcript: FAKE_TRANSCRIPT,
      reason: "D180: test accounts never use ElevenLabs",
    }), { status: 200, headers: { "content-type": "application/json", "cache-control": "no-store", ...CORS_HEADERS } })
    : null;
Deno.serve(withCors(withTestMode("stt-token", handler, { fake }), extraOriginsFromEnv()));
