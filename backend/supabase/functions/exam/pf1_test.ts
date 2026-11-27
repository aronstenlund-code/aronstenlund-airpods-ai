// Oscar PF1 (O104/E1): the photo exam "Cellens delar" lost everything about the cell nucleus. The model wrote two
// questions about it (two of four lines in the picture) and both were plain recall, so the trim took both. The trim
// now covers the material's sentences: a second question on the same sentence goes first, and the last question on
// a sentence the model asked about twice or more is kept.
import { assertEquals } from "jsr:@std/assert@1.0.8";
import { trimQuestions } from "./drill.ts";

const notes = "Cellens delar (Biologi, åk 8). Cellkärnan styr cellen och innehåller DNA. Mitokondrien gör energi åt cellen (ATP). Cellmembranet släpper in och ut ämnen. Växtceller har också cellvägg och kloroplaster.";
const qs = ["Vilken uppgift har cellkärnan?", "Hur får cellen energi?", "Hur fungerar cellmembranet?", "Hur skiljer sig växtceller från andra celler?", "Vad innehåller cellkärnan?"];

Deno.test("PF1: with the material, one question about the cell nucleus stays", () => {
  const out = trimQuestions(qs, 3, notes);
  assertEquals(out.filter((q) => /cellkärnan/.test(q)).length, 1, out.join(" | "));
  assertEquals(out.length, 3);
  assertEquals(out.filter((q) => !/cellkärnan/.test(q)), ["Hur får cellen energi?", "Hur fungerar cellmembranet?"]);
});

Deno.test("PF1: four topics into four questions keeps one per topic; without material nothing changes", () => {
  const four = trimQuestions(qs, 4, notes);
  assertEquals([four.length, four.filter((q) => /cellkärnan/.test(q)).length], [4, 1], four.join(" | "));
  assertEquals(trimQuestions(qs, 3), ["Hur får cellen energi?", "Hur fungerar cellmembranet?", "Hur skiljer sig växtceller från andra celler?"]);
});

Deno.test("PF1: a comparison that spans sentences never gives way for a sentence's last question (O107 D1)", () => {
  const notes = "Anteckningar: Nordens länder. Sverige: huvudstad Stockholm, språk svenska. Finland: huvudstad Helsingfors, språk finska och svenska. Island: huvudstad Reykjavik, språk isländska.";
  const qs = ["Vilken stad är Sveriges huvudstad?", "Vilket språk talar man i Sverige?", "Vad heter Finlands huvudstad?", "Vilka språk talar man i Finland?", "Hur skiljer sig Finland från Sverige och Island när det gäller språk?", "Vilket land har Reykjavik som huvudstad?", "Vilket språk talar man på Island?"];
  const out = trimQuestions(qs, 3, notes);
  assertEquals(out.includes("Hur skiljer sig Finland från Sverige och Island när det gäller språk?"), true, out.join(" | "));
});
