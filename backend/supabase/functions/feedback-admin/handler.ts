import { CORS_HEADERS, errorResponse, HttpError, toHttpError } from "../_shared/errors.ts";

/**
 * D57: owner view of feedback. `GET /feedback-admin?limit=50&type=report|app|suggestion&format=html`.
 * Service role only: the bearer token must be exactly the project's service role key (same scheme as
 * usage-stats, D49). Reads the view `feedback_admin`. Shared history is deliberately not exposed here.
 * D80: `POST /feedback-admin {"id": "<uuid>", "status": "processed"}` marks a row processed once the reported
 * problem is fixed; the hourly `purge_feedback` job then deletes it (and every row older than 90 days).
 */
export interface AdminDeps {
  serviceKey: string | null;
  select: (query: string) => Promise<unknown[]>;
  /** D80: sets status processed; false when no such row. */
  markProcessed?: (id: string) => Promise<boolean>;
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function safeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let d = 0;
  for (let i = 0; i < a.length; i++) d |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return d === 0;
}
const esc = (s: unknown) => String(s ?? "").replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`);

export function createAdminHandler(deps: AdminDeps) {
  return async (req: Request): Promise<Response> => {
    if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS_HEADERS });
    try {
      if (req.method !== "GET" && req.method !== "POST") {
        throw new HttpError(405, "method_not_allowed", "Use GET or POST");
      }
      const m = /^Bearer\s+(\S+)$/i.exec(req.headers.get("authorization") ?? "");
      if (!deps.serviceKey || !m || !safeEqual(m[1], deps.serviceKey)) {
        throw new HttpError(401, "unauthorized", "Service role only");
      }
      if (req.method === "POST") {
        let b: { id?: unknown; status?: unknown };
        try {
          b = await req.json();
        } catch {
          throw new HttpError(400, "invalid_request", "Body must be JSON");
        }
        if (typeof b?.id !== "string" || !UUID.test(b.id) || b.status !== "processed") {
          throw new HttpError(400, "invalid_request", 'Send {"id": "<uuid>", "status": "processed"}');
        }
        if (!deps.markProcessed) throw new HttpError(503, "unconfigured", "Not configured");
        const found = await deps.markProcessed(b.id);
        if (!found) throw new HttpError(404, "not_found", "No such feedback row");
        return new Response(JSON.stringify({ ok: true, status: "processed", deleted_within: "1 hour" }), {
          status: 200,
          headers: { "content-type": "application/json", "cache-control": "no-store", ...CORS_HEADERS },
        });
      }
      const url = new URL(req.url);
      const limit = Math.max(1, Math.min(500, Number(url.searchParams.get("limit") ?? "50") || 50));
      const type = url.searchParams.get("type");
      const filter = type && ["report", "app", "suggestion"].includes(type)
        ? `&type=eq.${type}`
        : "";
      const rows = await deps.select(
        `select=*&order=created_at.desc&limit=${limit}${filter}`,
      ) as Record<
        string,
        unknown
      >[];
      if (url.searchParams.get("format") === "html") {
        const body = rows.map((r) =>
          `<tr><td>${esc(r.created_at)}</td><td>${esc(r.status)}</td><td>${esc(r.type)}</td><td>${esc(r.mode)}/${
            esc(r.persona)
          }</td><td>${esc(r.fragment)}</td><td>${esc(r.answer)}</td><td>${esc(r.comment)}</td></tr>`
        ).join("");
        return new Response(
          `<!doctype html><meta charset="utf-8"><title>Lumen feedback</title><table border="1" cellpadding="4"><tr><th>tid</th><th>status</th><th>typ</th><th>läge</th><th>fråga</th><th>svar</th><th>kommentar</th></tr>${body}</table>`,
          {
            status: 200,
            headers: { "content-type": "text/html; charset=utf-8", "cache-control": "no-store" },
          },
        );
      }
      return new Response(JSON.stringify({ count: rows.length, rows }), {
        status: 200,
        headers: {
          "content-type": "application/json",
          "cache-control": "no-store",
          ...CORS_HEADERS,
        },
      });
    } catch (e) {
      return errorResponse(toHttpError(e));
    }
  };
}
