// Local dev server for the /answer and /tts handlers WITHOUT Supabase (no project, no cost).
//   deno task dev            -> mock LLM, token "dev-token", http://127.0.0.1:8787/functions/v1/answer
//   LLM_PROVIDER=anthropic ANTHROPIC_API_KEY=... deno task dev   (uses the real model; key from YOUR shell)
// Auth is replaced by a fixed dev token and ONLY exists in this file; it is never deployed.
import { HttpError } from "../supabase/functions/_shared/errors.ts";
import { MemoryRateLimiter } from "../supabase/functions/_shared/ratelimit.ts";
import { createHandler, DEFAULT_CONFIG } from "../supabase/functions/answer/handler.ts";
import { providerFromEnv } from "../supabase/functions/answer/llm/factory.ts";
import { MockProvider } from "../supabase/functions/answer/llm/mock.ts";

const env = {
  get: (k: string) => Deno.env.get(k) ?? (k === "LLM_PROVIDER" ? "mock" : undefined),
};
const provider = (env.get("LLM_PROVIDER") === "mock")
  ? new MockProvider({ delayMs: Number(Deno.env.get("MOCK_DELAY_MS") ?? 15) })
  : providerFromEnv(env);

const handler = createHandler({
  authenticate: (req) => {
    if (req.headers.get("authorization") !== "Bearer dev-token") {
      return Promise.reject(
        new HttpError(401, "unauthorized", "Use Authorization: Bearer dev-token locally"),
      );
    }
    return Promise.resolve({ id: "00000000-0000-0000-0000-000000000001", isAnonymous: true });
  },
  rateLimiter: new MemoryRateLimiter(),
  provider,
  recordUsage: (r) => {
    if (Deno.env.get("DEV_LOG_USAGE") === "1") console.log("usage", JSON.stringify(r));
  },
  config: { ...DEFAULT_CONFIG, limits: { perMinute: 1000, perDay: 100000, globalPerDay: 100000 } },
});

const port = Number(Deno.env.get("PORT") ?? 8787);
console.log(
  `dev server: http://127.0.0.1:${port}/functions/v1/answer  provider=${provider?.name ?? "none"}`,
);
Deno.serve({ port, hostname: "127.0.0.1" }, (req) => {
  const p = new URL(req.url).pathname;
  if (p.endsWith("/answer")) return handler(req);
  return new Response("not found", { status: 404 });
});
