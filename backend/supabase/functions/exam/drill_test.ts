// K45 (D142, D145, D146): Repetitionsläget, material to questions and answers. Invented material only (B4).
import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { MemoryRateLimiter } from "../_shared/ratelimit.ts";
import type { LLMChunk, LLMProvider, LLMRequest } from "../answer/llm/types.ts";
import { createExamHandler } from "./handler.ts";
import { cleanQuestion, composeLong, docxText, docxXmlToText, parseAnswers, parsePlan, words } from "./drill.ts";

const PLAN = {
  summary: { subject: "Biologi", grade: "åk 8", covers: "Fotosyntes, näringskedjor och energiflöde." },
  notes: "Fotosyntes sker i kloroplasterna. Klorofyll fångar ljusenergi. Vid varje steg i en näringskedja försvinner ungefär 90 procent av energin.",
  questions: [
    "Varför behövs klorofyll?",
    "1. Hur bildas en näringsväv",
    "Varför behövs klorofyll?", // duplicate
    "Vad händer med energin i varje steg av en lång näringskedja i naturen?", // 13 words: over the limit
    "Skillnad mellan producent och konsument?",
    "Varför försvinner energi i kedjan?",
  ],
};

/** Plays the plan step, then answers every question it gets (rest repeats the short answer once, as models do). */
class ScriptLLM implements LLMProvider {
  readonly name = "fake";
  readonly model = "haiku-fake";
  calls: LLMRequest[] = [];
  failFirstAnswerBatch = false;
  async *stream(req: LLMRequest): AsyncIterable<LLMChunk> {
    this.calls.push(req);
    if (req.system.includes("revision list")) {
      yield { type: "text", text: JSON.stringify(PLAN) };
      yield { type: "usage", inputTokens: 10_000, outputTokens: 1_500 };
      return;
    }
    const qs = JSON.parse(/<questions>([\s\S]*)<\/questions>/.exec(req.user)![1]) as { id: string; question: string }[];
    if (this.failFirstAnswerBatch) {
      this.failFirstAnswerBatch = false;
      yield { type: "text", text: "inte json" };
      return;
    }
    const answers = qs.map((q) => ({
      id: q.id,
      short: `**Kort** svar på ${q.question.replace("?", "")}`,
      rest: `Kort svar på ${q.question.replace("?", "")}. Sedan kommer förklaringen med begrepp och ett exempel.`,
    }));
    yield { type: "text", text: JSON.stringify({ answers }) };
    yield { type: "usage", inputTokens: 2_000, outputTokens: 900 };
  }
}
const mk = () => {
  const llm = new ScriptLLM();
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

Deno.test("K45 parsePlan: questions cleaned, at most 8 words, no duplicates, at most the count asked", () => {
  const p = parsePlan(JSON.stringify(PLAN), 20);
  assertEquals(p.questions, [
    "Varför behövs klorofyll?",
    "Hur bildas en näringsväv?",
    "Skillnad mellan producent och konsument?",
    "Varför försvinner energi i kedjan?",
  ]);
  assert(p.questions.every((q) => words(q) <= 8));
  // over the count: the longest go and the order stays
  assertEquals(parsePlan(JSON.stringify(PLAN), 2).questions, ["Varför behövs klorofyll?", "Hur bildas en näringsväv?"]);
  assertEquals(parsePlan(JSON.stringify(PLAN), 3).questions, ["Varför behövs klorofyll?", "Hur bildas en näringsväv?", "Skillnad mellan producent och konsument?"]); // a tie: the later one goes
  assertEquals(p.summary.subject, "Biologi");
  assertEquals(parsePlan("inget json", 20).questions, []);
  assertEquals(cleanQuestion("  - \"varför regnar det.\" "), "Varför regnar det?");
  // recall questions go before longer understanding questions when there are too many
  const many = JSON.stringify({ questions: ["Vad är klorofyll?", "Varför försvinner energi i varje steg?", "Hur bildas en näringsväv?", "Vilka är producenter?"] });
  assertEquals(parsePlan(many, 2).questions, ["Varför försvinner energi i varje steg?", "Hur bildas en näringsväv?"]);
});

Deno.test("K45 D145: the long answer starts with the short answer word for word, never twice", () => {
  assertEquals(composeLong("Klorofyll fångar ljus.", "Därför kan växten bilda glukos."), "Klorofyll fångar ljus. Därför kan växten bilda glukos.");
  assertEquals(composeLong("Klorofyll fångar ljus.", "Klorofyll fångar ljus. Därför bildas glukos."), "Klorofyll fångar ljus. Därför bildas glukos.");
  assertEquals(composeLong("Klorofyll fångar ljus", ""), "Klorofyll fångar ljus");
  const a = parseAnswers(JSON.stringify({ answers: [{ id: "q1", short: "**Ljus** behövs", rest: "- Utan ljus  ingen glukos." }] }));
  assertEquals(a.get("q1"), { short: "Ljus behövs.", long: "Ljus behövs. Utan ljus ingen glukos." });
});

Deno.test("K45 drill: summary, notes, questions and both answers; Haiku plans, Sonnet answers in batches; cost per step", async () => {
  const { h, llm } = mk();
  const r = await h(post({ action: "drill", text: "Fotosyntes ... (påhittat material)", grade: "åk 8", long_words: 70 }));
  assertEquals(r.status, 200);
  const j = await r.json();
  assertEquals(j.summary, PLAN.summary);
  assertEquals(j.items.length, 4);
  for (const it of j.items) {
    assert(it.long.startsWith(it.short), it.id); // D145
    assert(!it.short.includes("**"), "markdown stripped");
    assertEquals(it.long.split(it.short).length, 2, "the short answer is said once");
  }
  assertEquals(llm.calls[0].model, undefined, "step 1 on the provider's default (Haiku)");
  assertEquals(llm.calls.slice(1).map((c) => c.model), ["claude-sonnet-5-5"], "4 questions = one batch on Sonnet");
  assert(llm.calls[1].user.includes("<long_words>70</long_words>"));
  assert(llm.calls[1].user.includes("90 procent"), "the answers are written from the notes");
  assertEquals(llm.calls[0].user.includes("<count>24</count>"), true, "20 questions by default (D146), 4 extra to drop the longest");
  assertEquals(j.usage.plan.est_cost_usd, (10_000 * 0.10 + 1_500 * 0.50) / 1e6);
  assertEquals(j.usage.answers.est_cost_usd, (2_000 * 2 + 900 * 10) / 1e6);
});

Deno.test("K45 drill: answers false = questions only; a batch that fails is asked once more", async () => {
  const { h, llm } = mk();
  const r = await h(post({ action: "drill", text: "material", answers: false, questions: 5 }));
  const j = await r.json();
  assertEquals(j.items[0], { id: "q1", question: "Varför behövs klorofyll?" });
  assertEquals(llm.calls.length, 1);
  assert(llm.calls[0].user.includes("<count>9</count>"));
  const m = mk();
  m.llm.failFirstAnswerBatch = true;
  const r2 = await m.h(post({ action: "drill_answers", items: j.items, notes: j.notes, grade: "åk 8" }));
  const j2 = await r2.json();
  assertEquals(j2.items.every((it: { short?: string }) => !!it.short), true);
  assertEquals(m.llm.calls.length, 2);
});

Deno.test("K45 drill_one and drill_answers: 12 questions = 3 parallel batches; a correction is passed on", async () => {
  const { h, llm } = mk();
  const items = Array.from({ length: 12 }, (_, i) => ({ id: `x${i}`, question: `Varför fråga ${i}?` }));
  const r = await h(post({ action: "drill_answers", items, subject: "Biologi" }));
  assertEquals((await r.json()).items.length, 12);
  assertEquals(llm.calls.length, 3);
  const one = await (await h(post({ action: "drill_one", question: "Hur fungerar en näringsväv", id: "q7" }))).json();
  assertEquals(one.item.id, "q7");
  assertEquals(one.item.question, "Hur fungerar en näringsväv?");
  await h(post({ action: "drill", text: PLAN.notes, correction: "Det är Biologi för åk 9, inte åk 8." }));
  assert(llm.calls.at(-2)!.user.includes("<correction>Det är Biologi för åk 9, inte åk 8.</correction>"));
});

Deno.test("K45 drill: bad input never reaches the model; a drill weighs 4 in the rate limit", async () => {
  for (
    const b of [
      { action: "drill" },
      { action: "drill", pages: [{ media_type: "image/gif", data: "R0lG" }] },
      { action: "drill", pages: Array(21).fill({ media_type: "image/jpeg", data: "/9j/" }) },
      { action: "drill_answers", items: [] },
      { action: "drill_one", question: "" },
    ]
  ) {
    const { h, llm } = mk();
    assertEquals((await h(post(b))).status, 400, JSON.stringify(b).slice(0, 60));
    assertEquals(llm.calls.length, 0);
  }
  const { h } = mk();
  for (let i = 0; i < 3; i++) assertEquals((await h(post({ action: "drill", text: "x", answers: false }))).status, 200);
  assertEquals((await h(post({ action: "drill", text: "x", answers: false }))).status, 429, "12 per minute = 3 drills");
});

// ---------- doc_text ----------

const crc32 = (b: Uint8Array) => {
  let c = ~0;
  for (const x of b) {
    c ^= x;
    for (let k = 0; k < 8; k++) c = (c >>> 1) ^ (0xedb88320 & -(c & 1));
  }
  return ~c >>> 0;
};
async function zip(files: Record<string, string>, deflate: boolean): Promise<Uint8Array> {
  const enc = new TextEncoder();
  const parts: number[] = [];
  const central: number[] = [];
  const le = (n: number, len: number) => Array.from({ length: len }, (_, i) => (n >>> (8 * i)) & 0xff);
  for (const [name, text] of Object.entries(files)) {
    const raw = enc.encode(text);
    const body = deflate
      ? new Uint8Array(await new Response(new Blob([raw]).stream().pipeThrough(new CompressionStream("deflate-raw"))).arrayBuffer())
      : raw;
    const nb = enc.encode(name);
    const off = parts.length;
    const common = [...le(20, 2), ...le(0, 2), ...le(deflate ? 8 : 0, 2), ...le(0, 4), ...le(crc32(raw), 4), ...le(body.length, 4), ...le(raw.length, 4), ...le(nb.length, 2), ...le(0, 2)];
    parts.push(...le(0x04034b50, 4), ...common, ...nb, ...body);
    central.push(...le(0x02014b50, 4), ...le(20, 2), ...common, ...le(0, 2), ...le(0, 2), ...le(0, 2), ...le(0, 4), ...le(off, 4), ...nb);
  }
  const cdOff = parts.length;
  const n = Object.keys(files).length;
  return new Uint8Array([...parts, ...central, ...le(0x06054b50, 4), ...le(0, 4), ...le(n, 2), ...le(n, 2), ...le(central.length, 4), ...le(cdOff, 4), ...le(0, 2)]);
}
const XML =
  `<?xml version="1.0"?><w:document><w:body><w:p><w:r><w:t>Fotosyntes &amp; cellandning</w:t></w:r></w:p><w:p><w:r><w:t>Klorofyll</w:t><w:tab/><w:t>fångar ljus</w:t><w:br/><w:t>i bladen &#246;verallt.</w:t></w:r></w:p></w:body></w:document>`;
const b64 = (u: Uint8Array) => btoa(String.fromCharCode(...u));

Deno.test("K45 doc_text: a Word file's text, deflated or stored, in code; no model is called", async () => {
  assertEquals(docxXmlToText(XML), "Fotosyntes & cellandning\nKlorofyll\tfångar ljus\ni bladen överallt.");
  for (const deflate of [true, false]) {
    const z = await zip({ "[Content_Types].xml": "<Types/>", "word/document.xml": XML }, deflate);
    assertEquals(await docxText(b64(z)), "Fotosyntes & cellandning\nKlorofyll\tfångar ljus\ni bladen överallt.");
  }
  const { h, llm } = mk();
  const z = await zip({ "word/document.xml": XML }, true);
  const r = await h(post({ action: "doc_text", data: b64(z) }));
  assertEquals((await r.json()).text.startsWith("Fotosyntes & cellandning"), true);
  assertEquals((await h(post({ action: "doc_text", data: b64(new TextEncoder().encode("inte en zip-fil alls, bara text")) }))).status, 422);
  assertEquals(llm.calls.length, 0);
});
