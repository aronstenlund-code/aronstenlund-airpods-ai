import { type Authenticator } from "../_shared/auth.ts";
import { CORS_HEADERS, errorResponse, HttpError, toHttpError } from "../_shared/errors.ts";
import { appChecks, enforceLimits, type Limits, type RateLimiter } from "../_shared/ratelimit.ts";
import { networkKey } from "../_shared/demo.ts";
import { readLimitedJson } from "../answer/validate.ts";
import { sanitizeTagged } from "../answer/prompt.ts";
import { finalNumber, isBareNumber } from "./spoken.ts";
import type { LLMProvider, LLMRequest } from "../answer/llm/types.ts";

/**
 * D84 (owner): exam session. `POST /exam` with one of four actions. The exam and its assessment instructions are
 * interpreted ONCE from page images ("parse"); the app keeps the result and sends the task it needs with every
 * later call. Nothing is stored on the server (only a metadata row in `answer_usage`).
 *
 *  {"action":"parse","pages":[{"media_type":"image/jpeg","data":"<base64>"}], "subject"?, "grade"?}
 *     -> {"tasks":[{"no","text","points":{"E","C","A"},"answer","assessment"}], "boundaries":[{"grade","total","min_ca"?,"min_a"?}]}
 *     At most 10 pages per call; the app sends the exam and the instructions in batches and merges by task number.
 *  {"action":"hint","task":{...},"level":1|2|3,"tried"?}          -> {"hint"}
 *  {"action":"grade","task":{...},"answer":"<the student's answer>"} -> {"points":{E,C,A},"max":{E,C,A},"numeric":{...}|null,"feedback"}
 *  {"action":"summary","results":[{"no","points":{E,C,A}}],"boundaries":[...]} -> totals and the grade, in code only
 */
export const EXAM_LIMITS = {
  bodyBytes: 24 * 1024 * 1024,
  pages: 10,
  pageBase64: 3 * 1024 * 1024,
  text: 3000,
  answer: 3000,
  assessment: 3000,
  tasks: 80,
};

export interface Points {
  E: number;
  C: number;
  A: number;
}
export interface ExamTask {
  no: string;
  text: string;
  points: Points;
  answer: string;
  assessment: string;
}
export interface Boundary {
  grade: "E" | "D" | "C" | "B" | "A";
  total: number;
  /** At least this many points on C or A level (Swedish national exams: "varav minst … på lägst C-nivå"). */
  min_ca?: number;
  /** At least this many A points. */
  min_a?: number;
}

export interface ExamConfig {
  limits: Limits;
  networkPerDay: number;
  /** Parse model (vision). Default: the provider's (Haiku 5.5). */
  model?: string;
  priceInPerMTok: number;
  priceOutPerMTok: number;
}
export const DEFAULT_EXAM_CONFIG: ExamConfig = {
  limits: { perMinute: 12, perDay: 300, globalPerDay: 8000 },
  networkPerDay: 3000,
  priceInPerMTok: 0.10,
  priceOutPerMTok: 0.50,
};

export interface ExamDeps {
  authenticate: Authenticator;
  rateLimiter: RateLimiter;
  provider: LLMProvider | null;
  config?: ExamConfig;
  recordUsage?: (rec: Record<string, unknown>) => void | Promise<void>;
}

export const SYSTEM_PROMPT_EXAM_PARSE =
  `You read pages of a Swedish exam (often a national exam, "nationellt prov") and/or its assessment instructions ("bedömningsanvisningar"), given as images. Return ONLY a JSON object:
{"tasks": [{"no": "1a", "text": "...", "points": {"E": 1, "C": 0, "A": 0}, "answer": "...", "assessment": "..."}], "boundaries": [{"grade": "E", "total": 15, "min_ca": 0, "min_a": 0}]}
- tasks: every task you can see, in order. "no" as printed ("1", "3b"). "text": the full task text, word for word, including every value of a table (row by row, "Måndag: 12, Tisdag: 18, …") and a one-sentence description of a figure in square brackets. "points": the points per level as printed, e.g. (1/1/0) = E 1, C 1, A 0; 0 when not printed. "answer": the correct answer or model solution from the instructions ("" when not on these pages). "assessment": the scoring rules for the task from the instructions, word for word in substance ("" when not on these pages).
- boundaries: the grade limits ("provbetygsgränser") when they are on these pages: total points for E, D, C, B, A and the extra conditions (min_ca = points on at least C level, min_a = A points); [] otherwise.
- Copy numbers exactly. Never invent a task, an answer or a limit; leave a field empty when it is not on these pages. No other text.`;

