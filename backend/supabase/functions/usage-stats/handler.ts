import { CORS_HEADERS, errorResponse, HttpError, toHttpError } from "../_shared/errors.ts";

/**
 * D49: owner view of anonymous usage - counts per category and day. Service role only: the bearer token
 * must be exactly the project's service role key (the gateway additionally requires a valid JWT).
 * Reads the SQL function `usage_stats` (view `usage_by_category_day`); no text is stored anywhere.
 */
export interface StatsRow {
  day: string;
  category: string;
  requests: number;
  avg_ttft_ms: number | null;
  input_tokens: number | null;
  output_tokens: number | null;
  est_cost_usd: number | null;
}
export interface StatsDeps {
  serviceKey: string | null;
  rpc: (fn: string, args: Record<string, unknown>) => Promise<unknown>;
}

function safeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let d = 0;
  for (let i = 0; i < a.length; i++) d |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return d === 0;
}

const esc = (s: unknown) => String(s ?? "").replace(/[&<>"]/g, (c) => `&#${c.charCodeAt(0)};`);

export function createStatsHandler(deps: StatsDeps) {
  return async (req: Request): Promise<Response> => {
    if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS_HEADERS });
    try {
      if (req.method !== "GET") throw new HttpError(405, "method_not_allowed", "Use GET");
      const m = /^Bearer\s+(\S+)$/i.exec(req.headers.get("authorization") ?? "");
      if (!deps.serviceKey || !m || !safeEqual(m[1], deps.serviceKey)) {
        throw new HttpError(401, "unauthorized", "Service role only");
      }
      const url = new URL(req.url);
      const days = Math.max(1, Math.min(366, Number(url.searchParams.get("days") ?? "14") || 14));
      const rows = (await deps.rpc("usage_stats", { p_days: days })) as StatsRow[];
      const byCategory: Record<string, number> = {};
      for (const r of rows) {
        byCategory[r.category] = (byCategory[r.category] ?? 0) + Number(r.requests);
      }
      if (url.searchParams.get("format") === "html") {
        const body = rows.map((r) =>
          `<tr><td>${esc(r.day)}</td><td>${esc(r.category)}</td><td>${esc(r.requests)}</td><td>${
            esc(r.avg_ttft_ms)
          }</td><td>${esc(r.est_cost_usd)}</td></tr>`
        ).join("");
        return new Response(
          `<!doctype html><meta charset="utf-8"><title>Lumen usage</title><table border="1" cellpadding="4"><tr><th>dag</th><th>kategori</th><th>antal</th><th>ttft ms</th><th>USD</th></tr>${body}</table>`,
          {
            status: 200,
            headers: { "content-type": "text/html; charset=utf-8", "cache-control": "no-store" },
          },
        );
      }
      return new Response(JSON.stringify({ days, by_category: byCategory, rows }), {
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
