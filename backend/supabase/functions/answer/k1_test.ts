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

Deno.test("K1.3 derivatives and linear equations are computed in code", async () => {
  const { computeMath, normalizeMath } = await import("./mathcheck.ts");
  assertEquals(normalizeMath("tre x i kvadrat plus två x"), "3x^2+2x");
  const cases: [string, string | null][] = [
    ["derivatan av x i kvadrat", "f′(x) = 2x"],
    ["vad är derivatan av x^2", "f′(x) = 2x"],
    ["derivera tre x i kvadrat plus två x minus fem", "f′(x) = 6x + 2"],
    ["derivatan av x upphöjt till tre", "f′(x) = 3x²"],
    ["derivatan av f(x) = 4x³ − 2x", "f′(x) = 12x² − 2"],
    ["lös 3x − 7 = 14", "x = 7"],
    ["lös ekvationen två x plus nio är lika med tre", "x = -3"],
    ["5x + 2 = 3x + 10", "x = 4"],
    ["vad är x om 4x = 10", "x = 2,5"],
    ["vad är derivata", null],
    ["derivatan av sinus x", null],
    ["x är sju", null],
    ["lös x^2 = 9", null],
  ];
  for (const [f, want] of cases) {
    const r = computeMath(f);
    if (want === null) assertEquals(r, null, f);
    else assert(r && r.text.includes(want), `${f}: ${r?.text}`);
  }
});

Deno.test("K1.3 '2x' in maths is two x, elsewhere two times", async () => {
  const { beforeNumbers } = await import("./speechsym.ts");
  assert(beforeNumbers("Derivatan av x i kvadrat är 2x.").includes("2 x"), beforeNumbers("Derivatan av x i kvadrat är 2x."));
  assert(beforeNumbers("3x = 21, så x = 7.").includes("3 x"));
  assert(beforeNumbers("Derivatan blir 6x + 2.").includes("6 x"));
  assert(beforeNumbers("Laddningen går 2x snabbare.").includes("2 gånger"));
  assert(beforeNumbers("Ta tabletten 3x per dag.").includes("3 gånger"));
});

Deno.test("K1.4 förhör mig: no repeated question, a short reply is graded only in time and when not a question", async () => {
  const { askedQuestions, looksLikeQuestion } = await import("./prompt.ts");
  const { isRepeatedQuestion } = await import("./handler.ts");
  const asked = askedQuestions({
    context: {
      recent_qa: [{ q: "förhör mig", a: "Var i cellen sker cellandningen?" }],
      already_asked: ["Vad heter cellens kraftverk?", "Var i cellen sker cellandningen?"],
    },
  });
  assertEquals(asked, ["Vad heter cellens kraftverk?", "Var i cellen sker cellandningen?"]);
  assert(isRepeatedQuestion("Vad heter cellens kraftverk?", asked));
  assert(isRepeatedQuestion("Var i cellen sker cellandning?", asked));
  assert(!isRepeatedQuestion("Vilka ämnen behövs för fotosyntesen?", asked));
  for (const q of ["vad är mitos", "hur fungerar det?", "förklara cellandning", "och vad är meios"]) assert(looksLikeQuestion(q), q);
  for (const a of ["mitokondrien", "i mitokondrierna", "socker och syre", "ja", "var det glukos"]) assert(!looksLikeQuestion(a), a);
});

Deno.test("K1.4 already_asked and last_answer_age_sec are validated", async () => {
  const { validateAnswerRequest } = await import("./validate.ts");
  const ok = validateAnswerRequest({ fragment: "ja", mode: "tutor", language: "sv", context: { already_asked: ["a?"], last_answer_age_sec: 12 } });
  assertEquals(ok.context.already_asked, ["a?"]);
  assertEquals(ok.context.last_answer_age_sec, 12);
  let threw = false;
  try {
    validateAnswerRequest({ fragment: "ja", mode: "tutor", language: "sv", context: { last_answer_age_sec: -1 } });
  } catch {
    threw = true;
  }
  assert(threw);
});
