// K114 (D252): the account's own voices are listed (names and ids, GET /v1/voices costs no credits), service role only;
// no audio, no other ElevenLabs call.
import { assertEquals } from "jsr:@std/assert@1.0.8";
import { createVoiceLabHandler } from "./handler.ts";

Deno.test("K114 voice-lab account_voices: service role only; the list without audio; nothing else is called", async () => {
  let calls = 0;
  const h = createVoiceLabHandler({
    serviceKey: "svc", elevenLabsKey: "xi",
    fetchImpl: () => (calls++, Promise.resolve(new Response("{}"))),
    listVoices: () => Promise.resolve([{ voice_id: "abc123abc123abc123ab", name: "chinese americano", category: "cloned", language: "en", accent: null, gender: null, age: null }]),
  });
  const post = (key: string) => h(new Request("http://x/voice-lab", { method: "POST", headers: { authorization: `Bearer ${key}` }, body: JSON.stringify({ action: "account_voices" }) }));
  assertEquals((await post("wrong")).status, 401);
  const r = await post("svc");
  assertEquals(r.status, 200);
  assertEquals((await r.json()).voices[0].name, "chinese americano");
  assertEquals(calls, 0, "no ElevenLabs call that could cost credits");
});
