// K112 (Deangelo 07:58, D227): Release without test mode. What a reviewer can reach in the app is in Swedish (the app
// shows the server's message for /drill and for /exam's 4xx), and nothing but the test header / test account / script
// / CI turns test mode on.
import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { toHttpError } from "./errors.ts";
import { detectTest, resetCiRangesForTest } from "./testmode.ts";
import { createJwtAuthenticator } from "./auth.ts";

const APP_UA = "EarMind/1 CFNetwork/3826.400.120 Darwin/25.0.0";
const SWEDISH = /[åäö]|\b(?:inte|igen|försök|logga|filen|rösterna)\b/i;

Deno.test("K112: an unexpected error is told in Swedish (the app shows /drill's message)", () => {
  const e = toHttpError(new Error("boom"));
  assertEquals(e.status, 500);
  assert(SWEDISH.test(e.message), e.message);
});

Deno.test("K112: a missing or expired login is told in Swedish", async () => {
  const auth = createJwtAuthenticator({ supabaseUrl: "https://x.supabase.co", hs256Secret: "s".repeat(32) });
  for (const h of [{}, { authorization: "Bearer not-a-jwt" }] as Record<string, string>[]) {
    const err = await auth(new Request("http://x/drill", { headers: h })).then(() => null, (e) => e as { status: number; message: string });
    assertEquals(err?.status, 401);
    assert(SWEDISH.test(err!.message), err!.message);
  }
});

Deno.test("K112: a Word file over 10 MB is told in Swedish", async () => {
  const { docxText, DRILL_LIMITS } = await import("../exam/drill.ts");
  const err = await Promise.resolve().then(() => docxText("A".repeat(DRILL_LIMITS.docxBase64 + 4))).then(() => null, (e) => e as { status: number; message: string });
  assertEquals(err?.status, 413);
  assert(SWEDISH.test(err!.message), err!.message);
});

Deno.test("K112 (D227): the Release app's request is never test traffic (no header, app user agent, not CI)", () => {
  resetCiRangesForTest();
  const r = new Request("http://x/drill", { headers: { "user-agent": APP_UA, "x-forwarded-for": "17.0.0.1" } });
  assertEquals(detectTest(r).test, false);
  // and the hooks only answer the header or a script
  assertEquals(detectTest(new Request("http://x", { headers: { "user-agent": APP_UA, "x-earmind-test": "oscar-qa" } })).test, true);
  assertEquals(detectTest(new Request("http://x", { headers: { "user-agent": "python-urllib/3" } })).reason, "script");
});
