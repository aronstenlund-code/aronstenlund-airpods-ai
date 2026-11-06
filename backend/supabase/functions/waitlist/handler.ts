import { CORS_HEADERS, errorResponse, HttpError, toHttpError } from "../_shared/errors.ts";
import { networkKey } from "../_shared/demo.ts";
import type { RateLimiter } from "../_shared/ratelimit.ts";
import { readLimitedJson } from "../answer/validate.ts";

/**
 * D62: `POST /waitlist` {email, consent: true, source?, consent_version?} for the public demo page.
 * Public (no JWT): protected by validation, a consent requirement, a honeypot field (`website`), a limit per
 * network (5/hour, 20/day) and a global daily cap. A duplicate address is accepted silently (the answer is the
 * same, so the endpoint cannot be used to find out who is on the list). The service role writes the row.
 */
export const WAITLIST_LIMITS = {
  body: 2048,
  email: 254,
  perHour: 5,
  perDay: 20,
  globalPerDay: 2000,
};

const EMAIL =
  /^[a-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[a-z0-9!#$%&'*+/=?^_`{|}~-]+)*@[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?)*\.[a-z]{2,}$/;

export function normalizeEmail(v: unknown): string | null {
  if (typeof v !== "string") return null;
  const e = v.trim().toLowerCase();
  if (!e || e.length > WAITLIST_LIMITS.email) return null;
  const [local] = e.split("@");
  if (!local || local.length > 64 || !EMAIL.test(e)) return null;
  return e;
}

export interface WaitlistRow {
  email: string;
  source: string;
  consent_version: string | null;
}

export interface WaitlistDeps {
  rateLimiter: RateLimiter;
  /** Inserts the row, ignoring a duplicate e-mail. */
  insert: (row: WaitlistRow) => Promise<void>;
}

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json", "cache-control": "no-store", ...CORS_HEADERS },
  });

export function createWaitlistHandler(deps: WaitlistDeps) {
  return async (req: Request): Promise<Response> => {
    if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS_HEADERS });
    try {
      if (req.method !== "POST") throw new HttpError(405, "method_not_allowed", "Use POST");
      const raw = await readLimitedJson(req, WAITLIST_LIMITS.body) as Record<string, unknown>;
      if (typeof raw !== "object" || raw === null || Array.isArray(raw)) {
        throw new HttpError(400, "invalid_request", "Body must be an object");
      }
      // honeypot: a field no human sees; bots fill it. Pretend success, store nothing.
      if (typeof raw.website === "string" && raw.website.trim()) return json({ ok: true });
      const email = normalizeEmail(raw.email);
      if (!email) throw new HttpError(400, "invalid_email", "Ogiltig e-postadress.");
      if (raw.consent !== true) {
        throw new HttpError(
          400,
          "consent_required",
          "Du måste godkänna att vi sparar din e-postadress.",
        );
      }
      const source = typeof raw.source === "string" && /^[a-z0-9_-]{1,32}$/.test(raw.source)
        ? raw.source
        : "demo";
      const version = typeof raw.consent_version === "string" && raw.consent_version.length <= 16
        ? raw.consent_version
        : null;
      const net = await networkKey(req);
      for (
        const [key, limit, win, msg] of [
          [
            `waitlist:ip:${net}:h`,
            WAITLIST_LIMITS.perHour,
            3600,
            "För många försök. Vänta en stund.",
          ],
          [`waitlist:ip:${net}:d`, WAITLIST_LIMITS.perDay, 86400, "För många försök i dag."],
          [
            `waitlist:global:d`,
            WAITLIST_LIMITS.globalPerDay,
            86400,
            "Väntelistan är tillfälligt full.",
          ],
        ] as [string, number, number, string][]
      ) {
        let r;
        try {
          r = await deps.rateLimiter.check(key, limit, win);
        } catch (e) {
          console.error("waitlist_limiter_error", e instanceof Error ? e.message : String(e));
          throw new HttpError(503, "unavailable", "Tjänsten är tillfälligt otillgänglig.");
        }
        if (!r.allowed) {
          throw new HttpError(429, "rate_limited", msg, { retryAfterSec: r.retryAfterSec });
        }
      }
      try {
        await deps.insert({ email, source, consent_version: version });
      } catch (e) {
        console.error("waitlist_insert_failed", e instanceof Error ? e.message : String(e));
        throw new HttpError(503, "storage_unavailable", "Kunde inte spara just nu. Försök igen.");
      }
      return json({ ok: true });
    } catch (e) {
      return errorResponse(toHttpError(e));
    }
  };
}
