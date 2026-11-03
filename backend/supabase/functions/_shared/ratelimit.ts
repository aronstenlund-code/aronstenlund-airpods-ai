import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2.45.4";

export interface RateResult {
  allowed: boolean;
  retryAfterSec: number;
}

/** Fixed-window counter. `cost` lets TTS charge per character. Must fail closed: callers treat a
 *  thrown error as "denied". */
export interface RateLimiter {
  check(key: string, limit: number, windowSec: number, cost?: number): Promise<RateResult>;
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
  constructor(private db: SupabaseClient) {}

  async check(key: string, limit: number, windowSec: number, cost = 1): Promise<RateResult> {
    const { data, error } = await this.db.rpc("check_rate_limit", {
      p_key: key,
      p_limit: limit,
      p_window_seconds: windowSec,
      p_cost: cost,
    });
    if (error) throw new Error(`rate limiter failed: ${error.message}`);
    const row = Array.isArray(data) ? data[0] : data;
    return { allowed: !!row?.allowed, retryAfterSec: Number(row?.retry_after ?? windowSec) };
  }
}

export function serviceClient(): SupabaseClient {
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) throw new Error("SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY not set");
  return createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });
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
    const checks: [string, number, number][] = [
      [`${scope}:u:${userId}:m`, limits.perMinute, 60],
      [`${scope}:u:${userId}:d`, limits.perDay, 86400],
      [`${scope}:global:d`, limits.globalPerDay, 86400],
    ];
    for (const [key, limit, win] of checks) {
      const r = await rl.check(key, limit, win, cost);
      if (!r.allowed) return r;
    }
    return { allowed: true, retryAfterSec: 0 };
  } catch (e) {
    console.error("rate_limiter_error", e instanceof Error ? e.message : String(e));
    return { allowed: false, retryAfterSec: 30 };
  }
}
