// K83 (D206): coverage of the whole material, in code. Invented material only, a scripted model.
import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { coverage, isHeading, mergeCoverage, partCount, placeQuestions, sectionParts, splitParts } from "./coverage.ts";
import { DEFAULT_DRILL_CONFIG, handleDrill } from "./drill.ts";
import type { LLMChunk, LLMProvider, LLMRequest } from "../answer/llm/types.ts";

const P1 = "Fotosyntesen sker i kloroplasterna. Klorofyllet fångar ljusenergi och växten bildar glukos av koldioxid och vatten. Syret släpps ut genom klyvöppningarna. ".repeat(8);
const P2 = "Cellandningen sker i mitokondrierna. Glukosen bryts ned med syre och energin lagras som ATP. Koldioxid och vatten bildas som restprodukter. ".repeat(8);
const P3 = "Näringskedjor börjar med producenter. Konsumenter äter producenter och nedbrytare tar hand om döda organismer. Energin minskar för varje steg i kedjan. ".repeat(8);
const TEXT = [P1, P2, P3].join("\n\n");

Deno.test("K83 the text is cut into equal parts at paragraph ends; each question is placed where it draws on", () => {
  assertEquals(partCount(500, 10), 1, "short material: one part");
  const k = partCount(TEXT.length, 6);
  assertEquals(k, 3);
  const parts = splitParts(TEXT, 3);
  assertEquals(parts.length, 3);
  assert(parts[0].startsWith("Fotosyntesen") && parts[1].startsWith("Cellandningen") && parts[2].startsWith("Näringskedjor"), JSON.stringify(parts.map((p) => p.slice(0, 20))));
  const c = coverage(["Var sker fotosyntesen i växten?", "Vad fångar klorofyllet?", "Var sker cellandningen?"], parts);
  assertEquals(c.placed, [0, 0, 1]);
  assertEquals(c.missing, [2]);
});

Deno.test("K83 merge: the missing part gets its question; the list keeps its size; the most covered part gives way", () => {
  const qs = ["Var sker fotosyntesen?", "Vad fångar klorofyllet?", "Vart tar syret vägen?", "Var sker cellandningen?"];
  const out = mergeCoverage(qs, [0, 0, 0, 1], [{ part: 2, question: "Hur börjar en näringskedja?" }], 4);
  assertEquals(out, ["Var sker fotosyntesen?", "Vad fångar klorofyllet?", "Var sker cellandningen?", "Hur börjar en näringskedja?"]);
  // room left (the material allowed more): nothing gives way
  assertEquals(mergeCoverage(qs, [0, 0, 0, 1], [{ part: 2, question: "Hur börjar en näringskedja?" }], 6).length, 5);
});

Deno.test("K83 handleDrill: the model asked only about the start; the end gets its own call; coverage is reported", async () => {
  const calls: string[] = [];
  const llm: LLMProvider = {
    name: "fake",
    model: "haiku",
    async *stream(req: LLMRequest): AsyncIterable<LLMChunk> {
      calls.push(req.user.includes("one part of a longer material") ? "part" : req.user.includes("<part>notes") ? "notes" : "plan");
      let out: unknown;
      if (req.user.includes("<part>notes")) out = { notes: "" };
      else if (req.user.includes("one part of a longer material")) {
        out = req.user.includes("Näringskedjor")
          ? { questions: ["Hur börjar en näringskedja?", "Vad gör nedbrytare?"] }
          : { questions: ["Var bryts glukosen ned?"] };
      } else if (req.system.includes("shorten") || req.user.includes("<questions>")) out = { questions: [] };
      else out = { summary: { subject: "Biologi", grade: "åk 8", covers: "x" }, questions_possible: 4, questions: ["Var sker fotosyntesen i växten?", "Vad fångar klorofyllet?", "Vart tar syret vägen ut ur bladet?", "Vad bildar växten av koldioxid och vatten?"] };
      yield { type: "text", text: JSON.stringify(out) };
      yield { type: "usage", inputTokens: 10, outputTokens: 5 };
    },
  };
  const r = await handleDrill("drill", { text: TEXT, questions: 4, answers: false, subject: "Biologi", grade: "åk 8" }, llm, DEFAULT_DRILL_CONFIG);
  const cov = (r.body.usage as Record<string, unknown>).coverage as { parts: number; before: number; after: number; added: number };
  assertEquals(cov.parts, 3);
  assertEquals(cov.before, 1, "all four questions were about the first part");
  assertEquals(cov.after, 3);
  assertEquals(cov.added, 2);
  const items = (r.body.items as { question: string }[]).map((i) => i.question);
  assertEquals(items.length, 4, "the count is kept");
  assert(items.includes("Hur börjar en näringskedja?") && items.includes("Var bryts glukosen ned?"), JSON.stringify(items));
  assertEquals(calls.filter((c) => c === "part").length, 2);
});

