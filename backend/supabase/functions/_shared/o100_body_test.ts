// O100 S5 (Oscar): some bodies were read before sign-in without a limit (a chunked body has no content-length, which
// counted as 0). Now the purchase and the web guard's demo check never read an unbounded body.
import { assertEquals } from "jsr:@std/assert@1.0.8";
import { MemoryRateLimiter } from "./ratelimit.ts";
import { withWebGuard } from "./webguard.ts";
import { createPurchaseHandler } from "../purchase/handler.ts";

/** A chunked body (no content-length) of n bytes, and how much of it was read. */
function chunked(n: number) {
  let sent = 0;
  const body = new ReadableStream<Uint8Array>({
    pull(c) {
      if (sent >= n) return c.close();
      const k = Math.min(16_384, n - sent);
      sent += k;
      c.enqueue(new Uint8Array(k).fill(32));
    },
  });
  return { body, read: () => sent };
}

Deno.test("O100 S5: /purchase stops reading a body over 64 KB (no content-length) with 413, before sign-in", async () => {
  let authed = 0;
  const h = createPurchaseHandler({ authenticate: () => (authed++, Promise.resolve({ id: "u", isAnonymous: true })), rateLimiter: new MemoryRateLimiter(), roots: [], bundleId: "b",
    store: { product: () => Promise.resolve(null), ledger: () => Promise.resolve(null), addLedger: () => Promise.resolve(true), subByOriginal: () => Promise.resolve(null), upsertSub: () => Promise.resolve() } });
  const c = chunked(5_000_000);
  const r = await h(new Request("http://x/purchase", { method: "POST", body: c.body }));
  assertEquals(r.status, 413);
  assertEquals(authed, 0);
  assertEquals(c.read() < 200_000, true, `read ${c.read()} bytes`);
});

Deno.test("O100 S5: the web guard's demo check reads no body without a content-length (it is then an ordinary web call)", async () => {
  const c = chunked(5_000_000);
  const h = withWebGuard(() => Promise.resolve(new Response("ok")), { limiter: new MemoryRateLimiter(), demo: true });
  await h(new Request("http://x/answer", { method: "POST", headers: { origin: "https://earmind.vercel.app" }, body: c.body }));
  assertEquals(c.read() < 200_000, true, `read ${c.read()} bytes`);
});
