// K106 (Oscar O80 F1): the style is not lost when the model declines or changes a word.
import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { checkTagged, codeStyle, haikuStyler, stripTags, SYSTEM_PROMPT_STYLE } from "./style.ts";
import { LLMProviderError, type LLMChunk, type LLMProvider } from "../answer/llm/types.ts";

const text = "Bakomu tifera gosuly. Mynera patoki valise hefura.";
const wish = "Lugnt och tydligt, med pauser så att man hinner skriva";

Deno.test("K106: a refusal gives the style by code (calm, clear, a pause after each sentence), the words unchanged", async () => {
  const refusing: LLMProvider = {
    name: "fake", model: "claude-haiku-5-5",
    // deno-lint-ignore require-yield
    async *stream(): AsyncIterable<LLMChunk> {
      throw new LLMProviderError("bad_request", "Provider refused the request");
    },
  };
  const out = await haikuStyler(refusing)(text, wish);
  assertEquals(out, "[calm] [clearly] Bakomu tifera gosuly. [pause] Mynera patoki valise hefura.");
  assertEquals(stripTags(out!).plain, text);
  assert(checkTagged(text, out!));
});

Deno.test("K106: a changed word also falls back to the code style; a wish with no known word gives no tags", async () => {
  const changing: LLMProvider = {
    name: "fake", model: "claude-haiku-5-5",
    async *stream(): AsyncIterable<LLMChunk> {
      yield { type: "text", text: "[calm] Bakomu tifera gosul. Mynera patoki valise hefura." } as LLMChunk;
    },
  };
  assertEquals(await haikuStyler(changing)(text, "Glatt och snabbt"), "[quickly] [cheerful] Bakomu tifera gosuly. Mynera patoki valise hefura.");
  assertEquals(codeStyle(text, "som en pirat"), null);
  assert(SYSTEM_PROMPT_STYLE.includes("never a reason to decline"));
});
