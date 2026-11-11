/**
 * K37 (D126, owner): "Mina svar". The student writes a question and the exact answer they want to give on the exam;
 * the app keeps them on the phone (like the D49 memories, never on the server, never in the repo) and sends the ones
 * for the current exam with every /answer call as `saved_answers: [{id, q, a}]`. When what the student says asks the
 * same thing as a saved question, Lumen says THAT answer word for word instead of writing its own.
 *
 * Matching (semantic, not exact text), with false hits as the thing to avoid (a wrong saved answer in the ear on an
 * exam is worse than a fresh one):
 *  1. Code score per saved question: the content words (light Swedish stems, fuzzy against recognition errors) and
 *     the letter pairs of the whole question, plus the kind of question (vad/varför/hur/när/vem/var …).
 *  2. Sure (>= SAVED_SURE, same kind of question, every content word of the saved question heard, digits equal,
 *     at most two content words more): the saved answer at once, no model call.
 *  3. Maybe (>= SAVED_MAYBE): one short Haiku check of the best three ("which one asks the same thing, or 0").
 *     A failed or slow check = no hit (the normal answer), never a guess.
 */
export interface SavedAnswer {
  id: string;
  q: string;
  a: string;
}

export const SAVED_LIMITS = { items: 60, id: 64, q: 300, a: 1500 } as const;
export const SAVED_SURE = 0.78;
export const SAVED_MAYBE = 0.34;

/** Lenient reader for `saved_answers`: malformed entries are dropped, the rest trimmed and capped. */
export function readSavedAnswers(raw: unknown): SavedAnswer[] {
  if (!Array.isArray(raw)) return [];
  const out: SavedAnswer[] = [];
  for (const x of raw.slice(0, SAVED_LIMITS.items)) {
    if (!x || typeof x !== "object") continue;
    const o = x as Record<string, unknown>;
    const id = typeof o.id === "string" ? o.id.trim().slice(0, SAVED_LIMITS.id) : "";
    const q = typeof o.q === "string" ? o.q.replace(/[\u0000-\u001f<>]/g, " ").trim().slice(0, SAVED_LIMITS.q) : "";
    const a = typeof o.a === "string" ? o.a.replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f<>]/g, " ").trim().slice(0, SAVED_LIMITS.a) : "";
    if (id && q && a && /^[\w.:-]+$/.test(id)) out.push({ id, q, a });
  }
  return out;
}

// ---------------------------------------------------------------- normalising
const FILLER = new Set(
  ("lumen hej okej ok asså alltså typ liksom ba bara eh öh äh hmm mm snälla tack nu då du kan kunde skulle vill ja jaha " +
    "nej men så också ju väl eller lite någon något några").split(" "),
);
const STOP = new Set(
  ("är var blir blev har hade ska den det de en ett i på av till för med om som att och från ut upp vid under över " +
    "man mig jag vi oss min mitt mina sin sitt sina dess deras hans hennes hen han hon dom dem detta denna dessa " +
    "the a an is are was what why how when who where which of to in on for and").split(" "),
);
/** The kind of question: two questions of different kinds are never the same question in code (the check decides). */
const KIND: [RegExp, string][] = [
  [/^(?:jämför|vad är skillnaden|vad skiljer|skillnaden mellan|compare)/u, "compare"],
  [/^(?:varför|why|av vilken anledning|vad beror det på|vad är orsaken|vilka orsaker|vilka (?:var|är) orsakerna|vad orsakade|vad ledde till)/u, "why"],
  [/^(?:hur (?:många|mycket|stor|lång|gammal)|how (?:many|much))/u, "amount"],
  [/^(?:hur|how|på vilket sätt)/u, "how"],
  [/^(?:när|vilket år|vilken tid|when|what year)/u, "when"],
  [/^(?:vem|vilka var|who)/u, "who"],
  [/^(?:var (?!det\b)|vart|var ligger|where)/u, "where"],
  [/^(?:vad (?:är|betyder|menas|innebär|kallas)|vad är en|förklara (?:vad|begreppet)|definiera|what is|what does)/u, "what"],
  [/^(?:beskriv|förklara|berätta|redogör|describe|explain)/u, "explain"],
  [/^(?:ge (?:ett |några )?exempel|nämn|vilka)/u, "list"],
];
const WAKE = /^(?:(?:hej|okej|ok)\s+)?lumen[,!.]?\s*/iu;

