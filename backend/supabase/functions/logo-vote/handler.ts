import { type Authenticator } from "../_shared/auth.ts";
import { CORS_HEADERS, errorResponse, HttpError, toHttpError } from "../_shared/errors.ts";
import { enforceLimits, type Limits, type RateLimiter } from "../_shared/ratelimit.ts";
import { requireOwner } from "../_shared/owner.ts";
import { readLimitedJson } from "../answer/validate.ts";

/**
 * K39 (D127, owner): the logo vote (A54). One vote per user (the anonymous Supabase user id), can be changed.
 *   POST /logo-vote {"choice": "A" | ... | "F"} -> {"choice", "results"?}
 *   GET  /logo-vote                              -> {"choice": "A" | null, "results"?}   (only the caller's own vote)
 *   GET  /logo-vote?view=owner                   -> {"results": {"A" … "F", "total"}} (Aron only, as K30)
 * `results` (percent per logo) goes to a user only after they have voted and only when there are at least
 * RESULTS_MIN votes (A54: "procent per logga om det finns ≥ 20 röster"), so early votes are not steered.
 * No other personal data: no install id, no network, no device.
 */
export const RESULTS_MIN = 20;
export const CHOICES = ["A", "B", "C", "D", "E", "F"] as const;
export type Choice = typeof CHOICES[number];

export interface LogoVoteDeps {
  authenticate: Authenticator;
  rateLimiter: RateLimiter;
  ownerEmails: string[];
  cast: (userId: string, choice: Choice) => Promise<void>;
  own: (userId: string) => Promise<Choice | null>;
  counts: () => Promise<Record<Choice, number>>;
  limits?: Limits;
}
export const LOGO_VOTE_LIMITS: Limits = { perMinute: 10, perDay: 50, globalPerDay: 50_000 };

export type Results = Record<Choice, number> & { total: number; percent: Record<Choice, number> };
export function results(c: Record<Choice, number>): Results {
  const total = CHOICES.reduce((n, k) => n + (c[k] ?? 0), 0);
  const pct = (n: number) => (total ? Math.round((1000 * n) / total) / 10 : 0);
  const out = { total, percent: {} } as Results;
  for (const k of CHOICES) { out[k] = c[k] ?? 0; out.percent[k] = pct(c[k] ?? 0); }
  return out;
}

export function createLogoVoteHandler(deps: LogoVoteDeps) {
  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), {
      status,
      headers: { "content-type": "application/json", "cache-control": "no-store", ...CORS_HEADERS },
    });
  const forUser = async (choice: Choice | null) => {
    if (!choice) return { choice: null };
    const r = results(await deps.counts());
    return r.total >= RESULTS_MIN ? { choice, results: r } : { choice };
  };
  return async (req: Request): Promise<Response> => {
    if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS_HEADERS });
    try {
      if (req.method !== "GET" && req.method !== "POST") throw new HttpError(405, "method_not_allowed", "Use GET or POST");
      if (req.method === "GET" && new URL(req.url).searchParams.get("view") === "owner") {
        await requireOwner(req, deps.authenticate, deps.ownerEmails);
        return json({ results: results(await deps.counts()) });
      }
      const user = await deps.authenticate(req);
      if (req.method === "GET") return json(await forUser(await deps.own(user.id)));
      const rl = await enforceLimits(deps.rateLimiter, "logo-vote", user.id, deps.limits ?? LOGO_VOTE_LIMITS, 1, []);
      if (!rl.allowed) {
        throw new HttpError(429, "rate_limited", "För många försök just nu.", { retryAfterSec: rl.retryAfterSec });
      }
      const b = (await readLimitedJson(req, 1024)) as { choice?: unknown } | null;
      const choice = typeof b?.choice === "string" ? b.choice.trim().toUpperCase() : "";
      if (!(CHOICES as readonly string[]).includes(choice)) {
        throw new HttpError(400, "invalid_request", 'Send {"choice": "A" | ... | "F"}');
      }
      await deps.cast(user.id, choice as Choice);
      return json(await forUser(choice as Choice));
    } catch (e) {
      return errorResponse(toHttpError(e));
    }
  };
}
