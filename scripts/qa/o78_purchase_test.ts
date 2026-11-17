// O78 (Oscar moln, 2026-11-17): hållout-fall för K94 (köp, D218/D214), skrivna innan jag läste Kevins testfall i detalj.
// Kör: cd backend && deno test --no-lock --no-check --allow-read ../scripts/qa/o78_purchase_test.ts
// Falsk kedja från Kevins testpki.ts (skapas vid körningen, inga nycklar i repot). Inga riktiga köp, inget nät.
import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { MemoryRateLimiter } from "../../backend/supabase/functions/_shared/ratelimit.ts";
import { makeUseQuota, type WalletStore } from "../../backend/supabase/functions/_shared/wallet.ts";
import { APPLE_ROOT_G3_SHA256 } from "../../backend/supabase/functions/purchase/jws.ts";
import { createPurchaseHandler, type LedgerRow, type Product, type SubRow } from "../../backend/supabase/functions/purchase/handler.ts";
import { testPki } from "../../backend/supabase/functions/purchase/testpki.ts";

const BUNDLE = "com.rsolutions.lumen";
const CRED = "com.rsolutions.lumen.credits.500", SUB = "com.rsolutions.lumen.sub.week";
const PRODUCTS: Product[] = [{ product_id: CRED, kind: "credits", credits: 500 }, { product_id: SUB, kind: "subscription", credits: 0 }];
const DAY = 864e5;

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
      upsertSub: (r) => (subs.set(r.original_transaction_id, { ...r }), Promise.resolve()),
    },
  });
  const call = async (body: unknown, as = "u1") => {
    user = as;
    const r = await h(new Request("http://x/purchase", { method: "POST", body: JSON.stringify(body) }));
    return { status: r.status, body: await r.json() };
  };
  const balance = (u: string) => ledger.filter((r) => r.user_id === u).reduce((n, r) => n + r.credits, 0);
  return { call, ledger, subs, balance };
}
const tx = (o: Record<string, unknown> = {}) => ({
  transactionId: "2000000001", originalTransactionId: "2000000001", bundleId: BUNDLE, productId: CRED,
  purchaseDate: Date.now(), type: "Consumable", environment: "Sandbox", signedDate: Date.now(), ...o,
});
const subTx = (o: Record<string, unknown> = {}) => tx({ transactionId: "3000000001", originalTransactionId: "3000000001", productId: SUB, type: "Auto-Renewable Subscription", expiresDate: Date.now() + 7 * DAY, ...o });
const b64u = (s: string) => btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
const unb64u = (s: string) => atob(s.replace(/-/g, "+").replace(/_/g, "/") + "=".repeat((4 - (s.length % 4)) % 4));

Deno.test("O78 1: förfalskningar nekas (fel signatur, ändrad payload, alg none/HS256, utan markör, utgånget löv, kort kedja, annan rot)", async () => {
  const pki = await testPki(), other = await testPki();
  const w = world([pki.rootSha]);
  const good = await pki.sign(tx());
  const [h, p, s] = good.split(".");
  const header = JSON.parse(unb64u(h));
  const tampered = `${h}.${b64u(JSON.stringify({ ...tx(), quantity: 100 }))}.${s}`;
  const none = `${b64u(JSON.stringify({ ...header, alg: "none" }))}.${p}.`;
  const hs = `${b64u(JSON.stringify({ ...header, alg: "HS256" }))}.${p}.${s}`;
  const short = `${b64u(JSON.stringify({ ...header, x5c: header.x5c.slice(0, 1) }))}.${p}.${s}`;
  const mixed = (await other.sign(tx())).split(".");
  const swapSig = `${h}.${p}.${mixed[2]}`;
  const cases: Record<string, string> = {
    "fel signatur": await pki.sign(tx(), { badSig: true }), "ändrad payload": tampered, "alg none": none, "alg HS256": hs,
    "utan Apple-markör": await pki.sign(tx(), { noMarker: true }), "utgånget löv": await (await testPki({ leafExpired: true })).sign(tx()),
    "bara lövet": short, "annan kedjas signatur": swapSig, "annan rot": await other.sign(tx()), "skräp": "a.b.c", "tom": "",
  };
  const out: Record<string, unknown> = {};
  for (const [name, jws] of Object.entries(cases)) {
    const r = await w.call({ action: "verify", jws });
    out[name] = [r.status, r.body.reason ?? r.body.error?.code];
    assert(r.status === 422 || r.status === 400, `${name}: ${JSON.stringify(r)}`);
  }
  console.log("O78 1:", JSON.stringify(out));
  assertEquals(w.ledger.length, 0);
});