export function normalise(text: string): string {
  return text.toLowerCase().replace(WAKE, "").replace(/[^\p{L}\p{N}\s]/gu, " ").replace(/\s+/g, " ").trim();
}

function kindOf(norm: string): string | null {
  const t = norm.split(" ").filter((w) => !FILLER.has(w)).join(" ");
  for (const [rx, k] of KIND) if (rx.test(t)) return k;
  return null;
}

/** Light Swedish stem: definite and plural endings off longer words ("fotosyntesen" = "fotosyntes"). */
export function stem(w: string): string {
  if (/^\d/.test(w)) return w;
  for (const suf of ["arnas", "ernas", "ornas", "arna", "erna", "orna", "ens", "ets", "en", "et", "na", "ar", "er", "or", "s", "n"]) {
    if (w.length - suf.length >= 4 && w.endsWith(suf)) return w.slice(0, -suf.length);
  }
  return w;
}

function contentWords(norm: string): string[] {
  return norm.split(" ").filter((w) => w && !FILLER.has(w) && !STOP.has(w) && !KIND_WORDS.has(w)).map(stem);
}
const KIND_WORDS = new Set(
  ("vad varför hur när vem vilka vilken vilket var vart beror orsak orsaken orsakade ledde betyder menas innebär kallas " +
    "förklara beskriv berätta redogör definiera jämför skillnaden skillnad nämn ge exempel sätt många mycket år").split(" "),
);

function bigrams(s: string): Map<string, number> {
  const m = new Map<string, number>();
  const t = s.replace(/\s+/g, " ");
  for (let i = 0; i < t.length - 1; i++) {
    const k = t.slice(i, i + 2);
    m.set(k, (m.get(k) ?? 0) + 1);
  }
  return m;
}
function dice(a: string, b: string): number {
  const x = bigrams(a), y = bigrams(b);
  let both = 0, nx = 0, ny = 0;
  for (const v of x.values()) nx += v;
  for (const v of y.values()) ny += v;
  for (const [k, v] of x) both += Math.min(v, y.get(k) ?? 0);
  return nx + ny ? (2 * both) / (nx + ny) : 0;
}
/** Two content words are the same word: equal, or (both longer than 4 letters) nearly the same spelling. */
function sameWord(a: string, b: string): boolean {
  if (a === b) return true;
  if (/\d/.test(a) || /\d/.test(b)) return false; // numbers must be exact
  if (a.length < 5 || b.length < 5) return false;
  // misheard or inflected ("fotosyntesis", "näringskedjor"), but never a word inside a longer one ("andning" is not
  // "cellandning", "syntes" is not "fotosyntes")
  const ratio = Math.min(a.length, b.length) / Math.max(a.length, b.length);
  return ratio >= 0.75 && dice(a, b) >= 0.72;
}

const FOLLOW_UP = /(?:^|\s)(?:mer|mera|djupare|utförligare|noggrannare|igen|också|annars|sen|sedan|efter|före|innan)(?:\s|$)/u;

/** Kinds that can be the same question in other words ("förklara fotosyntes" = "vad är fotosyntes"). */
const COMPATIBLE = new Set(["what|explain", "why|explain", "how|explain", "list|what", "how|what"]); // O39: "hur funkar X" = "vad är X"

/** Speech recognition splits compounds ("foto syntes", "cell andning"): two heard words that together are a saved
 *  content word count as that word. */
function joinSplit(hw: string[], sw: string[]): string[] {
  const out: string[] = [];
  for (let i = 0; i < hw.length; i++) {
    const alone = (w: string) => sw.some((x) => sameWord(x, w));
    if (i + 1 < hw.length && !alone(hw[i]) && !alone(hw[i + 1])) {
      const j = stem(hw[i] + hw[i + 1]);
      if (sw.some((w) => w === j || dice(w, j) >= 0.88)) {
        out.push(j);
        i++;
        continue;
      }
    }
    out.push(hw[i]);
  }
  return out;
}

export interface MatchScore {
  score: number;
  /** Every content word of the saved question was heard, digits equal and at most two content words more. */
  covered: boolean;
  sameKind: boolean;
}

