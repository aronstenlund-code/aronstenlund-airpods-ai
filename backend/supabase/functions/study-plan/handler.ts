import { type Authenticator } from "../_shared/auth.ts";
import { CORS_HEADERS, errorResponse, HttpError, toHttpError } from "../_shared/errors.ts";
import { readLimitedJson } from "../answer/validate.ts";
import { notificationFor, readinessOf, streakOf } from "./progress.ts";

/**
 * K17 (owner 2026-11-09 22:03): Lumen remembers what the student missed and plans the days up to the exam.
 * `POST /study-plan` (code only: no model call, no cost, nothing stored; the app keeps the history per exam).
 *
 * Request: {"today": "2026-11-10", "exams": [{"name": "Biologiprovet", "date": "2026-11-13",
 *            "concepts": [{"concept": "cellandning", "history": [{"date": "2026-11-09", "ok": false}, …]}, …]}]}
 *   history: every time the concept came up in a quiz, a grading or a practice exam (ok = right; unsure = false).
 * Response: {"exams": [{"name", "date", "days_left", "due": [{"concept", "last", "box", "reason"}],
 *            "prompt": "I går missade du cellandning, ska vi ta den?" | null,
 *            "plan": [{"date", "minutes", "concepts": [...], "note"}]}]}
 *
 * K31 (D115 C2/C3): optional "quiz_days": ["2026-11-08", …] (every day with at least one quiz answer, the student's
 *   calendar) -> "streak": {current, best, done_today, at_risk} and "notification": {title, body} | null (null = today
 *   is done, no reminder). K33 (N1): every exam gets "readiness": {ready_pct, practiced, total, weakest, explain}.
 * Spaced repetition (Leitner): a concept is in box 0-3 (next review after 1, 3, 7 days, then 14). A wrong answer
 * puts it in box 0 (back tomorrow); a right one moves it up a box. Due = the next review day has come.
 */
export const PLAN_LIMITS = { bodyBytes: 64 * 1024, exams: 10, concepts: 60, history: 30, name: 80, concept: 60 };
export const INTERVALS = [1, 3, 7, 14];

export interface HistoryItem {
  date: string;
  ok: boolean;
}
export interface ConceptIn {
  concept: string;
  history: HistoryItem[];
}
export interface Due {
  concept: string;
  last: string;
  box: number;
  next: string;
  reason: "missed" | "review";
}

const DAY = 86_400_000;
const iso = (t: number) => new Date(t).toISOString().slice(0, 10);
const parse = (d: string) => {
  const t = Date.parse(`${d}T00:00:00Z`);
  return Number.isFinite(t) ? t : null;
};

/** Box and next review date of one concept from its history (oldest first). */
export function schedule(history: HistoryItem[]): { box: number; last: string; next: string; lastOk: boolean } | null {
  const h = history.filter((x) => parse(x.date) !== null).sort((a, b) => parse(a.date)! - parse(b.date)!);
  if (!h.length) return null;
  let box = 0;
  for (const x of h) box = x.ok ? Math.min(INTERVALS.length - 1, box + 1) : 0;
  const last = h[h.length - 1];
  // a wrong (or unsure) answer comes back the next day; a right one after the box's interval
  const wait = last.ok ? INTERVALS[box] : INTERVALS[0];
  return { box, last: last.date, next: iso(parse(last.date)! + wait * DAY), lastOk: last.ok };
}

const WEEKDAY = ["söndags", "måndags", "tisdags", "onsdags", "torsdags", "fredags", "lördags"];
/** "I går", "I förrgår", "I måndags", "Den 2 november". */
export function whenSaid(last: string, today: string): string {
  const d = Math.round((parse(today)! - parse(last)!) / DAY);
  if (d <= 0) return "Tidigare i dag";
  if (d === 1) return "I går";
  if (d === 2) return "I förrgår";
  if (d < 7) return `I ${WEEKDAY[new Date(parse(last)!).getUTCDay()]}`;
  return `Förra veckan`;
}

export function dueConcepts(concepts: ConceptIn[], today: string): Due[] {
  const out: Due[] = [];
  for (const c of concepts) {
    const s = schedule(c.history);
    if (!s || s.next > today) continue;
    out.push({ concept: c.concept, last: s.last, box: s.box, next: s.next, reason: s.lastOk ? "review" : "missed" });
  }
  // missed first, then the oldest
  return out.sort((a, b) => (a.reason === b.reason ? a.last.localeCompare(b.last) : a.reason === "missed" ? -1 : 1));
}

export function promptFor(due: Due[], today: string): string | null {
  const m = due.filter((x) => x.reason === "missed");
  if (m.length) {
    const names = m.slice(0, 2).map((x) => x.concept);
    const list = names.length === 2 ? `${names[0]} och ${names[1]}` : names[0];
    return `${whenSaid(m[0].last, today)} missade du ${list}. Ska vi ta ${names.length === 2 ? "dem" : "det"} nu?`;
  }
  if (due.length) return `Dags att repetera ${due[0].concept}. Ska vi ta en snabb fråga?`;
  return null;
}

