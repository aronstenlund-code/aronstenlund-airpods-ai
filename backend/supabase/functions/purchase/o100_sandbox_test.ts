// O100 S3 (Oscar): Sandbox purchases (free in TestFlight) gave real credits without limit. Not refused outright –
// App Review buys in Sandbox – but capped per account (SANDBOX_CREDITS_PER_30D within 30 days); Production untouched.
import { assertEquals } from "jsr:@std/assert@1.0.8";
import { MemoryRateLimiter } from "../_shared/ratelimit.ts";
import { createPurchaseHandler, type LedgerRow, type Product, SANDBOX_CREDITS_PER_30D } from "./handler.ts";
import { testPki } from "./testpki.ts";

const BUNDLE = "com.rsolutions.lumen";
const PRODUCTS: Product[] = [{ product_id: "com.rsolutions.lumen.credits.2000", kind: "credits", credits: 2000 }, { product_id: "com.rsolutions.lumen.credits.500", kind: "credits", credits: 500 }];
function world(roots: string[]) {
  const ledger: (LedgerRow & { at: number })[] = [];
  const h = createPurchaseHandler({
    authenticate: () => Promise.resolve({ id: "u1", isAnonymous: true }), rateLimiter: new MemoryRateLimiter(), roots, bundleId: BUNDLE,
    store: {
      product: (id) => Promise.resolve(PRODUCTS.find((p) => p.product_id === id) ?? null),
      ledger: (tx) => Promise.resolve(ledger.find((r) => r.transaction_id === tx) ?? null),
      addLedger: (r) => (ledger.some((x) => x.transaction_id === r.transaction_id) ? Promise.resolve(false) : (ledger.push({ ...r, at: Date.now() }), Promise.resolve(true))),
      subByOriginal: () => Promise.resolve(null), upsertSub: () => Promise.resolve(),
      sandboxCredits: (u, since) => Promise.resolve(ledger.filter((r) => r.user_id === u && r.environment !== "Production" && r.kind === "purchase" && r.at >= Date.parse(since)).reduce((n, r) => n + r.credits, 0)),
    },
  });
  const call = async (body: unknown) => { const r = await h(new Request("http://x/purchase", { method: "POST", body: JSON.stringify(body) })); return { status: r.status, body: await r.json() }; };
  return { call, ledger };
}
const tx = (id: string, o: Record<string, unknown> = {}) => ({ transactionId: id, originalTransactionId: id, bundleId: BUNDLE, productId: "com.rsolutions.lumen.credits.2000", purchaseDate: Date.now(), type: "Consumable", environment: "Sandbox", signedDate: Date.now(), ...o });

Deno.test("O100 S3: Sandbox purchases give credits up to the cap per 30 days, then 422 sandbox_cap; the same one again is 'added 0'", async () => {
  const pki = await testPki();
  const w = world([pki.rootSha]);
  assertEquals(SANDBOX_CREDITS_PER_30D, 2000);
  assertEquals((await w.call({ action: "verify", jws: await pki.sign(tx("s1")) })).body.added, 2000, "App Review can still buy");
  const over = await w.call({ action: "verify", jws: await pki.sign(tx("s2", { productId: "com.rsolutions.lumen.credits.500" })) });
  assertEquals([over.status, over.body.error.code], [422, "sandbox_cap"]);
  assertEquals((await w.call({ action: "verify", jws: await pki.sign(tx("s1")) })).body.added, 0, "a restore is never refused");
});

Deno.test("O100 S3: Production purchases are never capped", async () => {
  const pki = await testPki();
  const w = world([pki.rootSha]);
  for (const id of ["p1", "p2", "p3"]) assertEquals((await w.call({ action: "verify", jws: await pki.sign(tx(id, { environment: "Production" })) })).body.added, 2000);
});
