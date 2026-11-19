// K109 (3) (D239, Kevin's K108 proposal): the last check also writes the right answer to every question in one sentence;
// a later question whose answer says what an earlier one's says (k102-measure's measure) goes before the list is shown.
import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { DEFAULT_DRILL_CONFIG, finalCheck, SYSTEM_PROMPT_DRILL_FINAL_CHECK } from "./drill.ts";
import type { LLMChunk, LLMProvider, LLMRequest } from "../answer/llm/types.ts";

const MATERIAL = `Ekosystem

Växterna tar energi från solljuset. Bara ungefär en tiondel av energin följer med till nästa nivå. Resten blir värme.
Därför finns det fler växter än växtätare. Toppkonsumenterna blir få eftersom energin tar slut uppåt i kedjan.
Nedbrytare bryter ner döda växter och djur.`;

function reply(answers: string[], sources: number[][]): LLMProvider {
  return {
    name: "f", model: "x",
    async *stream(_req: LLMRequest): AsyncIterable<LLMChunk> {
      yield { type: "text", text: JSON.stringify({ questions: [], sources: sources.map((s, i) => ({ i, s, a: answers[i] })) }) } as LLMChunk;
      yield { type: "usage", inputTokens: 500, outputTokens: 60 };
    },
  };
}

const QS = [
  "Hur får växterna sin energi?",
  "Hur mycket energi följer med till nästa nivå?",
  "Varför finns det fler växter än växtätare?",
  "Varför blir toppkonsumenterna få?",
  "Vad gör nedbrytarna?",
  "Vad händer med resten av energin?",
];

Deno.test("K109: the last check asks for the answer in one sentence for every question", () => {
  assert(SYSTEM_PROMPT_DRILL_FINAL_CHECK.includes('"a"'));
  assert(/one (?:short )?sentence/i.test(SYSTEM_PROMPT_DRILL_FINAL_CHECK));
});

Deno.test("K109: different sentences but the same answer = the same question (Oscar's ekosystem 5/6/7); the later one goes", async () => {
  const same = "Bara ungefär en tiondel av energin följer med till nästa nivå, resten försvinner som värme.";
  const answers = [
    "Växterna tar energi från solljuset.",
    same,
    "Det finns fler växter än växtätare eftersom varje led har mindre att leva på.",
    "Energin tar slut uppåt i kedjan, bara en tiondel följer med till nästa nivå, resten försvinner som värme.",
    "Nedbrytarna bryter ner döda växter och djur.",
    "Resten av energin blir värme.",
  ];
  // sources all differ, so K107/K108 alone would keep every question
  const r = await finalCheck(reply(answers, [[2], [3], [5], [6], [7], [4]]), DEFAULT_DRILL_CONFIG, QS, [0, 0, 0, 0, 1, 1], MATERIAL);
  assertEquals(r.questions, [QS[0], QS[1], QS[2], QS[4], QS[5]]);
  assertEquals(r.dropped, 1);
});

Deno.test("K109: answers that only share a topic stay; no answers = as before", async () => {
  const answers = [
    "Växterna tar energi från solljuset.",
    "Ungefär en tiondel av energin följer med.",
    "Det finns fler växter eftersom energin minskar.",
    "Toppkonsumenterna blir få eftersom energin tar slut uppåt.",
    "Nedbrytarna bryter ner döda växter och djur.",
    "Resten blir värme.",
  ];
  const r = await finalCheck(reply(answers, [[2], [3], [5], [6], [7], [4]]), DEFAULT_DRILL_CONFIG, QS, [0, 0, 0, 0, 1, 1], MATERIAL);
  assertEquals(r.questions, QS);
  const none = await finalCheck(reply([], [[2], [3], [5], [6], [7], [4]]), DEFAULT_DRILL_CONFIG, QS, [0, 0, 0, 0, 1, 1], MATERIAL);
  assertEquals(none.questions, QS);
});
