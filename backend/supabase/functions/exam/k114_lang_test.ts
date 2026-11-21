// K114 (D251): an exam is in its text's language: English material gives English answers even when the subject is not
// a language exam; Swedish material stays Swedish.
import { assertEquals } from "jsr:@std/assert@1.0.8";
import { answerItems, DEFAULT_DRILL_CONFIG, textLanguage } from "./drill.ts";
import type { LLMChunk, LLMProvider, LLMRequest } from "../answer/llm/types.ts";

Deno.test("K114: the material's language from its words", () => {
  assertEquals(textLanguage("Photosynthesis is the process in which plants make sugar from light, water and carbon dioxide. The energy is stored in the plant."), "en");
  assertEquals(textLanguage("Fotosyntesen är processen där växterna gör socker av ljus, vatten och koldioxid. Energin lagras i växten."), "sv");
  assertEquals(textLanguage(""), "");
});

Deno.test("K114: English notes give English answers (<language>English</language>), Swedish notes none", async () => {
  const seen: LLMRequest[] = [];
  const p: LLMProvider = { name: "f", model: "x", async *stream(r: LLMRequest): AsyncIterable<LLMChunk> {
    seen.push(r);
    yield { type: "text", text: JSON.stringify({ answers: [{ id: "q1", short: "Plants make sugar from light.", rest: "They use water and carbon dioxide." }] }) } as LLMChunk;
  } };
  await answerItems(p, DEFAULT_DRILL_CONFIG, [{ id: "q1", question: "What is photosynthesis?" }], { subject: "Biology", grade: "", notes: "Photosynthesis is the process in which plants make sugar from light, water and carbon dioxide.", longWords: 90 });
  assertEquals(seen[0].user.includes("<language>English</language>"), true);
  seen.length = 0;
  await answerItems(p, DEFAULT_DRILL_CONFIG, [{ id: "q1", question: "Vad är fotosyntes?" }], { subject: "Biologi", grade: "", notes: "Fotosyntesen är processen där växterna gör socker av ljus och vatten.", longWords: 90 });
  assertEquals(seen[0].user.includes("<language>"), false);
});

Deno.test("K114 (D251): the plan writes the exam in the material's own language, not always Swedish", async () => {
  const { SYSTEM_PROMPT_DRILL_PLAN } = await import("./drill.ts");
  assertEquals(SYSTEM_PROMPT_DRILL_PLAN.includes("even when the material is in English"), false);
  assertEquals(SYSTEM_PROMPT_DRILL_PLAN.includes("in the material's own language"), true);
});
