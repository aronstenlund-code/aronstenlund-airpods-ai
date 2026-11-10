import { type Authenticator } from "../_shared/auth.ts";
import { CORS_HEADERS, errorResponse, HttpError, toHttpError } from "../_shared/errors.ts";

/**
 * K30 (D116, owner): Aron's private view of every question and answer (table `qa_log`, written by /answer).
 *   GET  /qa-log                       -> {rows: [{id, created_at, mode, persona, question, answer}], newest}
 *   POST /qa-log {"fetched_until": iso} -> deletes every row up to and including that time ("Hämtat") -> {deleted}
 * Only Aron: a user JWT whose email is OWNER_EMAIL (a secret, never in the repo) AND that was signed in by email
 * (magic link or one-time code, `amr` "otp"/"magiclink"), so a password sign-up with his address cannot read it.
 * The page is `backend/webtest/qa.html` (Edge Functions may not serve HTML, Supabase docs 2026-11-10).
 * Rows older than 14 days are deleted by the hourly job `purge_qa_log()`.
 */
export interface QaLogDeps {
  authenticate: Authenticator;
  ownerEmails: string[];
  select: (query: string) => Promise<unknown[]>;
  deleteWhere: (filter: string) => Promise<number>;
}

export const QA_LOG_MAX_ROWS = 5000;

export function createQaLogHandler(deps: QaLogDeps) {
  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), {
      status,
      headers: { "content-type": "application/json", "cache-control": "no-store", ...CORS_HEADERS },
    });
  return async (req: Request): Promise<Response> => {
    if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS_HEADERS });
    try {
      if (req.method !== "GET" && req.method !== "POST") throw new HttpError(405, "method_not_allowed", "Use GET or POST");
      const user = await deps.authenticate(req);
      const owners = deps.ownerEmails.map((e) => e.trim().toLowerCase()).filter(Boolean);
      const byEmail = (user.amr ?? []).some((m) => m === "otp" || m === "magiclink");
      if (!owners.length) throw new HttpError(503, "unconfigured", "OWNER_EMAIL is not set");
      if (user.isAnonymous || !user.email || !owners.includes(user.email.toLowerCase()) || !byEmail) {
        throw new HttpError(403, "forbidden", "Owner only");
      }
      if (req.method === "POST") {
        let b: { fetched_until?: unknown };
        try {
          b = await req.json();
        } catch {
          throw new HttpError(400, "invalid_request", "Body must be JSON");
        }
        const until = typeof b?.fetched_until === "string" ? new Date(b.fetched_until) : null;
        if (!until || isNaN(until.getTime())) {
          throw new HttpError(400, "invalid_request", 'Send {"fetched_until": "<ISO time of the newest row you fetched>"}');
        }
        const deleted = await deps.deleteWhere(`created_at=lte.${encodeURIComponent(until.toISOString())}`);
        return json({ deleted });
      }
      const rows = await deps.select(
        `select=id,created_at,mode,persona,question,answer&order=created_at.desc&limit=${QA_LOG_MAX_ROWS}`,
      ) as { created_at: string }[];
      return json({ rows, newest: rows[0]?.created_at ?? null, max: QA_LOG_MAX_ROWS });
    } catch (e) {
      return errorResponse(toHttpError(e));
    }
  };
}
