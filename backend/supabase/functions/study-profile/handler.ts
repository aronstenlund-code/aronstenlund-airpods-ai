import { type Authenticator } from "../_shared/auth.ts";
import { CORS_HEADERS, errorResponse, HttpError, toHttpError } from "../_shared/errors.ts";
import { appChecks, enforceLimits, type Limits, type RateLimiter } from "../_shared/ratelimit.ts";
import { networkKey } from "../_shared/demo.ts";
import { readLimitedJson } from "../answer/validate.ts";
import { nowContext } from "../answer/datecalc.ts";
import { sanitizeTagged } from "../answer/prompt.ts";
import type { LLMProvider } from "../answer/llm/types.ts";

/**
 * D84 (owner): `POST /study-profile` - a spoken profile ("Lumen, jag går i åk 9 och ska snart ha prov i biologi")
 * becomes the D83 profile, and a subject term list (30-50 central terms for the grade and subject, after
 * Skolverket's central content) for Scribe keyterms and for interpreting misheard words (`prep_terms`).
 * Haiku, short JSON; nothing is stored or logged (metadata row only).
 *
 * Request:  {"text": "...", "profile"?: {grade?, course?, subject?, exam_date?}, "language"?: "sv"}
 *           (no text: terms for the given profile only)
 * Response: {"profile": {"grade", "course", "subject", "exam_date", "no_exam"}, "terms": [...], "usage"}
 *           grade is one of y6 y7 y8 y9 gy1 gy2 gy3 university other (StudyProfile.Grade), or null.
 */
export const PROFILE_LIMITS = { bodyBytes: 8_192, text: 600, field: 80, terms: 50, term: 40 };
export const GRADES = ["y6", "y7", "y8", "y9", "gy1", "gy2", "gy3", "university", "other"] as const;
export type Grade = typeof GRADES[number];

export interface StudyProfileOut {
  grade: Grade | null;
  course: string | null;
  subject: string | null;
  /** ISO date (YYYY-MM-DD), absolute; null when no date was said. */
  exam_date: string | null;
  no_exam: boolean;
}

export interface ProfileConfig {
  limits: Limits;
  networkPerDay: number;
  model?: string;
  priceInPerMTok: number;
  priceOutPerMTok: number;
}
export const DEFAULT_PROFILE_CONFIG: ProfileConfig = {
  limits: { perMinute: 6, perDay: 60, globalPerDay: 5000 },
  networkPerDay: 1000,
  priceInPerMTok: 0.10,
  priceOutPerMTok: 0.50,
};

export interface ProfileDeps {
  authenticate: Authenticator;
  rateLimiter: RateLimiter;
  provider: LLMProvider | null;
  config?: ProfileConfig;
  recordUsage?: (rec: Record<string, unknown>) => void | Promise<void>;
  now?: () => Date;
}

export const SYSTEM_PROMPT_PROFILE =
  `You set up the study profile of a student in Sweden. You get <now> (today in Sweden), <current> (the profile so far, may be empty) and <said> (what the student just said about themselves, may be empty).

Return ONLY a JSON object:
{"profile": {"grade": ..., "course": ..., "subject": ..., "exam_date": ..., "no_exam": ...}, "terms": [...]}
- grade: one of "y6","y7","y8","y9" (åk 6-9, also "sexan", "nian"), "gy1","gy2","gy3" (gymnasiet år 1-3, "ettan/tvåan/trean på gymnasiet"), "university" (högskola, universitet), "other", or null when not said. Keep <current> values that <said> does not change.
- course: the gymnasium or university course if said ("Biologi 1", "Matematik 2c"), else null. subject: the school subject in Swedish with a capital letter ("Biologi", "Matematik"), else null.
- exam_date: the exam date as YYYY-MM-DD, always absolute from <now> ("på fredag", "nästa vecka" = Monday next week, "om två veckor"); "snart" without a day = null. no_exam: true only when the student says there is no exam.
- terms: 30-50 central Swedish terms of that subject for exactly that grade (and course), as in Skolverket's central content for it: the words a student meets in lessons and on tests, single terms or short compounds, most important first, no explanations, no duplicates. No subject known: [].`;

function clean(s: unknown, max: number): string | null {
  if (typeof s !== "string") return null;
  const t = s.replace(/[\u0000-\u001f]/g, " ").replace(/\s+/g, " ").trim();
  return t ? t.slice(0, max) : null;
}

