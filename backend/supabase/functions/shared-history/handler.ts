import { type Authenticator } from "../_shared/auth.ts";
import { CORS_HEADERS, errorResponse, HttpError, toHttpError } from "../_shared/errors.ts";
import { enforceLimits, type Limits, type RateLimiter } from "../_shared/ratelimit.ts";
import { readLimitedJson } from "../answer/validate.ts";
import { INSTALL_ID } from "../feedback/handler.ts";

/**
 * D57: opt-in shared history. `POST /shared-history` {install_id, items:[{fragment, answer, summary?, mode?,
 * persona?}]} (batch, max 50) stores the user's OWN question and the assistant's answer verbatim,
 * pseudonymously (random install id, no name / e-mail). `DELETE /shared-history` (optional body
 * {install_id}) deletes every row of the caller (by verified user id, and by install id when given) and is
 * what the app calls when sharing is turned off. Kept at most 12 months (daily purge job in the database).
 */
export const SHARED_LIMITS = {
  body: 256 * 1024,
  items: 50,
  fragment: 1000,
  answer: 4000,
  summary: 600,
  mode: 32,
  persona: 32,
  client_id: 64,
};

export interface SharedRow {
  user_id: string;
  install_id: string;
  fragment: string;
  answer: string;
  summary: string | null;
  mode: string | null;
  persona: string | null;
  /** D82: the app's id of the history item; a second upload of the same id is ignored. */
  client_id: string | null;
}

const bad = (m: string) => new HttpError(400, "invalid_request", m);
const tooBig = (m: string) => new HttpError(413, "payload_too_large", m);
const clean = (s: string) => s.replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f]/g, "").trim();

function str(o: Record<string, unknown>, k: string, max: number, required: boolean): string | null {
  const v = o[k];
  if (v === undefined || v === null) {
    if (required) throw bad(`${k} is required`);
    return null;
  }
  if (typeof v !== "string") throw bad(`${k} must be a string`);
  const t = clean(v);
  if (t.length > max) throw tooBig(`${k} exceeds ${max} characters`);
  if (required && !t) throw bad(`${k} is required`);
  return t || null;
}

export function validateShared(raw: unknown, userId: string): SharedRow[] {
  if (typeof raw !== "object" || raw === null || Array.isArray(raw)) {
    throw bad("Body must be an object");
  }
  const o = raw as Record<string, unknown>;
  const install = typeof o.install_id === "string" ? o.install_id : "";
  if (!INSTALL_ID.test(install)) throw bad("install_id must be 8-64 characters of A-Z a-z 0-9 _ -");
  if (!Array.isArray(o.items) || o.items.length === 0) throw bad("items must be a non-empty array");
  if (o.items.length > SHARED_LIMITS.items) {
    throw tooBig(`items exceeds ${SHARED_LIMITS.items}`);
  }
  return o.items.map((it, i) => {
    if (typeof it !== "object" || it === null || Array.isArray(it)) {
      throw bad(`items[${i}] must be an object`);
    }
    const x = it as Record<string, unknown>;
    return {
      user_id: userId,
      install_id: install,
      fragment: str(x, "fragment", SHARED_LIMITS.fragment, true)!,
      answer: str(x, "answer", SHARED_LIMITS.answer, true)!,
      summary: str(x, "summary", SHARED_LIMITS.summary, false),
      mode: str(x, "mode", SHARED_LIMITS.mode, false),
      persona: str(x, "persona", SHARED_LIMITS.persona, false),
      client_id: str(x, "client_id", SHARED_LIMITS.client_id, false),
    };
  }).filter((r, i, all) => !r.client_id || all.findIndex((o) => o.client_id === r.client_id) === i);
}

export interface SharedDeps {
  authenticate: Authenticator;
  rateLimiter: RateLimiter;
  insertMany: (rows: SharedRow[]) => Promise<void>;
  /** PostgREST filter for DELETE, e.g. `or=(user_id.eq.<id>,install_id.eq.<id>)`; returns deleted count. */
  deleteWhere: (filter: string) => Promise<number>;
  limits?: Limits;
}
export const DEFAULT_SHARED_LIMITS: Limits = { perMinute: 12, perDay: 400, globalPerDay: 20000 };

export function createSharedHandler(deps: SharedDeps) {
  return async (req: Request): Promise<Response> => {
    if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS_HEADERS });
    try {
      if (req.method !== "POST" && req.method !== "DELETE") {
        throw new HttpError(405, "method_not_allowed", "Use POST (upload) or DELETE (opt-out)");
      }
      const user = await deps.authenticate(req);
      const rl = await enforceLimits(
        deps.rateLimiter,
        "shared-history",
        user.id,
        deps.limits ?? DEFAULT_SHARED_LIMITS,
      );
      if (!rl.allowed) {
        throw new HttpError(429, "rate_limited", "Too many requests", {
          retryAfterSec: rl.retryAfterSec,
        });
      }
      const json = { "content-type": "application/json", ...CORS_HEADERS };
      if (req.method === "POST") {
        const rows = validateShared(await readLimitedJson(req, SHARED_LIMITS.body), user.id);
        try {
          await deps.insertMany(rows);
        } catch (e) {
          console.error("shared_insert_failed", e instanceof Error ? e.message : String(e));
          throw new HttpError(503, "storage_unavailable", "Could not store the history");
        }
        return new Response(JSON.stringify({ ok: true, stored: rows.length }), {
          status: 200,
          headers: json,
        });
      }
      // DELETE: all rows of this user (verified id) and, when given, of this install id.
      let install: string | null = null;
      const text = (await req.text()).slice(0, 2048);
      if (text.trim()) {
        let o: Record<string, unknown>;
        try {
          o = JSON.parse(text);
        } catch {
          throw bad("Body must be JSON");
        }
        if (o?.install_id !== undefined) {
          if (typeof o.install_id !== "string" || !INSTALL_ID.test(o.install_id)) {
            throw bad("install_id must be 8-64 characters of A-Z a-z 0-9 _ -");
          }
          install = o.install_id;
        }
      }
      const filter = install
        ? `or=(user_id.eq.${user.id},install_id.eq.${install})`
        : `user_id=eq.${user.id}`;
      let deleted: number;
      try {
        deleted = await deps.deleteWhere(filter);
      } catch (e) {
        console.error("shared_delete_failed", e instanceof Error ? e.message : String(e));
        throw new HttpError(503, "storage_unavailable", "Could not delete the history");
      }
      return new Response(JSON.stringify({ ok: true, deleted }), { status: 200, headers: json });
    } catch (e) {
      return errorResponse(toHttpError(e));
    }
  };
}
