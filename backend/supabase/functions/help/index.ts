// POST /functions/v1/help - K57 (D166): the help AI ("Fråga om EarMind"). See handler.ts.
import { extraOriginsFromEnv, withCors } from "../_shared/cors.ts";
import { createJwtAuthenticator } from "../_shared/auth.ts";
import { SupabaseRateLimiter } from "../_shared/ratelimit.ts";
import { restDbFromEnv } from "../_shared/restdb.ts";
import { supabaseUsageSink } from "../_shared/usage.ts";
import { providerFromEnv } from "../answer/llm/factory.ts";
import { createHelpHandler } from "./handler.ts";

const env = Deno.env;
const db = restDbFromEnv();

Deno.serve(withCors(
  createHelpHandler({
    authenticate: createJwtAuthenticator({ supabaseUrl: env.get("SUPABASE_URL")!, hs256Secret: env.get("SUPABASE_JWT_SECRET") }),
    rateLimiter: new SupabaseRateLimiter(db),
    provider: providerFromEnv(env),
    recordUsage: supabaseUsageSink(db),
    useQuota: async (u, n) => {
      const r = (await db.rpc("use_drill_quota", { p_user: u, p_n: n })) as { ok: boolean; used: number; lim: number }[];
      return r[0] ?? { ok: false, used: 0, lim: 0 };
    },
    addTryCredits: async (u, keys) => {
      for (const k of keys) await db.upsert("drill_try_credits", { user_id: u, question_key: k }, "user_id,question_key");
    },
  }),
  extraOriginsFromEnv(),
));
