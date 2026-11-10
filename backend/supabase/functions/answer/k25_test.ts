// K25: Oscar's O32 (calculator), O26 (numbers aloud) and O24 (kings' numbers only about kings), offline.
import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { computeFragment } from "./calc.ts";
import { toSpeech } from "./speech.ts";
import { afterNumbers, beforeNumbers } from "./speechsym.ts";

const NOW = new Date("2026-11-10T10:00:00Z");

Deno.test("K25 O32: parentheses are never computed without grouping (the model answers)", () => {
  assertEquals(computeFragment("vad är (12 + 8) * 2", NOW), null);
  assertEquals(computeFragment("vad är 12 + 8 * 2", NOW)?.value, 28);
  assertEquals(computeFragment("vad är 15 procent av 240", NOW)?.value, 36);
  assertEquals(computeFragment("vad är 9 minus 12", NOW)?.value, -3);
});

// [model text, one accepted spoken form (|), forbidden (|) or ""]: Oscar's O26 cases that failed before K25
const O26: [string, string, string][] = [
  ["Han kom 2:a i loppet.", "kom tvåa|kom på andra", ""],
  ["7/12 är mer än hälften.", "sju tolftedelar", ""],
  ["Nationaldagen firas 6/6.", "sjätte juni", "sjättedelar"],
  ["Valborg firas 30/4.", "trettionde april", "fjärdedelar"],
  ["Biljetten kostar 12,50 kr.", "tolv kronor och femtio öre", ""],
  ["Lektionen börjar kl. 14.30.", "klockan fjorton och trettio", ""],
  ["Midsommar är den 20 juni i år.", "tjugonde juni", ""],
  ["Sverige vann med 3–1.", "tre mot ett", ""],
  ["Hon har 1 bok och 1 äpple.", "en bok och ett äpple", "ett bok"],
  ["Spår nr 7 avgår snart.", "nummer sju", ""],
  ["Erik fick 14 poäng och Johan 12 poäng.", "fjorton poäng", "den fjortonde|den tolfte"],
  // unchanged
  ["3/4 av eleverna klarade det.", "tre fjärdedelar", ""],
  ["Ungefär 1/3 av klassen var sjuk.", "en tredjedel", ""],
  ["Första världskriget pågick 1914–1918.", "nittonhundrafjorton till nittonhundraarton", ""],
  ["Han har 1 äpple.", "ett äpple", "en äpple"],
  ["Hon fick 10/10 på provet.", "tio", "oktober"],
  ["Det kostar 1,50 kr.", "en krona och femtio öre", ""],
  ["Svaret är 1.", "svaret är ett", ""],
];

Deno.test("K25 O26: dates, kronor, klockan, scores, gender and 'nr' are read as a person says them", () => {
  for (const [t, acc, bad] of O26) {
    const out = toSpeech(t).toLowerCase();
    assert(!/\d/.test(out), `${t} -> ${out}`);
    assert(acc.split("|").some((a) => out.includes(a)), `${t} -> ${out}`);
    assert(!bad || !bad.split("|").some((b) => out.includes(b)), `${t} -> ${out}`);
  }
});

Deno.test("K25 O24: a name and a digit is a king only when the text is about rulers", () => {
  const say = (s: string) => afterNumbers(beforeNumbers(s));
  for (const [s, must] of [["Erik 14 var kung av Sverige", "Erik den fjortonde"], ["Karl den 12 dog 1718", "Karl den tolfte"],
    ["Ludvig 14 kallades solkungen", "Ludvig den fjortonde"]]) assert(say(s).includes(must), say(s));
  for (const s of ["Erik 14 poäng, Johan 12 poäng", "Peter 5 äpplen och Filip 3 äpplen", "Alexander 2 mål i matchen",
    "Oscar 7 och Leo 9 i provet", "Henrik 3 rätt av 10", "Johan 3 kom tvåa", "Magnus 4 timmar", "Leo 10 cm lång",
    "Filip 8, Ludvig 6"]) assert(!/\bden\b/.test(beforeNumbers(s)), `${s} -> ${beforeNumbers(s)}`);
});
