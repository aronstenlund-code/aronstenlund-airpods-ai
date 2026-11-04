import { assertEquals } from "jsr:@std/assert@1.0.8";
import { parseReference, wer } from "./wer.ts";
Deno.test("wer: substitutions, insertions, parse of the reference table", async () => {
  assertEquals(wer(["a", "b", "c"], ["a", "x", "c"]).errors, 1);
  assertEquals(wer(["a", "b"], ["a", "b", "c"]).errors, 1);
  const ref = parseReference(
    await Deno.readTextFile(new URL("../../testdata/scripts/sv-short-prompts.md", import.meta.url)),
  );
  assertEquals(ref.size, 30);
  assertEquals(ref.get(1), "roten ur hundra");
});
