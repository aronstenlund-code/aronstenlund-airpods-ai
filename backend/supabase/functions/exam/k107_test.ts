// K107 (D232, Oscar's omtest K106 F3/F5): the last check sees which sentences answer each question; a later question
// answered by the same sentences as an earlier one goes before the list is shown (the refill makes up the count).
import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { DEFAULT_DRILL_CONFIG, finalCheck, numberedSentences, oneAsk, sameSource, SYSTEM_PROMPT_DRILL_FINAL_CHECK } from "./drill.ts";
import type { LLMChunk, LLMProvider, LLMRequest } from "../answer/llm/types.ts";

const MATERIAL = `Energi i näringskedjan

Växterna tar energi från solljuset. Bara ungefär en tiondel av energin följer med till nästa nivå. Resten blir värme.
Nedbrytare bryter ner döda växter och djur.`;

Deno.test("K107: the material as numbered sentences, paragraph by paragraph", () => {
  assertEquals(numberedSentences(MATERIAL), [
    "Energi i näringskedjan",
    "Växterna tar energi från solljuset.",
    "Bara ungefär en tiondel av energin följer med till nästa nivå.",
    "Resten blir värme.",
    "Nedbrytare bryter ner döda växter och djur.",
  ]);
  assertEquals(numberedSentences("A b c. D e f.", 8), ["A b c."], "never more than the limit");
});

Deno.test("K107: the same sentences (one set inside the other) are the same answer", () => {
  assert(sameSource([3], [3]));
  assert(sameSource([3, 4], [3]));
  assertEquals(sameSource([2], [3]), false);
  assertEquals(sameSource([2, 3], [3, 4]), false, "overlap alone is not the same answer");
  assertEquals(sameSource(undefined, [3]), false);
});

Deno.test("K107: three questions answered by 'en tiondel av energin' keep the first; every part keeps one", async () => {
  const seen: LLMRequest[] = [];
  const llm: LLMProvider = {
    name: "fake", model: "sonnet-fake",
    async *stream(req: LLMRequest): AsyncIterable<LLMChunk> {
      seen.push(req);
      yield { type: "text", text: JSON.stringify({ questions: [], sources: [
        { i: 0, s: [2] }, { i: 1, s: [3] }, { i: 2, s: [3] }, { i: 3, s: [3, 4] }, { i: 4, s: [5] }, { i: 5, s: [3] },
      ] }) } as LLMChunk;
      yield { type: "usage", inputTokens: 500, outputTokens: 60 };
    },
  };
  const qs = [
    "Hur får växterna energi?",
    "Vad händer med energin från en nivå till nästa?",
    "Varför finns det fler växter än växtätare?",
    "Varför har näringskedjor sällan mer än fem led?",
    "Vad gör nedbrytarna?",
    "Varför är toppkonsumenterna få?",
  ];
  const r = await finalCheck(llm, DEFAULT_DRILL_CONFIG, qs, [0, 0, 0, 0, 1, 1], MATERIAL);
  // 2, 3 and 5 are answered by sentence 3 like question 1; at most a third (2 of 6) go, the earliest first
  assertEquals(r.questions, [qs[0], qs[1], qs[4], qs[5]]);
  assertEquals(r.dropped, 2);
  assert(seen[0].user.includes("[3] Bara ungefär en tiondel av energin följer med till nästa nivå."));
  assert(SYSTEM_PROMPT_DRILL_FINAL_CHECK.includes('"sources"'));
});

Deno.test("K107 (live 19:09): '…, och var ägde den rum?' is a second question too", () => {
  assertEquals(oneAsk("Vad var Dackefejden, och var ägde den rum?"), "Vad var Dackefejden?");
});
