// O105-4 (Oscar): the voice picker's reason was always Swedish ("a Swedish text", "one short Swedish sentence"),
// also for an English app and text. With lang en it is asked in English; without, Swedish as before.
import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { haikuVoicePicker, SYSTEM_PROMPT_VOICE_PICK } from "./style.ts";

Deno.test("O105-4: the voice picker is asked for its reason in the app's language", async () => {
  const seen: string[] = [];
  const provider = { name: "f", model: "f", stream: (r: { user: string }) => (seen.push(r.user), (async function* () { yield { type: "text" as const, text: '{"voice_id":"v1","reason":"A warm, friendly voice."}' }; })()) };
  const pick = haikuVoicePicker(provider as never);
  const voices = [{ voice_id: "v1", name: "Alyssa", description: "friendly", accent: "american", gender: "female", age: "young" }];
  const r = await pick("friendly", voices, "en");
  assertEquals(r, { voice_id: "v1", reason: "A warm, friendly voice." });
  assert(seen[0].includes("<language>en</language>"), seen[0]);
  await pick("lugnt", voices);
  assert(!seen[1].includes("<language>"), "Swedish as before");
  assert(/language of <language>/.test(SYSTEM_PROMPT_VOICE_PICK) && !/a Swedish text/.test(SYSTEM_PROMPT_VOICE_PICK), SYSTEM_PROMPT_VOICE_PICK.slice(0, 200));
});