Deno.test("O78 2: produktionens rot (Apple G3) nekar den falska kedjan", async () => {
  const pki = await testPki();
  const r = await world([APPLE_ROOT_G3_SHA256]).call({ action: "verify", jws: await pki.sign(tx()) });
  assertEquals([r.status, r.body.reason], [422, "root"]);
});

Deno.test("O78 3: fel bundle-id och okänd produkt nekas, inget läggs till", async () => {
  const pki = await testPki();
  const w = world([pki.rootSha]);
  const a = await w.call({ action: "verify", jws: await pki.sign(tx({ bundleId: "com.evil.app" })) });
  const b = await w.call({ action: "verify", jws: await pki.sign(tx({ productId: "com.rsolutions.lumen.credits.999999" })) });
  assertEquals([a.status, a.body.reason, b.status, b.body.reason], [422, "bundle", 422, "product"]);
  assertEquals(w.ledger.length, 0);
});

Deno.test("O78 4: samma transaktion två gånger ger krediter en gång, också från ett annat konto (409) och med appAccountToken", async () => {
  const pki = await testPki();
  const w = world([pki.rootSha]);
  const j = await pki.sign(tx());
  const r1 = await w.call({ action: "verify", jws: j }), r2 = await w.call({ action: "verify", jws: j }), r3 = await w.call({ action: "verify", jws: j }, "u2");
  const r4 = await w.call({ action: "verify", jws: await pki.sign(tx({ transactionId: "2000000009", appAccountToken: "U1" })) }, "u2");
  console.log("O78 4:", JSON.stringify([r1.body.added, r2.body.added, r3.status, r4.status]));
  assertEquals([r1.body.added, r2.body.added, r3.status, r4.status], [500, 0, 409, 409]);
  assertEquals([w.balance("u1"), w.balance("u2")], [500, 0]);
});

Deno.test("O78 5: prenumeration: aktiv till utgång, äldre transaktion flyttar inte slutet bakåt, utgången = inte aktiv", async () => {
  const pki = await testPki();
  const w = world([pki.rootSha]);
  const now = Date.now();
  const a = await w.call({ action: "verify", jws: await pki.sign(subTx({ transactionId: "3000000002", expiresDate: now + 14 * DAY })) });
  const b = await w.call({ action: "verify", jws: await pki.sign(subTx({ expiresDate: now + 7 * DAY })) });
  assertEquals([a.body.active, b.body.active], [true, true]);
  assertEquals(Date.parse(b.body.until) >= now + 13 * DAY, true, JSON.stringify(b.body));
  const w2 = world([pki.rootSha]);
  const c = await w2.call({ action: "verify", jws: await pki.sign(subTx({ expiresDate: now - DAY })) });
  assertEquals(c.body.active, false);
});

Deno.test("O78 6: återbetalning (notifiering) drar tillbaka köpta krediter en gång", async () => {
  const pki = await testPki();
  const w = world([pki.rootSha]);
  await w.call({ action: "verify", jws: await pki.sign(tx()) });
  const note = async (type: string, t: Record<string, unknown>) =>
    w.call({ signedPayload: await pki.sign({ notificationType: type, data: { bundleId: BUNDLE, signedTransactionInfo: await pki.sign(t) } }) });
  const r1 = await note("REFUND", tx({ revocationDate: Date.now() }));
  const r2 = await note("REFUND", tx({ revocationDate: Date.now() }));
  console.log("O78 6:", JSON.stringify([r1, r2, w.balance("u1")]));
  assertEquals(w.balance("u1"), 0);
  // en notifiering med fel signatur nekas
  const bad = await w.call({ signedPayload: await pki.sign({ notificationType: "REFUND", data: {} }, { badSig: true }) });
  assertEquals(bad.status, 422);
});

