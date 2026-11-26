// O100 retest (Oscar 2026-11-26 22:36): S1b the client's own cf-connecting-ip / x-real-ip was trusted (limits per
// network and "CI test traffic" could be faked); S5b /purchase hung on a chunked body; S2b a forged token blocked the
// real account's registration in the same isolate.
import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { clientIp, fromCi, registerTest, resetCiRangesForTest, setCiRangesForTest } from "./testmode.ts";
import { networkKey } from "./demo.ts";
import { readLimitedJson } from "../answer/validate.ts";
import { HttpError } from "./errors.ts";

const req = (h: Record<string, string>) => new Request("http://x/f", { method: "POST", headers: h });

Deno.test("O100 S1b: only the platform's x-forwarded-for counts; cf-connecting-ip and x-real-ip from the client do not", async () => {
  assertEquals(clientIp(req({ "cf-connecting-ip": "4.148.1.1", "x-forwarded-for": "203.0.113.7" })), "203.0.113.7");
  assertEquals(clientIp(req({ "x-real-ip": "4.148.1.1", "x-forwarded-for": "203.0.113.7, 10.0.0.1" })), "203.0.113.7");
  assertEquals(clientIp(req({ "cf-connecting-ip": "4.148.1.1" })), "");
  assertEquals(
    await networkKey(req({ "cf-connecting-ip": "1.1.1.1", "x-forwarded-for": "203.0.113.7" })),
    await networkKey(req({ "cf-connecting-ip": "8.8.8.8", "x-forwarded-for": "203.0.113.7" })),
  );
  setCiRangesForTest(["4.148.0.0/16"]);
  try {
    assertEquals(fromCi(req({ "cf-connecting-ip": "4.148.1.1", "x-forwarded-for": "203.0.113.7" })), false);
    assertEquals(fromCi(req({ "x-forwarded-for": "4.148.1.1" })), true);
  } finally {
    resetCiRangesForTest();
  }
});

Deno.test("O100 S5b: a body over the limit stops with 413 without cancelling the request's own stream", async () => {
  let cancelled = 0, sent = 0;
  const body = new ReadableStream<Uint8Array>({
    pull(c) {
      if (sent >= 3) return c.close();
      sent++;
      c.enqueue(new Uint8Array(65536).fill(97));
    },
    cancel() {
      cancelled++;
      return new Promise(() => {}); // the live platform: cancelling an upload in flight never settles
    },
  });
  const r = new Request("http://x/purchase", { method: "POST", body });
  const t0 = Date.now();
  const err = await readLimitedJson(r, 64 * 1024).then(() => null, (e) => e);
  assert(err instanceof HttpError && err.status === 413, String(err));
  assertEquals(cancelled, 0);
  assert(Date.now() - t0 < 1000);
});

Deno.test("O100 S2b: a forged token for an account does not stop that account's own registration later", async () => {
  const env = { get: (k: string) => ({ SUPABASE_URL: "http://sb", SUPABASE_SERVICE_ROLE_KEY: "svc" } as Record<string, string>)[k] } as unknown as typeof Deno.env;
  const writes: string[] = [];
  const f = ((url: string, init?: RequestInit) => {
    const auth = new Headers(init?.headers).get("authorization");
    if (url.endsWith("/auth/v1/user")) {
      return Promise.resolve(new Response(JSON.stringify(auth === "Bearer real" ? { id: "victim-s2b" } : { id: "attacker" }), { status: 200 }));
    }
    writes.push(url);
    return Promise.resolve(new Response("{}", { status: 200 }));
  }) as typeof fetch;
  const info = { test: true, reason: "header", userId: "victim-s2b" } as const;
  await registerTest(info, "f", env, f, "forged");
  assertEquals(writes.length, 0);
  await registerTest(info, "f", env, f, "real");
  assert(writes.some((u) => u.includes("/rest/v1/test_accounts")), JSON.stringify(writes));
});