export const SYSTEM_PROMPT_EXAM_HINT =
  `You help a student during an exam practice session in Sweden. You get <task> (text, points, the correct answer and the scoring rules), <level> (1, 2 or 3) and <tried> (optional: what the student has tried). Reply with plain spoken Swedish, never the final answer:
- level 1: a nudge in one sentence: what the task is really asking or which idea to start from.
- level 2: the method in one or two sentences: the formula, concept or first step, without doing the calculation.
- level 3: a worked first step in two or three sentences, stopping before the final answer.
No markdown, no symbols the speech would read out, numbers as digits.`;

export const SYSTEM_PROMPT_EXAM_GRADE =
  `You mark a student's answer to one exam task, strictly by the scoring rules. You get <task> (text, points per level E/C/A, the correct answer and the scoring rules), <numeric_check> (computed by code: whether the student's final number equals the correct one; trust it) and <answer> (the student's answer, from speech, so it may contain recognition errors in words but not in meaning).
Return ONLY a JSON object: {"points": {"E": 0, "C": 0, "A": 0}, "feedback": "..."}.
- Give each point exactly as the scoring rules say, never more than the task's points per level. When <numeric_check> says the final number is wrong, no point that requires the correct answer is given; when it says it is right, the point for the correct answer is given. A bare number without any method shown never earns a method point. Never claim the student wrote something that is not in <answer>.
- feedback: one or two spoken Swedish sentences: what earned points and the single most useful thing that was missing. Never the full solution.`;

function clean(s: unknown, max: number): string {
  if (typeof s !== "string") return "";
  return s.replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f]/g, " ").trim().slice(0, max);
}
const num = (v: unknown) => {
  const n = Number(v);
  return Number.isFinite(n) && n >= 0 && n <= 100 ? Math.round(n) : 0;
};
const pts = (v: unknown): Points => {
  const o = (v ?? {}) as Record<string, unknown>;
  return { E: num(o.E), C: num(o.C), A: num(o.A) };
};

export function validTask(v: unknown): ExamTask {
  const o = (v ?? {}) as Record<string, unknown>;
  const task = {
    no: clean(o.no, 12),
    text: clean(o.text, EXAM_LIMITS.text),
    points: pts(o.points),
    answer: clean(o.answer, EXAM_LIMITS.answer),
    assessment: clean(o.assessment, EXAM_LIMITS.assessment),
  };
  if (!task.text) throw new HttpError(400, "invalid_request", "task.text is required");
  return task;
}

export function validBoundaries(v: unknown): Boundary[] {
  const grades = ["E", "D", "C", "B", "A"];
  return (Array.isArray(v) ? v : [])
    .map((b) => b as Record<string, unknown>)
    .filter((b) => grades.includes(String(b?.grade)))
    .map((b) => ({
      grade: String(b.grade) as Boundary["grade"],
      total: num(b.total),
      ...(num(b.min_ca) ? { min_ca: num(b.min_ca) } : {}),
      ...(num(b.min_a) ? { min_a: num(b.min_a) } : {}),
    }))
    .filter((b) => b.total > 0);
}

/** The parsed JSON of a "parse" call: well-formed tasks and boundaries only. */
export function parseExamReply(text: string): { tasks: ExamTask[]; boundaries: Boundary[] } {
  const m = /\{[\s\S]*\}/.exec(text);
  if (!m) return { tasks: [], boundaries: [] };
  let j: Record<string, unknown>;
  try {
    j = JSON.parse(m[0]);
  } catch {
    return { tasks: [], boundaries: [] };
  }
  const tasks: ExamTask[] = [];
  for (const t of Array.isArray(j.tasks) ? j.tasks : []) {
    try {
      const v = validTask(t);
      if (v.no) tasks.push(v);
    } catch { /* a task without text is dropped */ }
  }
  return { tasks: tasks.slice(0, EXAM_LIMITS.tasks), boundaries: validBoundaries(j.boundaries) };
}