Deno.test("O78 7: återbetald prenumeration förblir avslutad när appen skickar det gamla köpet igen", async () => {
  const pki = await testPki();
  const w = world([pki.rootSha]);
  const original = await pki.sign(subTx());
  await w.call({ action: "verify", jws: original });
  const r = await w.call({ signedPayload: await pki.sign({ notificationType: "REFUND", data: { bundleId: BUNDLE, signedTransactionInfo: await pki.sign(subTx({ revocationDate: Date.now() })) } }) });
  const afterRefund = { ...w.subs.get("3000000001")! };
  const again = await w.call({ action: "verify", jws: original }); // samma JWS som telefonen fick vid köpet
  const after = w.subs.get("3000000001")!;
  console.log("O78 7:", JSON.stringify({ refund: r.body, afterRefund, again: again.body, after }));
  assertEquals([after.status, again.body.active], ["revoked", false], "återbetald prenumeration blev aktiv igen");
});

Deno.test("O78 8: plånboken: prenumerationens vecka först, sedan gratis, sist köpta; räcker det inte räknas inget", async () => {
  const st = { admin: false, mUsed: 0, mLim: 1500, bought: 500, until: null as string | null, wUsed: 0, wLim: 20000 };
  const s: WalletStore = {
    isAdmin: () => Promise.resolve(st.admin),
    monthly: (_u, n) => {
      if (st.mUsed + n > st.mLim) return Promise.resolve({ ok: false, used: st.mUsed, lim: st.mLim });
      st.mUsed += n;
      return Promise.resolve({ ok: true, used: st.mUsed, lim: st.mLim });
    },
    refundMonthly: (_u, n) => (st.mUsed -= n, Promise.resolve()),
    purchased: () => Promise.resolve(st.bought),
    usePurchased: (_u, n) => (st.bought >= n ? (st.bought -= n, Promise.resolve(true)) : Promise.resolve(false)),
    subscriptionUntil: () => Promise.resolve(st.until),
    week: (_u, n, lim) => {
      if (st.wUsed + n > lim) return Promise.resolve({ ok: false, used: st.wUsed });
      st.wUsed += n;
      return Promise.resolve({ ok: true, used: st.wUsed });
    },
    weekLimit: () => Promise.resolve(st.wLim),
  };
  const use = makeUseQuota(s);
  const a = await use("u", 1200); // bara gratis
  assertEquals([a.ok, st.mUsed, st.bought], [true, 1200, 500]);
  const b = await use("u", 600); // 300 gratis + 300 köpta
  assertEquals([b.ok, st.mUsed, st.bought], [true, 1500, 200]);
  const c = await use("u", 201); // räcker inte: inget räknas
  assertEquals([c.ok, st.mUsed, st.bought], [false, 1500, 200]);
  st.until = new Date(Date.now() + 7 * DAY).toISOString();
  const d = await use("u", 20000); // veckan först
  assertEquals([d.ok, st.wUsed, st.mUsed, st.bought], [true, 20000, 1500, 200]);
  const e = await use("u", 300); // veckan slut: 200 köpta räcker inte till 300
  assertEquals([e.ok, st.wUsed, st.bought], [false, 20000, 200]);
  st.until = null; // prenumerationen slutar
  const f = await use("u", 0);
  console.log("O78 8:", JSON.stringify({ a: a.wallet, b: b.wallet, d: d.wallet, f: f.wallet }));
  assertEquals([f.wallet?.subscription.active, f.lim - f.used], [false, 200]);
});
