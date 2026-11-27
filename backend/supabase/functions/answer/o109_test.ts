// O109 (Oscar, every mode under Fler lägen through K122).
import { assert, assertEquals, assertStringIncludes } from "jsr:@std/assert@1.0.8";
import { CRISIS_OTHER, CRISIS_SELF } from "./crisis.ts";

async function ask(body: Record<string, unknown>) {
  const { createHandler, DEFAULT_CONFIG } = await import("./handler.ts");
  const { MemoryRateLimiter } = await import("../_shared/ratelimit.ts");
  const h = createHandler({
    authenticate: () => Promise.resolve({ id: "u-o109", isAnonymous: false }), rateLimiter: new MemoryRateLimiter(),
    provider: { name: "f", model: "f", stream: () => (async function* () { yield { type: "text" as const, text: "nej" }; })() },
    recordUsage: () => {}, config: DEFAULT_CONFIG,
  });
  const res = await h(new Request("http://x/answer", { method: "POST", headers: { "content-type": "application/json", "x-forwarded-for": "198.51.100.11" }, body: JSON.stringify({ language: "sv", context: {}, ...body }) }));
  return await res.text();
}

Deno.test("O109-1: in Intervju the user's own answer with crisis words gets the answer for the user, the interviewer's question the one about someone else", async () => {
  const own = await ask({ fragment: "jag orkar inte leva längre", mode: "push_to_talk", persona: "interview", persona_setup: "Sommarjobb som butiksbiträde", turn: "user_answer" });
  assertStringIncludes(own, CRISIS_SELF.slice(0, 30));
  assert(!own.includes(CRISIS_OTHER.slice(0, 30)), "IN6: the user's own words are not about someone else");
  const theirs = await ask({ fragment: "jag orkar inte leva längre", mode: "push_to_talk", persona: "interview", persona_setup: "Sommarjobb som butiksbiträde", turn: "question" });
  assertStringIncludes(theirs, CRISIS_OTHER.slice(0, 30));
});