/**
 * A daily pass of about ten minutes from today up to the day before the exam: today's due concepts first, then
 * the weakest ones (most wrong), spread so every concept comes back at least once; the last day is a short mix.
 */
export function planDays(concepts: ConceptIn[], today: string, examDate: string): { date: string; minutes: number; concepts: string[]; note: string }[] {
  const t0 = parse(today)!, tE = parse(examDate);
  if (tE === null || tE <= t0) return [];
  const days = Math.min(14, Math.round((tE - t0) / DAY));
  const weak = concepts
    .map((c) => ({ c: c.concept, wrong: c.history.filter((x) => !x.ok).length, right: c.history.filter((x) => x.ok).length }))
    .sort((a, b) => b.wrong - a.wrong || a.right - b.right);
  const plan: { date: string; minutes: number; concepts: string[]; note: string }[] = [];
  const due = new Set(dueConcepts(concepts, today).map((x) => x.concept));
  let k = 0;
  for (let d = 0; d < days; d++) {
    const date = iso(t0 + d * DAY);
    const last = d === days - 1;
    const pick: string[] = [];
    if (d === 0) for (const c of due) if (pick.length < 3) pick.push(c);
    while (pick.length < (last ? 4 : 3) && weak.length) {
      const c = weak[k % weak.length].c;
      k++;
      if (!pick.includes(c)) pick.push(c);
      if (k > weak.length * 3) break;
    }
    plan.push({
      date,
      minutes: last ? 15 : 10,
      concepts: pick,
      note: last ? "Blandat förhör på det viktigaste, dagen före provet." : d === 0 && due.size ? "Det du missade först." : "Förhör på det som är svårast.",
    });
  }
  return plan;
}

function clean(s: unknown, max: number): string {
  return typeof s === "string" ? s.replace(/[\u0000-\u001f<>]/g, " ").replace(/\s+/g, " ").trim().slice(0, max) : "";
}
const dateOk = (s: unknown) => typeof s === "string" && /^\d{4}-\d{2}-\d{2}$/.test(s) && parse(s) !== null;

export interface PlanDeps {
  authenticate: Authenticator;
  clock?: () => Date;
}

export function createPlanHandler(deps: PlanDeps) {
  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json", "cache-control": "no-store", ...CORS_HEADERS } });
  return async (req: Request): Promise<Response> => {
    if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS_HEADERS });
    try {
      if (req.method !== "POST") throw new HttpError(405, "method_not_allowed", "Use POST");
      await deps.authenticate(req);
      const b = (await readLimitedJson(req, PLAN_LIMITS.bodyBytes)) as Record<string, unknown> | null;
      const today = dateOk(b?.today) ? String(b!.today) : (deps.clock ?? (() => new Date()))().toISOString().slice(0, 10);
      const exams = (Array.isArray(b?.exams) ? b!.exams : []).slice(0, PLAN_LIMITS.exams).map((e) => {
        const o = (e ?? {}) as Record<string, unknown>;
        const concepts: ConceptIn[] = (Array.isArray(o.concepts) ? o.concepts : []).slice(0, PLAN_LIMITS.concepts).map((c) => {
          const x = (c ?? {}) as Record<string, unknown>;
          return {
            concept: clean(x.concept, PLAN_LIMITS.concept),
            history: (Array.isArray(x.history) ? x.history : []).slice(-PLAN_LIMITS.history)
              .map((h) => h as Record<string, unknown>)
              .filter((h) => dateOk(h?.date) && typeof h?.ok === "boolean")
              .map((h) => ({ date: String(h.date), ok: h.ok as boolean })),
          };
        }).filter((c) => c.concept);
        return { name: clean(o.name, PLAN_LIMITS.name) || "Provet", date: dateOk(o.date) ? String(o.date) : null, concepts };
      });
      const quizDays = (Array.isArray(b?.quiz_days) ? b!.quiz_days : []).filter(dateOk).slice(-400).map(String);
      if (!exams.length && !Array.isArray(b?.quiz_days)) throw new HttpError(400, "invalid_request", "exams is required");
      const out = exams.map((e) => {
        const due = dueConcepts(e.concepts, today);
        return {
          name: e.name,
          date: e.date,
          days_left: e.date ? Math.round((parse(e.date)! - parse(today)!) / DAY) : null,
          due,
          prompt: promptFor(due, today),
          plan: e.date ? planDays(e.concepts, today, e.date) : [],
          readiness: readinessOf(e.concepts, today),
        };
      });
      const streak = streakOf(quizDays, today);
      // the nearest exam that has not been yet; its weakest concept goes in the notification
      const next = out.filter((e) => e.days_left !== null && e.days_left >= 0).sort((a, b) => a.days_left! - b.days_left!)[0] ?? null;
      const first = next ? (next.due[0]?.concept ?? next.readiness.weakest[0]?.concept ?? null) : null;
      return json({
        today,
        exams: out,
        streak,
        notification: notificationFor(streak, next ? { name: next.name, days_left: next.days_left, first } : null),
      });
    } catch (e) {
      return errorResponse(toHttpError(e));
    }
  };
}
