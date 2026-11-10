import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { MemoryRateLimiter } from "../_shared/ratelimit.ts";
import type { LLMChunk, LLMProvider, LLMRequest } from "../answer/llm/types.ts";
import { createExamHandler } from "./handler.ts";
import { practiceNav, spokenTask } from "./practice.ts";

const NOS = ["1", "2", "3a", "3b", "4", "5", "6", "7", "8", "9", "10", "11"];

Deno.test("K15 nav: next, previous, a task by number (digits, words, 3b), skip, repeat, stop; an answer is graded", () => {
  assertEquals(practiceNav("nästa", 0, NOS), { action: "next", index: 1 });
  assertEquals(practiceNav("Lumen, nästa fråga tack", 4, NOS), { action: "next", index: 5 });
  assertEquals(practiceNav("förra", 4, NOS), { action: "prev", index: 3 });
  assertEquals(practiceNav("fråga 7", 0, NOS), { action: "goto", index: 7 });
  assertEquals(practiceNav("kan vi ta fråga sju", 0, NOS), { action: "goto", index: 7 });
  assertEquals(practiceNav("uppgift 3b", 0, NOS), { action: "goto", index: 3 });
  assertEquals(practiceNav("fråga tre b", 0, NOS), { action: "goto", index: 3 });
  assertEquals(practiceNav("fråga tre", 0, NOS), { action: "goto", index: 2 }, "3 = the first of 3a, 3b");
  assertEquals(practiceNav("hoppa över den", 2, NOS), { action: "skip", index: 3 });
  assertEquals(practiceNav("kan du upprepa frågan", 2, NOS), { action: "repeat", index: 2 });
  assertEquals(practiceNav("avsluta provet", 2, NOS).action, "stop");
  assertEquals(practiceNav("hur gick det", 2, NOS).action, "results");
  for (const a of ["sju", "126 kronor", "det är fyrtio procent", "nästan hälften", "fotosyntesen behöver ljus"]) {
    assertEquals(practiceNav(a, 0, NOS).action, "answer", a);
  }
  assertEquals(practiceNav("nästa", 11, NOS), { action: "next", index: 11 }, "never past the last task");
});

Deno.test("K15 spoken task: number, text with numbers in words, the points", () => {
  const s = spokenTask("3b", "Beräkna 15 % av 840 kr.", { E: 1, C: 1, A: 0 });
  assert(s.startsWith("Fråga tre b") || s.startsWith("Fråga 3b") || s.startsWith("Fråga tre"), s);
  assert(s.includes("femton procent") && s.includes("åttahundrafyrtio kronor"), s);
  assert(s.includes("två poäng"), s);
  assert(spokenTask("1", "Lös x.", { E: 1, C: 0, A: 0 }).includes("en poäng"));
});

class Seq implements LLMProvider {
  readonly name = "fake";
  readonly model = "fake-1";
  calls: LLMRequest[] = [];
  constructor(private replies: string[]) {}
  async *stream(req: LLMRequest): AsyncIterable<LLMChunk> {
    this.calls.push(req);
    yield { type: "text", text: this.replies[Math.min(this.calls.length - 1, this.replies.length - 1)] };
    yield { type: "usage", inputTokens: 1000, outputTokens: 400 };
  }
}
const post = (b: unknown) =>
  new Request("http://x/exam", {
    method: "POST",
    headers: { "content-type": "application/json", "x-forwarded-for": "1.2.3.4" },
    body: JSON.stringify(b),
  });

Deno.test("K15 parse from text: tasks, topic, spoken form; no facit = Lumen's own answer, marked", async () => {
  const llm = new Seq([
    JSON.stringify({
      tasks: [
        { no: "1", text: "Beräkna 15 % av 840 kr.", points: { E: 1, C: 0, A: 0 }, answer: "126 kr", assessment: "", topic: "procent" },
        { no: "2", text: "Förklara varför franska revolutionen bröt ut.", points: { E: 1, C: 1, A: 1 }, answer: "", assessment: "", topic: "franska revolutionen" },
      ],
      boundaries: [],
    }),
    JSON.stringify({ answers: [{ no: "2", answer: "Missnöje med skatter och brist på mat, upplysningens idéer och statens skulder." }] }),
  ]);
  const h = createExamHandler({ authenticate: () => Promise.resolve({ id: "u1", isAnonymous: true }), rateLimiter: new MemoryRateLimiter(), provider: llm });
  const r = await h(post({ action: "parse", text: "1. Beräkna 15 % av 840 kr. (1/0/0) Svar: 126 kr\n2. Förklara varför franska revolutionen bröt ut. (1/1/1)", subject: "SO", grade: "Åk 9" }));
  assertEquals(r.status, 200);
  const j = await r.json();
  assertEquals(j.tasks.length, 2);
  assertEquals(j.tasks[0].answer_source, "facit");
  assertEquals(j.tasks[1].answer_source, "eget svar");
  assert(j.tasks[1].answer.includes("upplysningens"));
  assertEquals(j.tasks[0].topic, "procent");
  assert(j.tasks[0].spoken.includes("femton procent"), j.tasks[0].spoken);
  assert(llm.calls[0].user.includes("<material>") && !llm.calls[0].images);
  assertEquals(llm.calls[1].model, "claude-sonnet-5-5", "own answers on the stronger model");
});

Deno.test("K15 nav is code only (no model call); grade with practice explains", async () => {
  const llm = new Seq([JSON.stringify({ points: { E: 1, C: 0, A: 0 }, feedback: "Rätt. 15 % av 840 är 126 eftersom 0,15 gånger 840 är 126." })]);
  const h = createExamHandler({ authenticate: () => Promise.resolve({ id: "u1", isAnonymous: true }), rateLimiter: new MemoryRateLimiter(), provider: llm });
  const n = await (await h(post({ action: "nav", utterance: "fråga sju", current: 0, nos: NOS }))).json();
  assertEquals(n, { action: "goto", index: 7 });
  assertEquals(llm.calls.length, 0);
  const g = await h(post({ action: "grade", practice: true, task: { no: "1", text: "Beräkna 15 % av 840 kr.", points: { E: 1, C: 0, A: 0 }, answer: "126 kr", assessment: "" }, answer: "etthundratjugosex kronor" }));
  assertEquals(g.status, 200);
  assert(llm.calls[0].system.includes("PRACTICE RUN"));
});

Deno.test("K15 the result said first, the reason after 'för' or 'eftersom', counts as the answer", async () => {
  const { numericCheck } = await import("./handler.ts");
  assert(numericCheck("375 kr", "trehundrasjuttiofem kronor, för tjugofem procent av trehundra är sjuttiofem")!.equal);
  assert(numericCheck("10 cm", "tio centimeter för sex i kvadrat plus åtta i kvadrat är hundra")!.equal);
  assert(!numericCheck("375 kr", "fyrahundra kronor, för den blir lika dyr igen")!.equal);
  assert(!numericCheck("10 cm", "fjorton centimeter")!.equal);
  assert(numericCheck("126 kr", "jag räknade 0,15 gånger 840 och fick 126")!.equal, "the last number still counts");
});