/** The student's final number (spoken Swedish too, K1.1): see spoken.ts. */
export function lastNumber(text: string): number | null {
  return finalNumber(text);
}

/** "beräkningar i kod": the student's final number against the correct one. Exact for whole numbers, two decimals otherwise. */
export function numericCheck(correct: string, answer: string): { expected: number; given: number | null; equal: boolean } | null {
  // an algebraic answer ("8 − x") is not a number: no numeric check, the scoring rules decide
  if (/[+\-−*/^]\s*\(?[a-zåäö]\)?\s*$|^\s*[a-zåäö]\s*[+\-−*/^]/i.test(correct.trim())) return null;
  const expected = finalNumber(correct);
  if (expected === null) return null;
  const given = finalNumber(answer);
  if (given === null) return { expected, given: null, equal: false };
  const tol = Number.isInteger(expected) ? 1e-9 : Math.max(0.005, Math.abs(expected) * 0.0005);
  return { expected, given, equal: Math.abs(given - expected) <= tol };
}

/** The level the scoring rules give for the correct answer itself ("+C för korrekt svar"), or null. */
export function answerLevel(assessment: string): "E" | "C" | "A" | null {
  const m = /\+\s*([ECA])(?:[^+]{0,40}?)(?:korrekt|rätt|godtagbart)\s+(?:svar|slutsvar|värde|resultat)/i.exec(assessment);
  return m ? (m[1].toUpperCase() as "E" | "C" | "A") : null;
}

/** K1.1: the model's points corrected in code with the numeric check. */
export function correctPoints(task: ExamTask, answer: string, model: Points, numeric: ReturnType<typeof numericCheck>): Points {
  const max = task.points;
  let p: Points = { E: Math.min(model.E, max.E), C: Math.min(model.C, max.C), A: Math.min(model.A, max.A) };
  const level = answerLevel(task.assessment);
  if (numeric && level) {
    if (numeric.equal && p[level] === 0 && max[level] > 0) p = { ...p, [level]: 1 }; // "x är sju" = 7: the answer point
    // a wrong number never gets the answer point (a method point on the same level stays)
    if (!numeric.equal) p = { ...p, [level]: Math.min(p[level], Math.max(0, max[level] - 1)) };
  }
  // a bare number shows no method: a wrong one earns nothing ("500", "ungefär 16")
  if (numeric && !numeric.equal && isBareNumber(answer)) p = { E: 0, C: 0, A: 0 };
  return p;
}

/** "hur gick det?": totals and the grade reached, computed in code only. */
export function summarize(results: { no: string; points: Points }[], boundaries: Boundary[]) {
  const sum: Points = { E: 0, C: 0, A: 0 };
  for (const r of results) {
    sum.E += r.points.E;
    sum.C += r.points.C;
    sum.A += r.points.A;
  }
  const total = sum.E + sum.C + sum.A;
  const meets = (b: Boundary) =>
    total >= b.total && (b.min_ca === undefined || sum.C + sum.A >= b.min_ca) &&
    (b.min_a === undefined || sum.A >= b.min_a);
  const order = ["E", "D", "C", "B", "A"];
  const sorted = [...boundaries].sort((a, b) => order.indexOf(a.grade) - order.indexOf(b.grade));
  let grade: string = sorted.length ? "F" : "okänt";
  for (const b of sorted) if (meets(b)) grade = b.grade;
  const next = sorted.find((b) => order.indexOf(b.grade) > order.indexOf(grade === "F" ? "" : grade) && !meets(b));
  const needCa = next?.min_ca !== undefined ? Math.max(0, next.min_ca - (sum.C + sum.A)) : 0;
  const needA = next?.min_a !== undefined ? Math.max(0, next.min_a - sum.A) : 0;
  const toNext = next
    ? {
      grade: next.grade,
      // Oscar 2026-11-08: "saknas 2 poäng, varav 3 A-poäng" is impossible; the A points needed are new points
      total: Math.max(0, next.total - total, needA, needCa),
      ...(next.min_ca !== undefined ? { ca: needCa } : {}),
      ...(next.min_a !== undefined ? { a: needA } : {}),
    }
    : null;
  const spoken = boundaries.length
    ? `Du har ${total} poäng, varav ${sum.C} C-poäng och ${sum.A} A-poäng. Det räcker till ${grade === "F" ? "F" : `betyget ${grade}`}.` +
      (toNext
        ? toNext.a && toNext.a >= toNext.total
          ? ` Till ${toNext.grade} saknas ${toNext.a} A-poäng.`
          : toNext.ca && toNext.ca >= toNext.total
          ? ` Till ${toNext.grade} saknas ${toNext.ca} poäng på C- eller A-nivå.`
          : ` Till ${toNext.grade} saknas ${toNext.total} poäng${
            toNext.a ? `, varav ${toNext.a} A-poäng` : toNext.ca ? `, varav ${toNext.ca} på C- eller A-nivå` : ""
          }.`
        : "")
    : `Du har ${total} poäng, varav ${sum.C} C-poäng och ${sum.A} A-poäng.`;
  return { points: sum, total, grade, to_next: toNext, tasks: results.length, spoken };
}

