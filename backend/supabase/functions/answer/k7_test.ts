import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { AnswerPost, fixStump, isLevelMeta, type PostOptions, rewriteLevelMeta } from "./speech.ts";

function run(chunks: string[], opts: Partial<PostOptions> = {}): string {
  const p = new AnswerPost({ previousAnswers: [], trimQuestion: false, tutor: true, inputMeta: true, heard: "derivata", subjectKnown: true, ...opts });
  return (chunks.map((c) => p.push(c)).join("") + p.finish()).trim();
}

Deno.test("K7.1 the level, the grade or the choice of what to explain is never said (Oscar O1 finding A)", () => {
  for (
    const s of [
      "Det är ett väldigt viktigt men det här är Åk åtta, och en derivata hör till gymnasiets matematik, så på den nivån förklarar jag bara idén.",
      "Åk åtta matte har inga derivator, så jag förklarar idén.",
      "Åk åtta-nivå: derivata är inte något eleven ska kunna i årskurs åtta, så förklara idén enkelt.",
      "Det är svårt att förklara en derivata på grundskolenivå, men här är idén.",
      "Det är inget du behöver räkna med i årskurs sex, så här är den enkla idén.",
      "I Åk nio tänker man på det som lutningen hos en graf.",
      "Derivator hör till gymnasiet, men principen är enkel.",
      "Enligt kursplanen ska du kunna förklara begreppet.",
    ]
  ) assert(isLevelMeta(s), s);
  for (
    const s of [
      "Derivatan är hur snabbt något förändras just i ett visst ögonblick.",
      "Havsnivån stiger när isarna smälter.",
      "Grundskolan i Sverige är nioårig och obligatorisk.",
      "På provet kan du skriva att derivatan är lutningen i en punkt.",
      "X är lika med sju.",
    ]
  ) assert(!isLevelMeta(s), s);
  // the part after a colon is kept when it is the answer
  assertEquals(
    rewriteLevelMeta("Det är ett tillfälle att förklara på grundskolenivå: derivatan visar hur snabbt något ändras."),
    "Derivatan visar hur snabbt något ändras.",
  );
  assertEquals(rewriteLevelMeta("Åk åtta matte har inga derivator, så jag förklarar idén."), "");
});

Deno.test("K7.1 in the stream: every level sentence is dropped, the answer is said", () => {
  const out = run([
    "Derivatan är hur snabbt något förändras i ett ögonblick. ",
    "Det här är Åk åtta, så jag förklarar idén. ",
    "Om en bil kör tjugo meter per sekund är derivatan av sträckan tjugo meter per sekund där.",
  ]);
  assert(!/åk|idén/i.test(out), out);
  assert(out.startsWith("Derivatan är"), out);
  assert(out.includes("tjugo meter per sekund"), out);
});

Deno.test("K7.2 no stump after a dropped sentence (Oscar O1 finding C)", () => {
  assertEquals(fixStump("Där lärde jag mig att kontrollera legitimation."), "");
  assertEquals(fixStump("A syntes är en reaktion där två ämnen blir ett nytt."), "Syntes är en reaktion där två ämnen blir ett nytt.");
  assertEquals(fixStump("X är lika med sju."), "X är lika med sju.");
  assertEquals(fixStump("Derivatan är lutningen."), "Derivatan är lutningen.");
  const out = run([
    "Det här är Åk åtta, så jag förklarar idén. ",
    "Därför tar vi ett exempel. ",
    "Derivatan är hur snabbt något ändras.",
  ]);
  assertEquals(out, "Derivatan är hur snabbt något ändras.");
  // only one stump is dropped, never a chain of steps
  const steps = run([
    "Det här ligger över din nivå, så jag håller det enkelt. ",
    "Då börjar vi med sträckan. ",
    "Sedan delar du med tiden. ",
    "Då får du farten.",
  ]);
  assert(steps.includes("Sedan delar du med tiden"), steps);
});

Deno.test("K7.6 'På provet räcker det att skriva' becomes 'På provet kan du skriva'", () => {
  assertEquals(
    rewriteLevelMeta("På provet räcker det att skriva att Fredrik gick tidigare."),
    "På provet kan du skriva att Fredrik gick tidigare.",
  );
  assertEquals(rewriteLevelMeta("På provet skriver du varje steg."), "På provet skriver du varje steg.");
});

Deno.test("K2 '3x' in an equation is 'tre x' also in words and at the end of a sentence (pl-184, pl-187)", async () => {
  const { beforeNumbers } = await import("./speechsym.ts");
  assert(beforeNumbers("För att lösa 3x minus 7 är lika med 14 lägger du till sju.").includes("3 x minus"));
  assert(beforeNumbers("Då blir det 3x är lika med 21.").includes("3 x är"));
  assert(beforeNumbers("Sju plus sju blir 3x.", "lös ekvationen tre x minus sju").includes("3 x."));
  assert(beforeNumbers("derivatan av e^{3x} är").includes("3 x"));
  assert(beforeNumbers("Ta tabletten 3x per dag.").includes("3 gånger"));
  assert(beforeNumbers("Laddningen går 2x snabbare.").includes("2 gånger"));
});
