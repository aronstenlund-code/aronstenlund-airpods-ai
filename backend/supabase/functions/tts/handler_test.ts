import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { MemoryRateLimiter } from "../_shared/ratelimit.ts";
import {
  classifyElevenLabs,
  createTtsHandler,
  DEFAULT_TTS_CONFIG,
  type TtsDeps,
} from "./handler.ts";

const VOICE = "abcdefghij1234567890";
function setup(over: Partial<TtsDeps> = {}, fetchImpl?: typeof fetch) {
  const calls: { url: string; init: RequestInit }[] = [];
  const recs: Record<string, unknown>[] = [];
  const deps: TtsDeps = {
    authenticate: () => Promise.resolve({ id: "u1", isAnonymous: true }),
    rateLimiter: new MemoryRateLimiter(),
    apiKey: "xi-test",
    config: { ...DEFAULT_TTS_CONFIG, voiceId: VOICE },
    recordUsage: (r) => void recs.push(r),
    fetchImpl: fetchImpl ?? ((url, init) => {
      calls.push({ url: String(url), init: init! });
      return Promise.resolve(
        new Response(new Uint8Array([1, 2, 3]), {
          status: 200,
          headers: { "content-type": "audio/mpeg" },
        }),
      );
    }),
    ...over,
  };
  return { handler: createTtsHandler(deps), calls, recs };
}
const post = (b: unknown) =>
  new Request("http://x/tts", { method: "POST", body: JSON.stringify(b) });

Deno.test("streams audio and sends key only upstream", async () => {
  const { handler, calls, recs } = setup();
  const res = await handler(post({ text: "Sju.", language: "sv" }));
  assertEquals(res.status, 200);
  assertEquals(res.headers.get("content-type"), "audio/mpeg");
  assertEquals([...new Uint8Array(await res.arrayBuffer())], [1, 2, 3]);
  assert(calls[0].url.includes(`/text-to-speech/${VOICE}/stream`));
  assertEquals((calls[0].init.headers as Record<string, string>)["xi-api-key"], "xi-test");
  assertEquals(JSON.parse(calls[0].init.body as string).model_id, "eleven_flash_v2_5");
  assertEquals(recs[0].chars, 4);
});

Deno.test("validation: empty, too long, bad format, bad voice", async () => {
  const { handler } = setup();
  assertEquals((await handler(post({ text: " " }))).status, 400);
  assertEquals((await handler(post({ text: "a".repeat(501) }))).status, 413);
  assertEquals((await handler(post({ text: "a", output_format: "mp3_44100_192" }))).status, 400);
  assertEquals((await handler(post({ text: "a", voice_id: "../../evil" }))).status, 503);
});

Deno.test("unconfigured key/voice fails closed with fallback", async () => {
  for (const o of [{ apiKey: null }, { config: { ...DEFAULT_TTS_CONFIG, voiceId: null } }]) {
    const { handler } = setup(o);
    const res = await handler(post({ text: "a" }));
    assertEquals(res.status, 503);
    assertEquals((await res.json()).error.fallback, true);
  }
});

Deno.test("character budget stops requests before they reach ElevenLabs", async () => {
  const { handler, calls } = setup({
    config: {
      ...DEFAULT_TTS_CONFIG,
      voiceId: VOICE,
      limits: { perMinute: 10, perDay: 100, globalPerDay: 100 },
    },
  });
  assertEquals((await handler(post({ text: "123456" }))).status, 200);
  const res = await handler(post({ text: "123456" }));
  assertEquals(res.status, 429);
  assertEquals(calls.length, 1);
});

Deno.test("ElevenLabs quota / auth / rate errors map to fallback errors", async () => {
  assertEquals(
    classifyElevenLabs(401, '{"detail":{"status":"quota_exceeded"}}').code,
    "provider_quota",
  );
  assertEquals(
    classifyElevenLabs(401, '{"detail":{"status":"invalid_api_key"}}').code,
    "provider_misconfigured",
  );
  assertEquals(classifyElevenLabs(429, "").code, "provider_busy");
  assertEquals(classifyElevenLabs(500, "").code, "provider_unavailable");
  const { handler } = setup(
    {},
    () => Promise.resolve(new Response('{"detail":{"status":"quota_exceeded"}}', { status: 401 })),
  );
  const res = await handler(post({ text: "a" }));
  assertEquals(res.status, 503);
  assertEquals((await res.json()).error.code, "provider_quota");
});
