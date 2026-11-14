import { assert, assertEquals, assertRejects, assertThrows } from "jsr:@std/assert@1.0.8";
import {
  assertNotTest, detectTest, guardedFetch, inRanges, parseRanges, runWithTest, setCiRangesForTest, silentMp3, TestCreditsError,
} from "./testmode.ts";

const b64u = (o: unknown) => btoa(JSON.stringify(o)).replace(/=+$/, "").replace(/\+/g, "-").replace(/\//g, "_");
const jwt = (claims: Record<string, unknown>) => `Bearer ${b64u({ alg: "HS256" })}.${b64u(claims)}.sig`;
const req = (h: Record<string, string>) => new Request("http://x/tts", { method: "POST", headers: h });
const APP = "Lumen/1 CFNetwork/3826 Darwin/25.0.0";

Deno.test("K62b test traffic: header, account flag, script user agent and GitHub Actions IP; the app and the owner are not", () => {
  setCiRangesForTest(["4.148.0.0/16", "2a01:111:f100:1000::/62"]);
  const u = { sub: "11111111-1111-1111-1111-111111111111" };
  assertEquals(detectTest(req({ "user-agent": APP, authorization: jwt(u) })).test, false, "the real app");
  assertEquals(detectTest(req({ "user-agent": "Mozilla/5.0 (iPhone)" })).test, false, "a browser (the demo page)");
  assertEquals(detectTest(req({ "user-agent": APP, "x-earmind-test": "1" })).reason, "header");
  assertEquals(detectTest(req({ "user-agent": APP, authorization: jwt({ ...u, app_metadata: { test: true } }) })).reason, "account");
  for (const ua of ["Python-urllib/3.13", "curl/8.5.0", "Deno/2.1.0", "node", "Mozilla/5.0 HeadlessChrome/131", ""]) {
    assertEquals(detectTest(req({ "user-agent": ua })).reason, "script", ua);
  }
  assertEquals(detectTest(req({ "user-agent": APP, "x-forwarded-for": "4.148.3.7, 10.0.0.1" })).reason, "ci");
  assertEquals(detectTest(req({ "user-agent": APP, "x-forwarded-for": "2a01:111:f100:1001::5" })).reason, "ci");
  assertEquals(detectTest(req({ "user-agent": APP, "x-forwarded-for": "81.224.1.2" })).test, false, "a home network");
  const owner = jwt({ ...u, email: "aron@example.com", amr: [{ method: "otp" }] });
  assertEquals(detectTest(req({ "user-agent": "curl/8", authorization: owner }), ["aron@example.com"]).test, false, "the owner");
  assertEquals(detectTest(req({ authorization: jwt(u) })).userId, u.sub);
});

Deno.test("K62b the guard: a test request that reaches ElevenLabs throws; real requests and other hosts pass", async () => {
  let calls = 0;
  const f = guardedFetch(() => {
    calls++;
    return Promise.resolve(new Response("ok"));
  }, "tts");
  await runWithTest({ test: true, reason: "script", userId: "u" }, async () => {
    await assertRejects(() => f("https://api.elevenlabs.io/v1/text-to-speech/x"), TestCreditsError);
    assertEquals((await f("https://xjczbzfkmbjdebwlccki.supabase.co/rest/v1/x")).status, 200);
    assertThrows(() => assertNotTest("drill"), TestCreditsError);
  });
  await runWithTest({ test: false, reason: null, userId: "u" }, async () => {
    assertEquals((await f("https://api.elevenlabs.io/v1/text-to-speech/x")).status, 200);
  });
  assertEquals(calls, 2);
});

Deno.test("K62b fake audio is a silent MP3 of about the asked length", () => {
  const a = silentMp3(1);
  assertEquals([a[0], a[1]], [0xff, 0xfb]);
  assert(Math.abs(a.length / 417 * 0.026122 - 1) < 0.05);
  assert(inRanges("10.1.2.3", parseRanges(["10.0.0.0/8"])));
  assert(!inRanges("11.1.2.3", parseRanges(["10.0.0.0/8"])));
});
