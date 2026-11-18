import { assertEquals, assertRejects } from "jsr:@std/assert@1.0.8";
import { RestDb } from "./restdb.ts";
import { SupabaseRateLimiter } from "./ratelimit.ts";

function fake(status: number, body: unknown) {
  const calls: { url: string; init: RequestInit }[] = [];
  const f = ((url: string, init: RequestInit) => {
    calls.push({ url: String(url), init });
    return Promise.resolve(new Response(JSON.stringify(body), { status }));
  }) as typeof fetch;
  return { f, calls };
}

Deno.test("rpc posts JSON with the service key and returns the parsed body", async () => {
  const { f, calls } = fake(200, [{ allowed: true }]);
  const db = new RestDb("https://p.supabase.co", "svc-key", f);
  assertEquals(await db.rpc("check_rate_limits", { p_cost: 1 }), [{ allowed: true }]);
  assertEquals(calls[0].url, "https://p.supabase.co/rest/v1/rpc/check_rate_limits");
  const h = calls[0].init.headers as Record<string, string>;
  assertEquals([h.apikey, h.authorization], ["svc-key", "Bearer svc-key"]);
  assertEquals(JSON.parse(calls[0].init.body as string), { p_cost: 1 });
});

Deno.test("insert uses return=minimal; non-2xx throws without leaking the body", async () => {
  const ok = fake(201, null);
  await new RestDb("https://p.supabase.co", "k", ok.f).insert("answer_usage", { a: 1 });
  assertEquals((ok.calls[0].init.headers as Record<string, string>).prefer, "return=minimal");
  const bad = fake(500, { message: "secret detail" });
  const err = await assertRejects(() =>
    new RestDb("https://p.supabase.co", "k", bad.f).insert("t", {})
  );
  assertEquals((err as Error).message, "insert t failed: HTTP 500");
});

Deno.test("SupabaseRateLimiter maps the multi-window RPC result", async () => {
  const { f, calls } = fake(200, [{ allowed: false, denied_key: "x", retry_after: 17 }]);
  const rl = new SupabaseRateLimiter(new RestDb("https://p.supabase.co", "k", f));
  const r = await rl.checkMany([{ key: "a", limit: 1, windowSec: 60 }, {
    key: "b",
    limit: 2,
    windowSec: 86400,
  }], 3);
  assertEquals(r, { allowed: false, retryAfterSec: 17, deniedKey: "x" });
  assertEquals(JSON.parse(calls[0].init.body as string), {
    p_keys: ["a", "b"],
    p_limits: [1, 2],
    p_windows: [60, 86400],
    p_cost: 3,
  });
});

Deno.test("K101: an rpc error keeps the Postgres code (never the message); the wallet says 401 account_deleted for a deleted user", async () => {
  const { f } = fake(409, { code: "23503", message: "insert or update on table \"drill_quota\" violates foreign key constraint", details: "Key (user_id)=(x) is not present" });
  const db = new RestDb("https://p.supabase.co", "svc-key", f);
  const e = (await db.rpc("use_drill_chars", { p_user: "x", p_n: 0 }).catch((x) => x)) as Error;
  assertEquals(e.message, "rpc use_drill_chars failed: HTTP 409 23503");
  const { useQuotaFromDb } = await import("./wallet_db.ts");
  const { HttpError } = await import("./errors.ts");
  const err = await useQuotaFromDb(db)("x", 0).catch((x) => x);
  assertEquals([err instanceof HttpError, err.status, err.code], [true, 401, "account_deleted"]);
  // another error stays an error (no code in it)
  const other = (await new RestDb("https://p.supabase.co", "k", fake(500, "boom").f).rpc("x", {}).catch((x) => x)) as Error;
  assertEquals(other.message, "rpc x failed: HTTP 500");
});

Deno.test("K93 live: a read is sent once more after a dropped connection; a write never is", async () => {
  let n = 0;
  const flaky = ((_url: string) => (n++ === 0 ? Promise.reject(new TypeError("connection reset")) : Promise.resolve(Response.json([{ ok: 1 }])))) as typeof fetch;
  assertEquals(await new RestDb("https://p.supabase.co", "k", flaky).select("t", "select=*"), [{ ok: 1 }]);
  n = 0;
  assertEquals(await new RestDb("https://p.supabase.co", "k", flaky).rpcRead("is_credit_admin", {}), [{ ok: 1 }]);
  n = 0;
  await assertRejects(() => new RestDb("https://p.supabase.co", "k", flaky).rpc("use_drill_chars", { p_n: 5 }));
  assertEquals(n, 1, "a write is sent once");
});
