/**
 * K40 (Aron's phone test 2026-11-11): short quiz answers are misheard by speech recognition ("Nilen" -> "Nilan",
 * "om ni har redan svarat"; "Seine" said "sän" -> "såg en"). In the answer window after a check question the reply is
 * first compared by SOUND with the right answer and the plausible alternatives (a Swedish phonetic key + edit
 * distance over 1-3 word windows), before anything else reads it.
 *
 *   matchAnswer(heard, key) -> {verdict: "correct" | "near" | "alternative" | "none", answer?, score}
 *     correct      = sounds like the right answer, clearly closer than any alternative
 *     near         = might be the right answer ("Menade du Nilen? Rätt i så fall.")
 *     alternative  = sounds like one of the wrong alternatives (that one is named)
 */
export interface QuizKey {
  answer: string;
  alternatives: string[];
}

/** Swedish pronunciations of foreign names that speech recognition writes the Swedish way ("sän" = Seine). */
const SAID_AS: Record<string, string[]> = {
  seine: ["sän", "sen"], loire: ["loar"], rhône: ["rån"], rhone: ["rån"], garonne: ["garån"], marseille: ["marsej"],
  bordeaux: ["bordå"], lyon: ["lijon", "lion"], nice: ["nis"], toulouse: ["tulus"], genève: ["jenev"], geneve: ["jenev"],
  thames: ["tems"], themsen: ["temsen"], mississippi: ["misisipi"], missouri: ["misori", "misuri"], ohio: ["ohajo"],
  hudson: ["hadsån", "hudsån"], michigan: ["misjigan"], chicago: ["sjikago"], yangtze: ["jangtse"], zambezi: ["sambesi"],
  shanghai: ["sjanghaj"], champagne: ["sjampanj"], lausanne: ["losan"], bayern: ["bajern"], rhein: ["rajn"],
  niger: ["nidjer", "niger"], seattle: ["siätel"], "los angeles": ["los andjeles"], "new york": ["nju jork"],
};

/** A Swedish phonetic key: spellings that sound alike become the same letters. */
export function svKey(word: string): string {
  let s = word.toLowerCase().normalize("NFC").replace(/[^\p{L}]/gu, "");
  s = s.replace(/[éèêë]/g, "e").replace(/[áàâ]/g, "a").replace(/ü/g, "y").replace(/[óòô]/g, "o");
  s = s.replace(/(?:sch|skj|stj|sj|ch|sh)/g, "x").replace(/sk(?=[eiyäö])/g, "x");
  s = s.replace(/(?:tj|kj)/g, "c").replace(/k(?=[eiyäö])/g, "c");
  s = s.replace(/(?:dj|gj|hj|lj)/g, "j").replace(/g(?=[eiyäö])/g, "j");
  s = s.replace(/ck/g, "k").replace(/c(?=[eiy])/g, "s").replace(/c/g, "k").replace(/q/g, "k").replace(/z/g, "s")
    .replace(/ph/g, "f").replace(/w/g, "v").replace(/x(?![a-zåäö]*$)/g, "x").replace(/th/g, "t");
  s = s.replace(/aa/g, "å").replace(/ä/g, "e").replace(/å/g, "o").replace(/y/g, "i").replace(/u/g, "o");
  s = s.replace(/(.)\1+/g, "$1"); // doubled letters sound like one
  return s;
}

/** French-looking spelling read the French way ("Loire" = loar, "Bordeaux" = bordå), as an extra variant. */
function frenchish(word: string): string | null {
  const w = word.toLowerCase();
  if (!/(?:eau|aux|oi|ei|ai|ille|ou|gn|e$|s$|x$|t$)/.test(w)) return null;
  return w.replace(/eaux?|aux?/g, "å").replace(/oi/g, "oa").replace(/ei|ai/g, "ä").replace(/ille/g, "ij")
    .replace(/ou/g, "u").replace(/gn/g, "nj").replace(/ch/g, "sj").replace(/qu/g, "k").replace(/[estx]$/, "");
}

function variants(answer: string): string[] {
  const a = answer.toLowerCase().trim();
  const out = new Set<string>([svKey(a)]);
  for (const s of SAID_AS[a] ?? []) out.add(svKey(s));
  const fr = frenchish(a);
  if (fr) out.add(svKey(fr));
  // "floden Nilen", "Nilenfloden": the name alone also counts
  const core = a.replace(/^(?:floden|sjön|staden|berget|ön|landet)\s+/u, "").replace(/(?:floden|sjön|staden)$/u, "");
  if (core && core !== a) out.add(svKey(core));
  return [...out].filter((x) => x.length >= 2);
}

function lev(a: string, b: string): number {
  const d = Array.from({ length: a.length + 1 }, (_, i) => [i, ...Array(b.length).fill(0)]);
  for (let j = 1; j <= b.length; j++) d[0][j] = j;
  for (let i = 1; i <= a.length; i++) {
    for (let j = 1; j <= b.length; j++) {
      d[i][j] = Math.min(d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1));
    }
  }
  return d[a.length][b.length];
}

