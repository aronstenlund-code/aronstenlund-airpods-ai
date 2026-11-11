// GET/POST /functions/v1/logo-vote - K39 (D127): the logo vote. See handler.ts.
import { extraOriginsFromEnv, withCors } from "../_shared/cors.ts";
import { createJwtAuthenticator } from "../_shared/auth.ts";
import { SupabaseRateLimiter } from "../_shared/ratelimit.ts";
import { restDbFromEnv } from "../_shared/restdb.ts";
import { type Choice, createLogoVoteHandler } from "./handler.ts";

const env = Deno.env;
const db = restDbFromEnv();

Deno.serve(withCors(
  createLogoVoteHandler({
    authenticate: createJwtAuthenticator({ supabaseUrl: env.get("SUPABASE_URL")!, hs256Secret: env.get("SUPABASE_JWT_SECRET") }),
    rateLimiter: new SupabaseRateLimiter(db),
    ownerEmails: (env.get("OWNER_EMAIL") ?? "").split(","),
    cast: async (u, c) => {
      await db.rpc("cast_logo_vote", { p_user: u, p_choice: c });
    },
    own: async (u) => {
      const rows = await db.select("logo_votes", `select=choice&user_id=eq.${encodeURIComponent(u)}&limit=1`) as { choice: Choice }[];
      return rows[0]?.choice ?? null;
    },
    counts: async () => {
      const rows = await db.rpc("logo_vote_counts", {}) as { choice: Choice; votes: number }[];
      const out = { A: 0, B: 0, C: 0 } as Record<Choice, number>;
      for (const r of rows) if (r.choice in out) out[r.choice] = Number(r.votes) || 0;
      return out;
    },
  }),
  extraOriginsFromEnv(),
));
