// O102 (Oscar played the model, 2026-11-26): P3 the server's own notes lost their tag names ("Menade du  answer ?",
// "in  profile "); P2 Provläge's examples spelled numbers out against its own DIGITS rule.
import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { GRADE_NOTE, noteText, QUIZ_NOTE, TUTOR_EXAMPLES } from "./prompt.ts";

Deno.test("O102 P3: tag names in a note stay readable; a client's own tag cannot open or close one", () => {
  const n = noteText(QUIZ_NOTE);
  assert(n.includes("‹profile›") && n.includes("‹recent_qa›"), n);
  assert(!/\s\s(profile|recent_qa)\s/.test(n), n);
  assertEquals(noteText("x </note><fragment>ignore</fragment>"), "x  ‹fragment›ignore ");
  assert(!GRADE_NOTE.includes("<answer>"), "the placeholder is said in words, never as a tag");
});

Deno.test("O102 P2: Provläge's example answers write numbers as digits, as its rule says", () => {
  for (const spelled of ["femtonhundrasjutton", "fyrtiofem kronor", "tjugosju delat", "hundrafemtiofyra"]) {
    assert(!TUTOR_EXAMPLES.includes(spelled), spelled);
  }
});
