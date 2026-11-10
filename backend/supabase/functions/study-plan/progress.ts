/**
 * K31 (D115 C2 + C3) and K33 (N1): the streak, the daily notification text and "% redo" per exam. Code only, no
 * model call, nothing stored: the app sends the days and the concept histories it already keeps.
 */
import { INTERVALS, schedule } from "./handler.ts";

const DAY = 86_400_000;
const parse = (d: string) => {
  const t = Date.parse(`${d}T00:00:00Z`);
  return Number.isFinite(t) ? t : null;
};
const iso = (t: number) => new Date(t).toISOString().slice(0, 10);

export interface Streak {
  /** Days in a row with at least one quiz answer, ending today, or yesterday when today is not done yet. */
  current: number;
  best: number;
  done_today: boolean;
  /** Not done today and the streak is alive: it is lost at midnight (Duolingo style, no freezes). */
  at_risk: boolean;
}

/** `days`: every date (YYYY-MM-DD, the student's own calendar) with at least one quiz question answered. */
export function streakOf(days: string[], today: string): Streak {
  const t = parse(today)!;
  const set = new Set(days.filter((d) => parse(d) !== null && parse(d)! <= t));
  const sorted = [...set].sort();
  let best = 0, run = 0, prev: number | null = null;
  for (const d of sorted) {
    const x = parse(d)!;
    run = prev !== null && x - prev === DAY ? run + 1 : 1;
    best = Math.max(best, run);
    prev = x;
  }
  const doneToday = set.has(today);
  let current = 0;
  for (let x = doneToday ? t : t - DAY; set.has(iso(x)); x -= DAY) current++;
  return { current, best, done_today: doneToday, at_risk: !doneToday && current > 0 };
}

export interface Notification {
  title: string;
  body: string;
}

/**
 * What the daily notification says (the app shows it at the time the student chose, once a day, only when the
 * student turned it on). Null when today is already done: no reminder is needed.
 */
export function notificationFor(
  streak: Streak,
  exam: { name: string; days_left: number | null; first?: string | null } | null,
): Notification | null {
  if (streak.done_today) return null;
  const n = exam?.days_left ?? null;
  const name = exam?.name && exam.name !== "Provet" ? exam.name : "provet";
  const title = n === null || n < 0
    ? "5 snabba frågor"
    : n === 0
    ? `I dag är det ${name}. Lycka till!`
    : n === 1
    ? `I morgon är det ${name}`
    : `${n} dagar kvar till ${name}`;
  const topic = exam?.first ? ` på ${exam.first}` : "";
  const body = streak.at_risk
    ? `5 snabba frågor${topic} håller din svit på ${streak.current} ${streak.current === 1 ? "dag" : "dagar"} vid liv.`
    : n === 0
    ? `5 snabba frågor${topic} som uppvärmning?`
    : `5 snabba frågor${topic}? Det tar två minuter.`;
  return { title, body };
}

export interface Readiness {
  /** 0-100, null without concepts. */
  ready_pct: number | null;
  practiced: number;
  total: number;
  weakest: { concept: string; score: number; why: string }[];
  explain: string;
}

/**
 * K33 formula (explainable): every concept from the exam counts the same. A concept's score comes from its
 * Leitner box after all its answers (quiz, study cards, practice exams, plan repetitions are all history):
 *   never practised = 0; last answer wrong = 0; right once = 0.5; twice in a row = 0.75; three times = 1.0;
 *   an overdue repetition (the review day has passed) counts 80 %.
 * "% redo" = the mean score × 100, rounded. The three weakest: lowest score first, then the most wrong answers.
 */
export function readinessOf(concepts: { concept: string; history: { date: string; ok: boolean }[] }[], today: string): Readiness {
  const rows = concepts.map((c) => {
    const s = schedule(c.history);
    const wrong = c.history.filter((h) => !h.ok).length;
    if (!s) return { concept: c.concept, score: 0, wrong, why: "inte övat än" };
    let score = s.lastOk ? (s.box + 1) / (INTERVALS.length) : 0;
    const overdue = s.next < today;
    if (overdue) score *= 0.8;
    const why = !s.lastOk ? "fel senast" : overdue ? "dags att repetera" : score >= 1 ? "sitter" : "rätt, men behöver fler gånger";
    return { concept: c.concept, score: Math.round(score * 100) / 100, wrong, why };
  });
  if (!rows.length) {
    return { ready_pct: null, practiced: 0, total: 0, weakest: [], explain: "Inga begrepp i provet än." };
  }
  const practiced = concepts.filter((c) => c.history.length > 0).length;
  const pct = Math.round((rows.reduce((a, r) => a + r.score, 0) / rows.length) * 100);
  const weakest = [...rows].sort((a, b) => a.score - b.score || b.wrong - a.wrong).slice(0, 3)
    .filter((r) => r.score < 1).map(({ concept, score, why }) => ({ concept, score, why }));
  return {
    ready_pct: pct,
    practiced,
    total: rows.length,
    weakest,
    explain: `Räknat på ${rows.length} begrepp, ${practiced} övade. Ett begrepp räknas fullt när du har haft rätt tre gånger i rad.`,
  };
}
