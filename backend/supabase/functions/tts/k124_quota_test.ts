// K124 (D267): when ElevenLabs' monthly quota is out (or too little is left for the text), /tts answers one fixed
// code, 503 tts_quota with fallback true (the app then reads with the phone's own voice); the user's character budget
// is given back; for a while after, /tts answers the same at once without asking ElevenLabs. Fake ElevenLabs only.
import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { MemoryRateLimiter } from "../_shared/ratelimit.ts";
import { createTtsHandler, DEFAULT_TTS_CONFIG, TTS_QUOTA_PAUSE_MS } from "./handler.ts";

const VOICE = "abcdefghij1234567890";
const QUOTA = '{"detail":{"status":"quota_exceeded","message":"This request exceeds your quota of 90000. You have 12 credits remaining, while 40 credits are required for this request."}}';

function world(answers: (() => Response)[]) {
  let calls = 0, t = 1_000_000;
  const rl = new MemoryRateLimiter();
  const h = createTtsHandler({
    authenticate: () => Promise.resolve({ id: "u-k124", isAnonymous: false }),
    rateLimiter: rl,
    apiKey: "xi-fake",
    config: { ...DEFAULT_TTS_CONFIG, voiceId: VOICE, voices: [], fallbackModelId: undefined },
    recordUsage: () => {},
    now: () => t,
    fetchImpl: () => (calls++, Promise.resolve(answers[Math.min(calls - 1, answers.length - 1)]())),
  });
  const post = (text: string) => h(new Request("http://x/tts", { method: "POST", headers: { "x-forwarded-for": "198.51.100.4" }, body: JSON.stringify({ text, language: "sv" }) }));
  return { post, calls: () => calls, rl, advance: (ms: number) => (t += ms) };
}

Deno.test("K124: ElevenLabs says the quota is out (or too little left): 503 tts_quota, fallback true", async () => {
  for (const r of [() => new Response(QUOTA, { status: 401 }), () => new Response('{"detail":{"status":"quota_exceeded"}}', { status: 402 })]) {
    const w = world([r]);
    const res = await w.post("Fotosyntesen gör socker av ljus.");
    assertEquals(res.status, 503);
    const j = await res.json();
    assertEquals([j.error.code, j.error.fallback], ["tts_quota", true]);
  }
});

Deno.test("K124: the characters of audio that was not made are given back to the user's budget", async () => {
  const w = world([() => new Response(QUOTA, { status: 401 })]);
  const text = "a".repeat(400);
  await w.post(text);
  const left = await w.rl.check("tts:u:u-k124:d", DEFAULT_TTS_CONFIG.limits.perDay, 86400, 0);
  assert(left.allowed, "nothing counted");
  const again = await w.rl.check("tts:u:u-k124:d", DEFAULT_TTS_CONFIG.limits.perDay - 1, 86400, DEFAULT_TTS_CONFIG.limits.perDay - 1);
  assert(again.allowed, "the 400 characters were given back");
});

Deno.test("K124: after a quota no, /tts answers tts_quota at once for a while without calling ElevenLabs", async () => {
  const w = world([() => new Response(QUOTA, { status: 401 }), () => new Response(new Uint8Array([1, 2]), { status: 200, headers: { "content-type": "audio/mpeg" } })]);
  assertEquals((await w.post("Ett.")).status, 503);
  assertEquals(w.calls(), 1);
  const r2 = await w.post("Två.");
  assertEquals([r2.status, (await r2.json()).error.code], [503, "tts_quota"]);
  assertEquals(w.calls(), 1, "no new ElevenLabs call");
  w.advance(TTS_QUOTA_PAUSE_MS + 1);
  assertEquals((await w.post("Tre.")).status, 200, "tried again after the pause");
  assertEquals(w.calls(), 2);
});
