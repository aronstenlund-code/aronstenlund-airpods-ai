import { maskNumbers } from "../answer/qalog.ts";

/**
 * K77 (D197 within D116): Repetitionsläget and Läsläget in Aron's analysis. Rows go to the same table as the
 * listening modes (`qa_log`), so the same private page (backend/webtest/qa.html), the same "Hämtat" delete and the
 * same 14-day purge cover them. Never: the photographed material or a text drill's text (B4: that IS the material),
 * test accounts, copies imported from someone else, a user id. Numbers are masked as in qa-log.
 *   mode "repetition" (a question drill) or "read" (a text drill), persona:
 *     "sparad"  a new question and its answer (question, answer = the long answer)
 *     "ändrad"  the user changed a question or an answer (answer = "Före: ... / Efter: ...")
 *     "tryck"   press statistics sent by the app with `stats` (question = subject, answer = the counts)
 */
export interface AnalysisRow {
  mode: "repetition" | "read";
  persona: "sparad" | "ändrad" | "tryck";
  question: string;
  answer: string;
}

const cut = (s: string, n: number) => maskNumbers(s ?? "").slice(0, n);

interface ItemText { id?: string; question: string; short: string; long: string; part?: string | null }

/** The rows for one save of a question drill: new questions and changed ones. A text drill logs nothing here. */
export function saveRows(kind: "questions" | "text", oldItems: ItemText[], rows: ItemText[]): AnalysisRow[] {
  if (kind === "text") return [];
  const old = new Map(oldItems.filter((i) => i.id).map((i) => [i.id!, i]));
  const out: AnalysisRow[] = [];
  for (const r of rows) {
    const o = r.id ? old.get(r.id) : undefined;
    if (!o) {
      out.push({ mode: "repetition", persona: "sparad", question: cut(r.question, 1000), answer: cut(r.long || r.short, 6000) });
      continue;
    }
    const changes: string[] = [];
    if (o.question !== r.question) changes.push(`Fråga före: ${o.question}\nFråga efter: ${r.question}`);
    if (o.long !== r.long || o.short !== r.short) changes.push(`Svar före: ${o.long || o.short}\nSvar efter: ${r.long || r.short}`);
    if (changes.length) out.push({ mode: "repetition", persona: "ändrad", question: cut(r.question, 1000), answer: cut(changes.join("\n\n"), 6000) });
  }
  return out;
}

export interface PressStats { "1": number; "2": number; "3": number }
/** Press counts from the app (1 = pause/answer, 2 = next, 3 = back); whole numbers 0-100 000, else null. */
export function pressStats(v: unknown): PressStats | null {
  if (!v || typeof v !== "object") return null;
  const o = v as Record<string, unknown>;
  const n = (x: unknown) => (typeof x === "number" && Number.isInteger(x) && x >= 0 && x <= 100_000 ? x : null);
  const a = n(o["1"]), b = n(o["2"]), c = n(o["3"]);
  if (a === null || b === null || c === null) return null;
  return { "1": a, "2": b, "3": c };
}

/** One "tryck" row: the subject and the counts, per question for a question drill (its question text), never a text. */
export function statsRow(
  kind: "questions" | "text",
  subject: string,
  total: PressStats,
  perQuestion: { question: string; presses: PressStats }[],
  minutes: number | null,
): AnalysisRow {
  const line = (p: PressStats) => `1 tryck: ${p["1"]}, 2 tryck: ${p["2"]}, 3 tryck: ${p["3"]}`;
  const parts = [`Totalt: ${line(total)}`, ...(minutes !== null ? [`Minuter: ${minutes}`] : [])];
  if (kind === "questions") for (const q of perQuestion.slice(0, 60)) parts.push(`${q.question}: ${line(q.presses)}`);
  return { mode: kind === "text" ? "read" : "repetition", persona: "tryck", question: cut(subject || "(inget ämne)", 1000), answer: cut(parts.join("\n"), 6000) };
}
