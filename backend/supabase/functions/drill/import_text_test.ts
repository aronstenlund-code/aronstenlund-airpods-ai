import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { firstSentence, importText } from "./import_text.ts";

const T = `Fråga: Varför behöver växter ljus?
Svar: Växter behöver ljus för att kunna göra fotosyntes och bilda glukos. I kloroplasterna fångar klorofyllet ljusenergin. Den används för att bygga glukos av koldioxid och vatten, och syre släpps ut.

Fråga: Vad är klorofyll?
Svar: Klorofyll är det gröna ämnet i kloroplasterna som fångar ljus. Det gör att växten kan använda solens energi.
`;

Deno.test("K58 reads Fråga/Svar pairs; short = first sentence word for word, long = the whole answer (D145)", () => {
  const r = importText(T);
  assertEquals(r.items.length, 2);
  assertEquals(r.skipped, []);
  assertEquals(r.items[0], {
    id: "q1",
    question: "Varför behöver växter ljus?",
    short: "Växter behöver ljus för att kunna göra fotosyntes och bilda glukos.",
    long: "Växter behöver ljus för att kunna göra fotosyntes och bilda glukos. I kloroplasterna fångar klorofyllet ljusenergin. Den används för att bygga glukos av koldioxid och vatten, och syre släpps ut.",
  });
  assert(r.items[1].long.startsWith(r.items[1].short));
});

Deno.test("K58 tolerates what ChatGPT adds anyway: intro, markdown, numbering, CRLF, answer over two lines", () => {
  const t = "Här är dina frågor:\r\n\r\n**Fråga 1:** Hur bildas syre?\r\n**Svar:** Syre bildas när vatten delas i fotosyntesen.\r\nDet släpps ut genom klyvöppningarna.\r\n\r\n2. Fråga: Vad är glukos?\r\nSvar: Glukos är ett socker som växten bildar.\r\n\r\nLycka till!";
  const r = importText(t);
  assertEquals(r.items.map((i) => i.question), ["Hur bildas syre?", "Vad är glukos?"]);
  assertEquals(r.items[0].long, "Syre bildas när vatten delas i fotosyntesen. Det släpps ut genom klyvöppningarna.");
  assertEquals(r.skipped.map((s) => s.line), [1, 10]);
});

Deno.test("K58 shows what could not be read: a question without an answer, an answer without a question", () => {
  const r = importText("Svar: Ett löst svar.\n\nFråga: Vad är en cell?\n\nFråga: Vad är DNA?\nSvar: DNA är arvsmassan i cellen.");
  assertEquals(r.items.length, 1);
  assertEquals(r.skipped.map((s) => s.reason), ["Ett svar utan fråga före.", "Frågan har inget svar."]);
  assertEquals(importText("bara text").items, []);
});

Deno.test("K58 nothing is shortened: a long first sentence is kept and only warned about", () => {
  const long = "Detta är en mycket lång första mening som fortsätter och fortsätter med många ord för att visa att ingenting kortas av tolken även om den blir alldeles för lång.";
  const r = importText(`Fråga: Vad händer?\nSvar: ${long} Mer text.`);
  assertEquals(r.items[0].short, long);
  assertEquals(r.warnings.length, 1);
});

Deno.test("K58 first sentence skips abbreviations and decimals", () => {
  assertEquals(firstSentence("Många växter, t.ex. Tall och gran, är vintergröna. De tappar inte barren."), "Många växter, t.ex. Tall och gran, är vintergröna.");
  assertEquals(firstSentence("Det tar ca. 8 minuter för ljuset att nå jorden. Det är långt."), "Det tar ca. 8 minuter för ljuset att nå jorden.");
  assertEquals(firstSentence("pH 7.5 är svagt basiskt. Mer."), "pH 7.5 är svagt basiskt.");
  assertEquals(firstSentence("Inget slut"), "Inget slut");
});
