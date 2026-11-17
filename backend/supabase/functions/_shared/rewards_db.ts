/** K98: RewardStore on the database (service_role tables; see migrations 20261117220001–4). */
import type { RestDb } from "./restdb.ts";
import type { RewardStore } from "./rewards.ts";

export function rewardStore(db: RestDb): RewardStore {
  const q = (s: string) => encodeURIComponent(s);
  const one = async <T>(table: string, query: string) => ((await db.select(table, `${query}&limit=1`)) as T[])[0] ?? null;
  return {
    settings: async () => Object.fromEntries(((await db.select("drill_settings", "select=key,value")) as { key: string; value: number }[]).map((r) => [r.key, Number(r.value)])),
    credit: async (r) => {
      if (await one("credit_ledger", `select=id&transaction_id=eq.${q(r.transaction_id)}`)) return false;
      await db.insertIgnoreDuplicate("credit_ledger", r, "transaction_id");
      const mine = await one<{ user_id: string }>("credit_ledger", `select=user_id&transaction_id=eq.${q(r.transaction_id)}`);
      return mine?.user_id === r.user_id;
    },
    keyOwner: async (k) => (await one<{ user_id: string }>("app_attest_keys", `select=user_id&key_id=eq.${q(k)}`))?.user_id ?? null,
    registerKey: async (k, u) => {
      await db.insertIgnoreDuplicate("app_attest_keys", { key_id: k, user_id: u }, "key_id");
      return (await one<{ user_id: string }>("app_attest_keys", `select=user_id&key_id=eq.${q(k)}`))?.user_id === u;
    },
    keysOf: async (u) => ((await db.select("app_attest_keys", `select=key_id&user_id=eq.${q(u)}&limit=20`)) as { key_id: string }[]).map((r) => r.key_id),
    inviteCode: async (u) => (await one<{ code: string }>("invite_codes", `select=code&user_id=eq.${q(u)}`))?.code ?? null,
    createInviteCode: async (u, c) => {
      await db.insertIgnoreDuplicate("invite_codes", { code: c, user_id: u }, "code");
      return (await one<{ user_id: string }>("invite_codes", `select=user_id&code=eq.${q(c)}`))?.user_id === u;
    },
    codeOwner: async (c) => (await one<{ user_id: string }>("invite_codes", `select=user_id&code=eq.${q(c)}`))?.user_id ?? null,
    claim: async (i) => {
      const r = await one<{ inviter_id: string; rewarded_at: string | null }>("invite_claims", `select=inviter_id,rewarded_at&invitee_id=eq.${q(i)}`);
      return r ? { inviter: r.inviter_id, rewarded_at: r.rewarded_at } : null;
    },
    addClaim: async (i, inv) => {
      await db.insertIgnoreDuplicate("invite_claims", { invitee_id: i, inviter_id: inv }, "invitee_id");
      return (await one<{ inviter_id: string }>("invite_claims", `select=inviter_id&invitee_id=eq.${q(i)}`))?.inviter_id === inv;
    },
    markRewarded: async (i) => (await db.updateWhere("invite_claims", `invitee_id=eq.${q(i)}&rewarded_at=is.null`, { rewarded_at: new Date().toISOString() })) > 0,
    invitesThisMonth: async (inv) => {
      const d = new Date();
      const start = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), 1)).toISOString();
      return ((await db.select("credit_ledger", `select=id&user_id=eq.${q(inv)}&kind=eq.invite&created_at=gte.${q(start)}&limit=100`)) as unknown[]).length;
    },
  };
}
