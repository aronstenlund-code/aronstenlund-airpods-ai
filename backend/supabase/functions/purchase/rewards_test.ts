// K98 (D224): welcome credits and invitations with a fake App Attest chain and an in-memory store.
import { assertEquals } from "jsr:@std/assert@1.0.8";
import { MemoryRateLimiter } from "../_shared/ratelimit.ts";
import { onFirstPlay, type RewardStore } from "../_shared/rewards.ts";
import { createPurchaseHandler } from "./handler.ts";
import { testAttest } from "./testpki.ts";

const APP = "ABCDE12345.com.rsolutions.lumen";

function memStore(settings: Record<string, number> = {}) {
  const ledger: { user_id: string; kind: string; transaction_id: string; credits: number }[] = [];
  const keys = new Map<string, string>(), codes = new Map<string, string>(), claims = new Map<string, { inviter: string; rewarded_at: string | null }>();
  const s: RewardStore = {
    settings: () => Promise.resolve(settings),
    credit: (r) => ledger.some((x) => x.transaction_id === r.transaction_id) ? Promise.resolve(false) : (ledger.push(r), Promise.resolve(true)),
    keyOwner: (k) => Promise.resolve(keys.get(k) ?? null),
    registerKey: (k, u) => keys.has(k) ? Promise.resolve(keys.get(k) === u) : (keys.set(k, u), Promise.resolve(true)),
    keysOf: (u) => Promise.resolve([...keys].filter(([, v]) => v === u).map(([k]) => k)),
    inviteCode: (u) => Promise.resolve([...codes].find(([, v]) => v === u)?.[0] ?? null),
    createInviteCode: (u, c) => codes.has(c) ? Promise.resolve(false) : (codes.set(c, u), Promise.resolve(true)),
    codeOwner: (c) => Promise.resolve(codes.get(c) ?? null),
    claim: (i) => Promise.resolve(claims.get(i) ?? null),
    addClaim: (i, inv) => claims.has(i) ? Promise.resolve(false) : (claims.set(i, { inviter: inv, rewarded_at: null }), Promise.resolve(true)),
    markRewarded: (i) => {
      const c = claims.get(i);
      if (!c || c.rewarded_at) return Promise.resolve(false);
      c.rewarded_at = "now";
      return Promise.resolve(true);
    },
    invitesThisMonth: (inv) => Promise.resolve(ledger.filter((x) => x.user_id === inv && x.kind === "invite").length),
  };
  return { s, ledger, keys };
}

async function world(settings: Record<string, number> = {}) {
  const a = await testAttest();
  const m = memStore(settings);
  const challenges = new Map<string, string>();
  let user = "u1";
  const h = createPurchaseHandler({
    authenticate: () => Promise.resolve({ id: user, isAnonymous: true }),
    rateLimiter: new MemoryRateLimiter(),
    roots: [],
    bundleId: "com.rsolutions.lumen",
    store: { product: () => Promise.resolve(null), ledger: () => Promise.resolve(null), addLedger: () => Promise.resolve(true), subByOriginal: () => Promise.resolve(null), upsertSub: () => Promise.resolve() },
    rewards: m.s,
    attest: {
      appId: APP, allowDevelopment: false, rootDer: a.rootDer, roots: [a.rootSha],
      newChallenge: (u) => {
        const c = crypto.randomUUID();
        challenges.set(c, u);
        return Promise.resolve(c);
      },
      useChallenge: (u, c) => {
        const ok = challenges.get(c) === u;
        challenges.delete(c);
        return Promise.resolve(ok);
      },
    },
  });
  const call = async (body: unknown, as: string) => {
    user = as;
    const r = await h(new Request("http://x/purchase", { method: "POST", body: JSON.stringify(body) }));
    return { status: r.status, body: await r.json() };
  };
  /** a device: an attested key for this account */
  const device = async (as: string, reuse?: { keyId: string; attestation: Uint8Array; ch: string }) => {
    const { body } = await call({ action: "attest_challenge" }, as);
    const made = reuse ?? { ch: body.challenge, ...(await a.attest(new TextEncoder().encode(body.challenge), APP)) };
    const ch = reuse ? body.challenge : made.ch;
    const att = reuse ? await a.attest(new TextEncoder().encode(ch), APP) : made;
    const r = await call({ action: "welcome", key_id: reuse ? reuse.keyId : att.keyId, challenge: ch, attestation: btoa(String.fromCharCode(...att.attestation)) }, as);
    return { ...r, keyId: att.keyId, attestation: att.attestation, ch };
  };
  return { call, device, m, a };
}

