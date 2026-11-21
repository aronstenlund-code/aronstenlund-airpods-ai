// Toby T56 (A156 del 2): the web's listening mode is tested live only to the answer when the fake transcript is a
// question. `x-earmind-test: … question` gives one (sv, or en with x-earmind-lang: en); the default stays the same, so
// the app's tests that read today's sentence do not change. Never ElevenLabs (D180).
import { assertEquals } from "jsr:@std/assert@1.0.8";
import { FAKE_TRANSCRIPT, fakeTranscript, testMode, testTag } from "./testmode.ts";

const req = (h: Record<string, string>) => new Request("http://x/stt-token", { headers: h });

Deno.test("T56: the default fake transcript is unchanged", () => {
  assertEquals(fakeTranscript(req({ "x-earmind-test": "oscar-qa" })), FAKE_TRANSCRIPT);
  assertEquals(fakeTranscript(req({})), FAKE_TRANSCRIPT);
});

Deno.test("T56: 'question' in the test header gives a question, in the chosen language", () => {
  assertEquals(fakeTranscript(req({ "x-earmind-test": "toby question" })), "Vad gör fotosyntesen?");
  assertEquals(fakeTranscript(req({ "x-earmind-test": "question", "x-earmind-lang": "en" })), "What does photosynthesis do?");
  // the word is a variant, never the tag or a mode
  assertEquals(testTag("question toby"), "toby");
  assertEquals(testMode("toby question"), null);
});
