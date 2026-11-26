// O98 (Oscar moln, 2026-11-26): egna fall för K119 (D259) utöver Kevins k119_test.ts. Falsk kedja (testpki.ts), inget nät,
// inga riktiga köp, ingen modell, 0 ElevenLabs.
// Kör: cd backend && deno test --no-lock --no-check --allow-read ../scripts/qa/o98_launch_test.ts
import { assertEquals } from "jsr:@std/assert@1.0.8";
import { MemoryRateLimiter } from "../../backend/supabase/functions/_shared/ratelimit.ts";
import { createPurchaseHandler, type LaunchOffer, type LedgerRow, type Product } from "../../backend/supabase/functions/purchase/handler.ts";
import { testPki } from "../../backend/supabase/functions/purchase/testpki.ts";

const BUNDLE = "com.rsolutions.lumen";
const DAY = 86_400_000;
const T0 = Date.UTC(2026, 11, 1, 9, 0, 0);
const WEEK: LaunchOffer = { startsAt: T0, endsAt: T0 + 7 * DAY, percent: 65 };
const P = "com.rsolutions.lumen.credits.";
const PRODUCTS: Product[] = [
  { product_id: P + "100", kind: "credits", credits: 100 },
  { product_id: P + "500", kind: "credits", credits: 500 },
  { product_id: P + "2000", kind: "credits", credits: 2000 },
  { product_id: "com.rsolutions.lumen.sub.week", kind: "subscription", credits: 0 },
];

function world(offer: () => Promise<LaunchOffer | null>, now: number, roots: string[], ledger: LedgerRow[] = []) {
  let user = "u1";
  const h = createPurchaseHandler({
    authenticate: () => Promise.resolve({ id: user, isAnonymous: true }),
    rateLimiter: new MemoryRateLimiter(), roots, bundleId: BUNDLE, now: () => now, launchOffer: offer,
    store: {
      product: (id) => Promise.resolve(PRODUCTS.find((p) => p.product_id === id) ?? null),
      ledger: (tx) => Promise.resolve(ledger.find((r) => r.transaction_id === tx) ?? null),
      addLedger: (r) => (ledger.some((x) => x.transaction_id === r.transaction_id) ? Promise.resolve(false) : (ledger.push(r), Promise.resolve(true))),
      subByOriginal: () => Promise.resolve(null),
      upsertSub: () => Promise.resolve(),
    },
  });
  const call = async (body: unknown, as = "u1") => {
    user = as;
    const r = await h(new Request("http://x/purchase", { method: "POST", body: JSON.stringify(body) }));
    return { status: r.status, body: await r.json() };
  };
  return { call, ledger };
}
let n = 0;
const tx = (productId: string, purchaseDate: number, o: Record<string, unknown> = {}) => {
  const id = String(3000000000 + ++n);
  return { transactionId: id, originalTransactionId: id, bundleId: BUNDLE, productId, purchaseDate, type: "Consumable", environment: "Sandbox", signedDate: purchaseDate, ...o };
};
const week = () => Promise.resolve(WEEK);

Deno.test("O98 1: alla tre lanseringspacken ger samma krediter som ordinarie, gånger antal", async () => {
  const pki = await testPki();
  for (const [n, q, want] of [["100", 1, 100], ["500", 2, 1000], ["2000", 3, 6000]] as const) {
    const w = world(week, T0 + DAY, [pki.rootSha]);
    const r = await w.call({ action: "verify", jws: await pki.sign(tx(P + n + ".launch", T0 + DAY, { quantity: q })) });
    assertEquals([r.status, r.body.added], [200, want], `${n}.launch × ${q}`);
  }
});

Deno.test("O98 2: ordinarie pack ges som förut före, under och efter veckan, och utan vecka", async () => {
  const pki = await testPki();
  for (const [o, t] of [[() => Promise.resolve(null), T0], [week, T0 - DAY], [week, T0 + DAY], [week, T0 + 30 * DAY]] as const) {
    const w = world(o, t, [pki.rootSha]);
    const r = await w.call({ action: "verify", jws: await pki.sign(tx(P + "500", t)) });
    assertEquals([r.status, r.body.added], [200, 500]);
  }
});

Deno.test("O98 3: gränserna – start och slut + 1 dygn räknas, en millisekund före/efter nekas, och ett nekat köp skriver inget", async () => {
  const pki = await testPki();
  const at = async (d: number) => {
    const w = world(week, T0 + 9 * DAY, [pki.rootSha]);
    const r = await w.call({ action: "verify", jws: await pki.sign(tx(P + "500.launch", d)) });
    return [r.status, r.body.added ?? r.body.error?.code, w.ledger.length];
  };
  assertEquals(await at(T0), [200, 500, 1]);
  assertEquals(await at(T0 + 8 * DAY), [200, 500, 1]);
  assertEquals(await at(T0 - 1), [422, "launch_offer_over", 0]);
  assertEquals(await at(T0 + 8 * DAY + 1), [422, "launch_offer_over", 0]);
});

Deno.test("O98 4: om inställningen inte går att läsa nekas lanseringspack, ordinarie går igenom", async () => {
  const pki = await testPki();
  const broken = () => Promise.reject(new Error("db nere"));
  const w = world(broken, T0 + DAY, [pki.rootSha]);
  const a = await w.call({ action: "verify", jws: await pki.sign(tx(P + "500.launch", T0 + DAY)) });
  const b = await w.call({ action: "verify", jws: await pki.sign(tx(P + "500", T0 + DAY)) });
  assertEquals([a.status, a.body.error?.code, b.status, b.body.added], [422, "launch_offer_over", 200, 500]);
});

Deno.test("O98 5: ett lanseringsköp på ett annat konto ger 409 också efter veckan (återställningen släpper inte igenom det)", async () => {
  const pki = await testPki();
  const ledger: LedgerRow[] = [];
  const t = tx(P + "500.launch", T0 + DAY);
  await world(week, T0 + DAY, [pki.rootSha], ledger).call({ action: "verify", jws: await pki.sign(t) }, "u1");
  const later = world(() => Promise.resolve(null), T0 + 30 * DAY, [pki.rootSha], ledger);
  const r = await later.call({ action: "verify", jws: await pki.sign(t) }, "u2");
  assertEquals([r.status, r.body.error?.code, ledger.length], [409, "purchase_other_account", 1]);
});

Deno.test("O98 6: Apples rot som enda rot (som i drift) nekar den falska kedjan också för lanseringspack", async () => {
  const pki = await testPki();
  const { APPLE_ROOT_G3_SHA256 } = await import("../../backend/supabase/functions/purchase/jws.ts");
  const w = world(week, T0 + DAY, [APPLE_ROOT_G3_SHA256]);
  const r = await w.call({ action: "verify", jws: await pki.sign(tx(P + "500.launch", T0 + DAY)) });
  assertEquals([r.status, r.body.error?.code, w.ledger.length], [422, "purchase_invalid", 0]);
});
