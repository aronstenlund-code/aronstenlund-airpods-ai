/** K94: the wallet (wallet.ts) on the database's RPCs (service_role). Missing RPCs read as "none", never as "admin". */
import type { RestDb } from "./restdb.ts";
import { makeUseQuota, type WalletStore } from "./wallet.ts";

export function walletStore(db: RestDb): WalletStore {
  const one = <T>(r: unknown) => (Array.isArray(r) ? r[0] : r) as T;
  return {
    isAdmin: async (u) => (await db.rpc("is_credit_admin", { p_user: u }).catch(() => false)) === true,
    monthly: async (u, n) => one<{ ok: boolean; used: number; lim: number }>(await db.rpc("use_drill_chars", { p_user: u, p_n: n })) ?? { ok: false, used: 0, lim: 0 },
    refundMonthly: async (u, n) => void await db.rpc("refund_drill_chars", { p_user: u, p_n: n }),
    purchased: async (u) => Number(await db.rpc("credit_balance", { p_user: u }).catch(() => 0)) || 0,
    usePurchased: async (u, n) => (await db.rpc("use_purchased_credits", { p_user: u, p_n: n })) === true,
    subscriptionUntil: async (u) => {
      const rows = (await db.select("store_subscriptions", `select=expires_at&user_id=eq.${encodeURIComponent(u)}&status=eq.active&expires_at=gt.${encodeURIComponent(new Date().toISOString())}&order=expires_at.desc&limit=1`).catch(() => [])) as { expires_at: string }[];
      return rows[0]?.expires_at ?? null;
    },
    week: async (u, n, lim) => one<{ ok: boolean; used: number }>(await db.rpc("use_week_chars", { p_user: u, p_n: n, p_lim: lim })) ?? { ok: false, used: 0 },
    weekLimit: async () => {
      const rows = (await db.select("drill_settings", "select=value&key=eq.subscription_week_chars").catch(() => [])) as { value: number }[];
      return Number(rows[0]?.value) || 40_000;
    },
  };
}

export const useQuotaFromDb = (db: RestDb) => makeUseQuota(walletStore(db));
