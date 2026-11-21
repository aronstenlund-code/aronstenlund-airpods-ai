// K114 (D252): Marlon (Aron's own cloned voice) is no longer offered. Nothing is deleted in ElevenLabs; the server
// stops listing and accepting the voice id wherever it comes from (secret, catalog, default).
import { assertEquals } from "jsr:@std/assert@1.0.8";
import { MemoryRateLimiter } from "../_shared/ratelimit.ts";
import { activeVoiceId, isRetired, parseVoices, RETIRED_VOICE_IDS } from "./voices.ts";
import { createTtsHandler, DEFAULT_TTS_CONFIG, type TtsDeps } from "./handler.ts";
import { createVoicesHandler } from "../voices/handler.ts";

const MARLON = "L5eqCY1Zc0lkxB6M9pRQ";
const ADAM = "x0u3EW21dbrORJzOq1m9";

Deno.test("K114: Marlon is retired", () => {
  assertEquals(RETIRED_VOICE_IDS.has(MARLON), true);
  assertEquals(isRetired(MARLON), true);
  assertEquals(isRetired(ADAM), false);
});

Deno.test("K114: parseVoices skips a retired voice in ELEVENLABS_VOICES (reported, id not echoed)", () => {
  const r = parseVoices(`Adam:${ADAM},Marlon:${MARLON}`);
  assertEquals(r.voices, [{ name: "Adam", id: ADAM }]);
  assertEquals(r.errors.length, 1);
  assertEquals(r.errors[0].includes(MARLON), false);
});

Deno.test("K114: a retired default (ELEVENLABS_VOICE_ID) counts as no default", () => {
  assertEquals(activeVoiceId(MARLON), null);
  assertEquals(activeVoiceId(` ${MARLON} `), null);
  assertEquals(activeVoiceId(ADAM), ADAM);
  assertEquals(activeVoiceId(null), null);
});

Deno.test("K114: tts refuses the retired voice even when it is the configured default", async () => {
  let called = 0;
  const deps: TtsDeps = {
    authenticate: () => Promise.resolve({ id: "u1", isAnonymous: true }),
    rateLimiter: new MemoryRateLimiter(),
    apiKey: "xi-test",
    config: { ...DEFAULT_TTS_CONFIG, voiceId: MARLON, voices: [{ name: "Marlon", id: MARLON }, { name: "Adam", id: ADAM }] },
    recordUsage: () => {},
    fetchImpl: () => (called++, Promise.resolve(new Response(new Uint8Array([1]), { status: 200, headers: { "content-type": "audio/mpeg" } }))),
  };
  const h = createTtsHandler(deps);
  const res = await h(new Request("http://x/tts", { method: "POST", body: JSON.stringify({ text: "a", voice_id: MARLON }) }));
  assertEquals(res.status, 400);
  assertEquals((await res.json()).error.code, "invalid_voice");
  assertEquals(called, 0);
});

Deno.test("K114: /voices lists no retired voice (secret list, catalog or default)", async () => {
  const h = createVoicesHandler({
    authenticate: () => Promise.resolve({ id: "u1", isAnonymous: true }),
    rateLimiter: new MemoryRateLimiter(),
    voices: [{ name: "Marlon", id: MARLON }, { name: "Adam", id: ADAM }],
    defaultVoiceId: MARLON,
    catalog: () => Promise.resolve([{ voice_id: MARLON, name: "Marlon", review: false }, { voice_id: ADAM, name: "Adam", review: false }]),
  });
  const j = await (await h(new Request("http://x/voices"))).json();
  const text = JSON.stringify(j);
  assertEquals(text.includes(MARLON), false);
  assertEquals(j.default_id, ADAM);
});
