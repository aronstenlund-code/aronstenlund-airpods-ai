// O100 S2 (Oscar): a forged (unsigned) token with someone else's `sub` plus the test header marked that account as
// a test account with the service key. Now the token is checked with Supabase Auth first (GET /auth/v1/user with the
// caller's own token); only the id Auth returns is ever written, and only when it is the token's own.
import { assertEquals } from "jsr:@std/assert@1.0.8";
import { registerTest } from "./testmode.ts";

const env = { get: (k: string) => ({ SUPABASE_URL: "https://p.supabase.co", SUPABASE_SERVICE_ROLE_KEY: "svc" } as Record<string, string>)[k] } as unknown as typeof Deno.env;
function fakeFetch(authUserId: string | null) {
  const calls: string[] = [];
  const f = ((url: string | URL, init?: RequestInit) => {
    const u = String(url);
    calls.push(`${init?.method ?? "GET"} ${u.replace("https://p.supabase.co", "")}`);
    if (u.endsWith("/auth/v1/user")) {
      return Promise.resolve(authUserId ? new Response(JSON.stringify({ id: authUserId }), { status: 200 }) : new Response("{}", { status: 401 }));
    }
    return Promise.resolve(new Response("", { status: 201 }));
  }) as typeof fetch;
  return { f, calls, writes: () => calls.filter((c) => !c.endsWith("/auth/v1/user")) };
}

Deno.test("O100 S2: a forged token (Auth rejects it) registers nothing", async () => {
  const x = fakeFetch(null);
  await registerTest({ test: true, reason: "header", userId: "victim-1" }, "drill", env, x.f, "forged.token.sig");
  assertEquals(x.writes(), []);
});

Deno.test("O100 S2: a valid token for another account than its sub registers nothing", async () => {
  const x = fakeFetch("someone-else");
  await registerTest({ test: true, reason: "header", userId: "victim-2" }, "drill", env, x.f, "a.b.c");
  assertEquals(x.writes(), []);
});

Deno.test("O100 S2: no token, nothing is registered; a verified own token is registered as before", async () => {
  const none = fakeFetch("u-3");
  await registerTest({ test: true, reason: "header", userId: "u-3" }, "drill", env, none.f);
  assertEquals(none.calls, []);
  const ok = fakeFetch("u-4");
  await registerTest({ test: true, reason: "header", userId: "u-4" }, "drill", env, ok.f, "a.b.c");
  assertEquals(ok.writes().length, 2, ok.calls.join(" | "));
});
