import { composeLong, spokenText, words } from "../exam/drill.ts";

/**
 * K58 (D169), K60 (Oscar O58 fynd 6–9, the same rules as the app's ChatGPTImport, A96): reads the text the user
 * pasted from ChatGPT ("Fråga: …" / "Svar: …", repeated) into drill items, with no Claude call. Nothing is shortened
 * or rewritten: the short answer is the first sentence of the answer as written, the long answer is the whole answer
 * (D145: the long starts with the short word for word).
 * Rules (shared with Angela, testdata/import/o58-cases.json):
 *  1. A blank line does not end an answer: it goes on until the next question, paragraphs joined by a space. After the
 *     LAST answer, a separate paragraph ending in "?" or "!" is chatter ("Lycka till! Vill du ha fler?") -> skipped.
 *  2. Headings ("# …", "Fråga 2" without a colon), ``` fences and rules (---, ***, ===) are never answer text: skipped
 *     with their line number, and they end the answer.
 *  3. A line without a label directly before "Svar:" is the question when no question is waiting and it ends in "?"
 *     ("**1. Vad är magma?**") -> warning "Frågan saknade Fråga:.".
 *  4. Nothing is cut: an answer over 3 000 characters is kept with a warning; over 4 000 it is skipped (D120 cost).
 *  5. A question asked twice is kept, with a warning.
 */
export const IMPORT_LIMITS = { textChars: 80_000, items: 60, questionChars: 300, answerWarnChars: 3000, answerChars: 4000, shortWordsMax: 25 };

export interface ImportItem { id: string; question: string; short: string; long: string }
export interface ImportProblem { line: number; text: string; reason: string }
export interface ImportResult {
  items: ImportItem[];
  /** lines that were not part of any question or answer (an intro, a heading, chatter, a question without an answer) */
  skipped: ImportProblem[];
  /** read, but worth a look: a long first sentence or answer, a long question, a missing label, a duplicate */
  warnings: ImportProblem[];
}

// "Fråga 3:", "**Fråga:**", "1. Fråga:", "- Svar:", "F:" – markdown and numbering ChatGPT sometimes adds anyway
const LABEL = /^\s*(?:#{1,6}\s*)?(?:[-*•>]\s*)?(?:\d+[.)]\s*)?(?:\*\*|__)?\s*(fråga|svar|f|s)(?:\s*\d+)?\s*(?:\*\*|__)?\s*[:：]\s*(?:\*\*|__)?\s*/iu;
const HEADING = /^\s*#|^\s*(?:\*\*|__)?\s*fråga\s*\d+\s*\.?\s*(?:\*\*|__)?\s*$/iu;
const FENCE = /^\s*```/;
const RULE = /^\s*([-*_=])(?:\s*\1){2,}\s*$/;
// Swedish abbreviations whose full stop is not the end of a sentence
const ABBR = /(?:^|\s)(?:t\.ex|bl\.a|t\.o\.m|s\.k|d\.v\.s|dvs|osv|m\.m|m\.fl|ca|kl|nr|resp|jfr|el|o\.d|e\.d|f\.d|f\.Kr|e\.Kr|t\.ex\.|ff|s|st|tex)\.$/iu;
const stripMd = (s: string) => s.replace(/\*\*|__|`/g, "").trim();

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

interface Para { line: number; lines: string[]; afterBlank: boolean }

