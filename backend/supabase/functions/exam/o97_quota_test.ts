// O97 (Oscar 2026-11-22): with Anthropic's credits gone /exam answered 500 "internal", so the app could not say why.
// /exam and /drill now answer as /answer does: 503 provider_quota (fallback true), never 500. No real model.
import { assertEquals } from "jsr:@std/assert@1.0.8";
import { MemoryRateLimiter } from "../_shared/ratelimit.ts";
import { toHttpError } from "../_shared/errors.ts";
import { LLMProviderError, type LLMChunk, type LLMProvider } from "../answer/llm/types.ts";
import { createExamHandler } from "./handler.ts";

const broke = (kind: "quota" | "rate_limited" | "unconfigured" | "auth"): LLMProvider => ({
  name: "fake", model: "claude-haiku-5-5",
  stream(): AsyncIterable<LLMChunk> {
    // as the Anthropic provider throws on "Your credit balance is too low" (402/400 credit)
    return (async function* () { throw new LLMProviderError(kind, "credits exhausted", kind === "quota" ? 400 : 500); })();
  },
});

Deno.test("O97: /exam answers 503 provider_quota (fallback) when the model's credits are exhausted", async () => {
  const h = createExamHandler({ authenticate: () => Promise.resolve({ id: "u1", isAnonymous: true }), rateLimiter: new MemoryRateLimiter(), provider: broke("quota") });
  const res = await h(new Request("http://x/exam", { method: "POST", headers: { "content-type": "application/json", "x-forwarded-for": "1.2.3.4" },
    body: JSON.stringify({ action: "drill", text: "Fotosyntesen sker i bladen. Växten gör socker av ljus, vatten och koldioxid.", questions: 3, answers: false }) }));
  const j = await res.json();
  assertEquals([res.status, j.error.code, j.error.fallback], [503, "provider_quota", true]);
});

Deno.test("O97: the shared error mapping (/exam and /drill) gives /answer's provider codes, never 500", () => {
  const map = (k: "quota" | "rate_limited" | "unconfigured" | "auth") => {
    const e = toHttpError(new LLMProviderError(k, "x"));
    return [e.status, e.code, e.opts.fallback];
  };
  assertEquals(map("quota"), [503, "provider_quota", true]);
  assertEquals(map("rate_limited"), [503, "provider_busy", true]);
  assertEquals(map("unconfigured"), [503, "provider_unconfigured", true]);
  assertEquals(map("auth"), [503, "provider_misconfigured", true]);
  assertEquals(toHttpError(new Error("boom")).status, 500, "other errors as before");
});

Deno.test("O97: the message is for the user ('EarMind is down for a moment'), in Swedish or English after the chosen language", async () => {
  const { withCors } = await import("../_shared/cors.ts");
  const { errorResponse } = await import("../_shared/errors.ts");
  const e = toHttpError(new LLMProviderError("quota", "x"));
  assertEquals(e.message, "EarMind är nere en stund. Försök igen senare.");
  assertEquals(toHttpError(new LLMProviderError("rate_limited", "x")).message, "EarMind har mycket att göra just nu. Försök igen om en stund.");
  const h = withCors(() => Promise.resolve(errorResponse(e)));
  const en = await (await h(new Request("http://x/exam", { method: "POST", headers: { "x-earmind-lang": "en" } }))).json();
  assertEquals(en.error.message, "EarMind is down for a moment. Try again later.");
  const sv = await (await h(new Request("http://x/exam", { method: "POST", headers: { "accept-language": "sv-SE" } }))).json();
  assertEquals(sv.error.message, "EarMind är nere en stund. Försök igen senare.");
});
