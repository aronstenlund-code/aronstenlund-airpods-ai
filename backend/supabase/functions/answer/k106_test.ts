// K106 (D232): Oscar's O88 N2-N4 in /answer.
import { assert, assertEquals, assertStringIncludes } from "jsr:@std/assert@1.0.8";
import { AnswerPost, dependsLead, halfFix, NumberStream } from "./speech.ts";
import { TEXT_PROMPT } from "./web.ts";

Deno.test("K106 N2: a web answer never opens with what it depends on; 'beror på att' (because) stays", () => {
  assertEquals(dependsLead("Det beror mest på hur mycket vi minskar utsläppen. "), "");
  assertEquals(
    dependsLead("Det beror på hur mycket utsläppen minskar, men enligt IPCC blir det två komma fem grader varmare. "),
    "Enligt IPCC blir det två komma fem grader varmare. ",
  );
  assertEquals(dependsLead("Det beror på att luften är tunnare där uppe. "), "Det beror på att luften är tunnare där uppe. ");
  const post = new AnswerPost({ previousAnswers: [], trimQuestion: false, web: true });
  const said = ["Det beror mest på hur mycket vi minskar utsläppen. ", "Med dagens politik väntas ", "jorden bli 2,7 grader varmare."]
    .map((c) => post.push(c)).join("") + post.finish();
  assert(!/beror/.test(said), said);
  assertStringIncludes(said, "Med dagens politik väntas jorden bli två komma sju grader varmare.");
});

Deno.test("K106 N3: a quote by a person always names the person", () => {
  assertStringIncludes(TEXT_PROMPT, "Always say the person's name in the first sentence");
});

Deno.test("K106 N4: 'en och en halv tesked', also when the 1 and 'och en halv' come in different chunks", () => {
  assertEquals(halfFix("Ta 1 och en halv tesked salt."), "Ta en och en halv tesked salt.");
  assertEquals(halfFix("ett och en halv deciliter"), "en och en halv deciliter");
  assertEquals(halfFix("ett och ett halvt år"), "ett och ett halvt år");
  const ns = new NumberStream();
  const said = ["Blanda ", "1 ", "och ", "en ", "halv ", "tesked ", "salt."].map((c) => ns.push(c)).join("") + ns.finish();
  assertEquals(said, "Blanda en och en halv tesked salt.");
  const ns2 = new NumberStream();
  assertEquals(["Det tar 1 ", "och ", "sedan 2 ", "timmar."].map((c) => ns2.push(c)).join("") + ns2.finish(), "Det tar ett och sedan två timmar.");
});
