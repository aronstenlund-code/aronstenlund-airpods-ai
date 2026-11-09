import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { MemoryRateLimiter } from "./ratelimit.ts";
import { createTtsHandler, DEFAULT_TTS_CONFIG, type TtsDeps } from "../tts/handler.ts";
import { createSttHandler, DEFAULT_STT_CONFIG } from "../stt-token/handler.ts";
import { createWaitlistHandler, normalizeEmail, type WaitlistRow } from "../waitlist/handler.ts";
import { originAllowed, withCors } from "./cors.ts";
import { DEFAULT_DEMO_CAPS, demoCapsFromEnv } from "./demo.ts";

const VOICE = "abcdefghij1234567890";
function tts(over: Partial<TtsDeps> = {}) {
  const calls: { url: string; init: RequestInit }[] = [];
  const handler = createTtsHandler({
    authenticate: () => Promise.resolve({ id: "u1", isAnonymous: true }),
    rateLimiter: new MemoryRateLimiter(),
    apiKey: "xi-test",
    config: { ...DEFAULT_TTS_CONFIG, voiceId: VOICE, voices: [] },
    recordUsage: () => {},
    fetchImpl: (url, init) => {
      calls.push({ url: String(url), init: init! });
      return Promise.resolve(
        new Response(new Uint8Array([1]), {
          status: 200,
          headers: { "content-type": "audio/mpeg" },
        }),
      );
    },
    ...over,
  });
  return { handler, calls };
}
const post = (b: unknown) =>
  new Request("http://x/tts", { method: "POST", body: JSON.stringify(b) });

Deno.test("D62 tts demo: max 400 characters, default voice/model/format only, daily character cap", async () => {
  const { handler, calls } = tts();
  const long = await handler(post({ text: "a".repeat(401), source: "demo" }));
  assertEquals(long.status, 413);
  assertEquals((await long.json()).error.code, "demo_text_too_long");
  assertEquals(calls.length, 0);
  const ok = await handler(post({
    text: "Hej där.",
    source: "demo",
    voice_id: "../../evil",
    model: "eleven_multilingual_v2",
    output_format: "pcm_24000",
  }));
  assertEquals(ok.status, 200, "demo ignores voice / model / format instead of failing");
  assert(calls[0].url.includes(`/text-to-speech/${VOICE}/stream`));
  assertEquals(JSON.parse(calls[0].init.body as string).model_id, "eleven_v4_turbo"); // K14: the demo gets the default model
  // visitor allowance 2000 characters per day
  const small = tts({
    config: { ...DEFAULT_TTS_CONFIG, voiceId: VOICE, voices: [] },
    demo: { ...DEFAULT_DEMO_CAPS, ttsCharsPerVisitor: 10 },
  }).handler;
  assertEquals((await small(post({ text: "123456", source: "demo" }))).status, 200);
  const denied = await small(post({ text: "123456", source: "demo" }));
  assertEquals(denied.status, 429);
  const dj = (await denied.json()).error;
  assertEquals(dj.code, "demo_limit_visitor");
  // D77: the read-aloud cap says so, not "demofrågor"
  assert(dj.message.includes("uppläsning") && !dj.message.includes("demofrågor"), dj.message);
  // the app (no source) keeps its full feature set
  assertEquals((await handler(post({ text: "a".repeat(450) }))).status, 200);
});

Deno.test("D62 stt-token demo: ?source=demo is capped per visitor", async () => {
  const mk = () =>
    createSttHandler({
      authenticate: () => Promise.resolve({ id: "u1", isAnonymous: true }),
      rateLimiter: new MemoryRateLimiter(),
      apiKey: "xi",
      config: DEFAULT_STT_CONFIG,
      demo: { ...DEFAULT_DEMO_CAPS, sttPerVisitor: 2 },
      recordUsage: () => {},
      fetchImpl: () =>
        Promise.resolve(new Response(JSON.stringify({ token: "t" }), { status: 200 })),
    });
  const h = mk();
  const get = (q = "") => new Request(`http://x/stt-token${q}`);
  assertEquals((await h(get("?source=demo"))).status, 200);
  assertEquals((await h(get("?source=demo"))).status, 200);
  const third = await h(get("?source=demo"));
  assertEquals(third.status, 429);
  const tj = (await third.json()).error;
  assertEquals(tj.code, "demo_limit_visitor");
  // D77: the speech cap has its own text and number (was "Du har använt dagens 5 demofrågor")
  assertEquals(
    tj.message,
    "Du har använt dagens 2 röstfrågor i demon. Skriv frågan i stället, eller kom tillbaka i morgon.",
  );
  assertEquals((await h(get())).status, 200, "the app is not affected by the demo cap");
});

function wl(over: { insert?: (r: WaitlistRow) => Promise<void> } = {}) {
  const rows: WaitlistRow[] = [];
  const seen = new Set<string>();
  const handler = createWaitlistHandler({
    rateLimiter: new MemoryRateLimiter(),
    insert: over.insert ?? ((r) => {
      if (!seen.has(r.email)) {
        seen.add(r.email);
        rows.push(r);
      }
      return Promise.resolve();
    }),
  });
  return { handler, rows };
}
const wpost = (b: unknown, headers: Record<string, string> = {}) =>
  new Request("http://x/waitlist", { method: "POST", headers, body: JSON.stringify(b) });

