// K83 (D206): coverage of the whole material, in code. Invented material only, a scripted model.
import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { coverage, mergeCoverage, partCount, splitParts } from "./coverage.ts";
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
