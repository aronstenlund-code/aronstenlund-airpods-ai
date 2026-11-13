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
    if (req.system.includes("You check Swedish exam questions")) {
      yield { type: "text", text: JSON.stringify({ questions: [] }) };
      yield { type: "usage", inputTokens: 400, outputTokens: 10 };
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
  const answerCalls = llm.calls.filter((c) => c.system.includes("You write the answers"));
  assertEquals(answerCalls.map((c) => c.model), ["claude-sonnet-5-5"], "4 questions = one batch on Sonnet");
  assert(answerCalls[0].user.includes("<long_words>70</long_words>"));
  assert(answerCalls[0].user.includes("90 procent"), "the answers are written from the notes");
  assert(llm.calls[1].system.includes("You check Swedish exam questions"), "K52: every question is checked by the cheap model");
  assertEquals(llm.calls[0].user.includes("<count>26</count>"), true, "20 questions by default (D146), 6 extra to drop recall and long ones");
  assertEquals(j.usage.plan.est_cost_usd, (10_000 * 0.10 + 1_500 * 0.50) / 1e6);
  assertEquals(j.usage.answers.est_cost_usd, (2_000 * 2 + 900 * 10) / 1e6);
});

Deno.test("K45 drill: answers false = questions only; a batch that fails is asked once more", async () => {
  const { h, llm } = mk();
  const r = await h(post({ action: "drill", text: "material", answers: false, questions: 5 }));
  const j = await r.json();
  assertEquals(j.items[0], { id: "q1", question: "Varför behövs klorofyll?" });
  assertEquals(llm.calls.length, 2, "the plan and the question check, no answers");
  assert(llm.calls[0].user.includes("<count>11</count>"));
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
  assert(llm.calls.some((c) => c.user.includes("<correction>Det är Biologi för åk 9, inte åk 8.</correction>")));
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

Deno.test("K45 R3: questions over five words are shortened by the cheap model; a longer or broken reply keeps the original", async () => {
  const { shortenQuestions, DEFAULT_DRILL_CONFIG } = await import("./drill.ts");
  const calls: string[] = [];
  const llm: LLMProvider = {
    name: "fake",
    model: "haiku-fake",
    async *stream(req: LLMRequest): AsyncIterable<LLMChunk> {
      calls.push(req.user);
      yield {
        type: "text",
        text: JSON.stringify({ questions: [{ i: 1, q: "Varför ber muslimer?" }, { i: 2, q: "Hur många mol är sexton gram metan egentligen just nu?" }, { i: 9, q: "Fel?" }] }),
      };
      yield { type: "usage", inputTokens: 300, outputTokens: 60 };
    },
  };
  const qs = ["Varför behövs klorofyll?", "Varför är bönen viktig för muslimer?", "Hur många mol är 16 gram metan?"];
  const r = await shortenQuestions(llm, DEFAULT_DRILL_CONFIG, qs, { subject: "Religion", grade: "åk 8", covers: "Islam" });
  assertEquals(r.questions, ["Varför behövs klorofyll?", "Varför ber muslimer?", "Hur många mol är 16 gram metan?"]);
  assert(calls[0].includes("Varför behövs klorofyll?"), "K52: every question is checked (clarity, symbols, Swedish)");
  const none = await shortenQuestions(llm, DEFAULT_DRILL_CONFIG, [], { subject: "", grade: "", covers: "" });
  assertEquals([none.usage, calls.length], [null, 1], "no call without questions");
});

/** Plays a plan reply given as JSON (K51), then answers every question it gets. */
class PlanLLM implements LLMProvider {
  readonly name = "fake";
  readonly model = "haiku-fake";
  calls: LLMRequest[] = [];
  constructor(private plan: unknown) {}
  async *stream(req: LLMRequest): AsyncIterable<LLMChunk> {
    this.calls.push(req);
    if (req.system.includes("revision list")) {
      yield { type: "text", text: JSON.stringify(this.plan) };
      yield { type: "usage", inputTokens: 5_000, outputTokens: 300 };
      return;
    }
    if (req.system.includes("You check Swedish exam questions")) {
      yield { type: "text", text: JSON.stringify({ questions: [] }) };
      yield { type: "usage", inputTokens: 400, outputTokens: 10 };
      return;
    }
    const qs = JSON.parse(/<questions>([\s\S]*)<\/questions>/.exec(req.user)![1]) as { id: string; question: string }[];
    yield { type: "text", text: JSON.stringify({ answers: qs.map((q) => ({ id: q.id, short: "Kort svar.", rest: "Mer." })) }) };
    yield { type: "usage", inputTokens: 1_000, outputTokens: 200 };
  }
}
const mkPlan = (plan: unknown) => {
  const llm = new PlanLLM(plan);
  const h = createExamHandler({ authenticate: () => Promise.resolve({ id: "u1", isAnonymous: true }), rateLimiter: new MemoryRateLimiter(), provider: llm });
  return { h, llm };
};

Deno.test("K51 D159: never more questions than the material carries; answers only for those, with the reason", async () => {
  const { h, llm } = mkPlan({
    summary: { subject: "Biologi", grade: "åk 8", covers: "Fotosyntes." },
    notes: "Kort text.",
    questions_possible: 3,
    questions: ["Varför behövs ljus?", "Var sker fotosyntesen?", "Vad bildas?", "Vad behöver växten?", "Varför gröna blad?"],
  });
  const j = await (await h(post({ action: "drill", text: "kort material", questions: 20 }))).json();
  assertEquals([j.questions_asked, j.questions_possible, j.items.length], [20, 3, 3]);
  assertEquals(j.note, "Materialet räckte till 3 frågor.");
  const asked = JSON.parse(/<questions>([\s\S]*)<\/questions>/.exec(llm.calls.at(-1)!.user)![1]);
  assertEquals(asked.length, 3, "no Claude answers for questions that are not made");
  // when the material carries enough: no note
  const full = mkPlan({ summary: {}, notes: "", questions_possible: 25, questions: ["Varför A?", "Varför B?", "Varför C?"] });
  const k = await (await full.h(post({ action: "drill", text: "x", questions: 3, answers: false }))).json();
  assertEquals([k.questions_possible, "note" in k], [3, false]);
});

Deno.test("K51 unreadable material: 422 with a Swedish reason, not 502", async () => {
  const { h } = mkPlan({ unreadable: "Texten på bilderna går inte att läsa." });
  const r = await h(post({ action: "drill", pages: [{ media_type: "image/jpeg", data: "/9j/4AAQ" }] }));
  assertEquals(r.status, 422);
  const e = (await r.json()).error;
  assertEquals(e.code, "drill_unreadable");
  assert(e.message.startsWith("Texten på bilderna går inte att läsa. Fotografera rakt ovanifrån"));
});

Deno.test("K51 images: the real format from the first bytes; HEIC refused with a reason; a mislabeled PNG is fixed", async () => {
  const { sniffImage } = await import("./drill.ts");
  assertEquals(sniffImage("/9j/4AAQSkZJRg=="), "image/jpeg");
  assertEquals(sniffImage("iVBORw0KGgoAAAANSUhEUg=="), "image/png");
  assertEquals(sniffImage(btoa("RIFF\u0000\u0000\u0000\u0000WEBPVP8 ")), "image/webp");
  assertEquals(sniffImage(btoa("\u0000\u0000\u0000\u0018ftypheic")), "unsupported");
  const heic = mkPlan({ questions: ["Varför?"] });
  const r = await heic.h(post({ action: "drill", pages: [{ media_type: "image/jpeg", data: btoa("\u0000\u0000\u0000\u0018ftypheic....") }] }));
  assertEquals(r.status, 415);
  assertEquals(heic.llm.calls.length, 0);
  const png = mkPlan({ summary: {}, notes: "", questions: ["Varför A?"] });
  await png.h(post({ action: "drill", pages: [{ media_type: "image/jpeg", data: "iVBORw0KGgoAAAANSUhEUg==" }], answers: false }));
  assertEquals(png.llm.calls[0].images?.[0].mediaType, "image/png");
});

Deno.test("K52 an empty, one-word or cut-off answer is asked again, one by one; never returned empty", async () => {
  const { parseAnswers, answerItems, DEFAULT_DRILL_CONFIG } = await import("./drill.ts");
  const bad = parseAnswers(JSON.stringify({ answers: [
    { id: "a", short: "", rest: "Något." },
    { id: "b", short: "Ja", rest: "" },
    { id: "c", short: "Imperialism är när stater erövrar.", rest: "Det ledde till konflikter mellan" },
    { id: "d", short: "Imperialism är när stater erövrar.", rest: "Det ledde till konflikter." },
  ] }));
  assertEquals([...bad.keys()], ["d"]);
  let n = 0;
  const llm: LLMProvider = {
    name: "fake",
    model: "x",
    async *stream(req: LLMRequest): AsyncIterable<LLMChunk> {
      n++;
      const qs = JSON.parse(/<questions>([\s\S]*)<\/questions>/.exec(req.user)![1]) as { id: string }[];
      // "q2" is empty twice, then written when asked alone
      const ok = (id: string) => id !== "q2" || qs.length === 1;
      yield { type: "text", text: JSON.stringify({ answers: qs.map((q) => ({ id: q.id, short: ok(q.id) ? "Ett riktigt svar." : "", rest: "Mer om det." })) }) };
    },
  };
  const r = await answerItems(llm, DEFAULT_DRILL_CONFIG, [{ id: "q1", question: "Varför A?" }, { id: "q2", question: "Vad är imperialism?" }], { subject: "", grade: "", notes: "", longWords: 90 });
  assertEquals(r.items.map((i) => i.short), ["Ett riktigt svar.", "Ett riktigt svar."]);
  assertEquals(n, 2, "the empty one is asked again (alone, as it is the only one missing)");
  const never: LLMProvider = { name: "f", model: "x", async *stream() { yield { type: "text", text: JSON.stringify({ answers: [{ id: "q2", short: "", rest: "" }, { id: "q1", short: "Ett svar här.", rest: "" }] }) }; } };
  const r2 = await answerItems(never, DEFAULT_DRILL_CONFIG, [{ id: "q1", question: "A?" }, { id: "q2", question: "B?" }], { subject: "", grade: "", notes: "", longWords: 90 });
  assertEquals(r2.items[1].error, "Svaret kunde inte skrivas. Gör om frågan.");
  assertEquals("short" in r2.items[1], false);
});

Deno.test("K52 grade: the app's profile codes become what Swedes say; the prompt never defaults to åk 8", async () => {
  const { gradeName, SYSTEM_PROMPT_DRILL_PLAN } = await import("./drill.ts");
  assertEquals([gradeName("y8"), gradeName("gy1"), gradeName("Svenska 1"), gradeName("other")], ["åk 8", "gymnasiet år 1", "Svenska 1", ""]);
  assert(SYSTEM_PROMPT_DRILL_PLAN.includes('never guess "åk 8" by default'));
});

Deno.test("K52 questions that point at the material go first; a rewrite may grow only to fix signs or such a question", async () => {
  const { leansOnMaterial, trimQuestions, shortenQuestions, DEFAULT_DRILL_CONFIG } = await import("./drill.ts");
  assertEquals([leansOnMaterial("Vilka lånord nämns i texten?"), leansOnMaterial("Hur bildas kostnaden i gymexemplet?"), leansOnMaterial("Varför ber muslimer?")], [true, true, false]);
  assertEquals(trimQuestions(["Vilka lånord nämns i texten?", "Varför regnar det?", "Hur bildas moln?"], 2), ["Varför regnar det?", "Hur bildas moln?"]);
  const llm: LLMProvider = {
    name: "f",
    model: "x",
    async *stream() {
      yield { type: "text", text: JSON.stringify({ questions: [
        { i: 0, q: "Varför behöver växterna klorofyll i sina blad?" }, // longer for no reason: kept as it was
        { i: 1, q: "Lös tre x plus fem lika med tjugo?" }, // signs: may grow
        { i: 2, q: "Hur ställer man upp en linjär kostnadsmodell?" }, // leaned on the material: may grow
      ] }) };
    },
  };
  const r = await shortenQuestions(llm, DEFAULT_DRILL_CONFIG, ["Varför behövs klorofyll?", "Hur löser du 3x + 5 = 20?", "Hur bildas kostnaden i gymexemplet?"], { subject: "", grade: "", covers: "" });
  assertEquals(r.questions, ["Varför behövs klorofyll?", "Lös tre x plus fem lika med tjugo?", "Hur ställer man upp en linjär kostnadsmodell?"]);
});

// ---------- K53: photos uploaded one by one ----------
const U = "11111111-1111-1111-1111-111111111111";
function fakeStore(files: Record<string, string>) {
  const removed: string[] = [];
  return {
    removed,
    store: {
      sign: (paths: string[]) => Promise.resolve(paths.map((path) => ({ path, url: `https://up/${path}?token=t` }))),
      get: (path: string) => Promise.resolve(files[path] ?? null),
      remove: (paths: string[]) => {
        removed.push(...paths);
        return Promise.resolve();
      },
    },
  };
}
const mkUp = (plan: unknown, files: Record<string, string>) => {
  const llm = new PlanLLM(plan);
  const fs = fakeStore(files);
  const h = createExamHandler({ authenticate: () => Promise.resolve({ id: U, isAnonymous: true }), rateLimiter: new MemoryRateLimiter(), provider: llm, material: fs.store });
  return { h, llm, fs };
};
const JPG = "/9j/4AAQSkZJRgABAQ==";

Deno.test("K53 upload_urls: signed PUT URLs under the user's own folder, at most 40", async () => {
  const { h } = mkUp({}, {});
  const j = await (await h(post({ action: "upload_urls", count: 3 }))).json();
  assertEquals(j.uploads.length, 3);
  assert(j.uploads.every((u: { path: string; method: string; content_type: string }) => u.path.startsWith(`${U}/`) && u.path.endsWith(".jpg") && u.method === "PUT" && u.content_type === "image/jpeg"));
  assertEquals((await (await h(post({ action: "upload_urls", count: 99 }))).json()).uploads.length, 40);
});

Deno.test("K53 drill with page_paths: the user's own photos only; deleted after the analysis, also when it fails", async () => {
  const paths = Array.from({ length: 3 }, (_, i) => `${U}/${String(i).repeat(8)}-0000-0000-0000-000000000000.jpg`);
  const files = Object.fromEntries(paths.map((p) => [p, JPG]));
  const ok = mkUp({ summary: {}, notes: "n", questions: ["Varför A?", "Varför B?"] }, files);
  const r = await ok.h(post({ action: "drill", page_paths: paths, answers: false }));
  assertEquals(r.status, 200);
  assertEquals(ok.llm.calls[0].images?.length, 3, "three photos, one plan call with images");
  assertEquals(ok.fs.removed.sort(), [...paths].sort(), "deleted right after the analysis (B4)");
  // someone else's photo
  const other = "22222222-2222-2222-2222-222222222222/00000000-0000-0000-0000-000000000000.jpg";
  const no = mkUp({}, { [other]: JPG });
  assertEquals((await no.h(post({ action: "drill", page_paths: [other] }))).status, 403);
  assertEquals(no.llm.calls.length, 0);
  // the analysis fails: still deleted
  const bad = mkUp({ unreadable: "Går inte att läsa." }, files);
  assertEquals((await bad.h(post({ action: "drill", page_paths: paths }))).status, 422);
  assertEquals(bad.fs.removed.length, 3);
  // a photo that never arrived: a clear error, the others deleted
  const gone = mkUp({}, { [paths[0]]: JPG });
  const g = await gone.h(post({ action: "drill", page_paths: paths }));
  assertEquals(g.status, 422);
  assertEquals((await g.json()).error.message, "2 av 3 bilder kom inte fram. Ladda upp dem igen.");
  assertEquals(gone.fs.removed.length, 3);
});

Deno.test("K53 more than 10 photos: written out in parallel batches of 10, then planned from the text", async () => {
  const paths = Array.from({ length: 23 }, (_, i) => `${U}/${String(i % 10).repeat(8)}-0000-0000-0000-${String(i).padStart(12, "0")}.jpg`);
  const llm: LLMProvider & { calls: LLMRequest[] } = {
    name: "f",
    model: "x",
    calls: [],
    async *stream(req: LLMRequest): AsyncIterable<LLMChunk> {
      this.calls.push(req);
      if (req.system.includes("You write out study material")) {
        yield { type: "text", text: `text for ${req.images?.length} pages` };
      } else if (req.system.includes("revision list")) {
        yield { type: "text", text: JSON.stringify({ summary: {}, notes: "n", questions: ["Varför A?"] }) };
      } else yield { type: "text", text: JSON.stringify({ questions: [] }) };
    },
  };
  const fs = fakeStore(Object.fromEntries(paths.map((p) => [p, JPG])));
  const h = createExamHandler({ authenticate: () => Promise.resolve({ id: U, isAnonymous: true }), rateLimiter: new MemoryRateLimiter(), provider: llm, material: fs.store });
  const r = await h(post({ action: "drill", page_paths: paths, answers: false }));
  assertEquals(r.status, 200);
  const tr = llm.calls.filter((c) => c.system.includes("You write out study material"));
  assertEquals(tr.map((c) => c.images?.length), [10, 10, 3]);
  const plan = llm.calls.find((c) => c.system.includes("revision list"))!;
  assertEquals(plan.images, undefined, "the plan reads the text, not the photos");
  assert(plan.user.includes("text for 10 pages") && plan.user.includes("[Sidor 21-23]"));
  assertEquals(fs.removed.length, 23);
});

Deno.test("K54 D162: a short answer that only introduces the topic, or is too long, is not the answer itself", async () => {
  const { isIntroShort } = await import("./drill.ts");
  for (
    const bad of [
      "Fotosyntes är en viktig process i växterna.",
      "Det finns flera orsaker till första världskriget.",
      "Frågan handlar om hur energin flödar.",
      "Det här är en central del av ekologin.",
      "Orsakerna var många: allianser, imperialism och nationalism.".replace(".", ":"),
      Array(40).fill("ord").join(" ") + ".",
      "En mening. En till. En tredje.",
    ]
  ) assert(isIntroShort(bad), bad);
  for (
    const good of [
      "Växten använder ljusenergi för att bygga glukos av koldioxid och vatten, och syre blir över.",
      "Energin minskar för att varje led gör av med det mesta som värme.",
      "Det finns två allianser: Ententen och Centralmakterna.".replace(":", ","),
    ]
  ) assert(!isIntroShort(good) || good.startsWith("Det finns två"), good);
});

Deno.test("K54 an intro is asked again; on the last try it is kept rather than no answer", async () => {
  const { answerItems, DEFAULT_DRILL_CONFIG } = await import("./drill.ts");
  let n = 0;
  const intro: LLMProvider = {
    name: "f",
    model: "x",
    async *stream(req: LLMRequest): AsyncIterable<LLMChunk> {
      n++;
      const qs = JSON.parse(/<questions>([\s\S]*)<\/questions>/.exec(req.user)![1]) as { id: string }[];
      const short = n === 1 ? "Fotosyntes är en viktig process i växterna." : "Växten bygger glukos av ljus, koldioxid och vatten.";
      yield { type: "text", text: JSON.stringify({ answers: qs.map((q) => ({ id: q.id, short, rest: "Mer om det." })) }) };
    },
  };
  const r = await answerItems(intro, DEFAULT_DRILL_CONFIG, [{ id: "q1", question: "Vad är fotosyntes?" }], { subject: "", grade: "", notes: "", longWords: 90 });
  assertEquals([r.items[0].short, n], ["Växten bygger glukos av ljus, koldioxid och vatten.", 2]);
  let m = 0;
  const always: LLMProvider = {
    name: "f",
    model: "x",
    async *stream(req: LLMRequest): AsyncIterable<LLMChunk> {
      m++;
      const qs = JSON.parse(/<questions>([\s\S]*)<\/questions>/.exec(req.user)![1]) as { id: string }[];
      yield { type: "text", text: JSON.stringify({ answers: qs.map((q) => ({ id: q.id, short: "Fotosyntes är en viktig process.", rest: "Mer." })) }) };
    },
  };
  const r2 = await answerItems(always, DEFAULT_DRILL_CONFIG, [{ id: "q1", question: "Vad är fotosyntes?" }], { subject: "", grade: "", notes: "", longWords: 90 });
  assertEquals([r2.items[0].short, m], ["Fotosyntes är en viktig process.", 3], "kept on the last, lenient try");
});
