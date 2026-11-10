import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { MemoryRateLimiter } from "../_shared/ratelimit.ts";
import {
  _resetZeroRetention,
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
    config: { ...DEFAULT_TTS_CONFIG, voiceId: VOICE, voices: [] },
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
  assertEquals(JSON.parse(calls[0].init.body as string).model_id, "eleven_v4_turbo"); // K14 default
  assertEquals(recs[0].chars, 4);
});

Deno.test("validation: empty, too long, bad format, bad voice", async () => {
  const { handler } = setup();
  assertEquals((await handler(post({ text: " " }))).status, 400);
  assertEquals((await handler(post({ text: "a".repeat(501) }))).status, 413);
  assertEquals((await handler(post({ text: "a", output_format: "mp3_44100_192" }))).status, 400);
  assertEquals((await handler(post({ text: "a", voice_id: "../../evil" }))).status, 400);
});

Deno.test("unconfigured key/voice fails closed with fallback", async () => {
  for (
    const o of [{ apiKey: null }, { config: { ...DEFAULT_TTS_CONFIG, voiceId: null, voices: [] } }]
  ) {
    const { handler } = setup(o);
    const res = await handler(post({ text: "a" }));
    assertEquals(res.status, 503);
    assertEquals((await res.json()).error.fallback, true);
  }
});

Deno.test("character budget: the local guard stops a user before ElevenLabs is called", async () => {
  const { handler, calls } = setup({
    localLimiter: new MemoryRateLimiter(),
    config: {
      ...DEFAULT_TTS_CONFIG,
      voiceId: VOICE,
      voices: [],
      limits: { perMinute: 10, perDay: 100, globalPerDay: 100 },
    },
  });
  assertEquals((await handler(post({ text: "123456" }))).status, 200);
  const res = await handler(post({ text: "123456" }));
  assertEquals(res.status, 429);
  assertEquals(calls.length, 1);
});

Deno.test("character budget: shared limiter runs in parallel with ElevenLabs; denial aborts and returns no audio", async () => {
  let signal: AbortSignal | undefined;
  const fetchImpl = ((_u: unknown, init: RequestInit) => {
    signal = init.signal as AbortSignal;
    return Promise.resolve(new Response(new Uint8Array([9, 9]), { status: 200 }));
  }) as typeof fetch;
  const denying = { check: () => Promise.resolve({ allowed: false, retryAfterSec: 11 }) };
  const { handler } = setup({ rateLimiter: denying }, fetchImpl);
  const res = await handler(post({ text: "abc" }));
  assertEquals(res.status, 429);
  assertEquals(res.headers.get("retry-after"), "11");
  assertEquals(signal?.aborted, true);
  assertEquals((await res.json()).error.code, "rate_limited");
});

Deno.test("limiter and ElevenLabs overlap (total ~ max, not sum)", async () => {
  const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));
  const ok = async () => {
    await sleep(60);
    return { allowed: true, retryAfterSec: 0 };
  };
  const fetchImpl = (async () => {
    await sleep(60);
    return new Response(new Uint8Array([1]), { status: 200 });
  }) as typeof fetch;
  const { handler } = setup({ rateLimiter: { check: ok, checkMany: ok } }, fetchImpl);
  const t = performance.now();
  const res = await handler(post({ text: "abc" }));
  const dt = performance.now() - t;
  assertEquals(res.status, 200);
  assert(dt < 105, `expected overlap (<105 ms), got ${dt.toFixed(0)} ms`);
});

