import { type Authenticator } from "../_shared/auth.ts";
import { CORS_HEADERS, errorResponse, HttpError, toHttpError } from "../_shared/errors.ts";
import { enforceLimits, type Limits, type RateLimiter } from "../_shared/ratelimit.ts";
import { readLimitedJson } from "../answer/validate.ts";

/**
 * D57: `POST /feedback` - a user-triggered report of one answer (type "report"), free-text feedback about the
 * app ("app") or a suggestion ("suggestion"). Only what the user sends is stored: their own fragment, the
 * assistant's answer, an optional comment, mode, persona, timings, app version and the random install id.
 * Other people's speech is never part of the payload (the app does not send it). Rows are written with the
 * service role; user_id comes from the verified JWT, never from the body.
 */
export const FEEDBACK_LIMITS = {
  body: 16 * 1024,
  fragment: 1000,
  answer: 4000,
  comment: 2000,
  mode: 32,
  persona: 32,
  appVersion: 32,
  timings: 2048,
};
export const INSTALL_ID = /^[A-Za-z0-9_-]{8,64}$/;
export const FEEDBACK_TYPES = ["report", "app", "suggestion"] as const;
export type FeedbackType = (typeof FEEDBACK_TYPES)[number];

export interface FeedbackRow {
  user_id: string;
  install_id: string;
  type: FeedbackType;
  fragment: string | null;
  answer: string | null;
  comment: string | null;
  mode: string | null;
  persona: string | null;
  timings: Record<string, unknown> | null;
  app_version: string | null;
}

const bad = (m: string) => new HttpError(400, "invalid_request", m);
const tooBig = (m: string) => new HttpError(413, "payload_too_large", m);

function optStr(o: Record<string, unknown>, k: string, max: number): string | null {
  const v = o[k];
  if (v === undefined || v === null) return null;
  if (typeof v !== "string") throw bad(`${k} must be a string`);
  const t = v.replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f]/g, "").trim();
  if (t.length > max) throw tooBig(`${k} exceeds ${max} characters`);
  return t || null;
}

export function validateFeedback(raw: unknown, userId: string): FeedbackRow {
  if (typeof raw !== "object" || raw === null || Array.isArray(raw)) {
    throw bad("Body must be an object");
  }
  const o = raw as Record<string, unknown>;
  const install = typeof o.install_id === "string" ? o.install_id : "";
  if (!INSTALL_ID.test(install)) throw bad("install_id must be 8-64 characters of A-Z a-z 0-9 _ -");
  const type = o.type === undefined || o.type === null ? "report" : o.type;
  if (!FEEDBACK_TYPES.includes(type as FeedbackType)) {
    throw bad(`type must be one of ${FEEDBACK_TYPES.join(", ")}`);
  }
  const L = FEEDBACK_LIMITS;
  const fragment = optStr(o, "fragment", L.fragment);
  const answer = optStr(o, "answer", L.answer);
  const comment = optStr(o, "comment", L.comment);
  if (!fragment && !answer && !comment) {
    throw bad("Send at least a fragment, an answer or a comment");
  }
  let timings: Record<string, unknown> | null = null;
  if (o.timings !== undefined && o.timings !== null) {
    if (typeof o.timings !== "object" || Array.isArray(o.timings)) {
      throw bad("timings must be an object");
    }
    if (JSON.stringify(o.timings).length > L.timings) throw tooBig("timings too large");
    timings = o.timings as Record<string, unknown>;
  }
  return {
    user_id: userId,
    install_id: install,
    type: type as FeedbackType,
    fragment,
    answer,
    comment,
    mode: optStr(o, "mode", L.mode),
    persona: optStr(o, "persona", L.persona),
    timings,
    app_version: optStr(o, "app_version", L.appVersion),
  };
}

export interface FeedbackDeps {
  authenticate: Authenticator;
  rateLimiter: RateLimiter;
  insert: (row: FeedbackRow) => Promise<void>;
  limits?: Limits;
}
export const DEFAULT_FEEDBACK_LIMITS: Limits = { perMinute: 6, perDay: 100, globalPerDay: 2000 };

export function createFeedbackHandler(deps: FeedbackDeps) {
  return async (req: Request): Promise<Response> => {
    if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS_HEADERS });
    try {
      if (req.method !== "POST") throw new HttpError(405, "method_not_allowed", "Use POST");
      const user = await deps.authenticate(req);
      const rl = await enforceLimits(
        deps.rateLimiter,
        "feedback",
        user.id,
        deps.limits ?? DEFAULT_FEEDBACK_LIMITS,
      );
      if (!rl.allowed) {
        throw new HttpError(429, "rate_limited", "Too many reports", {
          retryAfterSec: rl.retryAfterSec,
        });
      }
      const row = validateFeedback(await readLimitedJson(req, FEEDBACK_LIMITS.body), user.id);
      try {
        await deps.insert(row);
      } catch (e) {
        console.error("feedback_insert_failed", e instanceof Error ? e.message : String(e));
        throw new HttpError(503, "storage_unavailable", "Could not store the report");
      }
      return new Response(JSON.stringify({ ok: true }), {
        status: 200,
        headers: { "content-type": "application/json", ...CORS_HEADERS },
      });
    } catch (e) {
      return errorResponse(toHttpError(e));
    }
  };
}
