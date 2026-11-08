import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { AnswerPost, isReasoningMeta } from "./speech.ts";

const run = (opts: ConstructorParameters<typeof AnswerPost>[0], chunks: string[]) => {
  const p = new AnswerPost(opts);
  let out = "";
  for (const c of chunks) out += p.push(c);
  return { out: out + p.finish(), post: p };
};

Deno.test("K1.2 Provläge reasoning is never spoken (Oscar D84)", () => {
  for (
    const s of [
      "Syntes är nog fotosyntes, som är det mest närliggande biologiska begreppet i din lista.",
      "Syntes är inte ett kemiord, så jag tar det som att du menar ett ord som låter likt något i Kemi.",
      "Åk nio och provet fredag den tretton november ligger nära, så jag tar nära ämnesord: syra, bas, jon eller kemisk reaktion.",
      "Jag tar det som att du menar kemisk syntes.",
      "Det låter likt ett ord i din ordlista.",
      "Du menar säkert mitos.",
      "Jag tolkar ordet som syntesreaktion.",
      "Det ordet finns i listan för provet.",
      "Jag håller mig till ämnesord.",
    ]
  ) assert(isReasoningMeta(s, "syntes"), s);
  for (
    const s of [
      "En syntesreaktion är när två eller fler ämnen bildar en ny förening.",
      "Fotosyntesen sker i kloroplasterna och ger socker och syre.",
      "På provet ska du skriva reaktionsformeln och förklara varför.",
      "Vatten är en molekyl av två väteatomer och en syreatom.",
      "Trycket blir troligen högre eftersom gasen värms.",
      "Ett exempel är när järn och svavel bildar järnsulfid.",
    ]
  ) assert(!isReasoningMeta(s, "syntes"), s);
});

Deno.test("K1.2 the reasoning sentence is dropped, the chemistry answer stays", () => {
  const { out } = run(
    { previousAnswers: [], trimQuestion: false, tutor: true, inputMeta: true, heard: "syntes", subjectKnown: true },
    ["Syntes är inte ett kemiord, så jag tar det som att du menar syntesreaktion. ", "En syntesreaktion är när två ämnen bildar en ny förening. ", "Till exempel järn och svavel som blir järnsulfid."],
  );
  assertEquals(out.trim(), "En syntesreaktion är när två ämnen bildar en ny förening. Till exempel järn och svavel som blir järnsulfid.");
  // outside Provläge (no tutor) the same words are not filtered by this gate
  const other = run({ previousAnswers: [], trimQuestion: false, inputMeta: true, heard: "x" }, ["Du menar att jag ska hjälpa dig. "]);
  assert(other.out.includes("Du menar"), other.out);
});
