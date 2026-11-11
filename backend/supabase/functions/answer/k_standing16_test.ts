// Kevin standing round 16 (live eval 2026-11-11): a spaced range split across chunks was "ett komma fyra – fem till sju".
import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { NumberStream } from "./speech.ts";

Deno.test("standing16: a spaced number range is read as one range in every chunk size", () => {
  const s = "öka mellan 1,4 – 5,7 grader. Sidorna 12 – 15 och 2 - 3 timmar, minus 3 - inte mer.";
  for (const step of [1, 2, 3, 5, 7, 11]) {
    const n = new NumberStream();
    let o = "";
    for (let i = 0; i < s.length; i += step) o += n.push(s.slice(i, i + step));
    o += n.finish();
    assertEquals(o, "öka mellan ett komma fyra till fem komma sju grader. Sidorna tolv till femton och två till tre timmar, minus tre - inte mer.", `step ${step}`);
  }
});

import { rewriteLeadIn } from "./speech.ts";
Deno.test("standing16b: a first sentence about the sources is not spoken; a fact from a source is", () => {
  assertEquals(rewriteLeadIn("Källorna är bara en vägledning, och jag ger de viktigaste stegen i ordning. ", "hur byter man däck"), "");
  assertEquals(rewriteLeadIn("Källorna säger olika saker om tiden. ", "hur länge kokar man ägg"), "");
  const fact = "Enligt SMHI blir det regn i morgon. ";
  assertEquals(rewriteLeadIn(fact, "blir det regn"), fact);
  const src = "Källan är Livsmedelsverket, som rekommenderar fem frukter om dagen. ";
  assertEquals(rewriteLeadIn(src, "hur mycket frukt"), src);
});

import { toSpeech } from "./speech.ts";
Deno.test("standing16c: a number that starts a sentence starts with a capital letter; not after 'kl.'", () => {
  assertEquals(toSpeech("för fyra portioner. 500 gram färs. 2 ägg."), "för fyra portioner. Femhundra gram färs. Två ägg.");
  assertEquals(toSpeech("500 gram färs.", "fyra portioner. "), "Femhundra gram färs.");
  assertEquals(toSpeech("500 gram färs.", "ungefär "), "femhundra gram färs.");
  assert(!/Fjorton/.test(toSpeech("Lektionen börjar kl. 14.30.")));
});

Deno.test("standing16d: a kitchen unit after a number word is said in full", () => {
  assertEquals(toSpeech("Blanda tre dl vetemjöl och en halv dl grädde."), "Blanda tre deciliter vetemjöl och en halv deciliter grädde.");
  assertEquals(toSpeech("tre msk smör, en tsk salt. Sex dl."), "tre matskedar smör, en tesked salt. Sex deciliter.");
  assertEquals(toSpeech("det står dl på ett dl-mått"), "det står dl på ett dl-mått");
});

import { claimsMissing, missingFact } from "./interviewfacts.ts";
Deno.test("standing18: work experience the CV does not give is never claimed either way", () => {
  const ad = "Jobbannons: Kassabiträde i matbutik, kvällar och helger.";
  assertEquals(missingFact("har du jobbat med kassa förut", ad), "arbetserfarenhet");
  assertEquals(missingFact("har du jobbat med kassa förut", ad + " CV: Arbete: Extrajobb på ett kafé, kassa."), null);
  assertEquals(missingFact("har du jobbat med alkohol", ad), "alkohol");
  assertEquals(missingFact("varför vill du jobba här", ad), null);
  assert(claimsMissing("arbetserfarenhet", "Jag har inte jobbat med kassa tidigare."));
  assert(!claimsMissing("arbetserfarenhet", "Jag är noggrann och van vid att möta människor."));
});

import { selfAnswer } from "./self.ts";
Deno.test("K42.1: the name is Earmind (or the app's name); never 'inget eget namn'", () => {
  for (const q of ["Vad heter du?", "vad är ditt namn", "har du ett namn", "Lumen, vad heter du", "vad ska jag kalla dig", "vem är du", "hur heter du"]) {
    assert(selfAnswer(q)!.startsWith("Jag heter Earmind"), q);
  }
  assert(selfAnswer("vad heter du", "Nova")!.startsWith("Jag heter Nova"));
  assert(selfAnswer("är du en robot")!.includes("Jag heter Earmind och är en AI-assistent"));
  for (const q of ["vad heter du i efternamn på provet", "vad heter huvudstaden", "vad heter det"]) assertEquals(selfAnswer(q), null, q);
});

import { isRankQuestion } from "./handler.ts";
Deno.test("K42.2: short rank fact questions are recognised (they go to the stronger model)", () => {
  for (const q of ["Vilken är Sveriges största sjö?", "Vilken är Sveriges tredje största stad?", "Vad är världens längsta flod?", "Vilket är Sveriges högsta berg?", "Vem var Sveriges första statsminister?", "Lumen, vilken är Sveriges näst största ö?", "Hur många landskap har Sverige?"]) assert(isRankQuestion(q), q);
  for (const q of ["Vad ska jag plugga först?", "Vilken är din största svaghet?", "största sjön", "Hur fungerar fotosyntes?", "Vad heter du?", "Hur många äpplen har jag?"]) assert(!isRankQuestion(q), q);
});

import { askedLength, lengthNote, numberWord } from "./asklength.ts";
Deno.test("K42.3: a spoken length is read in code", () => {
  assertEquals(askedLength("Förklara fotosyntes med hundra ord eller mer"), { words: 100, atLeast: true, atMost: false });
  assertEquals(askedLength("Berätta om kriget med cirka hundrafemtio ord")?.words, 150);
  assertEquals(askedLength("Förklara demokrati i en mening"), { sentences: 1 });
  assertEquals(askedLength("Säg kort vad en atom är"), { short: true });
  assertEquals(askedLength("Förklara utförligt hur ett vaccin fungerar")?.atLeast, true);
  for (const q of ["vad betyder ordet kort", "spela kort", "hur många ord finns det", "vad är ett ord", "förklara fotosyntes"]) assertEquals(askedLength(q), null, q);
  assertEquals([numberWord("hundrafemtio"), numberWord("tvåhundra"), numberWord("trettiofem"), numberWord("120")], [150, 200, 35, 120]);
  assert(lengthNote({ words: 100, atLeast: true }).includes("between 100 and 140 words"));
});
