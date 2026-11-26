// K121: cheaper models behind flags, the defaults unchanged. The test header's model pick (`model-haiku`, K104) also
// reaches Provläge and the exam's answers, so the live eval can measure Haiku there on test traffic only; production
// keeps Sonnet until TUTOR_MODEL / DRILL_ANSWER_MODEL are set. A pretend model only (no real calls, D258).
import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { MemoryRateLimiter } from "../_shared/ratelimit.ts";
import { createHandler, DEFAULT_CONFIG } from "./handler.ts";
import { createExamHandler } from "../exam/handler.ts";
import { DEFAULT_DRILL_CONFIG, drillConfigFromEnv } from "../exam/drill.ts";
import { cacheReadMultiplier } from "../_shared/prices.ts";
import type { LLMChunk, LLMProvider, LLMRequest } from "./llm/types.ts";

function fake(reply: string) {
  const seen: LLMRequest[] = [];
  const usage: Record<string, unknown>[] = [];
  const provider: LLMProvider = {
    name: "fake", model: "claude-haiku-5-5",
    stream(r: LLMRequest): AsyncIterable<LLMChunk> {
      seen.push(r);
      return (async function* () {
        yield { type: "text", text: reply } as LLMChunk;
        yield { type: "usage", inputTokens: 1000, outputTokens: 100 } as LLMChunk;
      })();
    },
  };
  return { provider, seen, usage };
}
const tutorBody = { fragment: "varför är himlen blå", mode: "tutor", persona: "tutor", persona_setup: "Prov i Fysik. Årskurs: Åk 9.", language: "sv", context: {} };

async function tutor(header?: string) {
  const f = fake("Ljuset sprids i luften.");
  const h = createHandler({ authenticate: () => Promise.resolve({ id: "u", isAnonymous: true }), rateLimiter: new MemoryRateLimiter(), provider: f.provider, recordUsage: (r) => void f.usage.push(r as unknown as Record<string, unknown>), config: { ...DEFAULT_CONFIG, tutorModel: "claude-sonnet-5-5", tutorPriceInPerMTok: 2, tutorPriceOutPerMTok: 10 } });
  await (await h(new Request("http://x/answer", { method: "POST", headers: { "content-type": "application/json", ...(header ? { "x-earmind-test": header } : {}) }, body: JSON.stringify(tutorBody) }))).text();
  return f;
}

Deno.test("K121: Provläge stays on its model (Sonnet) by default; the test header model-haiku runs it on Haiku, priced as Haiku", async () => {
  const d = await tutor();
  assertEquals(d.seen.at(-1)!.model, "claude-sonnet-5-5");
  const h = await tutor("oscar-qa model-haiku");
  assert(h.seen.every((r) => r.model === undefined || r.model === "claude-haiku-5-5"), JSON.stringify(h.seen.map((r) => r.model)));
  const ud = d.usage.find((u) => u.endpoint === "answer")!, uh = h.usage.find((u) => u.endpoint === "answer")!;
  assertEquals(uh.model, "claude-haiku-5-5");
  assert(Number(uh.est_cost_usd) < Number(ud.est_cost_usd) / 10, `${uh.est_cost_usd} vs ${ud.est_cost_usd}`);
});

Deno.test("K121: the exam's answers stay on Sonnet by default; model-haiku (test) or DRILL_ANSWER_MODEL moves them", async () => {
  const items = [{ id: "q1", question: "Vad är fotosyntes?" }];
  const run = async (header?: string) => {
    const f = fake(JSON.stringify({ answers: [{ id: "q1", short: "Växter gör socker av ljus.", rest: "De använder vatten och koldioxid." }] }));
    const h = createExamHandler({ authenticate: () => Promise.resolve({ id: "u1", isAnonymous: true }), rateLimiter: new MemoryRateLimiter(), provider: f.provider });
    await (await h(new Request("http://x/exam", { method: "POST", headers: { "content-type": "application/json", "x-forwarded-for": "1.2.3.4", ...(header ? { "x-earmind-test": header } : {}) }, body: JSON.stringify({ action: "drill_answers", items, notes: "Fotosyntes: växter gör socker av ljus.", subject: "Biologi" }) }))).text();
    return f.seen.map((r) => r.model);
  };
  assert((await run()).includes("claude-sonnet-5-5"));
  assert(!(await run("oscar-qa model-haiku")).includes("claude-sonnet-5-5"));
  assertEquals(drillConfigFromEnv({ get: () => undefined }), DEFAULT_DRILL_CONFIG, "unset = unchanged");
  const env = new Map([["DRILL_ANSWER_MODEL", "claude-haiku-5-5"]]);
  const c = drillConfigFromEnv({ get: (k) => env.get(k) });
  assertEquals([c.answerModel, c.answerPriceIn, c.answerPriceOut], ["claude-haiku-5-5", 0.10, 0.50]);
});

Deno.test("K121: cache reads are priced per model (Sonnet 5.5 0.05x, Haiku 5.5 0.1x) in the cost estimate", () => {
  assertEquals(cacheReadMultiplier("claude-sonnet-5-5"), 0.05);
  assertEquals(cacheReadMultiplier("claude-haiku-5-5"), 0.1);
  assertEquals(cacheReadMultiplier("something-else"), 0.1);
});
