// K94 (D218): purchases with a fake chain made at test time (testpki.ts); no real purchase, nothing leaves the test.
import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { MemoryRateLimiter } from "../_shared/ratelimit.ts";
import { makeUseQuota, type WalletStore } from "../_shared/wallet.ts";
import { APPLE_ROOT_G3_SHA256, verifyJws } from "./jws.ts";
import { createPurchaseHandler, type LedgerRow, type Product, type SubRow } from "./handler.ts";
import { testPki } from "./testpki.ts";

const BUNDLE = "com.rsolutions.lumen";
const PRODUCTS: Product[] = [
  { product_id: "com.rsolutions.lumen.credits.500", kind: "credits", credits: 500 },
  { product_id: "com.rsolutions.lumen.sub.week", kind: "subscription", credits: 0 },
];

function world(roots: string[]) {
  const ledger: LedgerRow[] = [];
  const subs = new Map<string, SubRow>();
  let user = "u1";
  const h = createPurchaseHandler({
    authenticate: () => Promise.resolve({ id: user, isAnonymous: true }),
    rateLimiter: new MemoryRateLimiter(),
    roots,
    bundleId: BUNDLE,
    store: {
      product: (id) => Promise.resolve(PRODUCTS.find((p) => p.product_id === id) ?? null),
      ledger: (tx) => Promise.resolve(ledger.find((r) => r.transaction_id === tx) ?? null),
      addLedger: (r) => {
        if (ledger.some((x) => x.transaction_id === r.transaction_id)) return Promise.resolve(false);
        ledger.push(r);
        return Promise.resolve(true);
      },
      subByOriginal: (o) => Promise.resolve(subs.get(o) ?? null),
      upsertSub: (r) => (subs.set(r.original_transaction_id, r), Promise.resolve()),
    },
  });
  const call = async (body: unknown, as = "u1") => {
    user = as;
    const r = await h(new Request("http://x/purchase", { method: "POST", body: JSON.stringify(body) }));
    return { status: r.status, body: await r.json() };
  };
  return { call, ledger, subs };
}

const tx = (o: Record<string, unknown> = {}) => ({
  transactionId: "1000000001", originalTransactionId: "1000000001", bundleId: BUNDLE, productId: "com.rsolutions.lumen.credits.500",
  purchaseDate: Date.now(), type: "Consumable", environment: "Sandbox", signedDate: Date.now(), ...o,
});

Deno.test("K94 verify: a bought pack adds its credits once; the same transaction again adds 0", async () => {
  const pki = await testPki();
  const w = world([pki.rootSha]);
  const a = await w.call({ action: "verify", jws: await pki.sign(tx()) });
  assertEquals([a.status, a.body.kind, a.body.added], [200, "credits", 500]);
  const b = await w.call({ action: "verify", jws: await pki.sign(tx()) });
  assertEquals([b.status, b.body.added], [200, 0]);
  assertEquals(w.ledger.length, 1);
  // quantity 2 = 1 000
  assertEquals((await w.call({ action: "verify", jws: await pki.sign(tx({ transactionId: "1000000002", quantity: 2 })) })).body.added, 1000);
});

Deno.test("K94 verify refuses: not Apple's root, a bad signature, no marker, an expired certificate, another app, an unknown product", async () => {
  const pki = await testPki();
  const reason = async (roots: string[], jws: string) => (await world(roots).call({ action: "verify", jws })).body.reason;
  assertEquals(await reason([APPLE_ROOT_G3_SHA256], await pki.sign(tx())), "root", "production accepts only Apple's root");
  assertEquals(await reason([pki.rootSha], await pki.sign(tx(), { badSig: true })), "signature");
  assertEquals(await reason([pki.rootSha], await pki.sign(tx(), { noMarker: true })), "marker");
  const old = await testPki({ leafExpired: true });
  assertEquals(await reason([old.rootSha], await old.sign(tx())), "expired");
  assertEquals(await reason([pki.rootSha], await pki.sign(tx({ bundleId: "com.other.app" }))), "bundle");
  assertEquals(await reason([pki.rootSha], await pki.sign(tx({ productId: "com.rsolutions.lumen.free.money" }))), "product");
  assertEquals((await world([pki.rootSha]).call({ action: "verify", jws: "a.b" })).status, 422);
  assertEquals((await world([pki.rootSha]).call({ action: "verify" })).status, 400);
});

Deno.test("K94 a purchase belongs to its account: another account's transaction or appAccountToken is 409", async () => {
  const pki = await testPki();
  const w = world([pki.rootSha]);
  await w.call({ action: "verify", jws: await pki.sign(tx()) }, "u1");
  assertEquals((await w.call({ action: "verify", jws: await pki.sign(tx()) }, "u2")).status, 409);
  assertEquals((await w.call({ action: "verify", jws: await pki.sign(tx({ transactionId: "9", appAccountToken: "u1" })) }, "u2")).status, 409);
  assertEquals((await w.call({ action: "verify", jws: await pki.sign(tx({ transactionId: "10", appAccountToken: "U2" })) }, "u2")).body.added, 500);
});

Deno.test("K94 subscription: active until its end; an older transaction never moves the end back", async () => {
  const pki = await testPki();
  const w = world([pki.rootSha]);
  const end = Date.now() + 7 * 864e5;
  const s = { productId: "com.rsolutions.lumen.sub.week", type: "Auto-Renewable Subscription", transactionId: "2000000002", originalTransactionId: "2000000001" };
  const a = await w.call({ action: "verify", jws: await pki.sign(tx({ ...s, expiresDate: end })) });
  assertEquals([a.body.kind, a.body.active, a.body.until], ["subscription", true, new Date(end).toISOString()]);
  await w.call({ action: "verify", jws: await pki.sign(tx({ ...s, transactionId: "2000000001", expiresDate: end - 7 * 864e5 })) });
  assertEquals(w.subs.get("2000000001")!.expires_at, new Date(end).toISOString());
});

