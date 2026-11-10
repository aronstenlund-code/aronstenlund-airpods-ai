import { assertEquals, assertRejects } from "jsr:@std/assert@1.0.8";
import { SignJWT } from "npm:jose@5.9.6";
import { createJwtAuthenticator } from "./auth.ts";
import { HttpError } from "./errors.ts";

const URL_ = "https://abc.supabase.co";
const SECRET = "test-secret-test-secret-test-secret-123";
const key = new TextEncoder().encode(SECRET);
const auth = createJwtAuthenticator({ supabaseUrl: URL_, hs256Secret: SECRET });
const sign = (
  claims: Record<string, unknown>,
  exp = "5m",
  iss = `${URL_}/auth/v1`,
  aud = "authenticated",
) =>
  new SignJWT(claims).setProtectedHeader({ alg: "HS256" }).setIssuer(iss).setAudience(aud)
    .setExpirationTime(exp).sign(key);
const req = (t?: string) =>
  new Request("http://x", { headers: t ? { authorization: `Bearer ${t}` } : {} });

Deno.test("accepts an anonymous-user token", async () => {
  const t = await sign({
    sub: "11111111-1111-1111-1111-111111111111",
    role: "authenticated",
    is_anonymous: true,
    amr: [{ method: "anonymous", timestamp: 1794083239 }],
  });
  assertEquals(await auth(req(t)), {
    id: "11111111-1111-1111-1111-111111111111",
    isAnonymous: true,
    sessionStartSec: 1794083239, // D79: from amr, unchanged by refreshes
    amr: ["anonymous"], // K30: the sign-in methods
  });
});

Deno.test("K30: an email sign-in carries the email claim and the otp method", async () => {
  const t = await sign({
    sub: "22222222-2222-2222-2222-222222222222",
    role: "authenticated",
    email: "owner@example.com",
    amr: [{ method: "otp", timestamp: 1794083239 }],
  });
  assertEquals(await auth(req(t)), {
    id: "22222222-2222-2222-2222-222222222222",
    isAnonymous: false,
    sessionStartSec: 1794083239,
    email: "owner@example.com",
    amr: ["otp"],
  });
});

Deno.test("rejects: missing, anon key (no sub), wrong role/issuer/audience/secret, expired", async () => {
  const bad = [
    undefined,
    await sign({ role: "anon" }),
    await sign({ sub: "u", role: "service_role" }),
    await sign({ sub: "u", role: "authenticated" }, "5m", "https://evil.example/auth/v1"),
    await sign({ sub: "u", role: "authenticated" }, "5m", `${URL_}/auth/v1`, "other"),
    await sign({ sub: "u", role: "authenticated" }, "-10s"),
    await new SignJWT({ sub: "u", role: "authenticated" }).setProtectedHeader({ alg: "HS256" })
      .setIssuer(`${URL_}/auth/v1`)
      .setAudience("authenticated").setExpirationTime("5m").sign(
        new TextEncoder().encode("a-different-secret-a-different-secret"),
      ),
    "not.a.jwt",
  ];
  for (const t of bad) {
    const e = await assertRejects(() => auth(req(t)), HttpError);
    assertEquals(e.status, 401);
  }
});
