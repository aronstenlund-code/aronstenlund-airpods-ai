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
  });
  assertEquals(await auth(req(t)), {
    id: "11111111-1111-1111-1111-111111111111",
    isAnonymous: true,
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