Deno.test("K85 (Oscar O73): a word every part shares does not decide the part; a rare word does", () => {
  const parts = [
    "Kraft mäts i newton. Newtons lagar beskriver hur kraft och rörelse hänger ihop. Energi finns i många former.",
    "Syror och baser kan neutralisera varandra. Energi frigörs vid neutralisation och salt bildas.",
    "Energi kan inte förstöras. Energiprincipen gäller för alla system, energi omvandlas bara.",
  ];
  // "energi" is in every part; "newton" only in the first
  assertEquals(placeQuestions(["Hur hänger energi och Newtons lagar ihop?"], parts), [0]);
  assertEquals(placeQuestions(["Vad händer vid neutralisation av energi?"], parts), [1]);
  assertEquals(placeQuestions(["Vad är energi?"], parts), [-1], "only a shared word: no part");
});

// ---------- K86 (D207) ----------
import { allocate, codeCap, shares } from "./coverage.ts";

Deno.test("K86 shares by length; at least one each; at most half from one part with three or more parts", () => {
  assertEquals(shares([1000, 1000, 1000], 12), [4, 4, 4]);
  assertEquals(shares([6000, 500, 500], 12), [6, 3, 3], "a long first part gets at most half");
  assertEquals(shares([3000, 1000], 8), [6, 2], "two parts: by length, no half cap");
  assertEquals(shares([1000, 1000, 1000, 1000], 3), [1, 1, 1, 0], "fewer questions than parts");
  assertEquals(codeCap(3449, 12), 5);
  assertEquals(codeCap(9000, 12), 12, "never more than asked");
  assertEquals(codeCap(300, 12), 1);
});

Deno.test("K86 allocate: a part over its share keeps its first questions; the rest are dropped; the need is counted", () => {
  const a = allocate([0, 0, 0, 0, 1, -1], [2, 2, 2]);
  assertEquals(a.keep, [0, 1, 4]);
  assertEquals(a.dropped, [2, 3, 5]);
  assertEquals(a.need, [0, 1, 2]);
});

Deno.test("K86 handleDrill: 10/1/1 from the model becomes a spread by length (at most half from one part)", async () => {
  const llm: LLMProvider = {
    name: "fake",
    model: "haiku",
    async *stream(req: LLMRequest): AsyncIterable<LLMChunk> {
      let out: unknown;
      if (req.user.includes("<part>notes")) out = { notes: "" };
      else if (req.user.includes("one part of a longer material")) {
        const n = Number(/<count>(\d+)<\/count>/.exec(req.user)?.[1] ?? 1);
        const topic = req.user.includes("Näringskedjor") ? "näringskedjan" : "cellandningen";
        out = { questions: Array.from({ length: n }, (_, i) => `Vad gör steg ${i + 1} i ${topic}?`) };
      } else if (req.user.includes("<questions>")) out = { questions: [] };
      else {
        const p1 = ["Var sker fotosyntesen?", "Vad fångar klorofyllet?", "Vart tar syret vägen?", "Vad bildar växten av koldioxid?", "Varför behöver växten ljus i kloroplasterna?",
          "Vad är glukos i fotosyntesen?", "Varför släpps syret ut genom klyvöppningarna?", "Hur fångar klorofyllet ljusenergi?", "Varför är kloroplasterna gröna av klorofyll?", "Vad händer i kloroplasterna?"];
        out = { summary: { subject: "Biologi", grade: "åk 8", covers: "x" }, questions_possible: 12, questions: [...p1, "Var sker cellandningen?", "Hur börjar en näringskedja?"] };
      }
      yield { type: "text", text: JSON.stringify(out) };
      yield { type: "usage", inputTokens: 10, outputTokens: 5 };
    },
  };
  const r = await handleDrill("drill", { text: TEXT, questions: 12, answers: false, subject: "Biologi", grade: "åk 8" }, llm, DEFAULT_DRILL_CONFIG);
  const cov = (r.body.usage as Record<string, unknown>).coverage as { parts: number; max_share: number; after: number; target: number };
  assertEquals(cov.parts, 3);
  assertEquals(cov.after, 3);
  assert(cov.max_share <= 6, `at most half: ${cov.max_share}`);
  assertEquals((r.body.items as unknown[]).length, 12);
});

