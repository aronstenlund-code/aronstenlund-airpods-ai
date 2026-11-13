// Kevin standing round 21 (live eval k9-ih-professional-2, 2026-11-12 and 2026-11-13): "vad borde jag säga" in
// Intervjuläget got coaching in second person ("Ditt sommarjobb … har gett dig …"), which the user cannot say aloud.
import { assertEquals } from "jsr:@std/assert@1.0.8";
import { AnswerPost, interviewFirstPerson } from "./speech.ts";

Deno.test("standing21: a second-person interview answer becomes first person", () => {
  assertEquals(
    interviewFirstPerson("Ditt sommarjobb på kafé har gett dig vana vid tempo och många kunder samtidigt. "),
    "Mitt sommarjobb på kafé har gett mig vana vid tempo och många kunder samtidigt. ",
  );
  assertEquals(
    interviewFirstPerson("Dessutom är du van att ta ansvar, som när du tränar barn i innebandy och håller dina pass."),
    "Dessutom är jag van att ta ansvar, som när jag tränar barn i innebandy och håller mina pass.",
  );
  assertEquals(interviewFirstPerson("Du är snabb och gillar att möta människor."), "Jag är snabb och gillar att möta människor.");
});

Deno.test("standing21: first person, questions to the interviewer, thanks and 'som du sa' are left alone", () => {
  for (
    const s of [
      "Jag har jobbat på kafé, så jag är van vid tempo.",
      "Vad tycker du är viktigast i rollen?",
      "Tack för att du frågar.",
      "Som du sa är kvällarna mest intensiva, och det passar bra.",
      "Kvällarna är mest intensiva, och det passar bra.",
      "Mitt mål är att du som kund känner dig välkommen.", // has a first-person word: untouched
      "Dunkelt ljus och dunder stör inte.", // 'du' only inside other words
    ]
  ) assertEquals(interviewFirstPerson(s), s, s);
});

function run(post: AnswerPost, chunks: string[]): string {
  let out = "";
  for (const c of chunks) out += post.push(c);
  return (out + post.finish()).trim();
}

Deno.test("standing21: in the stream only the user's own answer is turned, never feedback or other modes", () => {
  const chunks = ["Ditt sommarjobb på kafé har gett ", "dig vana vid tempo. Dessutom är du ", "van att ta ansvar."];
  const say = new AnswerPost({ previousAnswers: [], trimQuestion: false, interview: true, interviewSay: true });
  assertEquals(run(say, chunks), "Mitt sommarjobb på kafé har gett mig vana vid tempo. Dessutom är jag van att ta ansvar.");
  // interview_feedback / interview_summary talk to the user on purpose
  const feedback = new AnswerPost({ previousAnswers: [], trimQuestion: false, interview: true });
  assertEquals(run(feedback, chunks), "Ditt sommarjobb på kafé har gett dig vana vid tempo. Dessutom är du van att ta ansvar.");
  const plain = new AnswerPost({ previousAnswers: [], trimQuestion: false });
  assertEquals(run(plain, chunks), "Ditt sommarjobb på kafé har gett dig vana vid tempo. Dessutom är du van att ta ansvar.");
});
