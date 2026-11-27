// K115 (D253): Aron heard "1999" read as "nittonhundranittionien" (web beta, Swedish path). The text before the voice
// was right ("nittonhundranittionio"); every x9 from 39 to 99 ends in "-tionio", which looks like a "-tion" word
// (station, nation) – the voice's reading is an UNTESTED ASSUMPTION (D180: nobody listens). The tens and the nine are
// written apart from voice rules version 4 (older drills keep their text and hashes). English text keeps its digits
// for the voice (it says "nineteen ninety-nine" itself); Swedish number words never go into English.
import { assertEquals } from "jsr:@std/assert@1.0.8";
import { voiceText } from "./handler.ts";
import { splitNine, VOICE_RULES_VERSION } from "./voicerules.ts";
import { AnswerPost, NumberStream } from "../answer/speech.ts";

Deno.test("K115: x9 words are written apart (-tionio never reaches the voice); other numbers unchanged", () => {
  assertEquals(splitNine("Nittonhundranittionio"), "Nittonhundranittio nio");
  assertEquals(splitNine("trettionio, fyrtionio, femtionio, sextionio, sjuttionio, åttionio, nittionio"), "trettio nio, fyrtio nio, femtio nio, sextio nio, sjuttio nio, åttio nio, nittio nio");
  assertEquals(splitNine("tjugonio nittio nio station nationen"), "tjugonio nittio nio station nationen");
});

Deno.test("K115: voice rules 4 for new drills; a drill made with 3 keeps its text (and hashes)", () => {
  assertEquals(VOICE_RULES_VERSION, 5); // O105-3 (version 5: formulas next to their names); version 4 below as before
  assertEquals(voiceText("Det hände 1999.", "", 4), "Det hände nittonhundranittio nio.");
  assertEquals(voiceText("Det hände 1999.", "", 3), "Det hände nittonhundranittionio.");
  assertEquals(voiceText("Mellan 1939 och 1945.", "", 4), "Mellan nittonhundratrettio nio och nittonhundrafyrtiofem.");
  assertEquals(voiceText("In 1999 the euro came.", "English", 4), "In 1999 the euro came.");
});

const stream = (t: string, language?: string) => {
  const p = new AnswerPost({ previousAnswers: [], trimQuestion: false, heard: "q", ...(language ? { language } : {}) });
  let out = "";
  for (const ch of t.match(/.{1,7}/gs)!) out += p.push(ch);
  return out + p.finish();
};

Deno.test("K115: a spoken English answer keeps its numbers for the voice (no Swedish number words)", () => {
  const en = stream("The euro came in 1999. About 1,500 people were there. It costs 29 dollars.", "en");
  assertEquals(/ett komma|tjugonio|nittonhundra/.test(en), false, en);
  assertEquals(en.includes("1,500") && en.includes("29 dollars"), true, en);
});

Deno.test("K115: a spoken Swedish answer says numbers in Swedish with the nine apart", () => {
  const sv = stream("Euron kom 1999. Det kostar 99 kronor och 1 500 kom.", "sv");
  assertEquals(sv, "Euron kom nittonhundranittio nio. Det kostar nittio nio kronor och femtonhundra kom.");
  const ns = new NumberStream("sv");
  assertEquals(ns.push("År 1989 ") + ns.finish(), "År nittonhundraåttio nio ");
});
