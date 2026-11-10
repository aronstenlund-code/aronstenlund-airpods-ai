// POST /functions/v1/study-plan - K17 spaced repetition and a daily plan up to the exam (code only, no model).
import { extraOriginsFromEnv, withCors } from "../_shared/cors.ts";
import { createJwtAuthenticator } from "../_shared/auth.ts";
import { createPlanHandler } from "./handler.ts";

const env = Deno.env;

const handler = createPlanHandler({
  authenticate: createJwtAuthenticator({
    supabaseUrl: env.get("SUPABASE_URL")!,
    hs256Secret: env.get("SUPABASE_JWT_SECRET"),
  }),
});

Deno.serve(withCors(handler, extraOriginsFromEnv()));
