// POST /functions/v1/fetch-url - K81 (D204): a web page's text for the material flow. See handler.ts.
import { extraOriginsFromEnv, withCors } from "../_shared/cors.ts";
import { createJwtAuthenticator } from "../_shared/auth.ts";
import { SupabaseRateLimiter } from "../_shared/ratelimit.ts";
import { restDbFromEnv } from "../_shared/restdb.ts";
import { dohResolver } from "./guard.ts";
import { createFetchUrlHandler } from "./handler.ts";

const env = Deno.env;
const db = restDbFromEnv();
const own = new URL(env.get("SUPABASE_URL") ?? "https://invalid.example").hostname;

Deno.serve(withCors(
  createFetchUrlHandler({
    authenticate: createJwtAuthenticator({ supabaseUrl: env.get("SUPABASE_URL")!, hs256Secret: env.get("SUPABASE_JWT_SECRET") }),
    rateLimiter: new SupabaseRateLimiter(db),
    resolve: dohResolver(),
    ownHosts: [own, "supabase.co", "supabase.in"],
  }),
  extraOriginsFromEnv(),
));
