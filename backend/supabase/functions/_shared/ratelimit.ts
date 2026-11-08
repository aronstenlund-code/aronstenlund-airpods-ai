import { RestDb } from "./restdb.ts";

export interface RateResult {
  allowed: boolean;
  retryAfterSec: number;
  /** The window that said no (when known). */
  deniedKey?: string;
}

/** Oscar 2026-11-08: a new session that hit its first-hour window is told to retry within minutes, not an hour. */
export const NEW_USER_RETRY_CAP_SEC = 120;

/** Fixed-window counter. `cost` lets TTS charge per character. Must fail closed: callers treat a
 *  thrown error as "denied". */
export interface RateLimiter {
  check(key: string, limit: number, windowSec: number, cost?: number): Promise<RateResult>;
  /** Several windows in ONE round trip (all-or-nothing). Optional; enforceLimits falls back to check(). */
  checkMany?(
    checks: { key: string; limit: number; windowSec: number }[],
    cost?: number,
  ): Promise<RateResult>;
  /** D80: give units back in the window that was current at `atMs` (never below zero). Optional. */
  release?(windows: { key: string; windowSec: number }[], cost: number, atMs: number): Promise<void>;
}

/** D80: the user's own windows of a scope (the ones an aborted request gives back). */
export function userWindows(scope: string, userId: string): { key: string; windowSec: number }[] {
  return [
    { key: `${scope}:u:${userId}:m`, windowSec: 60 },
    { key: `${scope}:u:${userId}:d`, windowSec: 86400 },
  ];
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

  release(windows: { key: string; windowSec: number }[], cost: number, atMs: number): Promise<void> {
    const atSec = Math.floor(atMs / 1000);
    for (const w of windows) {
      const b = this.buckets.get(`${w.key}:${w.windowSec}`);
      if (b && b.windowStart === Math.floor(atSec / w.windowSec) * w.windowSec) {
        b.count = Math.max(0, b.count - cost);
      }
    }
    return Promise.resolve();
  }

  /** Test helper: the current count of a window. */
  count(key: string, windowSec: number): number {
    const b = this.buckets.get(`${key}:${windowSec}`);
    const ws = Math.floor(Math.floor(this.now() / 1000) / windowSec) * windowSec;
    return b && b.windowStart === ws ? b.count : 0;
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
      | { allowed?: boolean; retry_after?: number; denied_key?: string }
      | null;
    return {
      allowed: !!row?.allowed,
      retryAfterSec: Number(row?.retry_after ?? 60),
      ...(row?.denied_key ? { deniedKey: String(row.denied_key) } : {}),
    };
  }

  async release(windows: { key: string; windowSec: number }[], cost: number, atMs: number): Promise<void> {
    await this.db.rpc("release_rate_limits", {
      p_keys: windows.map((w) => w.key),
      p_windows: windows.map((w) => w.windowSec),
      p_cost: cost,
      p_at: new Date(atMs).toISOString(),
    });
  }
}

/** An extra window checked in the same round trip (D79: per network, new users). */
export interface ExtraCheck {
  key: string;
  limit: number;
  windowSec: number;
}

/**
 * D79 (owner): app traffic is also capped per network (hashed client IP, as in the demo) and a brand-new
 * anonymous session gets a small first-hour allowance. A script that mints a new anonymous user per call
 * gets a new per-user allowance every time; these two windows do not reset with a new user.
 * The session start is the `amr` timestamp of the JWT (verified live: it stays the same across token
 * refreshes, `iat` does not). No timestamp = no new-user check (never a false positive).
 */
export interface AppGuard {
  /** Per network and UTC day (answers, or TTS characters). 0 = off. */
  networkPerDay: number;
  /** A session younger than this many seconds counts as new. 0 = off. */
  newUserAgeSec: number;
  /** Requests a new session may make in its (clock) hour window. */
  newUserPerHour: number;
}

export function appChecks(
  scope: string,
  net: string | null,
  user: { id: string; sessionStartSec?: number },
  g: AppGuard,
  nowSec = Math.floor(Date.now() / 1000),
): ExtraCheck[] {
  const out: ExtraCheck[] = [];
  if (net && g.networkPerDay > 0) {
    out.push({ key: `${scope}:ip:${net}:d`, limit: g.networkPerDay, windowSec: 86400 });
  }
  const start = user.sessionStartSec;
  if (
    g.newUserAgeSec > 0 && g.newUserPerHour > 0 && typeof start === "number" &&
    nowSec - start < g.newUserAgeSec
  ) {
    out.push({ key: `${scope}:new:u:${user.id}:h`, limit: g.newUserPerHour, windowSec: 3600 });
  }
  return out;
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
  extra: ExtraCheck[] = [],
): Promise<RateResult> {
  try {
    const checks = [
      { key: `${scope}:u:${userId}:m`, limit: limits.perMinute, windowSec: 60 },
      { key: `${scope}:u:${userId}:d`, limit: limits.perDay, windowSec: 86400 },
      { key: `${scope}:global:d`, limit: limits.globalPerDay, windowSec: 86400 },
      ...extra,
    ];
    const cap = (r: RateResult): RateResult =>
      !r.allowed && r.deniedKey?.includes(":new:u:")
        ? { ...r, retryAfterSec: Math.min(r.retryAfterSec, NEW_USER_RETRY_CAP_SEC) }
        : r;
    if (rl.checkMany) return cap(await rl.checkMany(checks, cost));
    for (const c of checks) {
      const r = await rl.check(c.key, c.limit, c.windowSec, cost);
      if (!r.allowed) return cap({ ...r, deniedKey: c.key });
    }
    return { allowed: true, retryAfterSec: 0 };
  } catch (e) {
    console.error("rate_limiter_error", e instanceof Error ? e.message : String(e));
    return { allowed: false, retryAfterSec: 30 };
  }
}
