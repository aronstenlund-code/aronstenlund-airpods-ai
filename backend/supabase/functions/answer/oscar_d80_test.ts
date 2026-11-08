import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { AnswerPost, isInterviewMeta, rewriteLeadIn } from "./speech.ts";

Deno.test("Oscar 2026-11-08 Provläge: the reading of a misheard term is never said", () => {
  assertEquals(rewriteLeadIn('Fragmentet "gra vi ta tions kraften" låter som "gravitationskraften", ett klart studieämne, så jag svarar på det. ', "gra vi ta tions kraften"), "");
  assertEquals(rewriteLeadIn("Det låter som kosinussatsen, en sats i geometri som kopplar ihop sidor och vinklar. ", "ko sinus satsen"),
    "Kosinussatsen är en sats i geometri som kopplar ihop sidor och vinklar. ");
  assertEquals(rewriteLeadIn("Det här är fotosyntesen. ", "fo to syn tesen"), "");
  assertEquals(rewriteLeadIn("Det är demokrati, ett styrelseskick där folket väljer. ", "den mo kra tin"),
    "Demokrati är ett styrelseskick där folket väljer. ");
  // never touched: a reply to a check question, an ordinary first sentence
  assertEquals(rewriteLeadIn("Det är rätt. ", "kloroplast"), "Det är rätt. ");
  assertEquals(rewriteLeadIn("Det är viktigt, eftersom växter behöver ljus. ", "fotosyntes"), "Det är viktigt, eftersom växter behöver ljus. ");
  const p = new AnswerPost({ previousAnswers: [], trimQuestion: false, tutor: true, silence: true, inputMeta: true, heard: "fo to syn tesen" });
  const out = p.push("Det här är fotosyntesen. Växter bygger socker av ljus. ") + p.finish();
  assertEquals(out.trim(), "Växter bygger socker av ljus.");
});

Deno.test("Oscar 2026-11-08 interview: the remarks about missing facts are dropped", () => {
  for (
    const s of [
      "Jag har inget namn angivet, så jag svarar utan att nämna det.",
      "Jag vill hellre prata om vad jag tar med mig till jobbet än om mina år.",
      "Jag är inte så noga med siffror, men jag är noggrann i kassan.",
      "Hur gammal jag är spelar inte lika stor roll som vad jag kan bidra med.",
    ]
  ) assert(isInterviewMeta(s), s);
  assert(!isInterviewMeta("Jag är noggrann och tycker om att möta kunder."));
});

Deno.test("Oscar 2026-11-08 Provläge: a guessed subject is silence, not the wrong subject", () => {
  const p = new AnswerPost({ previousAnswers: [], trimQuestion: false, tutor: true, silence: true, inputMeta: true, heard: "pe ri o diska syste met" });
  const out = p.push("Det låter som perifera nervsystemet, som du kanske menar. Det är den del av nervsystemet som ligger utanför hjärnan. ") + p.finish();
  assertEquals(out.trim(), "");
  assert(p.silent);
  const q = new AnswerPost({ previousAnswers: [], trimQuestion: false, tutor: true, silence: true, inputMeta: true, heard: "gra vi ta tions kraften" });
  const o2 = q.push("Det verkar vara en fråga om fotosyntesen, men jag är inte säker på vad du menar, så jag svarar inte på den. ") + q.finish();
  assertEquals(o2.trim(), "");
  assert(isInterviewMeta("Jag tänker inte fokusera på min ålder utan på vad jag tar med mig till jobbet."));
});

Deno.test("Oscar 2026-11-08 Provläge: 'Fragmentet … liknar …' and 'Och jag svarar på det:' are cut", () => {
  assertEquals(rewriteLeadIn('Fragmentet "gra vi ta tions kraften" liknar "gravitationskraften", ett tydligt ämne, så jag svarar på det. ', "gra vi ta tions kraften"), "");
  assertEquals(rewriteLeadIn("Och jag svarar på det: demokrati betyder folkstyre. ", "den mo kra tin"), "Demokrati betyder folkstyre. ");
});

Deno.test("Oscar 2026-11-08 Provläge: 'Det verkar vara begreppet X, så här är det kort:' and '…, som är …'", () => {
  assertEquals(rewriteLeadIn("Det verkar vara begreppet demokratin, så här är det kort: demokrati betyder folkstyre. ", "den mo kra tin"),
    "Demokrati betyder folkstyre. ");
  assertEquals(rewriteLeadIn("Det här är periodiska systemet, som är ett sätt att ordna grundämnena. ", "pe ri o diska syste met"),
    "Periodiska systemet är ett sätt att ordna grundämnena. ");
});

Deno.test("D87 with an exam profile a guessed reading keeps the answer (only the guess sentence goes)", () => {
  const p = new AnswerPost({ previousAnswers: [], trimQuestion: false, tutor: true, silence: true, inputMeta: true, heard: "gra vi ta tion", subjectKnown: true });
  const out = p.push("Det låter som gravitation, som du kanske menar. Gravitation är dragningskraften mellan massor. ") + p.finish();
  assertEquals(out.trim(), "Gravitation är dragningskraften mellan massor.");
});
