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

/** For each question, the part it draws on most (shared content stems), or -1 when it shares nothing with any part. */
export function placeQuestions(questions: string[], parts: string[]): number[] {
  const ps = parts.map(stems);
  return questions.map((q) => {
    const qs = stems(q);
    let best = -1, bestScore = 0;
    ps.forEach((p, i) => {
      let s = 0;
      for (const w of qs) if (p.has(w)) s++;
      // a stem rare across the parts says more than one every part has
      if (s > bestScore) (best = i, bestScore = s);
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
  return list.map((x, i) => ({ ...x, i })).sort((a, b) => (a.part < 0 ? 1e9 : a.part) - (b.part < 0 ? 1e9 : b.part) || a.i - b.i).map((x) => x.q);
}
