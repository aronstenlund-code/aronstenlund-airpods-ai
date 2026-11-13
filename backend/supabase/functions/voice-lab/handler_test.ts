import { assertEquals } from "jsr:@std/assert@1.0.8";
import { createVoiceLabHandler } from "./handler.ts";
import VOICES from "../../../../scripts/k6-voices.json" with { type: "json" };

const TEXT = "Hej och välkommen! Nu kör vi igång dagens pluggpass, och jag lovar att det här blir både roligt och lärorikt för dig.";
const post = (b: unknown, key = "svc") =>
  new Request("http://x/voice-lab", { method: "POST", headers: { authorization: `Bearer ${key}`, "content-type": "application/json" }, body: JSON.stringify(b) });

Deno.test("K6 voice-lab: service role only, previews passed on, a real person refused, nothing saved", async () => {
  const calls: string[] = [];
  const h = createVoiceLabHandler({
    serviceKey: "svc",
    elevenLabsKey: "xi",
    fetchImpl: (url) => {
      calls.push(String(url));
      return Promise.resolve(Response.json({ previews: [{ generated_voice_id: "g1", audio_base_64: "AAA", media_type: "audio/mpeg", duration_secs: 6.2 }], text: TEXT }));
    },
  });
  assertEquals((await h(post({ action: "previews", voice_description: "A cheerful middle-aged Swedish sports commentator", text: TEXT }, "anon"))).status, 401);
  const r = await h(post({ action: "previews", voice_description: "A cheerful middle-aged Swedish sports commentator, fast and dramatic", text: TEXT }));
  assertEquals(r.status, 200);
  assertEquals((await r.json()).previews[0].generated_voice_id, "g1");
  assertEquals(calls.length, 1);
  assertEquals(calls[0].includes("/v1/text-to-voice/design"), true);
  assertEquals((await h(post({ action: "previews", voice_description: "A voice that sounds like Donald Trump giving a speech", text: TEXT }))).status, 400);
  assertEquals((await h(post({ action: "previews", voice_description: "short", text: TEXT }))).status, 400);
  assertEquals(calls.length, 1, "refused requests never reach ElevenLabs");
});

Deno.test("K6 the five planned characters are all allowed", async () => {
  const chars = VOICES.characters;
  const h = createVoiceLabHandler({ serviceKey: "svc", elevenLabsKey: "xi", fetchImpl: () => Promise.resolve(Response.json({ previews: [] })) });
  for (const c of chars) assertEquals((await h(post({ action: "previews", voice_description: c.description, text: c.text }))).status, 200, c.id);
});

Deno.test("K48 voice-lab sample: service role only, the default voice, the model asked for, same format, refused models never sent", async () => {
  const calls: { url: string; body: Record<string, unknown> }[] = [];
  const h = createVoiceLabHandler({
    serviceKey: "svc",
    elevenLabsKey: "xi",
    voiceId: "VoiceDefault12345",
    fetchImpl: (url, init) => {
      calls.push({ url: String(url), body: JSON.parse(String(init?.body)) });
      return Promise.resolve(new Response(new Uint8Array([1, 2, 3]), { headers: { "content-type": "audio/mpeg", "character-cost": "40" } }));
    },
  });
  const text = "Fotosyntesen sker i kloroplasterna.";
  assertEquals((await h(post({ action: "sample", text, model: "eleven_v3" }, "anon"))).status, 401);
  for (const model of ["eleven_multilingual_v2", "eleven_v3", "eleven_flash_v2_5"]) {
    const r = await h(post({ action: "sample", text, model }));
    assertEquals(r.status, 200, model);
    const j = await r.json();
    assertEquals([j.model, j.audio_base_64, j.chars, j.character_cost], [model, "AQID", text.length, 40]);
  }
  assertEquals(calls.map((c) => c.body.model_id), ["eleven_multilingual_v2", "eleven_v3", "eleven_flash_v2_5"]);
  assertEquals(calls.every((c) => c.url.includes("/v1/text-to-speech/VoiceDefault12345?output_format=mp3_44100_128")), true);
  assertEquals(calls.every((c) => c.body.text === text), true);
  assertEquals((await h(post({ action: "sample", text, model: "eleven_v4_turbo" }))).status, 400);
  assertEquals((await h(post({ action: "sample", text: "x".repeat(1201), model: "eleven_v3" }))).status, 400);
  assertEquals(calls.length, 3, "refused requests never reach ElevenLabs");
});
