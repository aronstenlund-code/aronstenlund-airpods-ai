/**
 * K83 (D206): the questions cover the whole material, checked in code. Language models take more from the start and
 * the end of a text than from its middle, so after step 1 the material's text is cut into equal parts (in code, at
 * paragraph or sentence ends) and each question is placed in the part it draws on (shared content words). A part
 * with no question gets one from a call that sees only that part. No number that should be random ever comes from
 * a model: the parts, the placing and which question gives way are all decided here.
 */
const STOP = new Set(("alla allt andra annan annat att av blir bland både där därför dessa detta efter eftersom eller en ett finns för från genom har hela hos hur här inte inom kan kallas man med mellan mer mest mot många när och också om sedan sig sin sina sitt ska som till under upp ut utan vad var varför vid vilka vilken vilket år är även över " +
  "about after also among and are because been before being between both but can could did does during each from have how into its many more most much other over same should some such than that their them then there these they this those through under very was were what when where which while who why will with would").split(" "));

/** Content-word stems (first 6 letters of words of 5+ letters, not stop words). */
export function stems(text: string): Set<string> {
  const out = new Set<string>();
  for (const w of text.toLowerCase().match(/\p{L}{5,}/gu) ?? []) if (!STOP.has(w)) out.add(w.slice(0, 6));
  return out;
}

/** How many parts: about one per 1 200 characters, at least 2 and at most min(questions, 6); 1 when too short. */
export function partCount(chars: number, questions: number): number {
  if (chars < 1200 || questions < 2) return 1;
  return Math.max(2, Math.min(6, questions, Math.round(chars / 1200)));
}

/**
 * O79 F1: a heading line: a short paragraph of its own (at most 80 characters and 10 words) that does not end like a
 * sentence, or a markdown heading.
 */