Deno.test("K86 near duplicates: the same question in other words is caught, different questions are not", async () => {
  const { nearDuplicate } = await import("./coverage.ts");
  assert(nearDuplicate("Varför är det kallare vid polerna än vid ekvatorn?", "Varför blir det kallare vid polerna än vid ekvatorn?"));
  assert(nearDuplicate("Varför är klimatet i Skandinavien mildare än i Kanada på samma breddgrad?", "Hur gör Golfströmmen att Skandinavien får ett mildare klimat än Kanada på samma breddgrad?"));
  assert(!nearDuplicate("Varför måste en reaktionsformel balanseras?", "Hur räknar man ut molmassan för vatten?"));
  assert(!nearDuplicate("Varför går samma ström genom en seriekoppling?", "Varför fortsätter lamporna lysa i en parallellkoppling?"));
});

// ---------- O79 F1 (Oscar): the material's own sections are the parts ----------
const SEC = [
  ["Vad inflation är", "Inflation betyder att den allmänna prisnivån stiger, så att samma pengar räcker till mindre. Den mäts med konsumentprisindex, KPI, som SCB räknar fram varje månad."],
  ["Orsaker", "Priserna kan stiga när efterfrågan är större än det som produceras, eller när det blir dyrare att producera, till exempel när energin blir dyrare."],
  ["Riksbanken", "Riksbanken försöker hålla inflationen nära två procent. När inflationen är för hög höjer Riksbanken styrräntan, så att lån blir dyrare och efterfrågan minskar."],
  ["Vem vinner och förlorar", "De som har fasta inkomster eller pengar på ett sparkonto med låg ränta förlorar köpkraft. Den som har stora lån med fast ränta kan i stället vinna på det."],
  ["2022 och efteråt", "År 2022 steg inflationen i Sverige till över tio procent, mest på grund av dyrare energi och livsmedel. Riksbanken höjde räntan flera gånger under 2022 och 2023."],
];
const secText = (xs: string[][]) => xs.map(([h, p]) => `${h}\n\n${p}`).join("\n\n");

Deno.test("O79 F1: headings make the parts (each heading with its text), so the last section is a part of its own", () => {
  const parts = sectionParts(secText(SEC), 14)!;
  assertEquals(parts.length, 5);
  assertEquals(parts.map((p) => p.split("\n")[0]), SEC.map(([h]) => h));
  assert(parts[4].includes("År 2022"));
  // the length split (the old way) put the last section inside a bigger part
  assertEquals(splitParts(secText(SEC), partCount(secText(SEC).length, 14)).length < 5, true);
});

Deno.test("O79 F1: paragraphs without headings are the parts; one paragraph or one title gives null (length split)", () => {
  const pars = SEC.map(([, p]) => p).join("\n\n");
  assertEquals(sectionParts(pars, 14)!.length, 5);
  assertEquals(sectionParts(SEC[0][1], 14), null);
  assertEquals(sectionParts(`Inflation\n\n${SEC.map(([, p]) => p).join(" ")}`, 14), null, "a single heading is a title");
  assertEquals(sectionParts(secText(SEC), 1), null, "one question: no parts");
});

Deno.test("O79 F1: more sections than questions are joined (shortest neighbours) until each can get one; tiny ones join the next", () => {
  const parts = sectionParts(secText(SEC), 3)!;
  assertEquals(parts.length, 3);
  assertEquals(parts.join("\n\n").replace(/\s+/g, " "), secText(SEC).replace(/\s+/g, " "), "nothing lost, order kept");
  const tiny = sectionParts("Del A\n\nKort.\n\nDel B\n\n" + SEC[1][1] + "\n\nDel C\n\n" + SEC[2][1], 10)!;
  assertEquals(tiny.length, 2, "a section under 120 characters joins the next");
  assertEquals(sectionParts(Array.from({ length: 20 }, (_, i) => `Stycke ${i}: ${SEC[i % 5][1]}`).join("\n\n"), 30)!.length, 8, "at most 8 parts");
  assertEquals([isHeading("2022 och efteråt"), isHeading("## Orsaker"), isHeading("Det här är en mening."), isHeading("Fråga: vad är KPI?")], [true, true, false, false]);
});
