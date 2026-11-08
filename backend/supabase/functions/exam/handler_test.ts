import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { MemoryRateLimiter } from "../_shared/ratelimit.ts";
import type { LLMChunk, LLMProvider, LLMRequest } from "../answer/llm/types.ts";
import { createExamHandler, lastNumber, numericCheck, parseExamReply, summarize } from "./handler.ts";

class FakeLLM implements LLMProvider {
  readonly name = "fake";
  readonly model = "fake-1";
  calls: LLMRequest[] = [];
  constructor(private reply: string) {}
  async *stream(req: LLMRequest): AsyncIterable<LLMChunk> {
    this.calls.push(req);
    yield { type: "text", text: this.reply };
    yield { type: "usage", inputTokens: 3000, outputTokens: 800 };
  }
}
const mk = (reply: string) => {
  const llm = new FakeLLM(reply);
  const h = createExamHandler({
    authenticate: () => Promise.resolve({ id: "u1", isAnonymous: true }),
    rateLimiter: new MemoryRateLimiter(),
    provider: llm,
  });
  return { h, llm };
};
const post = (b: unknown) =>
  new Request("http://x/exam", {
    method: "POST",
    headers: { "content-type": "application/json", "x-forwarded-for": "1.2.3.4" },
    body: JSON.stringify(b),
  });
const TASK = { no: "3", text: "Beräkna 15 % av 840 kr.", points: { E: 1, C: 1, A: 0 }, answer: "126 kr", assessment: "+E korrekt metod, +C korrekt svar" };

Deno.test("D84 exam parse: page images go to the model, tasks and limits come back", async () => {
  const { h, llm } = mk(JSON.stringify({
    tasks: [TASK, { no: "", text: "x" }, { no: "4", text: "" }],
    boundaries: [{ grade: "E", total: 15 }, { grade: "A", total: 45, min_a: 7 }, { grade: "Q", total: 3 }],
  }));
  const r = await h(post({ action: "parse", pages: [{ media_type: "image/png", data: "iVBORw0KGgo=" }], subject: "Matematik" }));
  assertEquals(r.status, 200);
  const j = await r.json();
  assertEquals(j.tasks.length, 1);
  assertEquals(j.boundaries, [{ grade: "E", total: 15 }, { grade: "A", total: 45, min_a: 7 }]);
  assertEquals(llm.calls[0].images?.length, 1);
  assertEquals((await h(post({ action: "parse", pages: [] }))).status, 400);
  assertEquals((await h(post({ action: "parse", pages: [{ media_type: "application/pdf", data: "x" }] }))).status, 400);
});

Deno.test("D84 exam grade: numbers checked in code, points clamped to the task's", async () => {
  assertEquals(lastNumber("Svaret är 126 kronor"), 126);
  assertEquals(lastNumber("det blir sjuttiotvåtusen niohundra"), 72900);
  assertEquals(lastNumber("72 900"), 72900);
  assertEquals(numericCheck("126 kr", "jag fick hundratjugosex")?.equal, true);
  assertEquals(numericCheck("126 kr", "130")?.equal, false);
  assertEquals(numericCheck("8 − x", "x minus 8"), null, "an expression is not checked as a number");
  assertEquals(numericCheck("x = 5", "fem")?.equal, true);
  const { h, llm } = mk('{"points": {"E": 5, "C": 1, "A": 1}, "feedback": "Rätt metod och svar."}');
  const r = await h(post({ action: "grade", task: TASK, answer: "15 procent av 840 är 126" }));
  const j = await r.json();
  assertEquals(j.points, { E: 1, C: 1, A: 0 }, "never more than the task gives");
  assertEquals(j.numeric.equal, true);
  assert(llm.calls[0].user.includes("The final number is correct (126)"));
});

