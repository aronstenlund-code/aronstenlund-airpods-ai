// D239 (Toby T24/T28, 2026-11-26): a new account (1 500 free credits) could not make the smallest exam (3 questions
// at 90 words ≈ 1 926). Prices and the free amount are Aron's and unchanged: the smallest exam gets long answers short
// enough to fit (capped in code, K110, so the save cannot cost more than the estimate). Enough credits: as before.
import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { MemoryRateLimiter } from "../_shared/ratelimit.ts";
import type { LLMChunk, LLMProvider, LLMRequest } from "../answer/llm/types.ts";
import { DRILL_LIMITS, estimatedCostPerQuestion, fitLongWords } from "./drill.ts";
import { createExamHandler } from "./handler.ts";

Deno.test("D239: fitLongWords – the asked length when it fits, else the longest that fits (never under the minimum)", () => {
  assertEquals(fitLongWords(3, 5000, 90), 90);
  const w = fitLongWords(3, 1500, 90)!;
  assert(w < 90 && w >= DRILL_LIMITS.longWordsMin, String(w));
  assert(3 * estimatedCostPerQuestion(w) <= 1500 && 3 * estimatedCostPerQuestion(w + 1) > 1500, String(w));
  assertEquals(fitLongWords(3, 900, 90), null, "not even the shortest answers fit");
});

const SRC = "Fotosyntes\n\nVäxter tar upp koldioxid genom klyvöppningarna och vatten genom rötterna. I kloroplasterna fångar klorofyllet solljusets energi och bygger glukos. Syre bildas som restprodukt.";
function exam(left: number) {
  const seen: LLMRequest[] = [];
  const provider: LLMProvider = {
    name: "f", model: "f",
    stream: (r) => (seen.push(r), (async function* (): AsyncGenerator<LLMChunk> { throw new Error("stop after the prompt"); })()),
  };
  const h = createExamHandler({
    authenticate: () => Promise.resolve({ id: "u-d239", isAnonymous: true }), rateLimiter: new MemoryRateLimiter(), provider,
    quota: () => Promise.resolve({ used: 0, lim: left }),
  });
  const logs: string[] = [];
  const run = async (questions: number) => {
    const keep = console.log;
    console.log = (...a: unknown[]) => void logs.push(a.map(String).join(" "));
    try {
      return await h(new Request("http://x/exam", { method: "POST", headers: { "content-type": "application/json", "x-forwarded-for": "198.51.100.9" }, body: JSON.stringify({ action: "drill", answers: true, questions, long_words: 90, subject: "Biologi", pages: [], text: SRC }) }));
    } finally {
      console.log = keep;
    }
  };
  const fitted = () => logs.filter((l) => l.startsWith("drill_long_fitted")).map((l) => JSON.parse(l.slice("drill_long_fitted".length + 1)));
  return { run, seen, fitted };
}

Deno.test("D239: /exam with 1 500 credits makes the 3-question exam at the fitted length (no 402)", async () => {
  const e = exam(1500);
  const r = await e.run(3);
  assert(r.status !== 402, `${r.status} ${await r.text()}`);
  assert(e.seen.length > 0, "the exam was started");
  const w = fitLongWords(3, 1500, 90)!;
  assertEquals(e.fitted(), [{ asked: 90, long_words: w, questions: 3, left: 1500 }]);
});

Deno.test("D239: more questions than fit at that length is still 402, with fits at the fitted length; plenty = as before", async () => {
  const r = await exam(1500).run(12);
  assertEquals(r.status, 402);
  const j = await r.json();
  assertEquals(j.fits, Math.floor(1500 / estimatedCostPerQuestion(fitLongWords(3, 1500, 90)!)));
  assert(j.fits >= 3, JSON.stringify(j));
  const rich = exam(50_000);
  assert((await rich.run(3)).status !== 402);
  assertEquals(rich.fitted(), [], "enough credits: the asked 90 words, nothing fitted");
});
