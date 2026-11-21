/**
 * K114 (D249): the web beta (earmind.vercel.app/beta, Angela Schrute's A156) is open to everyone; it is kept open
 * without letting one network mint free credits: a request from the web (an allowed browser Origin; the iOS app sends
 * none) is counted per network (hashed IP, as the demo) and per account, and the web's credits (characters of new
 * audio, K90) have a daily cap per network and in all. The numbers are env-tunable; the defaults follow the ElevenLabs
 * plan (about 90 000 characters a month when last seen, so the whole web may use at most about a ninth a day).
 * Web accounts get no welcome credits (App Attest, D224) and have the month's 1 500 (D213) like every account.
 */
import { AsyncLocalStorage } from "node:async_hooks";
import { originAllowed } from "./cors.ts";
import { networkKey } from "./demo.ts";
import type { RateLimiter, RateResult } from "./ratelimit.ts";
import { jwtClaims } from "./testmode.ts";

const num = (k: string, d: number) => {
  const v = Number(Deno.env.get(k));
  return Number.isFinite(v) && v > 0 ? Math.floor(v) : d;
};
export const WEB_LIMITS = {
  /** Different accounts a network may use from the web per UTC day. */
  accountsPerIpPerDay: num("WEB_ACCOUNTS_PER_IP_PER_DAY", 5),
  /** Credits (characters of new audio) a network may spend from the web per UTC day: two accounts' month. */
  creditsPerIpPerDay: num("WEB_CREDITS_PER_IP_PER_DAY", 3_000),
  /** Credits all web accounts together may spend per UTC day. */
  creditsGlobalPerDay: num("WEB_CREDITS_GLOBAL_PER_DAY", 10_000),
  /** A156: listening (Scribe realtime tokens, each at most 15 min) a network may start from the web per UTC day. */
  sttTokensPerIpPerDay: num("WEB_STT_TOKENS_PER_IP_PER_DAY", 20),
  /** A156: listening tokens all web accounts together may start per UTC day (the app's own cap is 600, D44). */
  sttTokensGlobalPerDay: num("WEB_STT_TOKENS_GLOBAL_PER_DAY", 150),
};
const DAY = 86400;

/** A browser request from the beta (or the project's own previews, localhost while developing). */
export function isWebRequest(req: Request, extra: string[] = []): boolean {
  const o = req.headers.get("origin");
  return !!o && originAllowed(o, extra);
}

const ctx = new AsyncLocalStorage<{ net: string; test?: boolean }>();
/** Inside a web request: its network key (and whether it is test traffic); outside (the app): null. */
export function currentWeb(): { net: string; test?: boolean } | null {
  return ctx.getStore() ?? null;
}

const msg = (req: Request, sv: string, en: string) => (/^\s*sv\b/i.test(req.headers.get("accept-language") ?? "") ? sv : en);

/** Wraps a function: web requests count their account against the network's daily allowance and run in the web context. */
export function withWebGuard(
  handler: (req: Request) => Promise<Response>,
  o: { limiter: RateLimiter; extraOrigins?: string[]; demo?: boolean },
): (req: Request) => Promise<Response> {
  return async (req) => {
    if (req.method === "OPTIONS" || !isWebRequest(req, o.extraOrigins)) return handler(req);
    // A156: the public demo page is on the same domain and has its own caps per network (D62); it is not the beta
    if (o.demo && await isDemo(req)) return handler(req);
    const net = await networkKey(req);
    const sub = typeof jwtClaims(req)?.sub === "string" ? String(jwtClaims(req)!.sub).slice(0, 64) : null;
    // K116 (D254, as D234): test traffic (x-earmind-test) has its own pool of accounts and spends none of the web's
    // credits or listening: its audio and transcripts are fake (D180), and the caps protect the ElevenLabs plan
    const test = req.headers.has("x-earmind-test");
    if (sub) {
      const r = await admit(o.limiter, sub, net, test ? "web-acct-test" : "web-acct").catch(() => ({ allowed: true, retryAfterSec: 0 }) as RateResult);
      if (!r.allowed) {
        return new Response(JSON.stringify({
          error: {
            code: "too_many_accounts",
            message: msg(req, "För många nya konton från den här anslutningen i dag. Försök igen i morgon.", "Too many new accounts from this connection today. Please try again tomorrow."),
          },
        }), { status: 429, headers: { "content-type": "application/json", "retry-after": String(r.retryAfterSec) } });
      }
    }
    return await ctx.run({ net, ...(test ? { test } : {}) }, () => handler(req));
  };
}

/** The demo page's calls: `?source=demo` (stt-token) or `"source": "demo"` in a small JSON body (answer, tts). */
async function isDemo(req: Request): Promise<boolean> {
  if (new URL(req.url).searchParams.get("source") === "demo") return true;
  if (req.method !== "POST" || Number(req.headers.get("content-length") ?? 0) > 64_000) return false;
  try {
    const j = await req.clone().json();
    return !!j && typeof j === "object" && (j as { source?: unknown }).source === "demo";
  } catch {
    return false;
  }
}

/** An account already admitted today goes on; a new one takes one of the network's places (a denied place is given back). */
async function admit(rl: RateLimiter, sub: string, net: string, pool: string): Promise<RateResult> {
  const seen = await rl.check(`${pool}:u:${sub}:d`, 0, DAY, 0); // a read: denied = counted already today
  if (!seen.allowed) return { allowed: true, retryAfterSec: 0 };
  const place = await rl.check(`${pool}:ip:${net}:d`, WEB_LIMITS.accountsPerIpPerDay, DAY, 1);
  if (!place.allowed) return { ...place, deniedKey: `${pool}:ip:${net}:d` };
  await rl.check(`${pool}:u:${sub}:d`, 1, DAY, 1);
  return { allowed: true, retryAfterSec: 0 };
}

/** The web's credits: allowed when the network's and the web's daily caps have room (always allowed outside the web). */
export async function webCredits(rl: RateLimiter, credits: number): Promise<RateResult> {
  const w = currentWeb();
  if (!w || w.test || credits <= 0) return { allowed: true, retryAfterSec: 0 };
  const checks = [
    { key: `web-credits:ip:${w.net}:d`, limit: WEB_LIMITS.creditsPerIpPerDay, windowSec: DAY },
    { key: "web-credits:global:d", limit: WEB_LIMITS.creditsGlobalPerDay, windowSec: DAY },
  ];
  if (rl.checkMany) return await rl.checkMany(checks, credits);
  for (const c of checks) {
    const r = await rl.check(c.key, c.limit, c.windowSec, credits);
    if (!r.allowed) return { ...r, deniedKey: c.key };
  }
  return { allowed: true, retryAfterSec: 0 };
}

/** A156: one unit of something the web may do only so often (listening tokens), per network and in all per UTC day. */
export async function webCount(rl: RateLimiter, scope: string, perIp: number, global: number): Promise<RateResult> {
  const w = currentWeb();
  if (!w || w.test) return { allowed: true, retryAfterSec: 0 };
  const checks = [
    { key: `web-${scope}:ip:${w.net}:d`, limit: perIp, windowSec: DAY },
    { key: `web-${scope}:global:d`, limit: global, windowSec: DAY },
  ];
  if (rl.checkMany) return await rl.checkMany(checks, 1);
  for (const c of checks) {
    const r = await rl.check(c.key, c.limit, c.windowSec, 1);
    if (!r.allowed) return { ...r, deniedKey: c.key };
  }
  return { allowed: true, retryAfterSec: 0 };
}