Deno.test("GET x-warm:1 -> 204 and triggers warm-up without auth", async () => {
  let warmed = 0;
  const { handler } = setup({
    warm: () => {
      warmed++;
    },
    authenticate: () => Promise.reject(new Error("must not authenticate")),
  });
  const res = await handler(new Request("http://x", { method: "GET", headers: { "x-warm": "1" } }));
  assertEquals([res.status, warmed], [204, 1]);
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

const V1 = "Astrid00000000000001", V2 = "Elin0000000000000002", V3 = "Oskar000000000000003";
const voices = [{ name: "Astrid", id: V1 }, { name: "Elin", id: V2 }, { name: "Oskar", id: V3 }];

Deno.test("allowlist: listed voices work, anything else is 400 invalid_voice (never reaches ElevenLabs)", async () => {
  const { handler, calls } = setup({ config: { ...DEFAULT_TTS_CONFIG, voiceId: null, voices } });
  for (const id of [V1, V2, V3]) {
    assertEquals((await handler(post({ text: "a", voice_id: id }))).status, 200);
  }
  assert(calls[1].url.includes(`/text-to-speech/${V2}/stream`));
  for (const bad of ["AnotherVoice00000000", "../x", 5, V1.toLowerCase()]) {
    const res = await handler(post({ text: "a", voice_id: bad }));
    assertEquals(res.status, 400);
    assertEquals((await res.json()).error.code, "invalid_voice");
  }
  assertEquals(calls.length, 3);
});

Deno.test("voice default: ELEVENLABS_VOICE_ID, else first allowlisted voice; default id is accepted even if unlisted", async () => {
  const a = setup({ config: { ...DEFAULT_TTS_CONFIG, voiceId: VOICE, voices } });
  await a.handler(post({ text: "a" }));
  assert(a.calls[0].url.includes(`/text-to-speech/${VOICE}/stream`));
  assertEquals((await a.handler(post({ text: "a", voice_id: VOICE }))).status, 200);
  const b = setup({ config: { ...DEFAULT_TTS_CONFIG, voiceId: null, voices } });
  await b.handler(post({ text: "a" }));
  assert(b.calls[0].url.includes(`/text-to-speech/${V1}/stream`));
});

Deno.test("with no allowlist and no default, any requested voice is refused (fail closed)", async () => {
  const { handler } = setup({ config: { ...DEFAULT_TTS_CONFIG, voiceId: null, voices: [] } });
  assertEquals((await handler(post({ text: "a", voice_id: V1 }))).status, 400);
  assertEquals((await handler(post({ text: "a" }))).status, 503);
});

Deno.test("D46: optional allowlisted model; multilingual is metered at double weight", async () => {
  const { handler, calls, recs } = setup();
  const res = await handler(post({ text: "Sju.", model: "eleven_multilingual_v2" }));
  assertEquals(res.status, 200);
  await res.arrayBuffer();
  assertEquals(JSON.parse(calls[0].init.body as string).model_id, "eleven_multilingual_v2");
  assertEquals(recs[0].model, "eleven_multilingual_v2");
  assertEquals((await handler(post({ text: "Sju.", model: "eleven_v3" }))).status, 400);
  // metering: 4 chars cost 8 on multilingual, so a 6-char/minute budget denies it but allows flash
  const cfg = {
    ...DEFAULT_TTS_CONFIG,
    voiceId: VOICE,
    voices: [],
    limits: { perMinute: 6, perDay: 100, globalPerDay: 100 },
  };
  const t1 = setup({ config: cfg, localLimiter: new MemoryRateLimiter() });
  assertEquals(
    (await t1.handler(post({ text: "Sju.", model: "eleven_multilingual_v2" }))).status,
    429,
  );
  const t2 = setup({ config: cfg, localLimiter: new MemoryRateLimiter() });
  assertEquals((await t2.handler(post({ text: "Sju." }))).status, 200);
});

Deno.test("D48: zero retention is requested; a plan that rejects it is retried once without it", async () => {
  const urls: string[] = [];
  const impl = (url: string | URL | Request) => {
    urls.push(String(url));
    return Promise.resolve(
      String(url).includes("enable_logging")
        ? new Response('{"detail":"zero retention mode is enterprise only"}', { status: 400 })
        : new Response(new Uint8Array([1]), {
          status: 200,
          headers: { "content-type": "audio/mpeg" },
        }),
    );
  };
  _resetZeroRetention(true);
  const { handler } = setup({}, impl as typeof fetch);
  assertEquals((await handler(post({ text: "Sju." }))).status, 200);
  assertEquals(urls.length, 2);
  assert(urls[0].includes("enable_logging=false") && !urls[1].includes("enable_logging"));
  assertEquals((await handler(post({ text: "Sju." }))).status, 200);
  assert(!urls[2].includes("enable_logging"), "remembered: no more attempts with the parameter");
  _resetZeroRetention(true);
  const ok = setup();
  await (await ok.handler(post({ text: "Sju." }))).arrayBuffer();
  assert(ok.calls[0].url.includes("enable_logging=false"));
});

Deno.test("D67: voice_settings are validated and forwarded; the demo ignores them", async () => {
  const { handler, calls } = setup();
  const ok = await handler(
    post({ text: "Hej.", voice_settings: { stability: 0.7, similarity_boost: 0.8, speed: 1.0 } }),
  );
  assertEquals(ok.status, 200);
  assertEquals(JSON.parse(calls[0].init.body as string).voice_settings, {
    stability: 0.7,
    similarity_boost: 0.8,
    speed: 1,
  });
  for (
    const v of [{ stability: 1.5 }, { stability: "hög" }, { speed: 2 }, { evil: 1 }, "x", [], {
      use_speaker_boost: 1,
    }]
  ) {
    assertEquals(
      (await handler(post({ text: "Hej.", voice_settings: v }))).status,
      400,
      JSON.stringify(v),
    );
  }
  assertEquals((await handler(post({ text: "Hej.", voice_settings: {} }))).status, 200);
  assertEquals(
    "voice_settings" in JSON.parse(calls[1].init.body as string),
    false,
    "empty settings are not sent",
  );
  await handler(post({ text: "Hej.", source: "demo", voice_settings: { stability: 0.1 } }));
  assertEquals(
    "voice_settings" in JSON.parse(calls[2].init.body as string),
    false,
    "demo: default settings only",
  );
});

Deno.test("K14: v4 Turbo by default; a 5xx or a slow start goes once to Flash; quota does not", async () => {
  const audio = () => new Response(new Uint8Array([9]), { status: 200, headers: { "content-type": "audio/mpeg" } });
  const models: string[] = [];
  const t1 = setup({}, (_u, init) => {
    const m = JSON.parse(init!.body as string).model_id;
    models.push(m);
    return Promise.resolve(m === "eleven_v4_turbo" ? new Response("boom", { status: 503 }) : audio());
  });
  const r1 = await t1.handler(post({ text: "Sju." }));
  assertEquals(r1.status, 200);
  assertEquals(r1.headers.get("x-tts-model"), "eleven_flash_v2_5");
  await r1.arrayBuffer();
  assertEquals(models, ["eleven_v4_turbo", "eleven_flash_v2_5"]);
  assertEquals(t1.recs[0].model, "eleven_flash_v2_5");

  const slow: string[] = [];
  const t2 = setup({ config: { ...DEFAULT_TTS_CONFIG, voiceId: VOICE, voices: [], firstByteMs: 50 } }, (_u, init) => {
    const m = JSON.parse(init!.body as string).model_id;
    slow.push(m);
    if (m === "eleven_v4_turbo") {
      return new Promise((_res, rej) => init!.signal!.addEventListener("abort", () => rej(new DOMException("a", "AbortError"))));
    }
    return Promise.resolve(audio());
  });
  const r2 = await t2.handler(post({ text: "Sju." }));
  assertEquals(r2.status, 200);
  await r2.arrayBuffer();
  assertEquals(slow, ["eleven_v4_turbo", "eleven_flash_v2_5"]);

  const q: string[] = [];
  const t3 = setup({}, (_u, init) => {
    q.push(JSON.parse(init!.body as string).model_id);
    return Promise.resolve(new Response('{"detail":{"status":"quota_exceeded"}}', { status: 401 }));
  });
  assertEquals((await t3.handler(post({ text: "Sju." }))).status, 503);
  assertEquals(q, ["eleven_v4_turbo"]);

  // an explicitly asked model is never swapped (A/B by ear)
  const e: string[] = [];
  const t4 = setup({}, (_u, init) => {
    e.push(JSON.parse(init!.body as string).model_id);
    return Promise.resolve(new Response("boom", { status: 503 }));
  });
  assertEquals((await t4.handler(post({ text: "Sju.", model: "eleven_v4_turbo" }))).status, 502);
  assertEquals(e, ["eleven_v4_turbo"]);
});

Deno.test("K18: measured subject terms get a spoken spelling for the voice only (Swedish), endings kept", async () => {
  const { pronounce } = await import("./handler.ts");
  assertEquals(pronounce("Plattektonik förklarar jordbävningar.", "sv"), "Platt-tektonik förklarar jordbävningar.");
  assertEquals(pronounce("om plattektoniken", "sv"), "om platt-tektoniken");
  assertEquals(pronounce("plate tectonics", "en"), "plate tectonics");
});