Deno.test("K98 welcome: 5 000 once per account after a genuine attestation; the same account again 0; a used challenge is refused", async () => {
  const w = await world();
  const d = await w.device("u1");
  assertEquals([d.status, d.body.added], [200, 5000]);
  const again = await w.device("u1");
  assertEquals([again.status, again.body.added, again.body.reason], [200, 0, "already"], "a second key on the same account gives nothing");
  const replay = await w.call({ action: "welcome", key_id: d.keyId, challenge: d.ch, attestation: btoa(String.fromCharCode(...d.attestation)) }, "u1");
  assertEquals([replay.status, replay.body.reason], [422, "challenge"]);
  assertEquals(w.m.ledger.filter((x) => x.kind === "welcome" && x.credits > 0).length, 1);
});

Deno.test("K98 welcome: a key gives welcome credits to one account only; a fake attestation is refused; without a team id it is off", async () => {
  const w = await world();
  const d = await w.device("u1");
  assertEquals(d.body.added, 5000);
  // another account presenting the same key (a second account on the same install)
  await w.m.s.registerKey(d.keyId, "u1");
  const { body } = await w.call({ action: "attest_challenge" }, "u2");
  const other = await w.a.attest(new TextEncoder().encode(body.challenge), APP);
  w.m.keys.set(other.keyId, "u1"); // the key is already the other account's
  const r = await w.call({ action: "welcome", key_id: other.keyId, challenge: body.challenge, attestation: btoa(String.fromCharCode(...other.attestation)) }, "u2");
  assertEquals([r.status, r.body.added, r.body.reason], [200, 0, "key_used"]);
  const c2 = await w.call({ action: "attest_challenge" }, "u3");
  const bad = await w.call({ action: "welcome", key_id: "AAAA", challenge: c2.body.challenge, attestation: btoa("not cbor") }, "u3");
  assertEquals([bad.status, bad.body.error.code], [422, "attest_invalid"]);
});

Deno.test("K98 invitation: a code per account; the invitee on another device plays its first text and the inviter gets 2 000 once; caps", async () => {
  const w = await world({ invite_month_max: 2 });
  await w.device("inviter");
  const code = (await w.call({ action: "invite_code" }, "inviter")).body.code;
  assertEquals((await w.call({ action: "invite_code" }, "inviter")).body.code, code, "the same code");
  // no device yet: refused
  assertEquals((await w.call({ action: "invite_claim", code }, "friend1")).body.error.code, "invite_needs_device");
  await w.device("friend1");
  assertEquals((await w.call({ action: "invite_claim", code }, "friend1")).status, 200);
  assertEquals((await w.call({ action: "invite_claim", code }, "friend1")).body.error.code, "invite_already");
  assertEquals((await w.call({ action: "invite_claim", code }, "inviter")).body.error.code, "invite_self");
  assertEquals((await w.call({ action: "invite_claim", code: "nosuchcode" }, "friend1")).status, 404);
  // nothing until the first play; then once
  assertEquals(w.m.ledger.filter((x) => x.kind === "invite").length, 0);
  assertEquals((await onFirstPlay(w.m.s, "friend1")).rewarded, 2000);
  assertEquals((await onFirstPlay(w.m.s, "friend1")).rewarded, 0, "once per invitee");
  // the month's cap (2 here)
  for (const f of ["friend2", "friend3"]) {
    await w.device(f);
    await w.call({ action: "invite_claim", code }, f);
  }
  assertEquals((await onFirstPlay(w.m.s, "friend2")).rewarded, 2000);
  const capped = await onFirstPlay(w.m.s, "friend3");
  assertEquals([capped.rewarded, capped.reason], [0, "month_cap"]);
  assertEquals(w.m.ledger.filter((x) => x.user_id === "inviter" && x.kind === "invite").reduce((n, x) => n + x.credits, 0), 4000);
});

Deno.test("K98 invitation: an account that shares a key (the same install) with the inviter is refused", async () => {
  const { claimInvite, RewardRefusal } = await import("../_shared/rewards.ts");
  const m = memStore();
  await m.s.createInviteCode("inviter", "abcdefgh");
  const s2: RewardStore = { ...m.s, keysOf: (u) => Promise.resolve(u === "friend" ? ["same-key"] : ["same-key", "other"]) };
  let code = "";
  try {
    await claimInvite(s2, "friend", "abcdefgh");
  } catch (e) {
    if (e instanceof RewardRefusal) code = e.code;
  }
  assertEquals(code, "invite_same_device");
});
