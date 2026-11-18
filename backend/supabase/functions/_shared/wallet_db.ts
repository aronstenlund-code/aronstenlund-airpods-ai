/** K94: the wallet (wallet.ts) on the database's RPCs (service_role). Missing RPCs read as "none", never as "admin". */
import type { RestDb } from "./restdb.ts";
import { makeUseQuota, type WalletStore } from "./wallet.ts";
import { HttpError } from "./errors.ts";
import { memo } from "./memo.ts";

export function walletStore(db: RestDb): WalletStore {
  // K100: the week's limit is a setting: read at most once a minute per instance
  const weekLimit = memo(async () => {
    const rows = (await db.select("drill_settings", "select=value&key=eq.subscription_week_chars")) as { value: number }[];
    return Number(rows[0]?.value) || 20_000; // D224
  });
  const one = <T>(r: unknown) => (Array.isArray(r) ? r[0] : r) as T;
  return {
    isAdmin: async (u) => (await db.rpc("is_credit_admin", { p_user: u }).catch(() => false)) === true,
    monthly: async (u, n) => {
      try {
        return one<{ ok: boolean; used: number; lim: number }>(await db.rpc("use_drill_chars", { p_user: u, p_n: n })) ?? { ok: false, used: 0, lim: 0 };
      } catch (e) {
        // K101: a still valid token of a deleted account (its quota row cannot be made: foreign key 23503)
        if (/ 23503$/.test(String((e as Error)?.message ?? ""))) throw new HttpError(401, "account_deleted", "Kontot finns inte längre.");
        throw e;
      }
    },
    refundMonthly: async (u, n) => void await db.rpc("refund_drill_chars", { p_user: u, p_n: n }),
    purchased: async (u) => Number(await db.rpc("credit_balance", { p_user: u }).catch(() => 0)) || 0,
    usePurchased: async (u, n) => (await db.rpc("use_purchased_credits", { p_user: u, p_n: n })) === true,
    subscriptionUntil: async (u) => {
      const rows = (await db.select("store_subscriptions", `select=expires_at&user_id=eq.${encodeURIComponent(u)}&status=eq.active&expires_at=gt.${encodeURIComponent(new Date().toISOString())}&order=expires_at.desc&limit=1`).catch(() => [])) as { expires_at: string }[];
      return rows[0]?.expires_at ?? null;
    },
    week: async (u, n, lim) => one<{ ok: boolean; used: number }>(await db.rpc("use_week_chars", { p_user: u, p_n: n, p_lim: lim })) ?? { ok: false, used: 0 },
    gifts: async (u) => {
      const rows = (await db.select("credit_ledger", `select=kind,credits&user_id=eq.${encodeURIComponent(u)}&kind=in.(welcome,invite,use)&limit=10000`)) as { kind: string; credits: number }[];
      const sum = (k: string) => rows.filter((r) => r.kind === k).reduce((n, r) => n + (Number(r.credits) || 0), 0);
      return { welcome: sum("welcome"), invite: sum("invite"), used: -sum("use") };
    },
    weekLimit: () => weekLimit().catch(() => 20_000),
  };
}

export const useQuotaFromDb = (db: RestDb) => makeUseQuota(walletStore(db));