export function parseProfileReply(text: string): { profile: StudyProfileOut; terms: string[] } {
  const empty = { profile: { grade: null, course: null, subject: null, exam_date: null, no_exam: false }, terms: [] };
  const m = /\{[\s\S]*\}/.exec(text);
  if (!m) return empty;
  let j: Record<string, unknown>;
  try {
    j = JSON.parse(m[0]);
  } catch {
    return empty;
  }
  const p = (j.profile ?? {}) as Record<string, unknown>;
  const grade = GRADES.includes(p.grade as Grade) ? p.grade as Grade : null;
  const date = typeof p.exam_date === "string" && /^\d{4}-\d{2}-\d{2}$/.test(p.exam_date) &&
      !Number.isNaN(Date.parse(p.exam_date))
    ? p.exam_date
    : null;
  const seen = new Set<string>();
  const terms = (Array.isArray(j.terms) ? j.terms : [])
    .map((t) => clean(t, PROFILE_LIMITS.term))
    .filter((t): t is string => !!t && !/[.!?:;]/.test(t) && !seen.has(t.toLowerCase()) && !!seen.add(t.toLowerCase()))
    .slice(0, PROFILE_LIMITS.terms);
  return {
    profile: {
      grade,
      course: clean(p.course, PROFILE_LIMITS.field),
      subject: clean(p.subject, PROFILE_LIMITS.field),
      exam_date: date,
      no_exam: p.no_exam === true,
    },
    terms,
  };
}

export function createProfileHandler(deps: ProfileDeps) {
  const cfg = deps.config ?? DEFAULT_PROFILE_CONFIG;
  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), {
      status,
      headers: { "content-type": "application/json", "cache-control": "no-store", ...CORS_HEADERS },
    });
  return async (req: Request): Promise<Response> => {
    if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS_HEADERS });
    const t0 = Date.now();
    try {
      if (req.method !== "POST") throw new HttpError(405, "method_not_allowed", "Use POST");
      const user = await deps.authenticate(req);
      const b = (await readLimitedJson(req, PROFILE_LIMITS.bodyBytes)) as Record<string, unknown> | null;
      const said = clean(b?.text, PROFILE_LIMITS.text) ?? "";
      const cur = (b?.profile ?? {}) as Record<string, unknown>;
      const current = ["grade", "course", "subject", "exam_date"]
        .map((k) => [k, clean(cur[k], PROFILE_LIMITS.field)])
        .filter(([, v]) => v)
        .map(([k, v]) => `${k}: ${v}`).join("; ");
      if (!said && !current) throw new HttpError(400, "invalid_request", "text or profile is required");
      const extra = appChecks("profile", await networkKey(req), user, {
        networkPerDay: cfg.networkPerDay,
        newUserAgeSec: 0,
        newUserPerHour: 0,
      });
      const rl = await enforceLimits(deps.rateLimiter, "profile", user.id, cfg.limits, 1, extra);
      if (!rl.allowed) {
        throw new HttpError(429, "rate_limited", "Too many requests", { retryAfterSec: rl.retryAfterSec });
      }
      if (!deps.provider) throw new HttpError(503, "provider_unconfigured", "LLM provider not configured");
      const now = (deps.now ?? (() => new Date()))();
      const user_ = `<now>${nowContext(now)}</now>\n<current>${sanitizeTagged(current)}</current>\n<said>${
        sanitizeTagged(said)
      }</said>`;
      let text = "";
      let inTok = 0, outTok = 0;
      for await (
        const c of deps.provider.stream({
          system: SYSTEM_PROMPT_PROFILE,
          user: user_,
          maxTokens: 700,
          cacheSystem: true,
          model: cfg.model,
          signal: req.signal,
        })
      ) {
        if (c.type === "text") text += c.text;
        else if (c.type === "usage") {
          inTok = c.inputTokens ?? inTok;
          outTok = c.outputTokens ?? outTok;
        }
      }
      const out = parseProfileReply(text);
      const cost = (inTok * cfg.priceInPerMTok + outTok * cfg.priceOutPerMTok) / 1e6;
      try {
        await deps.recordUsage?.({
          user_id: user.id,
          endpoint: "study-profile",
          provider: deps.provider.name,
          model: cfg.model ?? deps.provider.model,
          input_tokens: inTok,
          output_tokens: outTok,
          total_ms: Date.now() - t0,
          est_cost_usd: cost,
          status: "ok",
        });
      } catch (e) {
        console.error("usage_log_failed", e instanceof Error ? e.message : String(e));
      }
      return json({ ...out, usage: { input_tokens: inTok, output_tokens: outTok, est_cost_usd: cost } });
    } catch (e) {
      return errorResponse(toHttpError(e));
    }
  };
}
