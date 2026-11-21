// A156 (Angela Schrute 11:52, D249): listening and spoken answers from the web beta have a daily cap per network
// and for the whole web; the iOS app (no Origin) and the demo page (its own caps, D62) are not counted.
import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { MemoryRateLimiter } from "../_shared/ratelimit.ts";
import { WEB_LIMITS, withWebGuard } from "../_shared/webguard.ts";
import { createSttHandler, DEFAULT_STT_CONFIG } from "./handler.ts";
import { createTtsHandler, DEFAULT_TTS_CONFIG } from "../tts/handler.ts";

const WEB = "https://earmind.vercel.app";
const jwt = (sub: string) => `x.${btoa(JSON.stringify({ sub })).replace(/=+$/, "")}.y`;
const hdr = (sub: string, web = true) => ({ ...(web ? { origin: WEB } : {}), authorization: `Bearer ${jwt(sub)}`, "x-forwarded-for": "203.0.113.80" });

Deno.test("A156: Scribe tokens from the web stop at the network's daily cap with 429 web_daily_cap; the app goes on", async () => {
  const rl = new MemoryRateLimiter();
  let minted = 0;
  const stt = createSttHandler({
    authenticate: () => Promise.resolve({ id: "u1", isAnonymous: true }),
    rateLimiter: rl, apiKey: "xi", recordUsage: () => {},
    config: { ...DEFAULT_STT_CONFIG, limits: { perMinute: 1000, perDay: 1000, globalPerDay: 1000 } },
    fetchImpl: () => (minted++, Promise.resolve(new Response(JSON.stringify({ token: "t" }), { status: 200 }))),
  });
  const h = withWebGuard(stt, { limiter: rl, demo: true });
  const codes: number[] = [];
  for (let i = 0; i <= WEB_LIMITS.sttTokensPerIpPerDay; i++) codes.push((await h(new Request("http://x/stt-token", { headers: hdr("w1") }))).status);
  assertEquals(codes.filter((c) => c === 200).length, WEB_LIMITS.sttTokensPerIpPerDay);
  const last = await h(new Request("http://x/stt-token", { headers: hdr("w1") }));
  assertEquals(last.status, 429);
  assertEquals((await last.json()).error.code, "web_daily_cap");
  assertEquals(minted, WEB_LIMITS.sttTokensPerIpPerDay, "no token is minted over the cap");
  assertEquals((await h(new Request("http://x/stt-token", { headers: hdr("app", false) }))).status, 200, "the app");
});

Deno.test("A156: spoken answers (tts) from the web count against the web's credits; the app's do not", async () => {
  const rl = new MemoryRateLimiter();
  const tts = createTtsHandler({
    authenticate: () => Promise.resolve({ id: "u1", isAnonymous: true }),
    rateLimiter: rl, apiKey: "xi", recordUsage: () => {},
    config: { ...DEFAULT_TTS_CONFIG, voiceId: "x0u3EW21dbrORJzOq1m9", voices: [], limits: { perMinute: 1e9, perDay: 1e9, globalPerDay: 1e9 } },
    fetchImpl: () => Promise.resolve(new Response(new Uint8Array([1]), { status: 200, headers: { "content-type": "audio/mpeg" } })),
  });
  const h = withWebGuard(tts, { limiter: rl, demo: true });
  const text = "a".repeat(400);
  let ok = 0, last: Response | null = null;
  for (let i = 0; i < 20; i++) {
    last = await h(new Request("http://x/tts", { method: "POST", headers: hdr("t1"), body: JSON.stringify({ text }) }));
    if (last.status === 200) { ok++; await last.arrayBuffer(); }
  }
  assert(ok * 400 <= WEB_LIMITS.creditsPerIpPerDay && ok > 0, `ok=${ok}`);
  assertEquals(last!.status, 429);
  assertEquals((await last!.json()).error.code, "web_daily_cap");
  const app = await h(new Request("http://x/tts", { method: "POST", headers: hdr("app", false), body: JSON.stringify({ text }) }));
  assertEquals(app.status, 200, "the app");
});