Deno.test("K94 notifications v2: renewal extends, refund takes credits back once or ends the subscription, expiry, bad signature 422", async () => {
  const pki = await testPki();
  const w = world([pki.rootSha]);
  await w.call({ action: "verify", jws: await pki.sign(tx()) });
  const note = async (type: string, t: Record<string, unknown>, bad = false) =>
    await w.call({ signedPayload: await pki.sign({ notificationType: type, data: { bundleId: BUNDLE, signedTransactionInfo: await pki.sign(tx(t)) }, signedDate: Date.now() }, { badSig: bad }) });
  const r = await note("REFUND", { revocationDate: Date.now() });
  assertEquals([r.status, r.body.refunded], [200, 500]);
  await note("REFUND", { revocationDate: Date.now() });
  assertEquals(w.ledger.map((x) => x.credits), [500, -500], "taken back once");
  const s = { productId: "com.rsolutions.lumen.sub.week", type: "Auto-Renewable Subscription", transactionId: "3000000001", originalTransactionId: "3000000001" };
  const e1 = Date.now() + 864e5, e2 = Date.now() + 8 * 864e5;
  await w.call({ action: "verify", jws: await pki.sign(tx({ ...s, expiresDate: e1 })) });
  assertEquals((await note("DID_RENEW", { ...s, transactionId: "3000000002", expiresDate: e2 })).body.status, "active");
  assertEquals(w.subs.get("3000000001")!.expires_at, new Date(e2).toISOString());
  assertEquals((await note("EXPIRED", { ...s, expiresDate: e2 })).body.status, "expired");
  assertEquals((await note("REFUND", { ...s, revocationDate: Date.now() })).body.status, "revoked");
  assertEquals((await note("DID_RENEW", { ...s, originalTransactionId: "unknown" })).body.ignored, "unknown_subscription");
  assertEquals((await note("REFUND", {}, true)).status, 422, "a notification not signed by the chain is refused");
});

Deno.test("K94 the payload of a JWS is only read after the chain and the signature hold", async () => {
  const pki = await testPki();
  const p = await verifyJws<{ productId: string }>(await pki.sign(tx()), { roots: [pki.rootSha] });
  assertEquals(p.productId, "com.rsolutions.lumen.credits.500");
});

// ---------- the wallet: subscription week, then the month's free credits, then bought credits ----------
function wallet(o: { free?: number; bought?: number; sub?: boolean; admin?: boolean; weekLimit?: number }) {
  const st = { mUsed: 0, mLim: o.free ?? 1500, bought: o.bought ?? 0, week: 0 };
  const store: WalletStore = {
    isAdmin: () => Promise.resolve(!!o.admin),
    monthly: (_u, n) => {
      if (n > 0 && st.mUsed + n > st.mLim) return Promise.resolve({ ok: false, used: st.mUsed, lim: st.mLim });
      st.mUsed += Math.max(0, n);
      return Promise.resolve({ ok: true, used: st.mUsed, lim: st.mLim });
    },
    refundMonthly: (_u, n) => (st.mUsed = Math.max(0, st.mUsed - n), Promise.resolve()),
    purchased: () => Promise.resolve(st.bought),
    usePurchased: (_u, n) => Promise.resolve(st.bought >= n ? (st.bought -= n, true) : false),
    subscriptionUntil: () => Promise.resolve(o.sub ? "2026-11-24T10:00:00.000Z" : null),
    week: (_u, n, lim) => {
      if (n > 0 && st.week + n > lim) return Promise.resolve({ ok: false, used: st.week });
      st.week = Math.max(0, st.week + n);
      return Promise.resolve({ ok: true, used: st.week });
    },
    weekLimit: () => Promise.resolve(o.weekLimit ?? 40_000),
  };
  return { use: makeUseQuota(store), st };
}

Deno.test("K94 wallet: free credits first, then bought; not enough together = refused and nothing counted", async () => {
  const w = wallet({ free: 1500, bought: 500 });
  const a = await w.use("u", 1800);
  assertEquals([a.ok, w.st.mUsed, w.st.bought, a.lim - a.used], [true, 1500, 200, 200]);
  assertEquals([a.wallet!.monthly_free, a.wallet!.purchased, a.wallet!.subscription.active], [0, 200, false]);
  const b = await w.use("u", 300);
  assertEquals([b.ok, w.st.mUsed, w.st.bought], [false, 1500, 200], "refused, nothing counted");
  const q = await w.use("u", 0);
  assertEquals(q.lim - q.used, 200);
});

Deno.test("K94 wallet: a subscription covers 40 000 a week before anything else; beyond it the free and bought credits", async () => {
  const w = wallet({ sub: true, free: 1500, bought: 0, weekLimit: 40_000 });
  const a = await w.use("u", 39_000);
  assertEquals([a.ok, w.st.week, w.st.mUsed], [true, 39_000, 0]);
  const b = await w.use("u", 2000);
  assertEquals([b.ok, w.st.week, w.st.mUsed], [true, 40_000, 1000]);
  assertEquals(b.wallet!.subscription, { active: true, until: "2026-11-24T10:00:00.000Z", week_used: 40_000, week_limit: 40_000 });
  assertEquals((await w.use("u", 600)).ok, false, "500 left in all");
  assertEquals([w.st.week, w.st.mUsed], [40_000, 1000]);
});

Deno.test("K94 wallet: an admin (K93) is never counted", async () => {
  const w = wallet({ admin: true, free: 0 });
  const a = await w.use("u", 99_999);
  assertEquals([a.ok, a.unlimited, w.st.mUsed], [true, true, 0]);
});