export function scoreMatch(heard: string, saved: string): MatchScore {
  const h = normalise(heard), s = normalise(saved);
  const sw = contentWords(s);
  const hw = joinSplit(contentWords(h), sw);
  if (!sw.length || !hw.length) return { score: 0, covered: false, sameKind: false };
  const hit = sw.filter((w) => hw.some((x) => sameWord(w, x))).length;
  const extra = hw.filter((w) => !sw.some((x) => sameWord(w, x))).length;
  const jac = hit / (sw.length + extra);
  const digitsH = (h.match(/\d+/g) ?? []).join(" "), digitsS = (s.match(/\d+/g) ?? []).join(" ");
  const kh = kindOf(h), ks = kindOf(s);
  const sameKind = kh === ks || kh === null || ks === null || COMPATIBLE.has(`${kh}|${ks}`) || COMPATIBLE.has(`${ks}|${kh}`);
  const score = 0.65 * jac + 0.35 * dice(hw.join(" "), sw.join(" "));
  // a follow-up ("förklara mer", "djupare", "igen") wants more than the saved answer: never sure in code
  const followUp = FOLLOW_UP.test(h) && !FOLLOW_UP.test(s);
  return { score, covered: hit === sw.length && extra <= 2 && digitsH === digitsS && !followUp, sameKind };
}

/** A fragment that is phrased as a question or a request (hands-free Provläge hears the teacher too). */
export function looksLikeQuestion(text: string): boolean {
  const n = normalise(text);
  return /\?\s*$/.test(text.trim()) || kindOf(n) !== null || /(?:^|\s)(?:vad|varför|hur|när|vem|vilk\p{L}*)(?:\s|$)/u.test(n) ||
    /^(?:(?:kan|kunde|skulle) du |är |finns |har |blir |stämmer |gäller |kommer |ska )/u.test(n.split(" ").filter((w) => !FILLER.has(w) || w === "kan").join(" "));
}

export interface SavedCandidate {
  item: SavedAnswer;
  score: number;
  sure: boolean;
}

/** The best saved answers for what was heard, best first; `sure` = answer at once in code. */
export function rankSaved(heard: string, saved: SavedAnswer[], requireQuestion: boolean): SavedCandidate[] {
  if (!saved.length || normalise(heard).length < 3) return [];
  // hands-free Provläge also hears the teacher: a statement is never matched (and costs no check)
  if (requireQuestion && !looksLikeQuestion(heard)) return [];
  return saved
    .map((item) => {
      const m = scoreMatch(heard, item.q);
      // another kind of question (why vs when) is never the same question, not even for the check
      return { item, score: m.sameKind ? m.score : 0, sure: m.score >= SAVED_SURE && m.covered && m.sameKind };
    })
    .filter((c) => c.score >= SAVED_MAYBE)
    .sort((a, b) => b.score - a.score);
}

export const SAVED_CHECK_PROMPT =
  `A Swedish student has saved questions with their own answers for an exam. You get <heard> (what the student just said, from speech recognition, so words may be misheard) and <saved> (numbered saved questions). Decide whether <heard> asks for the same thing as one saved question, so that its saved answer would be a correct and complete answer to <heard>.
- The same thing: the same question in other words, a shorter or longer phrasing, misheard words, singular or plural, another word order.
- NOT the same thing (answer 0): another kind of question about the same topic (what it is vs why it happens vs how it works vs an example), another object or person or year or number, a part of the saved question only when the answer would say much more or something else, a follow-up ("förklara mer", "varför då"), or not a question at all.
Reply with only the number of the saved question, or 0.`;

/** The model's reply to SAVED_CHECK_PROMPT -> index into the candidates, or null (0, unclear, out of range). */
export function parseSavedCheck(reply: string, n: number): number | null {
  const m = /^\s*(\d{1,2})\b/.exec(reply);
  if (!m) return null;
  const k = Number(m[1]);
  return k >= 1 && k <= n ? k - 1 : null;
}

export function savedCheckUser(heard: string, cands: SavedCandidate[], sanitize: (s: string) => string): string {
  return `<heard>${sanitize(heard.slice(0, 400))}</heard>\n<saved>\n${
    cands.map((c, i) => `${i + 1}. ${sanitize(c.item.q)}`).join("\n")
  }\n</saved>`;
}
