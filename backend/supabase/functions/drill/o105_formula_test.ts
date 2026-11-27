// O105-3 (Oscar): "H2O är vatten och CO2 koldioxid" became "vatten är vatten och koldioxid koldioxid": when the
// sentence names the substance itself, the formula is read as written ("H två O"); alone it is still the name.
import { assert, assertStringIncludes } from "jsr:@std/assert@1.0.8";
import { voiceText } from "./handler.ts";
import { VOICE_RULES_VERSION } from "./voicerules.ts";

Deno.test("O105-3: a formula next to its own name is read as written; on its own it is still the name", () => {
  const t = voiceText("H2O är vatten och CO2 koldioxid.", "", VOICE_RULES_VERSION);
  assertStringIncludes(t, "H två O");
  assertStringIncludes(t, "C O två");
  assert(!/vatten är vatten|koldioxid koldioxid/i.test(t), t);
  assertStringIncludes(voiceText("Växten tar upp CO2 ur luften.", "", VOICE_RULES_VERSION), "koldioxid");
  assertStringIncludes(voiceText("Glukos har formeln C6H12O6 och är ett socker.", "", VOICE_RULES_VERSION), "C sex H tolv O sex");
  const en = voiceText("H2O is water and CO2 is carbon dioxide.", "English", VOICE_RULES_VERSION);
  assertStringIncludes(en, "H two O");
  assert(!/water is water/i.test(en), en);
});

Deno.test("O105-3: drills made with an earlier rules version keep their text (their audio hashes stay the same)", () => {
  assertStringIncludes(voiceText("H2O är vatten.", "", 4), "Vatten är vatten");
});
