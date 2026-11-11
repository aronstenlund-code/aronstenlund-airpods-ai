// /functions/v1/connect - K36: OAuth connections (Spotify). See handler.ts. Deployed with --no-verify-jwt because
// Spotify's redirect to /connect/callback carries no JWT; every other route verifies the user's JWT in the handler.
import { createJwtAuthenticator } from "../_shared/auth.ts";
import { restDbFromEnv } from "../_shared/restdb.ts";
import { restConnectionStore } from "../_shared/connections.ts";
import { TokenCrypto } from "../_shared/crypto.ts";
import { createConnectHandler } from "./handler.ts";

const env = Deno.env;
const db = restDbFromEnv();
const base = (env.get("SUPABASE_URL") ?? "").replace(/\/+$/, "");
let tc: TokenCrypto | null = null;
try {
  tc = await TokenCrypto.fromEnv(env);
} catch {
  console.warn("connect: CONNECTIONS_KEY invalid");
}
const id = env.get("SPOTIFY_CLIENT_ID"), secret = env.get("SPOTIFY_CLIENT_SECRET");

Deno.serve(createConnectHandler({
  authenticate: createJwtAuthenticator({ supabaseUrl: env.get("SUPABASE_URL")!, hs256Secret: env.get("SUPABASE_JWT_SECRET") }),
  store: restConnectionStore(db),
  crypto: tc,
  spotify: id && secret ? { clientId: id, clientSecret: secret, redirectUri: `${base}/functions/v1/connect/callback` } : null,
  returnUrl: env.get("CONNECT_RETURN_URL") || undefined,
}));