Deno.test("D62 waitlist: valid e-mail with consent is stored once, lower-cased", async () => {
  const { handler, rows } = wl();
  const res = await handler(
    wpost({ email: "  Pam.Test+demo@Example.SE ", consent: true, consent_version: "2026-11-06" }),
  );
  assertEquals(res.status, 200);
  assertEquals((await res.json()).ok, true);
  assertEquals(rows[0], {
    email: "pam.test+demo@example.se",
    source: "demo",
    consent_version: "2026-11-06",
  });
  // duplicate: same answer, no second row (the endpoint does not reveal who is on the list)
  const dup = await handler(wpost({ email: "PAM.test+demo@example.se", consent: true }));
  assertEquals(dup.status, 200);
  assertEquals(rows.length, 1);
  assertEquals(
    (await handler(wpost({ email: "a@b.se", consent: true, source: "Bad Source!" }))).status,
    200,
  );
  assertEquals(rows[1].source, "demo");
});

Deno.test("D62 waitlist: invalid e-mail, missing consent, honeypot, method, storage failure", async () => {
  const { handler, rows } = wl();
  for (
    const e of [
      "",
      "x",
      "a@b",
      "a b@c.se",
      "a@@c.se",
      ".a@c.se",
      "a..b@c.se",
      "a@c..se",
      "a@-c.se",
      `${"a".repeat(65)}@c.se`,
      5,
      null,
    ]
  ) {
    const r = await handler(wpost({ email: e, consent: true }));
    assertEquals(r.status, 400, String(e));
    assertEquals((await r.json()).error.code, "invalid_email");
  }
  const noConsent = await handler(wpost({ email: "ok@example.se" }));
  assertEquals(noConsent.status, 400);
  assertEquals((await noConsent.json()).error.code, "consent_required");
  assertEquals((await handler(wpost({ email: "ok@example.se", consent: "yes" }))).status, 400);
  const bot = await handler(
    wpost({ email: "bot@example.se", consent: true, website: "http://spam" }),
  );
  assertEquals(bot.status, 200);
  assertEquals(rows.length, 0, "honeypot stores nothing");
  assertEquals((await handler(new Request("http://x/waitlist"))).status, 405);
  assertEquals(
    (await handler(new Request("http://x/waitlist", { method: "POST", body: "{" }))).status,
    400,
  );
  const broken = wl({ insert: () => Promise.reject(new Error("db down")) }).handler;
  const res = await broken(wpost({ email: "ok@example.se", consent: true }));
  assertEquals(res.status, 503);
  assert(!(await res.text()).includes("db down"));
  assertEquals(normalizeEmail("Ålder@exempel.se"), null);
});

Deno.test("D62 waitlist: limit per network (5/hour) from the same address", async () => {
  const { handler } = wl();
  const h = { "x-forwarded-for": "203.0.113.9" };
  for (let i = 0; i < 5; i++) {
    assertEquals(
      (await handler(wpost({ email: `u${i}@example.se`, consent: true }, h))).status,
      200,
    );
  }
  const sixth = await handler(wpost({ email: "u9@example.se", consent: true }, h));
  assertEquals(sixth.status, 429);
  assert(sixth.headers.get("retry-after"));
  const other = await handler(
    wpost({ email: "u9@example.se", consent: true }, { "x-forwarded-for": "198.51.100.1" }),
  );
  assertEquals(other.status, 200);
});

Deno.test("D62 CORS: GitHub Pages and localhost are allowed, other sites are not, native apps untouched", async () => {
  assert(originAllowed("https://aronstenlund-code.github.io"));
  assert(originAllowed("http://localhost:5173"));
  assert(originAllowed("http://127.0.0.1:8080"));
  assert(!originAllowed("https://evil.example.com"));
  assert(!originAllowed("https://aronstenlund-code.github.io.evil.com"));
  assert(originAllowed("https://demo.lumen.se", ["https://demo.lumen.se"]));
  const inner = () =>
    Promise.resolve(
      new Response("ok", {
        headers: { "access-control-allow-origin": "*", "content-type": "text/plain" },
      }),
    );
  const h = withCors(inner);
  const ok = await h(
    new Request("http://x/f", { headers: { origin: "https://aronstenlund-code.github.io" } }),
  );
  assertEquals(
    ok.headers.get("access-control-allow-origin"),
    "https://aronstenlund-code.github.io",
  );
  assert(ok.headers.get("vary")?.includes("Origin"));
  const bad = await h(
    new Request("http://x/f", { headers: { origin: "https://evil.example.com" } }),
  );
  assertEquals(bad.headers.get("access-control-allow-origin"), null);
  const native = await h(new Request("http://x/f"));
  assertEquals(native.headers.get("access-control-allow-origin"), "*");
  const pre = await h(
    new Request("http://x/f", { method: "OPTIONS", headers: { origin: "http://localhost:3000" } }),
  );
  assertEquals(pre.status, 204);
  assertEquals(pre.headers.get("access-control-allow-origin"), "http://localhost:3000");
  assert(pre.headers.get("access-control-allow-methods")!.includes("DELETE"));
  assertEquals(
    (await h(
      new Request("http://x/f", {
        method: "OPTIONS",
        headers: { origin: "https://evil.example.com" },
      }),
    )).status,
    403,
  );
});

Deno.test("D62 demo caps can be tuned by environment, defaults are the contract", () => {
  assertEquals(DEFAULT_DEMO_CAPS.questionsPerVisitor, 5);
  assertEquals(DEFAULT_DEMO_CAPS.ttsCharsPerRequest, 400);
  const caps = demoCapsFromEnv({
    get: (k) =>
      ({ DEMO_GLOBAL_QUESTIONS_PER_DAY: "100", DEMO_QUESTIONS_PER_VISITOR: "x" } as Record<
        string,
        string
      >)[k],
  });
  assertEquals(caps.questionsGlobal, 100);
  assertEquals(caps.questionsPerVisitor, 5);
});