export function importText(raw: unknown): ImportResult {
  const text = typeof raw === "string" ? raw.slice(0, IMPORT_LIMITS.textChars) : "";
  const lines = text.replace(/\r\n?/g, "\n").split("\n");
  const items: ImportItem[] = [], skipped: ImportProblem[] = [], warnings: ImportProblem[] = [];
  const seen = new Map<string, number>();
  let cur: { line: number; question: string; paras: Para[]; blank: boolean } | null = null;
  let mode: "none" | "q" | "a" | "closed" = "none"; // closed: the answer ended at a heading or fence

  const flush = (last = false) => {
    if (!cur) return;
    // rule 1: chatter after the last answer
    while (last && cur.paras.length > 1) {
      const p = cur.paras[cur.paras.length - 1];
      const t = stripMd(p.lines.join(" "));
      if (!p.afterBlank || !/[?!]["”')]?$/.test(t)) break;
      cur.paras.pop();
      skipped.push({ line: p.line, text: t.slice(0, 160), reason: "Avslutning, inte en del av svaret." });
      warnings.push({ line: p.line, text: t.slice(0, 160), reason: "Texten efter sista svaret lästes inte in." });
    }
    const question = spokenText(cur.question, IMPORT_LIMITS.questionChars);
    const answer = spokenText(cur.paras.map((p) => p.lines.join(" ")).join(" "), 100_000);
    const answerLine = cur.paras[0]?.line ?? cur.line;
    if (!question) skipped.push({ line: cur.line, text: "Fråga:", reason: "Frågan är tom." });
    else if (!answer) skipped.push({ line: cur.line, text: `Fråga: ${question}`.slice(0, 160), reason: "Frågan har inget svar." });
    else if (answer.length > IMPORT_LIMITS.answerChars) {
      skipped.push({ line: answerLine, text: `Fråga: ${question}`.slice(0, 160), reason: `Svaret är för långt (${answer.length} tecken, högst 4 000).` });
    } else if (items.length >= IMPORT_LIMITS.items) {
      skipped.push({ line: cur.line, text: `Fråga: ${question}`.slice(0, 160), reason: `Högst ${IMPORT_LIMITS.items} frågor.` });
    } else {
      let short = firstSentence(answer);
      const rest = answer.slice(short.length).trim();
      if (!/[.!?]["”')]?$/.test(short)) short += ".";
      const q = /[?.!]$/.test(question) ? question : `${question}?`;
      items.push({ id: `q${items.length + 1}`, question: q, short, long: composeLong(short, rest) });
      const key = q.toLowerCase().replace(/[^\p{L}\p{N}]+/gu, " ").trim();
      if (seen.has(key)) warnings.push({ line: cur.line, text: q.slice(0, 160), reason: `Samma fråga som på rad ${seen.get(key)}.` });
      else seen.set(key, cur.line);
      if (words(short) > IMPORT_LIMITS.shortWordsMax) {
        warnings.push({ line: answerLine, text: short.slice(0, 160), reason: `Första meningen har ${words(short)} ord (högst ${IMPORT_LIMITS.shortWordsMax}).` });
      }
      if (answer.length > IMPORT_LIMITS.answerWarnChars) {
        warnings.push({ line: answerLine, text: short.slice(0, 160), reason: `Svaret har ${answer.length} tecken, långt att lyssna på.` });
      }
      if (words(q) > 8) warnings.push({ line: cur.line, text: q.slice(0, 160), reason: `Frågan har ${words(q)} ord.` });
    }
    cur = null;
    mode = "none";
  };

  const startQuestion = (n: number, q: string) => {
    flush();
    cur = { line: n, question: q, paras: [], blank: false };
    mode = "q";
  };

  lines.forEach((line, i) => {
    const n = i + 1;
    const t = line.trim();
    // the label goes first (Angela A96): "### Fråga 1: Vad är magma?" is a question, "### Fråga 1" a heading
    if (FENCE.test(line) || RULE.test(line) || (HEADING.test(line) && !LABEL.test(line))) {
      // rule 2: never answer text; ends the answer (kept open for the chatter check if it was the last one)
      if (mode === "a") mode = "closed";
      skipped.push({ line: n, text: t.slice(0, 160), reason: "Rubrik eller formatering, inte en del av svaret." });
      return;
    }
    const m = LABEL.exec(line);
    if (m) {
      const kind = m[1].toLowerCase().startsWith("f") ? "q" : "a";
      const rest = line.slice(m[0].length).replace(/(?:\*\*|__)\s*$/, "").trim();
      if (kind === "q") startQuestion(n, rest);
      else if (!cur) skipped.push({ line: n, text: t.slice(0, 160), reason: "Ett svar utan fråga före." });
      else {
        const c = cur as { paras: Para[]; blank: boolean };
        c.paras.push({ line: n, lines: rest ? [rest] : [], afterBlank: false });
        c.blank = false;
        mode = "a";
      }
      return;
    }
    if (!t) {
      if (cur) (cur as { blank: boolean }).blank = true;
      return;
    }
    // rule 3: an unlabelled question directly before "Svar:"
    const next = lines[i + 1] ?? "";
    const nm = LABEL.exec(next);
    const asQ = stripMd(t).replace(/^(?:\d+[.)]\s*)/, "").replace(/\*\*|__/g, "").trim();
    if (mode !== "q" && nm && !nm[1].toLowerCase().startsWith("f") && /\?$/.test(asQ)) {
      startQuestion(n, asQ);
      warnings.push({ line: n, text: asQ.slice(0, 160), reason: "Frågan saknade Fråga:." });
      return;
    }
    if (mode === "a" && cur) {
      // rule 1: the answer goes on, also after a blank line
      const c = cur as { paras: Para[]; blank: boolean };
      const piece = t.replace(/^(?:[-•*]|\d+[.)])\s+/, "");
      if (c.blank || !c.paras.length) c.paras.push({ line: n, lines: [piece], afterBlank: c.blank });
      else c.paras[c.paras.length - 1].lines.push(piece);
      c.blank = false;
    } else if (mode === "q" && cur && !(cur as { blank: boolean }).blank) {
      (cur as { question: string }).question += ` ${t}`; // the question went on over a second line
    } else {
      skipped.push({ line: n, text: t.slice(0, 160), reason: "Raden börjar inte med Fråga: eller Svar:." });
    }
  });
  flush(true);
  return { items, skipped, warnings };
}
