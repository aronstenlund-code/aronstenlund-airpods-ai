import { type Authenticator } from "../_shared/auth.ts";
import { CORS_HEADERS, errorResponse, HttpError, toHttpError } from "../_shared/errors.ts";
import { appChecks, enforceLimits, type Limits, type RateLimiter } from "../_shared/ratelimit.ts";
import { networkKey } from "../_shared/demo.ts";
import { readLimitedJson } from "../answer/validate.ts";
import { sanitizeTagged } from "../answer/prompt.ts";
import { finalNumber, isBareNumber } from "./spoken.ts";
import type { LLMProvider, LLMRequest } from "../answer/llm/types.ts";
import { practiceNav, spokenTask } from "./practice.ts";
import { DEFAULT_DRILL_CONFIG, docxText, DRILL_WEIGHT, type DrillConfig, handleDrill, type MaterialStore, uploadUrls } from "./drill.ts";

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
 *
 * K15 (practice exam by voice): "parse" also takes {"text": "<the exam as text>"} (a pasted text or a PDF's text);
 * every task gets "topic" (1-3 words, for weak areas), "spoken" (how Lumen reads it aloud) and "answer_source"
 * ("facit" from the material, or "eget svar": Lumen's own A-level answer when the material has none; off with
 * "own_answers": false). {"action":"nav","utterance","current","nos":[...]} -> {"action","index"?} in code only:
 * next, prev, goto ("fråga sju"), skip, repeat, stop, results, or "answer" (grade it). "grade" with "practice": true
 * explains the right answer too.
 * K45 (D142): Repetitionsläget: "drill", "drill_answers", "drill_one" and "doc_text", see drill.ts.
 */
export const EXAM_LIMITS = {
  bodyBytes: 24 * 1024 * 1024,
  pages: 10,
  pageBase64: 3 * 1024 * 1024,
  text: 3000,
  answer: 3000,
  assessment: 3000,
  tasks: 80,
  /** K15: an exam given as text (a pasted text or a PDF's text layer). */
  examText: 40_000,
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
  /** K15: the concept the task tests (1-3 words), for "testa mina svagaste". */
  topic?: string;
  /** K15: "facit" (from the material) or "eget svar" (Lumen's own A-level answer). */
  answer_source?: "facit" | "eget svar";
  /** K15: the task as read aloud. */
  spoken?: string;
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
  /** K15: the model that writes Lumen's own answers when the material has no facit (correctness matters). */
  solveModel?: string;
  solvePriceInPerMTok?: number;
  solvePriceOutPerMTok?: number;
  /** K45: Repetitionsläget (drill, drill_answers, drill_one). */
  drill?: DrillConfig;
}

export const DEFAULT_EXAM_CONFIG: ExamConfig = {
  limits: { perMinute: 12, perDay: 300, globalPerDay: 8000 },
  networkPerDay: 3000,
  priceInPerMTok: 0.10,
  priceOutPerMTok: 0.50,
  solveModel: "claude-sonnet-5-5",
  solvePriceInPerMTok: 2,
  solvePriceOutPerMTok: 10,
};

export interface ExamDeps {
  authenticate: Authenticator;
  rateLimiter: RateLimiter;
  provider: LLMProvider | null;
  config?: ExamConfig;
  recordUsage?: (rec: Record<string, unknown>) => void | Promise<void>;
  /** K53: the private bucket for uploaded photos. */
  material?: MaterialStore | null;
  /** K61 (D175): the month's generated questions (used, limit); "drill" never makes more than are left. */
  quota?: (userId: string) => Promise<{ used: number; lim: number }>;
}

/** K61: the first day of next month in Stockholm time (when the month's questions start again). */
function monthResets(nowMs: number): string {
  const ym = new Intl.DateTimeFormat("sv-SE", { timeZone: "Europe/Stockholm", year: "numeric", month: "2-digit" }).format(new Date(nowMs));
  const [y, m] = ym.split("-").map(Number);
  return m === 12 ? `${y + 1}-01-01` : `${y}-${String(m + 1).padStart(2, "0")}-01`;
}

export const SYSTEM_PROMPT_EXAM_PARSE =
  `You read a Swedish exam or practice exam (often a national exam, "nationellt prov", or a teacher's "övningsprov" or "instuderingsfrågor") and/or its assessment instructions ("bedömningsanvisningar"), given as page images or as text. Return ONLY a JSON object:
{"tasks": [{"no": "1a", "text": "...", "points": {"E": 1, "C": 0, "A": 0}, "answer": "...", "assessment": "...", "topic": "..."}], "boundaries": [{"grade": "E", "total": 15, "min_ca": 0, "min_a": 0}]}
- tasks: every task you can see, in order. "no" as printed ("1", "3b"). "text": the full task text, word for word, including every value of a table (row by row, "Måndag: 12, Tisdag: 18, …") and a one-sentence description of a figure in square brackets. "points": the points per level as printed, e.g. (1/1/0) = E 1, C 1, A 0; 0 when not printed. "answer": the correct answer or model solution from the instructions ("" when not on these pages). "assessment": the scoring rules for the task from the instructions, word for word in substance ("" when not on these pages).
- boundaries: the grade limits ("provbetygsgränser") when they are on these pages: total points for E, D, C, B, A and the extra conditions (min_ca = points on at least C level, min_a = A points); [] otherwise.
- "topic": the concept the task tests, in one to three Swedish words ("procent", "linjära ekvationer", "franska revolutionen").
- A list of numbered questions without points: each question is a task, its points 0. Questions that are not numbered: number them 1, 2, 3 in order.
- Copy numbers exactly. Never invent a task, an answer or a limit; leave a field empty when it is not in the material. No other text.`;

/** K15: Lumen's own A-level answers for tasks the material gives no facit for. */
export const SYSTEM_PROMPT_EXAM_SOLVE =
  `You write the model answers for tasks of a Swedish practice exam that has no facit. You get <context> (subject and grade) and <tasks> (JSON: no, text, points). Return ONLY a JSON object {"answers": [{"no": "1", "answer": "..."}]} with one entry per task.
- Each answer is what earns full points at A level for that grade, in Swedish: for a calculation the method in short steps and the final answer with its unit; for a question in words the key concepts, how they connect and one example, in two to four short sentences.
- Work every calculation out carefully before you write it; the final number must be right. When a task cannot be answered from its text (a missing figure or table), say so in the answer in one sentence.
No markdown, no other text.`;

export const SYSTEM_PROMPT_EXAM_HINT =
  `You help a student during an exam practice session in Sweden. You get <task> (text, points, the correct answer and the scoring rules), <level> (1, 2 or 3) and <tried> (optional: what the student has tried). Reply with plain spoken Swedish, never the final answer:
- level 1: a nudge in one sentence: what the task is really asking or which idea to start from.
- level 2: the method in one or two sentences: the formula, concept or first step, without doing the calculation.
- level 3: a worked first step in two or three sentences, stopping before the final answer.
No markdown, no symbols the speech would read out, numbers as digits.`;

export const SYSTEM_PROMPT_EXAM_GRADE =
  `You mark a student's answer to one exam task, strictly by the scoring rules. You get <task> (text, points per level E/C/A, the correct answer and the scoring rules), <numeric_check> (computed by code: whether the student's final number equals the correct one; trust it) and <answer> (the student's answer, from speech, so it may contain recognition errors in words but not in meaning).
Return ONLY a JSON object: {"points": {"E": 0, "C": 0, "A": 0}, "feedback": "..."}.
- Give each point exactly as the scoring rules say, never more than the task's points per level. When <numeric_check> says the final number is wrong, no point that requires the correct answer is given; when it says it is right, the point for the correct answer is given. A bare number without any method shown never earns a method point. When a task asks for several results (for example area and perimeter) and the student gives them without working, each correct result earns its answer point, as when the national exam says "Endast svar krävs" (area and perimeter both right = 2 E points, when the task has them). Never claim the student wrote something that is not in <answer>.
- feedback: one or two spoken Swedish sentences: what earned points and the single most useful thing that was missing. Never the full solution.`;

/** K15: in a practice run the student also hears why (the exam itself never gives the solution). */
export const PRACTICE_GRADE_RULE = `
- PRACTICE RUN: this is practice, not the exam. After the points, the feedback also says the correct answer and why in two or three short spoken sentences (the method or the key concept), so the student learns it now. Start with "Rätt.", "Delvis rätt." or "Inte riktigt.".`;

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
  const topic = clean(o.topic, 40);
  const src = o.answer_source === "eget svar" || o.answer_source === "facit" ? o.answer_source : undefined;
  const task: ExamTask = {
    no: clean(o.no, 12),
    text: clean(o.text, EXAM_LIMITS.text),
    points: pts(o.points),
    answer: clean(o.answer, EXAM_LIMITS.answer),
    assessment: clean(o.assessment, EXAM_LIMITS.assessment),
    ...(topic ? { topic } : {}),
    ...(src ? { answer_source: src } : {}),
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
  const tol = Number.isInteger(expected) ? 1e-9 : Math.max(0.005, Math.abs(expected) * 0.0005);
  // K15 (live: "trehundrasjuttiofem kronor, för tjugofem procent av trehundra är sjuttiofem" was read as 75): a
  // spoken answer often gives the result first and the reason after "för"/"eftersom": the result is the last number
  // before the reason
  const head = answer.split(/,?\s+(?:för att|för|eftersom|därför att|på grund av|alltså för|because|since)\s+/iu)[0];
  const lead = head !== answer ? finalNumber(head) : null;
  if (lead !== null && Math.abs(lead - expected) <= tol) return { expected, given: lead, equal: true };
  const given = finalNumber(answer);
  if (given === null) return { expected, given: null, equal: false };
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
    ? `Du har ${total} poäng, varav ${sum.C} C-poäng och ${sum.A} A-poäng. ${grade === "F" ? "Det räcker inte till godkänt än." : `Det räcker till betyget ${grade}.`}` +
      (toNext
        ? toNext.a && toNext.a >= toNext.total
          ? ` Till ${toNext.grade === "E" ? "godkänt" : toNext.grade} saknas ${toNext.a} A-poäng.`
          : toNext.ca && toNext.ca >= toNext.total
          ? ` Till ${toNext.grade === "E" ? "godkänt" : toNext.grade} saknas ${toNext.ca} poäng på C- eller A-nivå.`
          : ` Till ${toNext.grade === "E" ? "godkänt" : toNext.grade} saknas ${toNext.total} poäng${
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
      if (action === "nav") {
        // K15: what the student said during the practice run, decided in code (no model, no cost)
        const nos = (Array.isArray(b?.nos) ? b!.nos : []).slice(0, EXAM_LIMITS.tasks).map((x) => clean(x, 12)).filter(Boolean);
        const current = Math.max(0, Math.min(nos.length - 1, Math.floor(Number(b?.current) || 0)));
        return json(practiceNav(clean(b?.utterance, 300), current, nos));
      }
      if (action === "upload_urls") {
        // K53: signed upload URLs for many photos (no model, no cost); counted lightly in the exam limit
        if (!deps.material) throw new HttpError(503, "unconfigured", "Uploads are not configured");
        const rl = await enforceLimits(deps.rateLimiter, "exam_upload", user.id, { perMinute: 10, perDay: 200, globalPerDay: 100_000 }, 1);
        if (!rl.allowed) throw new HttpError(429, "rate_limited", "För många försök just nu. Vänta en liten stund.", { retryAfterSec: rl.retryAfterSec });
        return json(await uploadUrls(user.id, (b ?? {}) as Record<string, unknown>, deps.material));
      }
      if (action === "doc_text") {
        // K45: a Word file's text, read in code (iOS cannot read .docx); no model, no cost, nothing kept
        return json({ text: await docxText(String(b?.data ?? "")) });
      }
      const drill = action === "drill" || action === "drill_answers" || action === "drill_one";
      if (!drill && !["parse", "hint", "grade"].includes(action)) {
        throw new HttpError(400, "invalid_request", "action must be parse, hint, grade, summary, nav, drill, drill_answers, drill_one or doc_text");
      }
      const extra = appChecks("exam", await networkKey(req), user, {
        networkPerDay: cfg.networkPerDay,
        newUserAgeSec: 0,
        newUserPerHour: 0,
      });
      const rl = await enforceLimits(deps.rateLimiter, "exam", user.id, cfg.limits, drill ? DRILL_WEIGHT[action] : 1, extra);
      if (!rl.allowed) {
        throw new HttpError(429, "rate_limited", "För många försök just nu. Vänta en liten stund och försök igen.", {
          retryAfterSec: rl.retryAfterSec,
        });
      }
      if (!deps.provider) throw new HttpError(503, "provider_unconfigured", "LLM provider not configured");
      if (drill) {
        // K61 (D175): never more questions than the month has left; none left = say so before any work
        const req0 = { ...((b ?? {}) as Record<string, unknown>) };
        delete req0._max_questions;
        let quota: { used: number; limit: number; left: number; per: "month"; resets: string } | null = null;
        if (action === "drill" && deps.quota) {
          const q = await deps.quota(user.id);
          quota = { used: q.used, limit: q.lim, left: Math.max(0, q.lim - q.used), per: "month", resets: monthResets(Date.now()) };
          if (quota.left <= 0) {
            return json({
              error: { code: "quota_exceeded", message: "Du har inga frågor kvar den här månaden. Andras prov är gratis.", fallback: false },
              ...quota,
            }, 402);
          }
          req0._max_questions = quota.left;
        }
        const { body, steps } = await handleDrill(
          action as "drill" | "drill_answers" | "drill_one",
          req0,
          deps.provider,
          cfg.drill ?? DEFAULT_DRILL_CONFIG,
          req.signal,
          { userId: user.id, store: deps.material ?? null },
        );
        for (const st of steps) {
          try {
            await deps.recordUsage?.({
              user_id: user.id,
              endpoint: `exam-${action}`,
              provider: deps.provider.name,
              model: st.model,
              input_tokens: st.input_tokens,
              output_tokens: st.output_tokens,
              total_ms: Date.now() - t0,
              est_cost_usd: st.est_cost_usd,
              status: "ok",
            });
          } catch (e) {
            console.error("usage_log_failed", e instanceof Error ? e.message : String(e));
          }
        }
        return json(quota ? { ...body, quota } : body);
      }

      let llm: LLMRequest;
      let numeric: ReturnType<typeof numericCheck> = null;
      let task: ExamTask | null = null;
      const examText = action === "parse" && typeof b?.text === "string" ? clean(b.text, EXAM_LIMITS.examText) : "";
      if (action === "parse" && examText) {
        const ctx = [clean(b?.subject, 60) && `Ämne: ${clean(b?.subject, 60)}`, clean(b?.grade, 60) && `Årskurs: ${clean(b?.grade, 60)}`]
          .filter(Boolean).join(". ");
        llm = {
          system: SYSTEM_PROMPT_EXAM_PARSE,
          user: `${ctx ? `<context>${sanitizeTagged(ctx)}</context>\n` : ""}<material>\n${sanitizeTagged(examText)}\n</material>\nRead this material.`,
          maxTokens: 8000,
          cacheSystem: true,
          model: cfg.model,
          signal: req.signal,
        };
      } else if (action === "parse") {
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
        // K15: a study question without points (instuderingsfrågor) is marked right or wrong: one E point
        if (task.points.E + task.points.C + task.points.A === 0) task = { ...task, points: { E: 1, C: 0, A: 0 } };
        const answer = clean(b?.answer, EXAM_LIMITS.answer);
        if (!answer) throw new HttpError(400, "invalid_request", "answer is required");
        numeric = task.answer ? numericCheck(task.answer, answer) : null;
        const nc = numeric
          ? numeric.equal
            ? `The final number is correct (${numeric.expected}).`
            : `The final number is wrong: expected ${numeric.expected}, the student gave ${numeric.given ?? "no number"}.`
          : "No numeric answer to check.";
        llm = {
          system: SYSTEM_PROMPT_EXAM_GRADE + (b?.practice === true ? PRACTICE_GRADE_RULE : ""),
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
        else if (c.type === "usage") {
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
        // K15: Lumen's own A-level answer where the material has no facit (one extra call), and the spoken form
        const missing = out.tasks.filter((t) => !t.answer);
        let solveCost = 0;
        if (missing.length && b?.own_answers !== false) {
          const ctx = [clean(b?.subject, 60) && `Ämne: ${clean(b?.subject, 60)}`, clean(b?.grade, 60) && `Årskurs: ${clean(b?.grade, 60)}`]
            .filter(Boolean).join(". ");
          let st = "";
          let si = 0, so = 0;
          try {
          for await (const c of deps.provider.stream({
            system: SYSTEM_PROMPT_EXAM_SOLVE,
            user: `<context>${sanitizeTagged(ctx || "okänt")}</context>\n<tasks>${
              sanitizeTagged(JSON.stringify(missing.map((t) => ({ no: t.no, text: t.text, points: t.points }))))
            }</tasks>`,
            maxTokens: 6000,
            cacheSystem: true,
            ...(cfg.solveModel ? { model: cfg.solveModel, noThinking: true } : {}),
            timeoutMs: 60_000,
            signal: req.signal,
          })) {
            if (c.type === "text") st += c.text;
            else if (c.type === "usage") {
              si = c.inputTokens ?? si;
              so = c.outputTokens ?? so;
            }
          }
          } catch (e) {
            // the tasks are still returned, without Lumen's own answers (the app can ask again later)
            console.warn("exam_solve_failed", e instanceof Error ? e.message.slice(0, 200) : String(e));
          }
          solveCost = (si * (cfg.solvePriceInPerMTok ?? cfg.priceInPerMTok) + so * (cfg.solvePriceOutPerMTok ?? cfg.priceOutPerMTok)) / 1e6;
          try {
            const j = JSON.parse(/\{[\s\S]*\}/.exec(st)?.[0] ?? "{}");
            for (const a of Array.isArray(j.answers) ? j.answers : []) {
              const t = missing.find((x) => x.no === clean(a?.no, 12));
              const ans = clean(a?.answer, EXAM_LIMITS.answer);
              if (t && ans) {
                t.answer = ans;
                t.answer_source = "eget svar";
              }
            }
          } catch { /* malformed: the tasks stay without an answer */ }
        }
        const tasks = out.tasks.map((t) => ({
          ...t,
          ...(t.answer && !t.answer_source ? { answer_source: "facit" as const } : {}),
          spoken: spokenTask(t.no, t.text, t.points),
        }));
        return json({ ...out, tasks, usage: { ...usage, est_cost_usd: usage.est_cost_usd + solveCost } });
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
