// K111 (Deangelo 20:05, K109 proposal): a question the answer step rewrote (may_fix) that got the same short answer as
// another question gets back its original question and answer, with no new call. The original answer comes in the same
// reply ("original") when the model rewrites; it is used only when it answers and is not a duplicate itself.
import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { answerItems, DEFAULT_DRILL_CONFIG, parseAnswers, SYSTEM_PROMPT_DRILL_ANSWERS } from "./drill.ts";
import type { LLMChunk, LLMProvider, LLMRequest } from "../answer/llm/types.ts";

function llm(reply: (req: LLMRequest) => unknown): LLMProvider & { seen: LLMRequest[] } {
  const seen: LLMRequest[] = [];
  return {
    name: "f", model: "x", seen,
    async *stream(req: LLMRequest): AsyncIterable<LLMChunk> {
      seen.push(req);
      yield { type: "text", text: JSON.stringify(reply(req)) } as LLMChunk;
      yield { type: "usage", inputTokens: 300, outputTokens: 200 };
    },
  };
}
const CTX = { subject: "Historia", grade: "", notes: "Gustav Vasa …", longWords: 90, mayFix: true };

Deno.test("K111: the answer prompt asks for the original answer when it rewrites a question", () => {
  assert(SYSTEM_PROMPT_DRILL_ANSWERS.includes('"original"'));
  const m = parseAnswers(JSON.stringify({ answers: [{ id: "q1", question: "Vad hände?", short: "Det hände något stort.", rest: "Mer om det.", original: { short: "Originalet besvaras så här.", rest: "Och mer." } }] }));
  assertEquals(m.get("q1")?.original?.short, "Originalet besvaras så här.");
  assertEquals(m.get("q1")?.original?.long, "Originalet besvaras så här. Och mer.");
});

Deno.test("K111 (Vasa 8): the rewrite got the answer of question 9; the original question and its answer come back, no new call", async () => {
  const q8 = "Vilken roll hade Gustav Vasas bibel för språket i kyrkan?";
  const q9 = "Hur hänger översättningen av Bibeln till svenska ihop med att gudstjänsterna hålls på svenska i stället för latin?";
  const p = llm(() => ({
    answers: [
      {
        id: "q8", question: "Vad hände med språket i kyrkan när Bibeln fanns på svenska?",
        short: "När Bibeln hade översatts till svenska kunde gudstjänsterna hållas på svenska i stället för på latin.", rest: "Gustav Vasas bibel trycktes 1541.",
        original: { short: "Gustav Vasas bibel från 1541 blev den första hela bibeln på svenska och gav kyrkan ett gemensamt skriftspråk.", rest: "Den lästes i kyrkorna över hela landet." },
      },
      { id: "q9", short: "Bibeln översattes till svenska, och därför kunde gudstjänsterna hållas på svenska i stället för på latin.", rest: "Folket förstod då vad prästen sa." },
    ],
  }));
  const r = await answerItems(p, DEFAULT_DRILL_CONFIG, [{ id: "q8", question: q8 }, { id: "q9", question: q9 }], CTX);
  assertEquals(p.seen.length, 1, "no new call");
  assertEquals(r.items[0].question, q8);
  assert(r.items[0].short!.startsWith("Gustav Vasas bibel från 1541"));
  assertEquals(r.items[1].question, q9);
});

Deno.test("K111 (Vasa 6): an original that the notes do not answer, or that is a duplicate too, is never brought back", async () => {
  const q5 = "Vad hade kronan för skulder efter kriget?";
  const q6 = "Varför ville Gustav Vasa komma åt kyrkans rikedomar och makt?";
  const fixed = "Vad var Gustav Vasas skäl till att vilja komma åt kyrkans rikedomar och makt?";
  const answers = (orig: { short: string; rest: string }) => () => ({
    answers: [
      { id: "q5", short: "Kronan hade stora skulder till Lübeck efter kriget.", rest: "Skulderna måste betalas." },
      { id: "q6", question: fixed, short: "Kronan hade stora skulder till Lübeck efter kriget, och kyrkans rikedomar kunde hjälpa kungen.", rest: "Det stärkte hans makt.", original: orig },
    ],
  });
  // the original says it is not known: the rewrite stays
  const a = await answerItems(llm(answers({ short: "Varför han ville det är inte känt härifrån, men kronan hade skulder.", rest: "Det stärkte hans makt." })), DEFAULT_DRILL_CONFIG, [{ id: "q5", question: q5 }, { id: "q6", question: q6 }], CTX);
  assertEquals(a.items[1].question, fixed);
  // the original has the same answer as question 5 too: the rewrite stays
  const b = await answerItems(llm(answers({ short: "Kronan hade stora skulder till Lübeck efter kriget och behövde kyrkans rikedomar.", rest: "Det stärkte hans makt." })), DEFAULT_DRILL_CONFIG, [{ id: "q5", question: q5 }, { id: "q6", question: q6 }], CTX);
  assertEquals(b.items[1].question, fixed);
});

Deno.test("K111: without may_fix, or a rewrite with its own answer, nothing changes", async () => {
  const p = llm(() => ({ answers: [{ id: "q1", short: "Fotosyntes gör socker av ljus.", rest: "Det sker i bladen." }, { id: "q2", question: "Var sker fotosyntesen?", short: "Fotosyntesen sker i bladens gröna delar.", rest: "Klorofyllet fångar ljuset.", original: { short: "Originalsvaret här.", rest: "Mer." } }] }));
  const r = await answerItems(p, DEFAULT_DRILL_CONFIG, [{ id: "q1", question: "Vad är fotosyntes?" }, { id: "q2", question: "Var sker den?" }], CTX);
  assertEquals(r.items[1].question, "Var sker fotosyntesen?");
});
