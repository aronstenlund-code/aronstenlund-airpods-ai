// K109 (D239, Oscar O90): no exam is generated that the credits cannot save; the answer says how many questions fit.
import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { MemoryRateLimiter } from "../_shared/ratelimit.ts";
import { createExamHandler } from "./handler.ts";
import { estimatedCostPerQuestion } from "./drill.ts";
import type { LLMChunk, LLMProvider, LLMRequest } from "../answer/llm/types.ts";

function world(o: { used: number; lim: number; unlimited?: boolean }) {
  const calls: LLMRequest[] = [];
  const llm: LLMProvider = {
    name: "f", model: "x",
    async *stream(req: LLMRequest): AsyncIterable<LLMChunk> {
      calls.push(req);
      yield { type: "text", text: "{}" } as LLMChunk;
    },
  };
  const h = createExamHandler({
    authenticate: () => Promise.resolve({ id: "u1", isAnonymous: true }),
    rateLimiter: new MemoryRateLimiter(),
    provider: llm,
    quota: () => Promise.resolve({ used: o.used, lim: o.lim, ...(o.unlimited ? { unlimited: true } : {}) }),
  });
  const ask = async (b: Record<string, unknown>) => {
    const r = await h(new Request("http://x/exam", { method: "POST", headers: { "content-type": "application/json", "x-forwarded-for": "1.2.3.4" }, body: JSON.stringify(b) }));
    return { status: r.status, body: await r.json() as Record<string, unknown> };
  };
  return { ask, calls };
}

Deno.test("K109: the estimate per question follows the long answer's length (Oscar O90: 12 questions at 90 words cost 5 882)", () => {
  const per = estimatedCostPerQuestion(90);
  assert(per >= 470 && per <= 520, String(per));
  assert(estimatedCostPerQuestion(40) < per);
});

Deno.test("K109: drill with too few credits is 402 before any model call, with how many questions fit", async () => {
  const w = world({ used: 0, lim: 1500 });
  const r = await w.ask({ action: "drill", text: "Fotosyntes är när växter gör socker av ljus.", questions: 12 });
  assertEquals(r.status, 402);
  const e = r.body.error as Record<string, unknown>;
  assertEquals(e.code, "quota_exceeded");
  const per = estimatedCostPerQuestion(90);
  assertEquals(r.body.fits, Math.floor(1500 / per));
  assertEquals(r.body.cost, 12 * per);
  assertEquals(r.body.remaining, 1500);
  assertEquals(r.body.estimated, true);
  assert(String(e.message).includes("räcker till"), String(e.message));
  assertEquals(w.calls.length, 0, "no exam is made that cannot be saved");
});

Deno.test("K109: enough credits, or unlimited, makes the exam as before", async () => {
  const ok = world({ used: 0, lim: 6500 });
  const r = await ok.ask({ action: "drill", text: "Fotosyntes är när växter gör socker av ljus.", questions: 12 });
  assert(r.status !== 402, JSON.stringify(r.body).slice(0, 200));
  assert(ok.calls.length > 0);
  const admin = world({ used: 0, lim: 1_000_000_000, unlimited: true }); // as wallet.ts: lim = used + BIG
  const a = await admin.ask({ action: "drill", text: "Fotosyntes är när växter gör socker av ljus.", questions: 20 });
  assert(a.status !== 402);
});

Deno.test("K109: drill_answers counts its questions and the long answers to come; 402 with fits before any call", async () => {
  const w = world({ used: 0, lim: 1200 });
  const items = Array.from({ length: 10 }, (_, i) => ({ id: `q${i + 1}`, question: `Vad är fråga nummer ${i + 1}?` }));
  const r = await w.ask({ action: "drill_answers", items, long_words: 90 });
  assertEquals(r.status, 402);
  assertEquals(typeof r.body.fits, "number");
  assert((r.body.fits as number) < 10);
  assertEquals(w.calls.length, 0);
});

Deno.test("K109 (Oscar O91): a QA measurement (test header from CI, deps.qaMeasure) skips the estimate; the credits are still taken at save", async () => {
  const { createExamHandler: mk } = await import("./handler.ts");
  const { fromCi, setCiRangesForTest, resetCiRangesForTest } = await import("../_shared/testmode.ts");
  const calls: LLMRequest[] = [];
  const llm: LLMProvider = { name: "f", model: "x", async *stream(req: LLMRequest): AsyncIterable<LLMChunk> { calls.push(req); yield { type: "text", text: "{}" } as LLMChunk; } };
  let u = 0;
  const h = mk({
    authenticate: () => Promise.resolve({ id: `u${++u}`, isAnonymous: true }), // a new account per call (no 429)
    rateLimiter: new MemoryRateLimiter(),
    provider: llm,
    quota: () => Promise.resolve({ used: 0, lim: 1500 }),
    qaMeasure: (req) => Promise.resolve(req.headers.has("x-earmind-test") && !/user-path/.test(req.headers.get("x-earmind-test")!) && fromCi(req)),
  });
  const ask = (ip: string, header: boolean | string) =>
    h(new Request("http://x/exam", {
      method: "POST",
      headers: { "content-type": "application/json", "x-forwarded-for": ip, ...(header ? { "x-earmind-test": header === true ? "kevin-k102" : header } : {}) },
      body: JSON.stringify({ action: "drill", text: "Fotosyntes är när växter gör socker av ljus.", questions: 12 }),
    }));
  setCiRangesForTest(["20.1.0.0/16"]);
  try {
    const qa = await ask("20.1.2.3", true);
    assert(qa.status !== 402, String(qa.status));
    await qa.body?.cancel();
    assert(calls.length > 0);
    const n = calls.length;
    const anyone = await ask("1.2.3.4", true); // the header alone (anyone can send it) is not enough
    assertEquals(anyone.status, 402);
    await anyone.body?.cancel();
    const ciNoHeader = await ask("20.1.2.3", false);
    assertEquals(ciNoHeader.status, 402);
    await ciNoHeader.body?.cancel();
    const userPath = await ask("20.1.2.3", "kevin-k109 user-path"); // QA checking what a user gets
    assertEquals(userPath.status, 402);
    await userPath.body?.cancel();
    assertEquals(calls.length, n);
  } finally {
    resetCiRangesForTest();
  }
});
