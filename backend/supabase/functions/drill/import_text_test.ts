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

Deno.test("K60 two paragraphs stay one answer; chatter after the last answer, headings and fences are skipped", () => {
  const r = importText("```\n### Fråga 1\nFråga: Vad är lava?\nSvar: Lava är smält berg på ytan.\n\nDen stelnar till basalt.\n---\nFråga 2\nFråga: Vad är magma?\nSvar: Magma är smält berg under ytan.\n\nLycka till! Vill du ha fler?\n```");
  assertEquals(r.items.map((i) => i.long), ["Lava är smält berg på ytan. Den stelnar till basalt.", "Magma är smält berg under ytan."]);
  assert(r.skipped.some((s) => s.reason === "Avslutning, inte en del av svaret."));
  assertEquals(r.skipped.filter((s) => s.reason.startsWith("Rubrik")).length, 5);
});

Deno.test("K60 an unlabelled question before Svar:, a duplicate, and a too long answer", () => {
  const r = importText("**1. Vad är magma?**\nSvar: Magma är smält berg.\n\nFråga: Vad är magma?\nSvar: Smält berg.");
  assertEquals(r.items.length, 2);
  assertEquals(r.warnings.map((w) => w.reason), ["Frågan saknade Fråga:.", "Samma fråga som på rad 1."]);
  const long = "Ord ".repeat(1100).trim() + ".";
  const t = importText(`Fråga: Vad?\nSvar: Kort mening. ${long}`);
  assertEquals([t.items.length, t.skipped[0].reason.startsWith("Svaret är för långt")], [0, true]);
  assertEquals(importText(`Fråga: Vad?\nSvar: Kort mening. ${"Ord ".repeat(800).trim()}.`).warnings.some((w) => w.reason.includes("tecken")), true);
});
