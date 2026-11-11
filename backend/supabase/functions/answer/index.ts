// POST /functions/v1/answer  - streamed (SSE) answer for the Lumen app. See backend/README.md.
import { demoCapsFromEnv } from "../_shared/demo.ts";
import { extraOriginsFromEnv, withCors } from "../_shared/cors.ts";
import { createJwtAuthenticator } from "../_shared/auth.ts";
import { MemoryRateLimiter, SupabaseRateLimiter } from "../_shared/ratelimit.ts";
import { restDbFromEnv } from "../_shared/restdb.ts";
import { envInt, supabaseUsageSink } from "../_shared/usage.ts";
import { createHandler, DEFAULT_CONFIG } from "./handler.ts";
import { providerFromEnv } from "./llm/factory.ts";
import { withQaLog } from "./qalog.ts";
import { TokenCrypto } from "../_shared/crypto.ts";
import { restConnectionStore } from "../_shared/connections.ts";
import { accessToken } from "../_shared/spotify.ts";
import { runSpotify } from "./spotifytools.ts";

const env = Deno.env;

// Open the TLS connection to Anthropic while the isolate boots (unauthenticated GET -> 401, free and
// not billed). The connection pool then reuses it for the first real request.
const warmUpstream = () =>
  void fetch(`${env.get("ANTHROPIC_BASE_URL") || "https://api.anthropic.com"}/v1/models`).then((
    r,
  ) => r.body?.cancel()).catch(() => {});
warmUpstream();
const supabaseUrl = env.get("SUPABASE_URL")!;
const db = restDbFromEnv();

// K36: Spotify server tools only when SPOTIFY_CLIENT_ID/SECRET are set (key: CONNECTIONS_KEY or derived)
const spotifyConfigured = () => !!(env.get("SPOTIFY_CLIENT_ID") && env.get("SPOTIFY_CLIENT_SECRET"));
let tokenCrypto: TokenCrypto | null = null;
try {
  tokenCrypto = spotifyConfigured() ? await TokenCrypto.fromEnv(env) : null;
} catch {
  console.warn("answer: CONNECTIONS_KEY invalid, no Spotify tools");
}
const spotifyId = env.get("SPOTIFY_CLIENT_ID"), spotifySecret = env.get("SPOTIFY_CLIENT_SECRET");
const spotifyApp = spotifyId && spotifySecret
  ? { clientId: spotifyId, clientSecret: spotifySecret, redirectUri: `${supabaseUrl.replace(/\/+$/, "")}/functions/v1/connect/callback` }
  : null;
const connStore = restConnectionStore(db);

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
  ...(tokenCrypto && spotifyApp
    ? {
      runSpotify: async (userId: string, name: Parameters<typeof runSpotify>[0], input: Record<string, unknown>) =>
        runSpotify(name, input, await accessToken(userId, { store: connStore, crypto: tokenCrypto!, app: spotifyApp })),
    }
    : {}),
  config: {
    demo: demoCapsFromEnv(env),
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
    // D52: Rizz suggestions run on a stronger model (Sonnet 5.5: $2 in / $10 out per MTok, docs 2026-11-05).
    rizzModel: env.get("RIZZ_MODEL") || DEFAULT_CONFIG.rizzModel,
    // D87: Provläge model (unset = Haiku via LLM_MODEL); prices for the cost estimate
    tutorModel: env.get("TUTOR_MODEL") || DEFAULT_CONFIG.tutorModel,
    tutorFactRoute: env.get("TUTOR_FACT_ROUTE") === "1",
    demoModel: env.get("DEMO_MODEL") ?? DEFAULT_CONFIG.demoModel,
    tutorPriceInPerMTok: Number(env.get("TUTOR_PRICE_IN_PER_MTOK") ?? DEFAULT_CONFIG.tutorPriceInPerMTok ?? 0.10),
    tutorPriceOutPerMTok: Number(env.get("TUTOR_PRICE_OUT_PER_MTOK") ?? DEFAULT_CONFIG.tutorPriceOutPerMTok ?? 0.50),
    rizzPriceInPerMTok: Number(
      env.get("RIZZ_PRICE_IN_PER_MTOK") ?? DEFAULT_CONFIG.rizzPriceInPerMTok,
    ),
    rizzPriceOutPerMTok: Number(
      env.get("RIZZ_PRICE_OUT_PER_MTOK") ?? DEFAULT_CONFIG.rizzPriceOutPerMTok,
    ),
    // D79: per network (hashed IP) and per brand-new session; 0 turns a window off.
    appGuard: {
      networkPerDay: envInt(env, "ANSWER_PER_NETWORK_PER_DAY", DEFAULT_CONFIG.appGuard!.networkPerDay),
      newUserAgeSec: envInt(env, "NEW_USER_AGE_SEC", DEFAULT_CONFIG.appGuard!.newUserAgeSec),
      newUserPerHour: envInt(env, "NEW_USER_ANSWERS_PER_HOUR", DEFAULT_CONFIG.appGuard!.newUserPerHour),
    },
    // Web search costs $0.01 per search (owner's Claude credits): hard daily caps.
    webLimits: {
      perMinute: envInt(env, "WEB_PER_MINUTE", DEFAULT_CONFIG.webLimits!.perMinute),
      perDay: envInt(env, "WEB_PER_DAY", DEFAULT_CONFIG.webLimits!.perDay),
      globalPerDay: envInt(env, "WEB_GLOBAL_PER_DAY", DEFAULT_CONFIG.webLimits!.globalPerDay),
    },
  },
});

// K30 (D116): questions and answers to Aron's private log when the app sends qa_log: true (consent v5); masked
const waitUntil = (p: Promise<unknown>) => {
  const rt = (globalThis as { EdgeRuntime?: { waitUntil?: (p: Promise<unknown>) => void } }).EdgeRuntime;
  if (rt?.waitUntil) rt.waitUntil(p);
  else void p;
};
const logged = env.get("QA_LOG") === "0" ? handler : withQaLog(handler, (row) => db.insert("qa_log", row), waitUntil);

Deno.serve(withCors(logged, extraOriginsFromEnv()));
