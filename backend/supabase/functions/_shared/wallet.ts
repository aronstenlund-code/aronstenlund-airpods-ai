/**
 * K94 (D213, D214, D218): an account's credits. In this order: an admin (K93) is never counted; an active weekly
 * subscription covers up to its week limit (drill_settings.subscription_week_chars, 20 000 since D224); then the month's free
 * credits; then bought credits (credit_ledger). A charge that the free and bought credits together cannot pay is
 * refused and nothing is counted. The answer keeps the shape the handlers already use ({ok, used, lim}: remaining =
 * lim - used) and adds `wallet` for the app.
 */
export interface Wallet {
  monthly_free: number;
  purchased: number;
  subscription: { active: boolean; until: string | null; week_used: number; week_limit: number };
}
export interface QuotaAnswer { ok: boolean; used: number; lim: number; unlimited?: boolean; wallet?: Wallet }

export interface WalletStore {
  isAdmin(u: string): Promise<boolean>;
  /** month's free credits: atomic, all-or-nothing (use_drill_chars); n = 0 reads */
  monthly(u: string, n: number): Promise<{ ok: boolean; used: number; lim: number }>;
  refundMonthly(u: string, n: number): Promise<void>;
  /** bought credits left (credit_ledger sum) */
  purchased(u: string): Promise<number>;
  /** take n bought credits if there are that many (atomic); false = not enough */
  usePurchased(u: string, n: number): Promise<boolean>;
  /** the active subscription's end, or null */
  subscriptionUntil(u: string): Promise<string | null>;
  /** this week's subscription characters: atomic within lim; n = 0 reads */
  week(u: string, n: number, lim: number): Promise<{ ok: boolean; used: number }>;
  weekLimit(): Promise<number>;
}

const BIG = 1_000_000;

export function makeUseQuota(s: WalletStore) {
  return async (u: string, n: number): Promise<QuotaAnswer> => {
    if (await s.isAdmin(u).catch(() => false)) {
      const m = await s.monthly(u, 0);
      return { ok: true, used: m.used, lim: m.used + BIG, unlimited: true };
    }
    const [m, bought, until, wlim] = await Promise.all([
      s.monthly(u, 0), s.purchased(u).catch(() => 0), s.subscriptionUntil(u).catch(() => null), s.weekLimit().catch(() => 20_000),
    ]);
    const wk = until ? await s.week(u, 0, wlim) : { ok: true, used: 0 };
    const freeLeft = Math.max(0, m.lim - m.used);
    const weekLeft = until ? Math.max(0, wlim - wk.used) : 0;
    const wallet = (mUsed: number, b: number, wUsed: number): Wallet => ({
      monthly_free: Math.max(0, m.lim - mUsed), purchased: Math.max(0, b),
      subscription: { active: !!until, until, week_used: wUsed, week_limit: until ? wlim : 0 },
    });
    // used/lim so that lim - used = everything that is left
    const answer = (ok: boolean, mUsed: number, b: number, wUsed: number): QuotaAnswer => {
      const left = Math.max(0, m.lim - mUsed) + Math.max(0, b) + (until ? Math.max(0, wlim - wUsed) : 0);
      return { ok, used: mUsed, lim: mUsed + left, wallet: wallet(mUsed, b, wUsed) };
    };
    if (n <= 0) return answer(true, m.used, bought, wk.used);
    if (n > weekLeft + freeLeft + bought) return answer(false, m.used, bought, wk.used);
    let rest = n, wUsed = wk.used, mUsed = m.used, b = bought;
    // 1) the subscription's week, 2) the month's free credits, 3) bought credits
    const fromWeek = Math.min(rest, weekLeft);
    if (fromWeek > 0) {
      const w = await s.week(u, fromWeek, wlim);
      if (!w.ok) return answer(false, m.used, bought, wk.used);
      (wUsed = w.used, rest -= fromWeek);
    }
    const fromFree = Math.min(rest, freeLeft);
    if (fromFree > 0) {
      const r = await s.monthly(u, fromFree);
      if (!r.ok) {
        if (fromWeek > 0) await s.week(u, -fromWeek, wlim).catch(() => {});
        return answer(false, m.used, bought, wk.used);
      }
      (mUsed = r.used, rest -= fromFree);
    }
    if (rest > 0) {
      if (!(await s.usePurchased(u, rest))) {
        if (fromFree > 0) await s.refundMonthly(u, fromFree).catch(() => {});
        if (fromWeek > 0) await s.week(u, -fromWeek, wlim).catch(() => {});
        return answer(false, m.used, bought, wk.used);
      }
      b -= rest;
    }
    return answer(true, mUsed, b, wUsed);
  };
}

/** The app's fields (A134) for quota, cost and list. */
export const walletFields = (q: QuotaAnswer) =>
  q.wallet ? { monthly_free: q.wallet.monthly_free, purchased: q.wallet.purchased, subscription: q.wallet.subscription } : {};