const taskTag = (t: ExamTask) =>
  `<task>\nUppgift ${sanitizeTagged(t.no)}: ${sanitizeTagged(t.text)}\nPoäng: E ${t.points.E}, C ${t.points.C}, A ${t.points.A}\nRätt svar: ${
    sanitizeTagged(t.answer)
  }\nBedömning: ${sanitizeTagged(t.assessment)}\n</task>`;

export function createExamHandler(deps: ExamDeps) {
  const cfg = deps.config ?? DEFAULT_EXAM_CONFIG;
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
      const b = (await readLimitedJson(req, EXAM_LIMITS.bodyBytes)) as Record<string, unknown> | null;
      const action = String(b?.action ?? "");
      if (action === "summary") {
        const results = (Array.isArray(b?.results) ? b!.results : []).slice(0, EXAM_LIMITS.tasks).map((r) => ({
          no: clean((r as Record<string, unknown>)?.no, 12),
          points: pts((r as Record<string, unknown>)?.points),
        }));
        return json(summarize(results, validBoundaries(b?.boundaries))); // no model, no cost
      }
      if (!["parse", "hint", "grade"].includes(action)) {
        throw new HttpError(400, "invalid_request", "action must be parse, hint, grade or summary");
      }
      const extra = appChecks("exam", await networkKey(req), user, {
        networkPerDay: cfg.networkPerDay,
        newUserAgeSec: 0,
        newUserPerHour: 0,
      });
      const rl = await enforceLimits(deps.rateLimiter, "exam", user.id, cfg.limits, 1, extra);
      if (!rl.allowed) {
        throw new HttpError(429, "rate_limited", "För många försök just nu. Vänta en liten stund och försök igen.", {
          retryAfterSec: rl.retryAfterSec,
        });
      }
      if (!deps.provider) throw new HttpError(503, "provider_unconfigured", "LLM provider not configured");

      let llm: LLMRequest;
      let numeric: ReturnType<typeof numericCheck> = null;
      let task: ExamTask | null = null;
      if (action === "parse") {
        const pages = Array.isArray(b?.pages) ? b!.pages : [];
        if (!pages.length || pages.length > EXAM_LIMITS.pages) {
          throw new HttpError(400, "invalid_request", `pages: 1-${EXAM_LIMITS.pages} images per call`);
        }
        const images = pages.map((p, i) => {
          const o = (p ?? {}) as Record<string, unknown>;
          const mediaType = String(o.media_type ?? "image/jpeg");
          const data = typeof o.data === "string" ? o.data.replace(/^data:[^,]+,/, "") : "";
          if (!["image/jpeg", "image/png", "image/webp"].includes(mediaType) || !data) {
            throw new HttpError(400, "invalid_request", `pages[${i}] needs media_type (jpeg/png/webp) and base64 data`);
          }
          if (data.length > EXAM_LIMITS.pageBase64) {
            throw new HttpError(413, "payload_too_large", `pages[${i}] is larger than 3 MB`);
          }
          return { mediaType: mediaType as "image/jpeg" | "image/png" | "image/webp", data };
        });
        const ctx = [clean(b?.subject, 60) && `Ämne: ${clean(b?.subject, 60)}`, clean(b?.grade, 60) && `Årskurs: ${clean(b?.grade, 60)}`]
          .filter(Boolean).join(". ");
        llm = {
          system: SYSTEM_PROMPT_EXAM_PARSE,
          user: `${ctx ? `<context>${sanitizeTagged(ctx)}</context>\n` : ""}Read these ${images.length} pages.`,
          images,
          maxTokens: 8000,
          cacheSystem: true,
          model: cfg.model,
          signal: req.signal,
        };
      } else if (action === "hint") {
        task = validTask(b?.task);
        const level = [1, 2, 3].includes(Number(b?.level)) ? Number(b?.level) : 1;
        llm = {
          system: SYSTEM_PROMPT_EXAM_HINT,
          user: `${taskTag(task)}\n<level>${level}</level>\n<tried>${sanitizeTagged(clean(b?.tried, 1000))}</tried>`,
          maxTokens: 200,
          cacheSystem: true,
          signal: req.signal,
        };
      } else {
        task = validTask(b?.task);
        const answer = clean(b?.answer, EXAM_LIMITS.answer);
        if (!answer) throw new HttpError(400, "invalid_request", "answer is required");
        numeric = task.answer ? numericCheck(task.answer, answer) : null;
        const nc = numeric
          ? numeric.equal
            ? `The final number is correct (${numeric.expected}).`
            : `The final number is wrong: expected ${numeric.expected}, the student gave ${numeric.given ?? "no number"}.`
          : "No numeric answer to check.";
        llm = {
          system: SYSTEM_PROMPT_EXAM_GRADE,
          user: `${taskTag(task)}\n<numeric_check>${nc}</numeric_check>\n<answer>${sanitizeTagged(answer)}</answer>`,
          maxTokens: 300,
          cacheSystem: true,
          signal: req.signal,
        };
      }
      let text = "";
      let inTok = 0, outTok = 0;
      for await (const c of deps.provider.stream(llm)) {
        if (c.type === "text") text += c.text;
        else {
          inTok = c.inputTokens ?? inTok;
          outTok = c.outputTokens ?? outTok;
        }
      }
      const cost = (inTok * cfg.priceInPerMTok + outTok * cfg.priceOutPerMTok) / 1e6;
      try {
        await deps.recordUsage?.({
          user_id: user.id,
          endpoint: `exam-${action}`,
          provider: deps.provider.name,
          model: llm.model ?? deps.provider.model,
          input_tokens: inTok,
          output_tokens: outTok,
          total_ms: Date.now() - t0,
          est_cost_usd: cost,
          status: "ok",
        });
      } catch (e) {
        console.error("usage_log_failed", e instanceof Error ? e.message : String(e));
      }
      const usage = { input_tokens: inTok, output_tokens: outTok, est_cost_usd: cost };
      if (action === "parse") {
        const out = parseExamReply(text);
        if (!out.tasks.length && !out.boundaries.length) {
          throw new HttpError(502, "exam_unreadable", "No tasks or grade limits could be read from these pages");
        }
        return json({ ...out, usage });
      }
      if (action === "hint") return json({ hint: text.trim().replace(/\s+/g, " "), usage });
      // grade: the points are clamped to the task's points in code; the sum is code
      const m = /\{[\s\S]*\}/.exec(text);
      let p: Points = { E: 0, C: 0, A: 0 };
      let feedback = "";
      try {
        const j = m ? JSON.parse(m[0]) : {};
        p = pts(j.points);
        feedback = clean(j.feedback, 600);
      } catch { /* malformed: zero points, no feedback */ }
      const max = task!.points;
      const answerText = clean(b?.answer, EXAM_LIMITS.answer);
      const points = correctPoints(task!, answerText, p, numeric);
      // K1.7 (Oscar: "du har räknat ut summan rätt, eftersom 66 ingår" for "ungefär 16"): a bare wrong number
      // shows no work, so the feedback never praises a method; it says so in code
      if (numeric && !numeric.equal && isBareNumber(answerText)) {
        feedback = "Svaret stämmer inte, och utan uträkning finns ingen metod att ge poäng för. Visa hur du räknar, steg för steg.";
      }
      return json({ points, max, total: points.E + points.C + points.A, numeric, feedback, usage });
    } catch (e) {
      return errorResponse(toHttpError(e));
    }
  };
}
