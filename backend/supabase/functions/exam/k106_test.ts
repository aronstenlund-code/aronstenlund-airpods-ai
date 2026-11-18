// K106 (D232): Oscar's K102 omtest in the exam drill: questions the material does not answer, full exams, the near pair.
import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { answerItems, DEFAULT_DRILL_CONFIG, dropNearSame, notAnswered, oneAsk } from "./drill.ts";
import { nearDuplicate } from "./coverage.ts";
import type { LLMChunk, LLMProvider, LLMRequest } from "../answer/llm/types.ts";

Deno.test("K106 F1: an answer that says the notes do not answer it is seen", () => {
  assert(notAnswered("Varför han flydde till Dalarna framgår inte här, men han sökte stöd hos bönderna."));
  assert(notAnswered("Why he left is not explained here, but he wanted support."));
  assertEquals(notAnswered("Han flydde för att danskarna jagade honom efter blodbadet."), false);
});

Deno.test("K106 F1: a two-part question keeps the first part; one question stays as it is", () => {
  assertEquals(oneAsk("Vad var fogdarnas uppgift i landskapen, och varför skapade han en egen här?"), "Vad var fogdarnas uppgift i landskapen?");
  assertEquals(oneAsk("Hur påverkade reformationen kyrkans makt?"), "Hur påverkade reformationen kyrkans makt?");
  assertEquals(oneAsk("Förklara hur X och Y hänger ihop."), "Förklara hur X och Y hänger ihop.");
});

Deno.test("K106 F1: a generated question the notes do not answer is replaced by one they answer (asked again once)", async () => {
  const seen: LLMRequest[] = [];
  const llm: LLMProvider = {
    name: "fake", model: "sonnet-fake",
    async *stream(req: LLMRequest): AsyncIterable<LLMChunk> {
      seen.push(req);
      const fix = req.user.includes("<must_fix>yes</must_fix>");
      const answers = fix
        ? [{ id: "q1", question: "Vad hände när Gustav Vasa kom till Dalarna?", short: "Han försökte få dalkarlarna att resa sig mot danskarna.", rest: "Först sa de nej." }]
        : [
          { id: "q1", short: "Varför han flydde till Dalarna framgår inte här, men han sökte stöd.", rest: "Mer." },
          { id: "q2", short: "Riksdagen valde honom till kung 1523.", rest: "I Strängnäs." },
        ];
      yield { type: "text", text: JSON.stringify({ answers }) };
      yield { type: "usage", inputTokens: 100, outputTokens: 50 };
    },
  };
  const items = [{ id: "q1", question: "Varför flydde Gustav Vasa till Dalarna?" }, { id: "q2", question: "När blev Gustav Vasa kung?" }];
  const r = await answerItems(llm, DEFAULT_DRILL_CONFIG, items, { subject: "Historia", grade: "åk 8", notes: "n", longWords: 60, mayFix: true });
  assertEquals(r.items[0].question, "Vad hände när Gustav Vasa kom till Dalarna?");
  assertEquals(notAnswered(r.items[0].short!), false);
  assertEquals(r.items[1].question, "När blev Gustav Vasa kung?");
  assertEquals(seen.filter((x) => x.user.includes("<must_fix>")).length, 1, "only the unanswered one is asked again");
  // the student's own questions (no may_fix) are never asked again or changed
  seen.length = 0;
  const own = await answerItems(llm, DEFAULT_DRILL_CONFIG, items, { subject: "Historia", grade: "åk 8", notes: "n", longWords: 60 });
  assertEquals(own.items[0].question, "Varför flydde Gustav Vasa till Dalarna?");
  assertEquals(seen.length, 1);
});

Deno.test("K106 F3: the ljud pair is one question; different topics on one subject are two", () => {
  assert(nearDuplicate("Hur påverkar frekvensen tonhöjden?", "Jämför hur hög och låg frekvens påverkar tonen."));
  assertEquals(nearDuplicate("Hur påverkar temperaturen fotosyntesen?", "Hur påverkar ljuset fotosyntesen?"), false);
  assertEquals(nearDuplicate("Vad är frekvens?", "Hur mäts ljudets styrka i decibel?"), false);
  assertEquals(nearDuplicate("Varför steg priserna efter kriget?", "Hur påverkade kriget handeln med Lübeck?"), false);
});

Deno.test("K106 (live 18:00, Vasa): a two-part question without a comma is cut; a later near-same question goes", () => {
  assertEquals(oneAsk("Vad var Dackefejden och varför var den viktig?"), "Vad var Dackefejden?");
  assertEquals(oneAsk("Hur hänger utsläppen och temperaturen ihop?"), "Hur hänger utsläppen och temperaturen ihop?");
  const qs = [
    "Hur gick Gustav Vasas uppror mot danskarna till?",
    "Vad beslutades vid riksdagen i Västerås 1527?",
    "Förklara hur Gustav Vasas uppror mot danskarna hänger ihop med att han blev kung.",
    "Hur byggde Gustav Vasa upp en starkare kungamakt?",
  ];
  const r = dropNearSame(qs, [0, 1, 0, 2]);
  assertEquals(r.questions, [qs[0], qs[1], qs[3]]);
  assertEquals(r.dropped, 1);
  // the only question of its part stays even when it is near an earlier one
  assertEquals(dropNearSame(qs, [0, 1, 2, 3]).questions.length, 4);
});
