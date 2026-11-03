import { RestDb } from "./restdb.ts";

export interface RateResult {
  allowed: boolean;
  retryAfterSec: number;
}

/** Fixed-window counter. `cost` lets TTS charge per character. Must fail closed: callers treat a
 *  thrown error as "denied". */
export interface RateLimiter {
  check(key: string, limit: number, windowSec: number, cost?: number): Promise<RateResult>;
  /** Several windows in ONE round trip (all-or-nothing). Optional; enforceLimits falls back to check(). */
  checkMany?(
    checks: { key: string; limit: number; windowSec: number }[],
    cost?: number,
  ): Promise<RateResult>;
}

export class MemoryRateLimiter implements RateLimiter {
  private buckets = new Map<string, { windowStart: number; count: number }>();
  constructor(private now: () => number = Date.now) {}

  check(key: string, limit: number, windowSec: number, cost = 1): Promise<RateResult> {
    const nowSec = Math.floor(this.now() / 1000);
    const windowStart = Math.floor(nowSec / windowSec) * windowSec;
    const id = `${key}:${windowSec}`;
    let b = this.buckets.get(id);
    if (!b || b.windowStart !== windowStart) {
      b = { windowStart, count: 0 };
      this.buckets.set(id, b);
    }
    if (b.count + cost > limit) {
      return Promise.resolve({ allowed: false, retryAfterSec: windowStart + windowSec - nowSec });
    }
    b.count += cost;
    return Promise.resolve({ allowed: true, retryAfterSec: 0 });
  }
}

/** Postgres-backed (atomic upsert in `check_rate_limit`, see migrations). Survives cold starts and
 *  is shared by all function instances. */
export class SupabaseRateLimiter implements RateLimiter {
  constructor(private db: RestDb) {}

  async check(key: string, limit: number, windowSec: number, cost = 1): Promise<RateResult> {
    const data = await this.db.rpc("check_rate_limit", {
      p_key: key,
      p_limit: limit,
      p_window_seconds: windowSec,
      p_cost: cost,
    });
    const row = (Array.isArray(data) ? data[0] : data) as
      | { allowed?: boolean; retry_after?: number }
      | null;
    return { allowed: !!row?.allowed, retryAfterSec: Number(row?.retry_after ?? windowSec) };
  }

  async checkMany(
    checks: { key: string; limit: number; windowSec: number }[],
    cost = 1,
  ): Promise<RateResult> {
    const data = await this.db.rpc("check_rate_limits", {
      p_keys: checks.map((c) => c.key),
      p_limits: checks.map((c) => c.limit),
      p_windows: checks.map((c) => c.windowSec),
      p_cost: cost,
    });
    const row = (Array.isArray(data) ? data[0] : data) as
      | { allowed?: boolean; retry_after?: number }
      | null;
    return { allowed: !!row?.allowed, retryAfterSec: Number(row?.retry_after ?? 60) };
  }
}

export interface Limits {
  perMinute: number;
  perDay: number;
  globalPerDay: number;
}

/** Applies per-user minute + day windows and a global daily kill-switch. Throws nothing; returns the
 *  first denial. A limiter failure is a denial (fail closed). */
export async function enforceLimits(
  rl: RateLimiter,
  scope: string,
  userId: string,
  limits: Limits,
  cost = 1,
): Promise<RateResult> {
  try {
    const checks = [
      { key: `${scope}:u:${userId}:m`, limit: limits.perMinute, windowSec: 60 },
      { key: `${scope}:u:${userId}:d`, limit: limits.perDay, windowSec: 86400 },
      { key: `${scope}:global:d`, limit: limits.globalPerDay, windowSec: 86400 },
    ];
    if (rl.checkMany) return await rl.checkMany(checks, cost);
    for (const c of checks) {
      const r = await rl.check(c.key, c.limit, c.windowSec, cost);
      if (!r.allowed) return r;
    }
    return { allowed: true, retryAfterSec: 0 };
  } catch (e) {
    console.error("rate_limiter_error", e instanceof Error ? e.message : String(e));
    return { allowed: false, retryAfterSec: 30 };
  }
}