export function isHeading(par: string): boolean {
  const p = par.trim();
  if (!p || p.includes("\n")) return false;
  if (/^#{1,6}\s+\S/.test(p)) return true;
  return p.length <= 80 && p.split(/\s+/).length <= 10 && !/[.!?:;,]$/.test(p) && /\p{L}/u.test(p);
}

const MIN_SECTION = 120;
/** at most this many parts (each short part may cost a model call of its own) */
const MAX_SECTIONS = 8;

/**
 * O79 F1 (Oscar): the material's own sections as parts. With two or more headings, a part is a heading and the text
 * under it (text before the first heading goes with it). Without headings, the paragraphs are the parts when there
 * are at least two. A part shorter than MIN_SECTION characters joins the next (the last joins the one before). More
 * parts than `max` (the questions there are room for): the two neighbours that together are shortest are joined
 * until they fit, so every part can get a question. null = no structure: the caller cuts on length (splitParts).
 */
export function sectionParts(text: string, max: number): string[] | null {
  const pars = text.trim().split(/\n\s*\n/).map((p) => p.trim()).filter(Boolean);
  if (pars.length < 2 || max < 2) return null;
  const heads = pars.filter((p) => isHeading(p)).length;
  let parts: string[] = [];
  if (heads >= 2) {
    let open = false; // the last part is a heading with nothing under it yet (two headings in a row stay together)
    for (const p of pars) {
      if (isHeading(p) && !open) (parts.push(p), open = true);
      else if (!parts.length) (parts.push(p), open = false);
      else (parts[parts.length - 1] += "\n\n" + p, open = open && isHeading(p));
    }
  } else if (heads === 0) {
    parts = pars;
  } else {
    return null; // one heading: a title, not sections
  }
  // too short to stand alone: join the next (the last joins the one before)
  for (let i = 0; i < parts.length && parts.length > 1;) {
    if (parts[i].length >= MIN_SECTION) { i++; continue; }
    if (i < parts.length - 1) parts.splice(i, 2, `${parts[i]}\n\n${parts[i + 1]}`);
    else parts.splice(i - 1, 2, `${parts[i - 1]}\n\n${parts[i]}`);
  }
  while (parts.length > Math.min(max, MAX_SECTIONS)) {
    let best = 0;
    for (let i = 1; i < parts.length - 1; i++) if (parts[i].length + parts[i + 1].length < parts[best].length + parts[best + 1].length) best = i;
    parts.splice(best, 2, `${parts[best]}\n\n${parts[best + 1]}`);
  }
  return parts.length >= 2 ? parts : null;
}

/** The text cut into `k` parts of about equal length, at a paragraph (else sentence) end near each cut. */
export function splitParts(text: string, k: number): string[] {
  const t = text.trim();
  if (k <= 1 || t.length < 2 * k) return [t];
  const parts: string[] = [];
  let start = 0;
  for (let i = 1; i < k; i++) {
    const target = Math.round((t.length * i) / k);
    const window = Math.round(t.length / k / 3);
    let cut = -1;
    for (const re of [/\n\s*\n/g, /[.!?]\s+/g]) {
      re.lastIndex = Math.max(start + 1, target - window);
      let m: RegExpExecArray | null;
      let best = -1;
      while ((m = re.exec(t)) && m.index <= target + window) {
        const at = m.index + m[0].length;
        if (best < 0 || Math.abs(at - target) < Math.abs(best - target)) best = at;
      }
      if (best > start) {
        cut = best;
        break;
      }
    }
    if (cut <= start) cut = target;
    parts.push(t.slice(start, cut).trim());
    start = cut;
  }
  parts.push(t.slice(start).trim());
  return parts.filter(Boolean);
}

/**
 * For each question, the part it draws on most, or -1 when it shares nothing distinctive with any part. K85 (Oscar
 * O73): words are weighted by how rare they are among the parts (TF-IDF): a word every part has says nothing, a word
 * only one part has says most. Ties go to the earlier part.
 */
export function placeQuestions(questions: string[], parts: string[]): number[] {
  const ps = parts.map(stems);
  const df = new Map<string, number>();
  for (const p of ps) for (const w of p) df.set(w, (df.get(w) ?? 0) + 1);
  const idf = (w: string) => Math.log((ps.length + 1) / ((df.get(w) ?? 0) + 0.5)) - Math.log((ps.length + 1) / (ps.length + 0.5));
  return questions.map((q) => {
    const qs = stems(q);
    let best = -1, bestScore = 0;
    ps.forEach((p, i) => {
      let s = 0;
      for (const w of qs) if (p.has(w)) s += idf(w);
      if (s > bestScore + 1e-9) (best = i, bestScore = s);
    });
    return best;
  });
}

export interface Coverage {
  parts: number;
  covered: number;
  /** parts with no question, in order */
  missing: number[];
  /** part of each question (-1 = none) */
  placed: number[];
}
export function coverage(questions: string[], parts: string[]): Coverage {
  const placed = placeQuestions(questions, parts);
  const has = new Set(placed.filter((p) => p >= 0));
  const missing = parts.map((_, i) => i).filter((i) => !has.has(i));
  return { parts: parts.length, covered: has.size, missing, placed };
}

/**
 * Adds one question for each part that had none and keeps the total: when the list is full, the question that
 * gives way is the last one of the part with the most questions (decided here, never by a model). Returns the new
 * list in the material's order (by part, the old order within a part).
 */
export function mergeCoverage(questions: string[], placed: number[], extra: { part: number; question: string }[], max: number): string[] {
  return mergeCoverageParts(questions, placed, extra, max).questions;
}

/** As mergeCoverage, with the part of each question: an added question belongs to the part it was written from. */
export function mergeCoverageParts(questions: string[], placed: number[], extra: { part: number; question: string }[], max: number): { questions: string[]; parts: number[] } {
  const list = questions.map((q, i) => ({ q, part: placed[i] }));
  for (const e of extra) {
    if (list.some((x) => x.q.toLowerCase() === e.question.toLowerCase())) continue;
    if (list.length >= max) {
      const counts = new Map<number, number>();
      for (const x of list) counts.set(x.part, (counts.get(x.part) ?? 0) + 1);
      // the most covered part (ties: the later part); a question no part claims goes first
      let drop = list.findIndex((x) => x.part < 0);
      if (drop < 0) {
        const most = [...counts.entries()].sort((a, b) => b[1] - a[1] || b[0] - a[0])[0];
        if (!most || most[1] < 2) continue; // every part has one: nothing may give way
        drop = list.map((x) => x.part).lastIndexOf(most[0]);
      }
      list.splice(drop, 1);
    }
    list.push({ q: e.question, part: e.part });
  }
  const sorted = list.map((x, i) => ({ ...x, i })).sort((a, b) => (a.part < 0 ? 1e9 : a.part) - (b.part < 0 ? 1e9 : b.part) || a.i - b.i);
  return { questions: sorted.map((x) => x.q), parts: sorted.map((x) => x.part) };
}

// ---------- K86 (D207): spread by length, at most half from one part, and a cap of our own ----------

/** Questions per 600 characters of material: the code's own cap (D207), never more than asked. */
export const CHARS_PER_QUESTION = 600;
export const codeCap = (chars: number, asked: number) => Math.min(asked, Math.max(1, Math.floor(chars / CHARS_PER_QUESTION)));

/**
 * Each part's share of `target` questions: by its length (largest remainders), at least 1 each when there are enough
 * questions, and with three or more parts never more than half of all from one part (the excess goes to the others
 * by length). Decided here, never by a model (D206).
 */
export function shares(lengths: number[], target: number): number[] {
  const n = lengths.length;
  if (!n || target <= 0) return lengths.map(() => 0);
  const total = lengths.reduce((a, b) => a + b, 0) || 1;
  const cap = n >= 3 ? Math.max(1, Math.floor(target / 2)) : target;
  const out = lengths.map(() => 0);
  let left = target;
  // at least one each while there are questions to give
  for (let i = 0; i < n && left > 0; i++) (out[i] = 1, left--);
  // the rest by length, largest remainder first, within the cap
  while (left > 0) {
    let best = -1, bestGap = -Infinity;
    for (let i = 0; i < n; i++) {
      if (out[i] >= cap) continue;
      const gap = (target * lengths[i]) / total - out[i];
      if (gap > bestGap + 1e-9) (best = i, bestGap = gap);
    }
    if (best < 0) break; // every part at the cap
    out[best]++;
    left--;
  }
  return out;
}

/**
 * Which questions to keep and how many each part still needs. `placed` is each question's part (-1 = none).
 * A part over its share keeps its first ones; the dropped ones are returned (they fill up if calls fail).
 */
export function allocate(placed: number[], share: number[]): { keep: number[]; dropped: number[]; need: number[] } {
  const have = share.map(() => 0);
  const keep: number[] = [], dropped: number[] = [];
  placed.forEach((p, i) => {
    if (p >= 0 && have[p] < share[p]) (have[p]++, keep.push(i));
    else dropped.push(i);
  });
  return { keep, dropped, need: share.map((s, i) => Math.max(0, s - have[i])) };
}

/**
 * K86: two questions that ask the same thing in other words ("Varför är det kallare vid polerna?" / "Varför blir
 * det kallare vid polerna?"): most of their content words are the same.
 */
export function nearDuplicate(a: string, b: string): boolean {
  const x = stems(a), y = stems(b);
  if (!x.size || !y.size) return a.trim().toLowerCase() === b.trim().toLowerCase();
  let shared = 0;
  for (const w of x) if (y.has(w)) shared++;
  return shared / Math.min(x.size, y.size) >= 0.75 && shared >= 2;
}
