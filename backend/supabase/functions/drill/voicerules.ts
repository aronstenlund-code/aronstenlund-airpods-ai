/**
 * K74 (Aron: "ibland låter det rätt konstigt"): the last step of the text the voice reads (`voiceText`), after
 * numbers, units and formulas became words (K18, K66, K67). A table, so a rule is one line. Only what the voice gets
 * changes; the display text (`screen`, the stored question and answer) is never touched.
 * Rules are versioned (`drills.voice_rules`): a drill made before K74 keeps version 1 (the same hashes, so no file
 * is made again and nothing is counted again when it is edited or started); new drills get version 2.
 */
export const VOICE_RULES_VERSION = 2;

/**
 * K74 part 2: ElevenLabs v4, prepared but off. A drill may ask for it only when drill_settings.allow_eleven_v4 = 1
 * (default 0, so no call is ever made with it now). With drill_settings.v4_pause_tag = 1 the long answer's file
 * starts with ONE audio tag, a short pause, so the answer does not run straight on from the question.
 * The tag's spelling for v4 is an untested assumption (v3's documented tags are in square brackets); the A/B script
 * (scripts/k74-ab.py, run only after Aron's yes, D180) is how it gets checked.
 */
export const V4_MODEL = "eleven_v4";
export const V4_PAUSE_TAG = "[short pause]";
/** The long answer's voice text and its short-answer boundary with the pause tag in front (v4 only). */
export function withPauseTag(text: string, shortChars: number): { text: string; shortChars: number } {
  return { text: `${V4_PAUSE_TAG} ${text}`, shortChars: shortChars + V4_PAUSE_TAG.length + 1 };
}

type To = string | ((...m: string[]) => string);
export interface VoiceRule {
  /** what the rule is for (tests and the report) */
  kind: "abbreviation" | "parenthesis" | "slash" | "list" | "symbol" | "quote" | "number" | "space";
  lang: "sv" | "en" | "*";
  re: RegExp;
  to: To;
}

const cap = (s: string) => s.charAt(0).toUpperCase() + s.slice(1);
/** keeps a capital letter at the start of a sentence ("Ca 300" -> "Cirka 300", "Obs!" -> "Observera!") */
const keepCase = (word: string) => (m: string) => /^\p{Lu}/u.test(m) ? cap(word) : word;

