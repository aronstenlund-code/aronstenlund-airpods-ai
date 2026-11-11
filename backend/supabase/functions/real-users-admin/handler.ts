import { type Authenticator } from "../_shared/auth.ts";
import { CORS_HEADERS, errorResponse, HttpError, toHttpError } from "../_shared/errors.ts";
import { requireOwner } from "../_shared/owner.ts";

/**
 * K38 (Oscar O36): the weekly K22 candidates, on Aron's private page instead of a public Actions artifact.
 *   GET  /real-users-admin                                 -> {rows: [{id, week, q, mode, installs, count, decision}]}
 *   POST /real-users-admin {"id": "real-…", "decision": "approved" | "rejected" | null}  -> {changed}
 * Owner only (same check as K30's qa-log). Approved rows reach git only through the "approve" run of the
 * real-users workflow (`scripts/real_users.py --approve-db`), which filters them once more and deletes them here.
 * Rejected rows stay 90 days so the same question is not offered every week; waiting rows go after 30 days.
 */
export interface RealUsersAdminDeps {
  authenticate: Authenticator;
  ownerEmails: string[];
  select: (query: string) => Promise<unknown[]>;
  updateWhere: (filter: string, patch: object) => Promise<number>;
  now?: () => Date;
}

const ID = /^real-[0-9a-f]{10}$/;

export function createRealUsersAdminHandler(deps: RealUsersAdminDeps) {
  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), {
      status,
      headers: { "content-type": "application/json", "cache-control": "no-store", ...CORS_HEADERS },
    });
  return async (req: Request): Promise<Response> => {
    if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS_HEADERS });
    try {
      if (req.method !== "GET" && req.method !== "POST") throw new HttpError(405, "method_not_allowed", "Use GET or POST");
      await requireOwner(req, deps.authenticate, deps.ownerEmails);
      if (req.method === "POST") {
        let b: { id?: unknown; decision?: unknown };
        try {
          b = await req.json();
        } catch {
          throw new HttpError(400, "invalid_request", "Body must be JSON");
        }
        const id = typeof b?.id === "string" && ID.test(b.id) ? b.id : null;
        const d = b?.decision;
        if (!id || !(d === "approved" || d === "rejected" || d === null)) {
          throw new HttpError(400, "invalid_request", 'Send {"id": "real-…", "decision": "approved" | "rejected" | null}');
        }
        const changed = await deps.updateWhere(`id=eq.${id}`, {
          decision: d,
          decided_at: d === null ? null : (deps.now?.() ?? new Date()).toISOString(),
        });
        return json({ changed });
      }
      const rows = await deps.select(
        "select=id,week,q,mode,installs,count,decision&order=week.desc,installs.desc,count.desc&limit=1000",
      );
      return json({ rows });
    } catch (e) {
      return errorResponse(toHttpError(e));
    }
  };
}
