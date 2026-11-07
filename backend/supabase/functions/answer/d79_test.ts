import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { appChecks, MemoryRateLimiter } from "../_shared/ratelimit.ts";
import { sessionStart } from "../_shared/auth.ts";
import { createHandler, DEFAULT_CONFIG } from "./handler.ts";
import { MockProvider } from "./llm/mock.ts";
import { createTtsHandler, DEFAULT_TTS_CONFIG } from "../tts/handler.ts";

const nowSec = () => Math.floor(Date.now() / 1000);

/** The caller comes from test headers: x-user (id) and x-age (seconds since the session signed in). */
function answerHandler(guard = DEFAULT_CONFIG.appGuard!) {
  return createHandler({
    authenticate: (req) => {
      const age = req.headers.get("x-age");
      return Promise.resolve({
        id: req.headers.get("x-user") ?? "u1",
        isAnonymous: true,
        sessionStartSec: age === null ? undefined : nowSec() - Number(age),
      });
    },
    rateLimiter: new MemoryRateLimiter(),
    provider: new MockProvider(),
    recordUsage: () => {},
    config: { ...DEFAULT_CONFIG, appGuard: guard },
  });
}
const ask = (headers: Record<string, string>, extra: Record<string, unknown> = {}) =>
  new Request("http://x/answer", {
    method: "POST",
    headers: { "content-type": "application/json", "x-forwarded-for": "1.2.3.4", ...headers },
    body: JSON.stringify({ fragment: "vad är fotosyntes", mode: "text", language: "sv", context: {}, ...extra }),
  });

Deno.test("D79 sessionStart: earliest amr timestamp, nothing when missing", () => {
  assertEquals(sessionStart({ amr: [{ method: "anonymous", timestamp: 1794083239 }] }), 1794083239);
  assertEquals(sessionStart({ amr: [{ timestamp: 20 }, { timestamp: 10 }] }), 10);
  assertEquals(sessionStart({}), undefined);
  assertEquals(sessionStart({ amr: [{ method: "anonymous" }] }), undefined);
});

Deno.test("D79 appChecks: network window always, new-user window only for a young session", () => {
  const g = { networkPerDay: 1500, newUserAgeSec: 600, newUserPerHour: 20 };
  const t = 1_000_000;
  assertEquals(appChecks("answer", "abc", { id: "u" }, g, t).map((c) => c.key), ["answer:ip:abc:d"]);
  const young = appChecks("answer", "abc", { id: "u", sessionStartSec: t - 599 }, g, t);
  assertEquals(young.map((c) => [c.key, c.limit, c.windowSec]), [
    ["answer:ip:abc:d", 1500, 86400],
    ["answer:new:u:u:h", 20, 3600],
  ]);
  assertEquals(appChecks("answer", "abc", { id: "u", sessionStartSec: t - 600 }, g, t).length, 1);
  assertEquals(appChecks("answer", null, { id: "u" }, g, t).length, 0);
});

Deno.test("D79 answer: a new session gets its first-hour allowance, an older one is not affected", async () => {
  const h = answerHandler({ networkPerDay: 1500, newUserAgeSec: 600, newUserPerHour: 3 });
  for (let i = 0; i < 3; i++) assertEquals((await h(ask({ "x-user": "new", "x-age": "30" }))).status, 200);
  const denied = await h(ask({ "x-user": "new", "x-age": "30" }));
  assertEquals(denied.status, 429);
  const e = (await denied.json()).error;
  assertEquals(e.code, "rate_limited");
  assertEquals(e.fallback, true);
  for (let i = 0; i < 5; i++) {
    assertEquals((await h(ask({ "x-user": "old", "x-age": "7200" }))).status, 200, "older session");
    assertEquals((await h(ask({ "x-user": "unknown" }))).status, 200, "no amr timestamp = no new-user check");
  }
});

Deno.test("D79 answer: the network cap holds across new users; another network is not affected", async () => {
  const h = answerHandler({ networkPerDay: 3, newUserAgeSec: 600, newUserPerHour: 20 });
  for (const u of ["a", "b", "c"]) assertEquals((await h(ask({ "x-user": u }))).status, 200);
  assertEquals((await h(ask({ "x-user": "d" }))).status, 429, "a fresh user does not reset the network");
  assertEquals((await h(ask({ "x-user": "e", "x-forwarded-for": "5.6.7.8" }))).status, 200);
  // the demo has its own caps and does not use the app's network allowance
  const demo = await h(ask({ "x-user": "f" }, { source: "demo" }));
  assertEquals(demo.status, 200);
});

Deno.test("D79 tts: app characters are capped per network across users", async () => {
  const h = createTtsHandler({
    authenticate: (req) => Promise.resolve({ id: req.headers.get("x-user") ?? "u1", isAnonymous: true }),
    rateLimiter: new MemoryRateLimiter(),
    apiKey: "xi",
    config: { ...DEFAULT_TTS_CONFIG, voiceId: "abcdefghij1234567890", voices: [], networkCharsPerDay: 10 },
    recordUsage: () => {},
    fetchImpl: () =>
      Promise.resolve(new Response(new Uint8Array([1]), { status: 200, headers: { "content-type": "audio/mpeg" } })),
  });
  const say = (u: string, ip = "1.2.3.4") =>
    h(
      new Request("http://x/tts", {
        method: "POST",
        headers: { "x-user": u, "x-forwarded-for": ip },
        body: JSON.stringify({ text: "123456" }),
      }),
    );
  assertEquals((await say("a")).status, 200);
  const r = await say("b");
  assertEquals(r.status, 429);
  assert((await r.json()).error.fallback === true);
  assertEquals((await say("c", "5.6.7.8")).status, 200);
});