export const VOICE_RULES: VoiceRule[] = [
  // ---------- abbreviations (t.ex., bl.a., osv., ca, s. and nr are already words from K25/K67) ----------
  { kind: "abbreviation", lang: "sv", re: /(?<![\p{L}])fr\.\s?o\.\s?m\.?/giu, to: keepCase("från och med") },
  { kind: "abbreviation", lang: "sv", re: /(?<![\p{L}])t\.\s?o\.\s?m\.?/giu, to: keepCase("till och med") },
  { kind: "abbreviation", lang: "sv", re: /(?<![\p{L}])kap\.\s?(?=[\p{N}\p{L}])/giu, to: keepCase("kapitel ") },
  { kind: "abbreviation", lang: "sv", re: /(?<![\p{L}])inkl\.(?=\s)/giu, to: keepCase("inklusive") },
  { kind: "abbreviation", lang: "sv", re: /(?<![\p{L}])exkl\.(?=\s)/giu, to: keepCase("exklusive") },
  { kind: "abbreviation", lang: "sv", re: /(?<![\p{L}])ung\.(?=\s)/giu, to: keepCase("ungefär") },
  { kind: "abbreviation", lang: "sv", re: /(?<![\p{L}])jfr\.?(?=\s)/giu, to: keepCase("jämför") },
  { kind: "abbreviation", lang: "sv", re: /(?<![\p{L}])obs[.!]?(?=\s)/giu, to: (m) => (/^\p{Lu}/u.test(m) ? "Observera" : "observera") + (m.endsWith("!") ? "!" : "") },
  { kind: "abbreviation", lang: "sv", re: /(?<![\p{L}])etc\.?(?![\p{L}])/giu, to: "etcetera" },
  { kind: "abbreviation", lang: "sv", re: /(?<![\p{L}])ca(?=\s)/gu, to: "cirka" },
  { kind: "abbreviation", lang: "sv", re: /(?<![\p{L}])Ca(?=\s+[\p{N}\p{Ll}])/gu, to: "Cirka" },
  // "trehundra stycken. elever" (the abbreviation's full stop was left in the middle of the sentence)
  { kind: "abbreviation", lang: "sv", re: /(?<![\p{L}])stycken\.(?=\s+\p{Ll})/gu, to: "stycken" },
  { kind: "abbreviation", lang: "en", re: /(?<![\p{L}])e\.\s?g\.,?/giu, to: (m) => (/^E/.test(m) ? "For example" : "for example") + (m.endsWith(",") ? "," : "") },
  { kind: "abbreviation", lang: "en", re: /(?<![\p{L}])i\.\s?e\.,?/giu, to: (m) => (/^I/.test(m) ? "That is" : "that is") + (m.endsWith(",") ? "," : "") },
  { kind: "abbreviation", lang: "en", re: /(?<![\p{L}])etc\.?(?![\p{L}])/giu, to: "et cetera" },
  { kind: "abbreviation", lang: "en", re: /(?<![\p{L}])vs\.?(?=\s)/giu, to: "versus" },
  { kind: "abbreviation", lang: "en", re: /(?<![\p{L}])approx\.(?=\s)/giu, to: "approximately" },
  { kind: "abbreviation", lang: "en", re: /(?<![\p{L}])ca\.?(?=\s+\p{N})/giu, to: "about" },
  // ---------- parentheses: said as a short aside, between commas ----------
  // "Fotosyntesen (som sker i bladen) ger" -> "Fotosyntesen, som sker i bladen, ger"; "... socker (glukos)." -> ", glukos."
  { kind: "parenthesis", lang: "*", re: /\s*[([]\s*([^()[\]]{1,120}?)\s*[)\]]\s*(?=[.!?,;:]|$)/gu, to: (_m, x) => `, ${x}` },
  { kind: "parenthesis", lang: "*", re: /\s*[([]\s*([^()[\]]{1,120}?)\s*[)\]]\s*/gu, to: (_m, x) => `, ${x}, ` },
  // ---------- slash between two words (formulas and units were said before this step) ----------
  { kind: "slash", lang: "sv", re: /(?<![\p{L}])(och)\/(eller)(?![\p{L}])/giu, to: (_m, a) => `${a} eller` },
  { kind: "slash", lang: "sv", re: /(\p{L}{2,})\s?\/\s?(\p{L}{2,})/gu, to: (_m, a, b) => `${a} eller ${b}` },
  { kind: "slash", lang: "en", re: /(?<![\p{L}])(and)\/(or)(?![\p{L}])/giu, to: (_m, a) => `${a} or` },
  { kind: "slash", lang: "en", re: /(\p{L}{2,})\s?\/\s?(\p{L}{2,})/gu, to: (_m, a, b) => `${a} or ${b}` },
  // ---------- list marks left inside a line ("Se punkterna: • luft • vatten") ----------
  { kind: "list", lang: "*", re: /\s*[•·▪◦‣]\s*/gu, to: ", " },
  { kind: "list", lang: "*", re: /:\s*,\s*/gu, to: ": " },
  // ---------- symbols left after the number words ----------
  { kind: "symbol", lang: "sv", re: /\s?~\s?(?=\S)/gu, to: " ungefär " },
  { kind: "symbol", lang: "sv", re: /\s?%/gu, to: " procent" },
  { kind: "symbol", lang: "sv", re: /\s?°\s?C(?![\p{L}])/gu, to: " grader Celsius" },
  { kind: "symbol", lang: "sv", re: /\s?°/gu, to: " grader" },
  { kind: "symbol", lang: "sv", re: /\s?&\s?/gu, to: " och " },
  { kind: "symbol", lang: "en", re: /\s?~\s?(?=\S)/gu, to: " about " },
  { kind: "symbol", lang: "en", re: /\s?°\s?C(?![\p{L}])/gu, to: " degrees Celsius" },
  { kind: "symbol", lang: "en", re: /\s?°\s?F(?![\p{L}])/gu, to: " degrees Fahrenheit" },
  { kind: "symbol", lang: "en", re: /\s?°/gu, to: " degrees" },
  { kind: "symbol", lang: "en", re: /\s?→\s?/gu, to: " leads to " },
  { kind: "symbol", lang: "en", re: /\s?±\s?/gu, to: " plus or minus " },
  { kind: "symbol", lang: "en", re: /\s?≈\s?/gu, to: " is about " },
  { kind: "symbol", lang: "en", re: /\s?&\s?/gu, to: " and " },
  { kind: "symbol", lang: "*", re: /\s?[*#|]\s?/gu, to: " " },
  // ---------- quotation marks: the voice reads the words, the marks only make it stumble ----------
  { kind: "quote", lang: "*", re: /["“”„«»]/gu, to: "" },
  { kind: "quote", lang: "*", re: /(?<![\p{L}])'([^']{1,80})'(?![\p{L}])/gu, to: "$1" },
  // numbers: years and decimals are words before this step in Swedish (toSpeech); English keeps digits (D182)
  // ---------- spaces and punctuation the rules above leave ----------
  { kind: "space", lang: "*", re: /\s+([,.!?;:])/gu, to: "$1" },
  { kind: "space", lang: "*", re: /,\s*,+/gu, to: "," },
  { kind: "space", lang: "*", re: /,([.!?])/gu, to: "$1" },
  { kind: "space", lang: "*", re: /^\s*,\s*/gu, to: "" },
  { kind: "space", lang: "*", re: /\s{2,}/gu, to: " " },
];

/** Where a long sentence may be cut, best first: after a semicolon or colon, then before a conjunction after a comma. */
const CUTS: Record<"sv" | "en", RegExp> = {
  sv: /(?:;|:|,(?=\s+(?:men|och|så|eftersom|därför|vilket|medan|alltså|för att|så att|fast|trots att|samtidigt som)\s))/giu,
  en: /(?:;|:|,(?=\s+(?:but|and|so|because|which|while|since|although|though|yet)\s))/giu,
};
export const LONG_SENTENCE_WORDS = 30;
const words = (s: string) => s.trim().split(/\s+/).filter(Boolean).length;

/** A sentence over 30 words is cut where it breathes (closest to the middle, at least 6 words on each side). */
export function splitLong(sentence: string, lang: "sv" | "en"): string[] {
  if (words(sentence) <= LONG_SENTENCE_WORDS) return [sentence];
  const re = new RegExp(CUTS[lang].source, "giu");
  const total = words(sentence);
  let best: { at: number; len: number; score: number } | null = null;
  let m: RegExpExecArray | null;
  while ((m = re.exec(sentence))) {
    const left = words(sentence.slice(0, m.index));
    if (left < 6 || total - left < 6) continue;
    const score = Math.abs(total / 2 - left) + (m[0] === ";" || m[0] === ":" ? -3 : 0);
    if (!best || score < best.score) best = { at: m.index, len: m[0].length, score };
  }
  if (!best) {
    // no conjunction: a plain comma closest to the middle (still a breath), never inside a number
    const c = /,(?=\s)/g;
    while ((m = c.exec(sentence))) {
      const left = words(sentence.slice(0, m.index));
      if (left < 6 || total - left < 6) continue;
      const score = Math.abs(total / 2 - left);
      if (!best || score < best.score) best = { at: m.index, len: 1, score };
    }
  }
  if (!best) {
    // nor a comma: before "because"/"eftersom" (the sentence goes on as "Det är för att ..." / "That is because ...")
    const b = lang === "en" ? /\s(?=because\s)/g : /\s(?=eftersom\s)/g;
    while ((m = b.exec(sentence))) {
      const left = words(sentence.slice(0, m.index));
      if (left < 6 || total - left < 6) continue;
      const score = Math.abs(total / 2 - left);
      if (!best || score < best.score) best = { at: m.index, len: 1, score };
    }
    if (best) {
      const a = sentence.slice(0, best.at).trim();
      const rest = sentence.slice(best.at + 1).trim().replace(/^(?:because|eftersom)\s+/i, "");
      const b2 = lang === "en" ? `That is because ${rest}` : `Det beror på att ${rest}`;
      return [...splitLong(`${a}.`, lang), ...splitLong(b2, lang)];
    }
  }
  if (!best) return [sentence];
  const a = sentence.slice(0, best.at).trim();
  let b = sentence.slice(best.at + best.len).trim();
  // "..., och det kan" -> "... . Det kan"; "..., men X" -> ". Men X" (the conjunction stays when it carries meaning)
  b = b.replace(/^(?:och|and)\s+/iu, "");
  b = cap(b);
  return [...splitLong(/[.!?]$/.test(a) ? a : `${a}.`, lang), ...splitLong(b, lang)];
}

/** The rules for one language ("" = Swedish), then long sentences cut. */
export function polishVoice(text: string, lang = ""): string {
  const L: "sv" | "en" = /^english$/i.test(lang) ? "en" : lang ? "en" : "sv";
  // other foreign languages (Spanish, German ...) only get the language-neutral rules
  const only = lang && !/^english$/i.test(lang) ? "*" : null;
  let t = text;
  for (const r of VOICE_RULES) {
    if (r.lang !== "*" && (only || r.lang !== L)) continue;
    t = t.replace(r.re, r.to as never);
  }
  const sentences = t.split(/(?<=[.!?])\s+(?=["“„«(]?[\p{Lu}\p{N}])/u);
  return sentences.flatMap((s) => splitLong(s, L)).join(" ").replace(/\s{2,}/g, " ").trim();
}
