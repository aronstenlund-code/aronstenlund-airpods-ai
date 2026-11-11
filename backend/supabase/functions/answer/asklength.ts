/**
 * K42.3 (Aron's phone test 18:58: "Förklara fotosyntes med hundra ord eller mer" got about 50 words): a length the
 * user says is always followed, in every mode. Read in code; the model gets a note, the limits follow the length,
 * and the short-first two-level answer is off (the whole asked length is spoken at once).
 */
export interface AskedLength {
  words?: number;
  atLeast?: boolean;
  atMost?: boolean;
  sentences?: number;
  short?: boolean;
  long?: boolean;
}

const UNITS: Record<string, number> = {
  en: 1, ett: 1, två: 2, tre: 3, fyra: 4, fem: 5, sex: 6, sju: 7, åtta: 8, nio: 9, tio: 10, elva: 11, tolv: 12,
  femton: 15, tjugo: 20, trettio: 30, fyrtio: 40, femtio: 50, sextio: 60, sjuttio: 70, åttio: 80, nittio: 90,
};

/** "hundrafemtio" -> 150, "tvåhundra" -> 200, "120" -> 120, "trettiofem" -> 35. */
export function numberWord(w: string): number | null {
  const s = w.toLowerCase().replace(/\s+/g, "");
  if (/^\d{1,4}$/.test(s)) return Number(s);
  const m = /^(?:(en|ett|två|tre|fyra|fem|sex|sju|åtta|nio)?(hundra))?(.*)$/u.exec(s);
  if (!m) return null;
  let n = m[2] ? (m[1] ? UNITS[m[1]] : 1) * 100 : 0;
  let rest = m[3];
  if (rest) {
    const tens = /^(tjugo|trettio|fyrtio|femtio|sextio|sjuttio|åttio|nittio)?(.*)$/u.exec(rest)!;
    if (tens[1]) n += UNITS[tens[1]];
    rest = tens[2];
    if (rest) {
      if (!(rest in UNITS) || UNITS[rest] >= 20) return null;
      n += UNITS[rest];
    }
  }
  return n || null;
}

const NUM = String.raw`(\d{1,4}|(?:(?:en|ett|två|tre|fyra|fem|sex|sju|åtta|nio)?hundra)?(?:tjugo|trettio|fyrtio|femtio|sextio|sjuttio|åttio|nittio)?(?:en|ett|två|tre|fyra|fem|sex|sju|åtta|nio|tio|elva|tolv|femton)?)`;
const WORDS = new RegExp(String.raw`(?<![\p{L}])(minst|åtminstone|ungefär|cirka|runt|max|högst|max|mer än|över|under)?\s*${NUM}\s+ord(?![\p{L}])(\s+eller\s+(?:mer|fler|längre|mindre|kortare))?`, "iu");
const SENTS = new RegExp(String.raw`(?<![\p{L}])(?:i|med|på)\s+${NUM}\s+(?:mening|meningar)(?![\p{L}])`, "iu");
const SHORT = /(?<![\p{L}])(?:kortfattat|kortfattad|i korthet|i korta drag|superkort|(?:säg|förklara|berätta|svara|beskriv|sammanfatta|förklara det|säg det)(?: (?:mig|det|bara|väldigt|mycket|lite))* kort|kort (?:och (?:koncist|gott)|vad|hur|om|varför))(?![\p{L}])/iu;
const LONG = /(?<![\p{L}])(?:utförligt|utförlig|utförligare|detaljerat|detaljerad|ingående|grundligt|på djupet|mer utförligt|långt svar|lång förklaring)(?![\p{L}])/iu;

export function askedLength(text: string): AskedLength | null {
  const t = text.trim();
  const w = WORDS.exec(t);
  if (w && w[2]) {
    const n = numberWord(w[2]);
    if (n && n >= 5 && n <= 600) {
      const pre = (w[1] ?? "").toLowerCase(), post = (w[3] ?? "").toLowerCase();
      return {
        words: n,
        atLeast: /minst|åtminstone|mer än|över/.test(pre) || /mer|fler|längre/.test(post),
        atMost: /max|högst|under/.test(pre) || /mindre|kortare/.test(post),
      };
    }
  }
  const s = SENTS.exec(t);
  if (s && s[1]) {
    const n = numberWord(s[1]);
    if (n && n <= 20) return { sentences: n };
  }
  if (LONG.test(t)) return { long: true, words: 150, atLeast: true };
  if (SHORT.test(t)) return { short: true };
  return null;
}

/** The note the model gets (in the user message). */
export function lengthNote(a: AskedLength): string {
  if (a.sentences) {
    return `LENGTH (K42): the user asked for exactly ${a.sentences} ${a.sentences === 1 ? "sentence" : "sentences"}. Write exactly ${a.sentences} ${a.sentences === 1 ? "sentence" : "sentences"} (one full stop each), no more and no fewer; this overrides every other length rule.`;
  }
  if (a.words) {
    const lo = a.atLeast ? a.words : Math.round(a.words * 0.9), hi = a.atMost ? a.words : Math.round(a.words * (a.atLeast ? 1.4 : 1.1));
    // live: "femtio ord" got 74, "trettio ord" 41: short targets get a sentence budget too (about 12 words each)
    const sents = Math.max(1, Math.floor((a.atLeast ? lo : hi) / 14));
    const budget = a.words <= 80 && !a.atLeast ? ` That is ${sents} short ${sents === 1 ? "sentence" : "sentences"} and nothing more: no example, no "På provet" sentence, no extra clause.` : "";
    return `LENGTH (K42): the user asked for ${a.atLeast ? "at least " : a.atMost ? "at most " : "about "}${a.words} words. Write between ${lo} and ${hi} words in full sentences (count them as you go); this overrides every other length rule, also "short" and the two-level rule.${budget} Never mention the word count.`;
  }
  if (a.short) return "LENGTH (K42): the user asked for a short answer: one or two short sentences, at most about 30 words.";
  return "";
}

/** Output limits for the asked length (tokens about 2 per Swedish word plus the summary line; chars about 7 per word). */
export function lengthCaps(a: AskedLength): { maxTokens: number; maxChars: number; exact: boolean } | null {
  const words = a.words ? Math.round(a.words * (a.atLeast ? 1.5 : 1.25)) : a.sentences ? a.sentences * 30 : 0;
  if (!words) return null;
  // "about"/"at most" N words: the spoken text is cut at the last sentence end within ~1.2 N words (live: 121 for 100; 1.1 N cut "femtio ord" to 32)
  if (a.words && !a.atLeast) return { maxTokens: Math.max(256, words * 3 + 120), maxChars: Math.round(a.words * 1.2 * 6.8) + 20, exact: true };
  return { maxTokens: Math.max(256, words * 3 + 120), maxChars: Math.max(600, words * 9), exact: false };
}