Deno.test("D84 exam summary: totals and the grade in code only (no model)", async () => {
  const b = [{ grade: "E", total: 10 }, { grade: "C", total: 20, min_ca: 6 }, { grade: "A", total: 30, min_a: 5 }];
  const s = summarize([{ no: "1", points: { E: 8, C: 6, A: 2 } }, { no: "2", points: { E: 2, C: 1, A: 1 } }], b as never);
  assertEquals(s.total, 20);
  assertEquals(s.grade, "C");
  assertEquals(s.to_next?.grade, "A");
  assertEquals(s.to_next?.total, 10);
  const { h, llm } = mk("{}");
  const r = await h(post({ action: "summary", results: [{ no: "1", points: { E: 3 } }], boundaries: b }));
  assertEquals((await r.json()).grade, "F");
  assertEquals(llm.calls.length, 0);
  assertEquals(parseExamReply("trasigt").tasks, []);
});

Deno.test("K1.1 oral grading: spoken numbers, the answer after the last 'så/är/=', algebra forms", async () => {
  const { finalNumber } = await import("./spoken.ts");
  const cases: [string, number | null][] = [
    ["medelvärdet är sexton komma fem", 16.5], ["sexton komma fem", 16.5], ["en halv", 0.5], ["tre fjärdedelar", 0.75],
    ["två och en halv", 2.5], ["3x = 21 så x är sju", 7], ["x är sju", 7], ["7 = x", 7], ["x = 7", 7],
    ["det blir sexhundra kronor", 600], ["25 % av 800 är 200, så 800–200=600", 600], ["800/0,75 = 1067", 1067],
    ["600,5 kr", 600.5], ["ungefär 16", 16], ["16,6", 16.6], ["area 40 cm2 och omkrets 26 cm", 26],
    ["3x = 14+7 = 21, x = 21/3 = 7", 7], ["jag vet inte", null], ["svaret är tolv komma fem", 12.5],
    ["x blir minus tre", -3], ["det är en tredjedel", 0.3333], ["hundratjugosex", 126], ["126 kr", 126],
    ["noll komma två fem", 0.25], ["tjugo procent", 20], ["x = -3", -3], ["y är lika med fyra", 4],
    ["först 5 sen 10 så blir det 15", 15], ["jag fick tvåhundrasjuttio", 270], ["sju komma nio", 7.9],
  ];
  for (const [t, want] of cases) {
    const got = finalNumber(t);
    assert(want === null ? got === null : got !== null && Math.abs(got - want) < 0.001, `${t}: ${got} != ${want}`);
  }
  // "600,5" is not 600; a bare wrong number gets nothing; "x är sju" gets the answer point
  assertEquals(numericCheck("600 kr", "600,5 kr")?.equal, false);
  const { correctPoints } = await import("./handler.ts");
  const task = { no: "2", text: "Lös 3x = 21", points: { E: 1, C: 1, A: 0 }, answer: "x = 7", assessment: "+E för korrekt metod, +C för korrekt svar" };
  assertEquals(correctPoints(task, "x är sju", { E: 0, C: 0, A: 0 }, numericCheck(task.answer, "x är sju")), { E: 0, C: 1, A: 0 });
  assertEquals(correctPoints(task, "500", { E: 1, C: 0, A: 0 }, numericCheck(task.answer, "500")), { E: 0, C: 0, A: 0 });
  const pct = { no: "3", text: "800 kr sänks 25 %", points: { E: 2, C: 0, A: 0 }, answer: "600 kr", assessment: "+E för korrekt metod, +E för korrekt svar 600 kr" };
  assertEquals(correctPoints(pct, "25 % av 800 är 200 kronor", { E: 2, C: 0, A: 0 }, numericCheck(pct.answer, "25 % av 800 är 200 kronor")), { E: 1, C: 0, A: 0 });
});

Deno.test("K1 exam summary never says fewer missing points than A points needed", () => {
  const s = summarize([{ no: "1", points: { E: 5, C: 3, A: 0 } }], [{ grade: "C", total: 7, min_ca: 2 }, { grade: "A", total: 10, min_a: 3 }] as never);
  assertEquals(s.grade, "C");
  assertEquals(s.to_next?.total, 3);
  assert(s.spoken.includes("Till A saknas 3 A-poäng."), s.spoken);
  const s2 = summarize([{ no: "1", points: { E: 5, C: 3, A: 2 } }], [{ grade: "C", total: 7, min_ca: 2 }, { grade: "A", total: 10, min_a: 3 }] as never);
  assert(s2.spoken.includes("Till A saknas 1 A-poäng."), s2.spoken);
});
