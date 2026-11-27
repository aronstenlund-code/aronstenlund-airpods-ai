// O107 (Oscar): F3 the task's spoken text kept formulas and symbols ("trex + fem", "√fyrtionio", "H₂SO₄", "(milj.)",
// "Bilden visar Tabell:", no full stop before "Den ger", the E/C/A split lost); F2 an English exam got a Swedish frame
// and Swedish model answers.
import { assert, assertStringIncludes } from "jsr:@std/assert@1.0.8";
import { spokenTask } from "./practice.ts";
import { SYSTEM_PROMPT_EXAM_PARSE, SYSTEM_PROMPT_EXAM_SOLVE } from "./handler.ts";

const p = (E: number, C = 0, A = 0) => ({ E, C, A });
Deno.test("O107 F3: a task's formulas are said in words", () => {
  const a = spokenTask("1", "Lös ekvationen 3x + 5 = 20", p(1));
  assertStringIncludes(a, "tre x plus fem är lika med tjugo");
  assertStringIncludes(spokenTask("2", "Lös x² + 2x − 8 = 0", p(1)), "x i kvadrat plus två x minus åtta är lika med noll");
  assertStringIncludes(spokenTask("3", "Förenkla √49 + ½ · 6", p(1)), "roten ur fyrtionio plus en halv gånger sex");
  assertStringIncludes(spokenTask("4", "Vilken syra är H₂SO₄ eller H₂SO₃?", p(1)), "H två S O fyra eller H två S O tre");
  assertStringIncludes(spokenTask("5", "Befolkningen (milj.) per år", p(1)), "(miljoner)");
});

Deno.test("O107 F3: a table is said as a table, a full stop before the points, and the split by level", () => {
  const t = spokenTask("6", "Hur många sålde de på tisdag?\n[Tabell: Måndag 12, Tisdag 18]", p(1, 1));
  assert(!t.includes("Bilden visar Tabell"), t);
  assertStringIncludes(t, "Tabell: Måndag tolv, Tisdag arton.");
  assertStringIncludes(t, "Den ger två poäng, en E-poäng och en C-poäng.");
  assertStringIncludes(spokenTask("7", "Vad är 15 procent av 840", p(1)), "av åttahundrafyrtio. Den ger en poäng.");
});

Deno.test("O107 F2: an English exam gets an English frame; the answer writer and reader follow the exam's language", () => {
  const en = spokenTask("1", "Name the gas that plants take in during photosynthesis.", p(1, 1));
  assertStringIncludes(en, "Question one. Name the gas");
  assertStringIncludes(en, "It gives two points, one E point and one C point.");
  assert(!/in Swedish:/.test(SYSTEM_PROMPT_EXAM_SOLVE) && /language of the tasks/.test(SYSTEM_PROMPT_EXAM_SOLVE));
  assert(/in the exam's language/.test(SYSTEM_PROMPT_EXAM_PARSE));
});

Deno.test("O107 F2: the frame's language is decided for the whole exam (a short English task is still English)", () => {
  assertStringIncludes(spokenTask("2", "Write a sentence using 'although'.", p(1), "en"), "Question two. Write a sentence");
  assertStringIncludes(spokenTask("2", "Write a sentence using 'although'.", p(1), "en"), "It gives one point.");
});
