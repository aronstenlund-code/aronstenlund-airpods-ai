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
