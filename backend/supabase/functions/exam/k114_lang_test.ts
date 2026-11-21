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

Deno.test("K114 (D251, live 21/22): an English text's plan, refills and check get <language>English</language>; a Swedish one none", async () => {
  const { handleDrill, shortenQuestions, SYSTEM_PROMPT_DRILL_PLAN, SYSTEM_PROMPT_DRILL_FINAL_CHECK } = await import("./drill.ts");
  const users: string[] = [];
  const llm: LLMProvider = { name: "f", model: "x", async *stream(r: LLMRequest): AsyncIterable<LLMChunk> {
    // the final check keeps each question's own language ("same language"), so it needs no <language>
    if (r.system !== SYSTEM_PROMPT_DRILL_FINAL_CHECK) users.push(r.user);
    if (r.user.includes("<part>notes</part>")) yield { type: "text", text: JSON.stringify({ notes: "Water evaporates and condenses." }) } as LLMChunk;
    else if (r.system.includes("You check")) yield { type: "text", text: JSON.stringify({ questions: [] }) } as LLMChunk;
    else yield { type: "text", text: JSON.stringify({ summary: { subject: "Geografi", grade: "", covers: "The water cycle." }, questions: ["Why does water evaporate from the oceans?", "What happens to water vapour as it rises?", "How do droplets become rain?"] }) } as LLMChunk;
  } };
  const EN = "The Water Cycle. Water moves between the oceans, the air and the land in a cycle. The sun heats the oceans and water evaporates into the air. As the vapour rises it cools and condenses into droplets that form clouds.";
  await handleDrill("drill", { text: EN, questions: 3, answers: false }, llm, DEFAULT_DRILL_CONFIG);
  const plans = users.filter((u) => u.includes("<material>"));
  assertEquals(SYSTEM_PROMPT_DRILL_PLAN.includes("When <language> is given"), true);
  assertEquals(plans.length > 0 && plans.every((u) => u.includes("<language>English</language>")), true, plans.join("\n---\n"));
  users.length = 0;
  const SV = "Vattnets kretslopp. Vattnet rör sig mellan haven, luften och marken i ett kretslopp. Solen värmer haven och vattnet avdunstar till luften. När ångan stiger kyls den och bildar droppar som blir moln.";
  await handleDrill("drill", { text: SV, questions: 3, answers: false }, llm, DEFAULT_DRILL_CONFIG);
  assertEquals(users.some((u) => u.includes("<language>")), false);
  // the check step translates a Swedish question back when the material is English
  users.length = 0;
  await shortenQuestions(llm, DEFAULT_DRILL_CONFIG, ["Varför avdunstar vatten?"], { subject: "Geografi", grade: "", covers: "" }, undefined, EN);
  assertEquals(users[0].includes("<language>English</language>"), true);
});