/** How well the heard words sound like `answer` (0-1): the best 1-3 word window, joined. */
export function soundScore(heard: string, answer: string): number {
  const words = heard.toLowerCase().split(/[^\p{L}]+/u).filter(Boolean);
  const targets = variants(answer);
  if (!words.length || !targets.length) return 0;
  let best = 0;
  for (let i = 0; i < words.length; i++) {
    for (let n = 1; n <= 3 && i + n <= words.length; n++) {
      const k = svKey(words.slice(i, i + n).join(""));
      if (k.length < 2) continue;
      for (const t of targets) {
        const s = 1 - lev(k, t) / Math.max(k.length, t.length);
        if (s > best) best = s;
      }
    }
  }
  return best;
}

export type AnswerVerdict = "correct" | "near" | "alternative" | "none";
export const SURE = 0.75;
export const NEAR = 0.5;

export function matchAnswer(heard: string, key: QuizKey): { verdict: AnswerVerdict; answer?: string; score: number } {
  const right = soundScore(heard, key.answer);
  let alt = { a: "", s: 0 };
  for (const a of key.alternatives) {
    const s = soundScore(heard, a);
    if (s > alt.s) alt = { a, s };
  }
  if (right >= SURE && right >= alt.s + 0.1) return { verdict: "correct", answer: key.answer, score: right };
  if (alt.s >= SURE && alt.s >= right + 0.1) return { verdict: "alternative", answer: alt.a, score: alt.s };
  if (right >= NEAR && right >= alt.s) return { verdict: "near", answer: key.answer, score: right };
  return { verdict: "none", score: Math.max(right, alt.s) };
}

/** O43 (prio 3): an alternative that is a form of the answer ("Kloroplast" for "Kloroplasten", "Celldelning" for
 *  "Mitos") is dropped; the same sound stem, or one contains the other. */
function sameThing(alt: string, answer: string): boolean {
  const a = svKey(alt), b = svKey(answer);
  if (!a || !b) return false;
  if (a === b || a.includes(b) || b.includes(a)) return true;
  return lev(a, b) <= 1 && Math.min(a.length, b.length) >= 6;
}

/**
 * O43 (BUG prio 2): in classroom noise Scribe sometimes reads the keyterm list back ("Viktoriasjön, Tanganyikasjön,
 * Malawisjön, …"). With the answer first in the list that became a false "Rätt". The reply is "nothing heard" when it
 * is mostly the terms sent (3+ list items that are terms), or names the answer AND 2+ alternatives.
 */
export function isTermListEcho(heard: string, key: QuizKey | null, terms: string[] = []): boolean {
  const all = [...(key ? [key.answer, ...key.alternatives] : []), ...terms].map((x) => svKey(x)).filter((x) => x.length >= 2);
  if (!all.length) return false;
  const items = heard.split(/[,;]+/).map((x) => x.trim()).filter(Boolean);
  const isTerm = (s: string) => {
    const k = svKey(s);
    return k.length >= 2 && all.some((x) => x === k || (k.length >= 5 && lev(x, k) <= 1));
  };
  if (items.length >= 3 && items.filter(isTerm).length >= 3) return true;
  if (key) {
    const named = [key.answer, ...key.alternatives].filter((x) => soundScore(heard, x) >= 0.9).length;
    if (named >= 3) return true;
  }
  return false;
}

/** `[[SVAR]] Nilen | Kongo, Niger, Zambezi` (the model's line after a check question) -> the key. */
export function parseQuizKey(line: string): QuizKey | null {
  const t = line.replace(/^[\s:\]\-–—*]+/, "").split("\n")[0].trim();
  const [a, rest] = t.split("|");
  const answer = (a ?? "").replace(/["“”«»]/g, "").trim().slice(0, 80);
  if (!answer) return null;
  const alternatives = (rest ?? "").split(/[,;]/).map((x) => x.replace(/["“”«»]/g, "").trim()).filter((x) => x && !sameThing(x, answer))
    .slice(0, 6).map((x) => x.slice(0, 80));
  return { answer, alternatives };
}

/** A key from the app (A62 sends back what done.quiz_key gave): lenient, capped. */
export function readQuizKey(raw: unknown): QuizKey | null {
  if (!raw || typeof raw !== "object") return null;
  const o = raw as Record<string, unknown>;
  const answer = typeof o.answer === "string" ? o.answer.replace(/[<>\u0000-\u001f]/g, " ").trim().slice(0, 80) : "";
  if (!answer) return null;
  const alternatives = Array.isArray(o.alternatives)
    ? o.alternatives.filter((x): x is string => typeof x === "string").map((x) => x.replace(/[<>\u0000-\u001f]/g, " ").trim().slice(0, 80)).filter((x) => x && !sameThing(x, answer)).slice(0, 6)
    : [];
  return { answer, alternatives };
}
