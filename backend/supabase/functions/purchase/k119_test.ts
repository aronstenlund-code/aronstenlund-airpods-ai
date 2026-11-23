// K119 (D259): the launch week. A setting {starts_at, ends_at, percent} that the app and the site read without signing
// in (GET /purchase), empty until the agents start it; launch products (com.rsolutions.lumen.credits.<n>.launch) give
// the same credits as the ordinary pack, and only when bought within the week plus one day. Fake chain (testpki.ts),
// no real purchase, no model, 0 ElevenLabs.
import { assertEquals } from "jsr:@std/assert@1.0.8";
import { MemoryRateLimiter } from "../_shared/ratelimit.ts";
import { createPurchaseHandler, type LaunchOffer, type LedgerRow, type Product } from "./handler.ts";
import { testPki } from "./testpki.ts";

const BUNDLE = "com.rsolutions.lumen";
const DAY = 86_400_000;
const T0 = Date.UTC(2026, 11, 1, 9, 0, 0); // the launch
const NOW = T0 + 2 * DAY;
const PRODUCTS: Product[] = [
  { product_id: "com.rsolutions.lumen.credits.500", kind: "credits", credits: 500 },
  { product_id: "com.rsolutions.lumen.sub.week", kind: "subscription", credits: 0 },
];

function world(roots: string[], offer: LaunchOffer | null, now = NOW) {
  const ledger: LedgerRow[] = [];
  const h = createPurchaseHandler({
    authenticate: () => Promise.resolve({ id: "u1", isAnonymous: true }),
    rateLimiter: new MemoryRateLimiter(),
    roots, bundleId: BUNDLE, now: () => now,
    launchOffer: () => Promise.resolve(offer),
    store: {
      product: (id) => Promise.resolve(PRODUCTS.find((p) => p.product_id === id) ?? null),
      ledger: (tx) => Promise.resolve(ledger.find((r) => r.transaction_id === tx) ?? null),
      addLedger: (r) => (ledger.some((x) => x.transaction_id === r.transaction_id) ? Promise.resolve(false) : (ledger.push(r), Promise.resolve(true))),
      subByOriginal: () => Promise.resolve(null),
      upsertSub: () => Promise.resolve(),
    },
  });
  const call = async (body: unknown) => {
    const r = await h(new Request("http://x/purchase", { method: "POST", body: JSON.stringify(body) }));
    return { status: r.status, body: await r.json() };
  };
  const get = async () => {
    const r = await h(new Request("http://x/purchase", { method: "GET" }));
    return { status: r.status, body: await r.json() };
  };
  return { call, get, ledger };
}
const WEEK: LaunchOffer = { startsAt: T0, endsAt: T0 + 7 * DAY, percent: 65 };
const tx = (o: Record<string, unknown> = {}) => ({
  transactionId: "2000000001", originalTransactionId: "2000000001", bundleId: BUNDLE, productId: "com.rsolutions.lumen.credits.500.launch",
  purchaseDate: NOW, type: "Consumable", environment: "Sandbox", signedDate: NOW, ...o,
});

Deno.test("K119: GET /purchase gives the launch offer without signing in while the week runs; null before and after", async () => {
  const pki = await testPki();
  const on = await world([pki.rootSha], WEEK).get();
  assertEquals(on.status, 200);
  assertEquals(on.body.launch_offer, { starts_at: new Date(T0).toISOString(), ends_at: new Date(T0 + 7 * DAY).toISOString(), percent: 65, product_suffix: ".launch" });
  assertEquals((await world([pki.rootSha], null).get()).body.launch_offer, null, "empty until the launch");
  assertEquals((await world([pki.rootSha], WEEK, T0 - 1).get()).body.launch_offer, null, "not before the start");
  assertEquals((await world([pki.rootSha], WEEK, T0 + 7 * DAY).get()).body.launch_offer, null, "not after the end");
});

Deno.test("K119: a launch pack bought in the week gives the ordinary pack's credits", async () => {
  const pki = await testPki();
  const w = world([pki.rootSha], WEEK);
  const r = await w.call({ action: "verify", jws: await pki.sign(tx()) });
  assertEquals([r.status, r.body.kind, r.body.added], [200, "credits", 500]);
  assertEquals(w.ledger[0].product_id, "com.rsolutions.lumen.credits.500.launch", "the ledger keeps what was bought");
  // the day after the end still counts (a purchase in the last minutes reaches the server late)
  const late = world([pki.rootSha], WEEK, T0 + 8 * DAY);
  assertEquals((await late.call({ action: "verify", jws: await pki.sign(tx({ purchaseDate: T0 + 7 * DAY + DAY - 60_000 })) })).body.added, 500);
});

Deno.test("K119: a launch pack outside the week (or with no week set) is refused; ordinary packs are untouched", async () => {
  const pki = await testPki();
  const refused = async (offer: LaunchOffer | null, purchaseDate: number) => {
    const r = await world([pki.rootSha], offer).call({ action: "verify", jws: await pki.sign(tx({ purchaseDate })) });
    return [r.status, r.body.error?.code, r.body.reason];
  };
  assertEquals(await refused(WEEK, T0 + 8 * DAY + 1), [422, "launch_offer_over", "launch_window"]);
  assertEquals(await refused(WEEK, T0 - 60_000), [422, "launch_offer_over", "launch_window"]);
  assertEquals(await refused(null, NOW), [422, "launch_offer_over", "launch_window"]);
  const ord = await world([pki.rootSha], null).call({ action: "verify", jws: await pki.sign(tx({ productId: "com.rsolutions.lumen.credits.500" })) });
  assertEquals(ord.body.added, 500);
  // only credit packs have launch versions; anything else is an unknown product as before
  const sub = await world([pki.rootSha], WEEK).call({ action: "verify", jws: await pki.sign(tx({ productId: "com.rsolutions.lumen.sub.week.launch" })) });
  assertEquals([sub.status, sub.body.reason], [422, "product"]);
  const junk = await world([pki.rootSha], WEEK).call({ action: "verify", jws: await pki.sign(tx({ productId: "com.rsolutions.lumen.credits.999999.launch" })) });
  assertEquals([junk.status, junk.body.reason], [422, "product"]);
});

Deno.test("K119: a refund of a launch pack takes its credits back, also after the week", async () => {
  const pki = await testPki();
  const w = world([pki.rootSha], WEEK);
  await w.call({ action: "verify", jws: await pki.sign(tx()) });
  const after = world([pki.rootSha], null, T0 + 30 * DAY);
  after.ledger.push(...w.ledger);
  const n = await pki.sign({ notificationType: "REFUND", data: { bundleId: BUNDLE, signedTransactionInfo: await pki.sign(tx({ revocationDate: T0 + 30 * DAY })) } });
  const r = await after.call({ signedPayload: n });
  assertEquals([r.status, r.body.refunded], [200, 500]);
});

Deno.test("K119: an already credited launch pack sent again after the week (a restore) is 'added 0', never a refusal", async () => {
  const pki = await testPki();
  const w = world([pki.rootSha], WEEK);
  await w.call({ action: "verify", jws: await pki.sign(tx()) });
  const later = world([pki.rootSha], null, T0 + 30 * DAY);
  later.ledger.push(...w.ledger);
  const r = await later.call({ action: "verify", jws: await pki.sign(tx()) });
  assertEquals([r.status, r.body.added], [200, 0]);
});
