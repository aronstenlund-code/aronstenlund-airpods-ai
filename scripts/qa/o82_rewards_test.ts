// O82 (Oscar moln, 2026-11-18): hållout-fall för K98 (D224) välkomstkrediter och inbjudan, direkt mot _shared/rewards.ts.
// Kör: cd backend && deno test --no-lock --no-check --allow-read ../scripts/qa/o82_rewards_test.ts
import { assertEquals, assertRejects } from "jsr:@std/assert@1.0.8";
import { claimInvite, inviteCodeFor, onFirstPlay, type RewardStore, welcome } from "../../backend/supabase/functions/_shared/rewards.ts";

function mem(settings: Record<string, number> = {}) {
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
  const bal = (u: string) => ledger.filter((x) => x.user_id === u).reduce((n, x) => n + x.credits, 0);
  return { s, ledger, bal, keys };
}

Deno.test("O82 1: välkomst 5 000 en gång per konto och en gång per nyckel", async () => {
  const m = mem();
  const a = await welcome(m.s, "u1", "K1");
  const b = await welcome(m.s, "u1", "K1"); // samma konto, samma nyckel
  const c = await welcome(m.s, "u2", "K1"); // annat konto i samma installation (samma nyckel)
  const d = await welcome(m.s, "u1", "K2"); // samma konto, ny nyckel (ominstallation, samma konto)
  console.log("O82 1:", JSON.stringify([a, b, c, d]));
  assertEquals([a.added, b.added, c.added, d.added], [5000, 0, 0, 0]);
  assertEquals([c.reason, m.bal("u1"), m.bal("u2")], ["key_used", 5000, 0]);
});

Deno.test("O82 2: ominstallation = ny nyckel = nytt konto får välkomst igen (känd gräns utan DeviceCheck)", async () => {
  const m = mem();
  await welcome(m.s, "u1", "K1");
  const r = await welcome(m.s, "u9", "K9");
  console.log("O82 2:", JSON.stringify(r));
  assertEquals(r.added, 5000); // dokumenteras i rapporten som risk, inte som fel
});

Deno.test("O82 3: inbjudan: samma kod, 2 000 först vid första spelningen, en gång per inbjuden", async () => {
  const m = mem();
  await welcome(m.s, "inv", "KA");
  await welcome(m.s, "new", "KB");
  const code = await inviteCodeFor(m.s, "inv");
  assertEquals(await inviteCodeFor(m.s, "inv"), code);
  await claimInvite(m.s, "new", code);
  assertEquals(m.bal("inv"), 5000, "belöning före spelning");
  const p1 = await onFirstPlay(m.s, "new"), p2 = await onFirstPlay(m.s, "new");
  console.log("O82 3:", JSON.stringify([p1, p2, m.bal("inv")]));
  assertEquals([p1.rewarded, p2.rewarded, m.bal("inv")], [2000, 0, 7000]);
  await assertRejects(() => claimInvite(m.s, "new", code), Error, "redan");
});

Deno.test("O82 4: nekas: egen kod, ingen nyckel, samma installation, okänd kod", async () => {
  const m = mem();
  await welcome(m.s, "inv", "KA");
  const code = await inviteCodeFor(m.s, "inv");
  const codes: Record<string, string> = {};
  for (const [who, c, setup] of [["inv", code, null], ["nokey", code, null], ["same", code, "KA"], ["x", "zzzzzz", "KX"], ["y", "../etc", "KY"]] as const) {
    if (setup) m.keys.set(setup === "KA" ? "KA2" : setup, who); // "same": en egen nyckel finns inte, se nedan
    try {
      await claimInvite(m.s, who, c);
      codes[who] = "ok";
    } catch (e) {
      codes[who] = (e as { code?: string }).code ?? String(e);
    }
  }
  // "same": konto på samma installation som den som bjöd in delar nyckeln KA
  m.keys.set("KA", "inv");
  const shared = mem();
  await welcome(shared.s, "inv", "KA");
  shared.keys.set("KA", "inv");
  const c2 = await inviteCodeFor(shared.s, "inv");
  // ett andra konto i samma installation kan inte registrera KA (den hör till inv), alltså ingen nyckel alls:
  let same = "ok";
  try {
    await claimInvite(shared.s, "same2", c2);
  } catch (e) {
    same = (e as { code?: string }).code ?? "";
  }
  console.log("O82 4:", JSON.stringify({ ...codes, same2: same }));
  assertEquals([codes.inv, codes.nokey, codes.x, codes.y, same], ["invite_self", "invite_needs_device", "invite_not_found", "invite_not_found", "invite_needs_device"]);
});

Deno.test("O82 5: taket 10 i månaden", async () => {
  const m = mem();
  await welcome(m.s, "inv", "KA");
  const code = await inviteCodeFor(m.s, "inv");
  const got = [];
  for (let i = 0; i < 12; i++) {
    await welcome(m.s, `n${i}`, `KN${i}`);
    await claimInvite(m.s, `n${i}`, code);
    got.push((await onFirstPlay(m.s, `n${i}`)).rewarded);
  }
  console.log("O82 5:", JSON.stringify(got), m.bal("inv"));
  assertEquals(got.filter((x) => x === 2000).length, 10);
  assertEquals(m.bal("inv"), 5000 + 10 * 2000);
});

Deno.test("O82 6: samtidiga första spelningar går inte över taket", async () => {
  const m = mem({ invite_month_max: 3 });
  await welcome(m.s, "inv", "KA");
  const code = await inviteCodeFor(m.s, "inv");
  for (let i = 0; i < 6; i++) (await welcome(m.s, `n${i}`, `KN${i}`), await claimInvite(m.s, `n${i}`, code));
  const r = await Promise.all([0, 1, 2, 3, 4, 5].map((i) => onFirstPlay(m.s, `n${i}`)));
  const paid = r.filter((x) => x.rewarded > 0).length;
  console.log("O82 6: belönade samtidigt", paid, "av 6 med taket 3");
  assertEquals(paid <= 3, true, `${paid} belönade, taket är 3`);
});

Deno.test("O82 7: ett gammalt konto (har spelat förut) kan ta en inbjudan och ger belöning vid nästa start", async () => {
  const m = mem();
  await welcome(m.s, "inv", "KA");
  await welcome(m.s, "old", "KO");
  const code = await inviteCodeFor(m.s, "inv");
  await claimInvite(m.s, "old", code); // inget stoppar ett konto som redan har spelat
  const r = await onFirstPlay(m.s, "old");
  console.log("O82 7:", JSON.stringify(r));
  // registreras som observation (D224 säger "ny användare"): inget assert på beteendet
});
