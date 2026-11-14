import { composeLong, spokenText, words } from "../exam/drill.ts";

/**
 * K58 (D169): reads the text the user pasted from ChatGPT ("Fråga: …" / "Svar: …" / empty line, repeated) into
 * drill items, with no Claude call. Nothing is shortened or rewritten: the short answer is the first sentence of the
 * answer as written, the long answer is the whole answer (D145: the long starts with the short word for word).
 * Lines that cannot be read are returned with their line number so the app can show them.
 */
export const IMPORT_LIMITS = { textChars: 60_000, items: 60, questionChars: 300, answerChars: 3000, shortWordsMax: 25 };

export interface ImportItem { id: string; question: string; short: string; long: string }
export interface ImportProblem { line: number; text: string; reason: string }
export interface ImportResult {
  items: ImportItem[];
  /** lines that were not part of any question or answer (an intro, a heading, a question without an answer) */
  skipped: ImportProblem[];
  /** read, but worth a look: a first sentence over 25 words, a question over 8 words */
  warnings: ImportProblem[];
}

// "Fråga 3:", "**Fråga:**", "1. Fråga:", "F:" – markdown and numbering ChatGPT sometimes adds anyway
const LABEL = /^\s*(?:[-*•>]\s*)?(?:\d+[.)]\s*)?(?:\*\*|__)?\s*(fråga|svar|f|s)(?:\s*\d+)?\s*(?:\*\*|__)?\s*[:：]\s*(?:\*\*|__)?\s*/iu;
// Swedish abbreviations whose full stop is not the end of a sentence
const ABBR = /(?:^|\s)(?:t\.ex|bl\.a|t\.o\.m|s\.k|d\.v\.s|dvs|osv|m\.m|m\.fl|ca|kl|nr|resp|jfr|el|o\.d|e\.d|f\.d|f\.Kr|e\.Kr|t\.ex\.|ff|s|st|tex)\.$/iu;

/** The first sentence: up to the first ". ", "! " or "? " that is not an abbreviation or a decimal number. */
export function firstSentence(answer: string): string {
  const s = answer.trim();
  const re = /[.!?]["”')]?(?=\s+["”(]?[\p{Lu}\p{N}])/gu;
  for (let m = re.exec(s); m; m = re.exec(s)) {
    const end = m.index + m[0].length;
    if (s[m.index] === "." && ABBR.test(s.slice(Math.max(0, m.index - 8), m.index + 1))) continue;
    return s.slice(0, end).trim();
  }
  return s;
}

export function importText(raw: unknown): ImportResult {
  const text = typeof raw === "string" ? raw.slice(0, IMPORT_LIMITS.textChars) : "";
  const lines = text.replace(/\r\n?/g, "\n").split("\n");
  const items: ImportItem[] = [], skipped: ImportProblem[] = [], warnings: ImportProblem[] = [];
  let cur: { line: number; question: string; answer: string[]; answerLine: number } | null = null;
  let mode: "none" | "q" | "a" = "none";

  const flush = () => {
    if (!cur) return;
    const question = spokenText(cur.question, IMPORT_LIMITS.questionChars);
    const answer = spokenText(cur.answer.join(" "), IMPORT_LIMITS.answerChars);
    if (!question) skipped.push({ line: cur.line, text: "Fråga:", reason: "Frågan är tom." });
    else if (!answer) skipped.push({ line: cur.line, text: `Fråga: ${question}`.slice(0, 160), reason: "Frågan har inget svar." });
    else if (items.length >= IMPORT_LIMITS.items) skipped.push({ line: cur.line, text: `Fråga: ${question}`.slice(0, 160), reason: `Högst ${IMPORT_LIMITS.items} frågor.` });
    else {
      let short = firstSentence(answer);
      if (!/[.!?]["”')]?$/.test(short)) short += ".";
      const rest = answer.slice(firstSentence(answer).length).trim();
      const q = /[?.!]$/.test(question) ? question : `${question}?`;
      items.push({ id: `q${items.length + 1}`, question: q, short, long: composeLong(short, rest) });
      if (words(short) > IMPORT_LIMITS.shortWordsMax) {
        warnings.push({ line: cur.answerLine, text: short.slice(0, 160), reason: `Första meningen har ${words(short)} ord (högst ${IMPORT_LIMITS.shortWordsMax}).` });
      }
      if (words(q) > 8) warnings.push({ line: cur.line, text: q.slice(0, 160), reason: `Frågan har ${words(q)} ord.` });
    }
    cur = null;
    mode = "none";
  };

  lines.forEach((line, i) => {
    const n = i + 1;
    const m = LABEL.exec(line);
    if (m) {
      const kind = m[1].toLowerCase().startsWith("f") ? "q" : "a";
      const rest = line.slice(m[0].length).replace(/(?:\*\*|__)\s*$/, "").trim();
      if (kind === "q") {
        flush();
        cur = { line: n, question: rest, answer: [], answerLine: n };
        mode = "q";
      } else if (!cur) {
        skipped.push({ line: n, text: line.trim().slice(0, 160), reason: "Ett svar utan fråga före." });
      } else {
        if (cur.answer.length) cur.answer.push(" ");
        cur.answer.push(rest);
        cur.answerLine = cur.answer.length === 1 ? n : cur.answerLine;
        mode = "a";
      }
      return;
    }
    const t = line.trim();
    if (!t) {
      // an empty line ends the answer; a question may still wrap onto a second line before its answer
      if (mode === "a") flush();
      return;
    }
    if (mode === "a" && cur) cur.answer.push(t); // the answer went on over more lines
    else if (mode === "q" && cur && !cur.answer.length) cur.question += ` ${t}`;
    else skipped.push({ line: n, text: t.slice(0, 160), reason: "Raden börjar inte med Fråga: eller Svar:." });
  });
  flush();
  return { items, skipped, warnings };
}
