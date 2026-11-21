/**
 * K74 (Aron: "ibland låter det rätt konstigt"): the last step of the text the voice reads (`voiceText`), after
 * numbers, units and formulas became words (K18, K66, K67). A table, so a rule is one line. Only what the voice gets
 * changes; the display text (`screen`, the stored question and answer) is never touched.
 * Rules are versioned (`drills.voice_rules`): a drill made before K74 keeps version 1 (the same hashes, so no file
 * is made again and nothing is counted again when it is edited or started); new drills get version 2.
 */
export const VOICE_RULES_VERSION = 4;

/**
 * K115 (D253): Aron heard "1999" as "nittonhundranittionien". The text was right ("nittonhundranittionio"), but every
 * x9 from 39 to 99 ends in "-tionio", which looks like a "-tion" word (station, nationen). UNTESTED ASSUMPTION that
 * this is what the voice stumbles on (D180: nobody listens); the tens and the nine are written apart ("nittio nio"),
 * as they are said. Used by the drill voice (rules version 4) and every spoken Swedish answer.
 */
export function splitNine(t: string): string {
  return t.replace(/(trettio|fyrtio|femtio|sextio|sjuttio|åttio|nittio)nio(?![\p{L}])/giu, "$1 nio");
}

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

// deno-lint-ignore no-explicit-any
type To = string | ((...m: any[]) => string);
export interface VoiceRule {
  /** what the rule is for (tests and the report) */
  kind: "abbreviation" | "parenthesis" | "slash" | "list" | "symbol" | "quote" | "number" | "space" | "formula" | "unit";
  lang: "sv" | "en" | "*";
  re: RegExp;
  to: To;
}

const cap = (s: string) => /^\p{Ll}\p{Lu}/u.test(s) ? s : s.charAt(0).toUpperCase() + s.slice(1);
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

// ---------- K75 (Oscar O68): version 3 ----------
const NUM_SV = String.raw`(?:noll|en|ett|två|tre|fyra|fem|sex|sju|åtta|nio|tio|elva|tolv|\p{L}*(?:ton|tio|hundra|tusen|miljoner|miljon)|\p{L}+(?:ett|en|två|tre|fyra|fem|sex|sju|åtta|nio))`;
/** the formula's name, with a capital letter when it starts a sentence ("CO2 och CH4 ..." -> "Koldioxid och metan ...") */
const atStart = (name: string) => (m: string, k: string, off: number, all: string) => {
  const start = /(?:^|[.!?]\s+)$/.test(all.slice(0, off));
  const w = (k ? `${k} ` : "") + name;
  return start && !k ? cap(w) : w;
};
/** Common chemical formulas as their names (else the voice says "se ha fyra"); before numbers become words. */
const FORMULAS: [string, string, string][] = [
  ["CO2", "koldioxid", "carbon dioxide"], ["CO", "kolmonoxid", "carbon monoxide"], ["O2", "syre", "oxygen"], ["O3", "ozon", "ozone"],
  ["H2O", "vatten", "water"], ["CH4", "metan", "methane"], ["H2", "vätgas", "hydrogen"], ["N2", "kvävgas", "nitrogen"],
  ["NaCl", "natriumklorid", "sodium chloride"], ["C6H12O6", "glukos", "glucose"], ["H2SO4", "svavelsyra", "sulphuric acid"],
  ["HCl", "saltsyra", "hydrochloric acid"], ["NH3", "ammoniak", "ammonia"], ["SO2", "svaveldioxid", "sulphur dioxide"],
  ["NO2", "kvävedioxid", "nitrogen dioxide"], ["CaCO3", "kalciumkarbonat", "calcium carbonate"], ["NaOH", "natriumhydroxid", "sodium hydroxide"],
];
/** Version 3, before the text is made speakable (numbers, formulas and "/" are still as written). */
export const VOICE_RULES_PRE_V3: VoiceRule[] = [
  // "CH4 + 2O2 -> CO2 + 2H2O": a coefficient stays a number ("två syre"), the formula becomes its name
  ...FORMULAS.flatMap(([f, sv, en]): VoiceRule[] => [
    { kind: "formula", lang: "sv", re: new RegExp(String.raw`(?<![\p{L}\p{N}])(\d*)${f}(?![\p{L}\p{N}₀-₉])`, "gu"), to: atStart(sv) },
    { kind: "formula", lang: "en", re: new RegExp(String.raw`(?<![\p{L}\p{N}])(\d*)${f}(?![\p{L}\p{N}₀-₉])`, "gu"), to: atStart(en) },
  ]),
  { kind: "slash", lang: "en", re: /(?<![\p{L}])w\/o(?![\p{L}])/giu, to: "without" },
  { kind: "slash", lang: "en", re: /(?<![\p{L}])w\/(?=\s|\p{L})/giu, to: "with " },
  { kind: "slash", lang: "sv", re: /(?<![\p{L}])m\.\s?h\.\s?a\.?/giu, to: "med hjälp av" },
  // a numbered list in running text: "argument: 1) tonåringar sover mer, 2) de lär sig bättre" -> no "ett)" said
  { kind: "list", lang: "*", re: /(^|[\s:;,])\(?\d{1,2}\)\s+/gu, to: "$1" },
  { kind: "list", lang: "*", re: /(^|[\s:;,])\(?[a-h]\)\s+/gu, to: "$1" },
];
/** Version 3, after the text is speakable; run before the version 2 table (whose last rules tidy spaces). */
export const VOICE_RULES_V3: VoiceRule[] = [
  { kind: "abbreviation", lang: "sv", re: /(?<![\p{L}])enl\.(?=\s)/giu, to: keepCase("enligt") },
  { kind: "abbreviation", lang: "sv", re: /(?<![\p{L}])fig\.\s?(?=[\p{N}\p{L}])/giu, to: keepCase("figur ") },
  { kind: "abbreviation", lang: "sv", re: /(?<![\p{L}])milj\.(?=\s)/giu, to: "miljoner" },
  { kind: "abbreviation", lang: "sv", re: /(?<![\p{L}])mdr\.?(?=\s)/giu, to: "miljarder" },
  { kind: "abbreviation", lang: "sv", re: /(?<![\p{L}])ggr\.?(?![\p{L}])/giu, to: "gånger" },
  { kind: "abbreviation", lang: "sv", re: /(?<![\p{L}])Sthlm(?![\p{L}])/gu, to: "Stockholm" },
  { kind: "abbreviation", lang: "sv", re: /(?<![\p{L}])Gbg(?![\p{L}])/gu, to: "Göteborg" },
  { kind: "abbreviation", lang: "sv", re: /(?<![\p{L}])Ex(?:\.|:)\s*/gu, to: "Till exempel: " },
  { kind: "abbreviation", lang: "sv", re: /(?<![\p{L}])ex\.(?=\s)/gu, to: "till exempel" },
  { kind: "abbreviation", lang: "en", re: /(?<=\d)\s?ft(?![\p{L}])/gu, to: " feet" },
  { kind: "abbreviation", lang: "en", re: /(?<=\d)\s?(?:sec|secs)\.?(?![\p{L}])/gu, to: " seconds" },
  { kind: "abbreviation", lang: "en", re: /(?<=\d)\s?(?:min|mins)\.?(?![\p{L}])/gu, to: " minutes" },
  { kind: "abbreviation", lang: "en", re: /(?<=\d)\s?(?:hr|hrs)\.?(?![\p{L}])/gu, to: " hours" },
  { kind: "abbreviation", lang: "en", re: /(?<![\p{L}])a\.\s?m\.(?=\s|$|[,;])/gu, to: "a m" },
  { kind: "abbreviation", lang: "en", re: /(?<![\p{L}])p\.\s?m\.(?=\s|$|[,;])/gu, to: "p m" },
  { kind: "abbreviation", lang: "en", re: /(?<![\p{L}])Ex(?:\.|:)\s*/gu, to: "For example: " },
  { kind: "symbol", lang: "sv", re: /\s?<\s?/gu, to: " är mindre än " },
  { kind: "symbol", lang: "sv", re: /\s?>\s?/gu, to: " är större än " },
  { kind: "symbol", lang: "en", re: /\s?<\s?/gu, to: " is less than " },
  { kind: "symbol", lang: "en", re: /\s?>\s?/gu, to: " is greater than " },
  // "→" between two short things is "gives" (a reaction), between clauses "so"
  { kind: "symbol", lang: "en", re: /(\S+(?:\s\S+)?)\s?→\s?(?=(\S+(?:\s\S+)?)(?:[.,;!?]|$))/gu, to: (_m, a) => `${a} gives ` },
  { kind: "symbol", lang: "en", re: /\s?→\s?/gu, to: ", so " },
  // a unit letter after a number said as a word ("tio N", "femtusen åttahundra K")
  { kind: "unit", lang: "sv", re: new RegExp(String.raw`(?<![\p{L}])(${NUM_SV})\s(kN|N|K|J|kJ|W|kW|MW|V|Pa|kPa|Hz|kHz)(?![\p{L}\d])`, "gu"),
    to: (_m, n, u) => `${n} ${({ kN: "kilonewton", N: "newton", K: "kelvin", J: "joule", kJ: "kilojoule", W: "watt", kW: "kilowatt", MW: "megawatt", V: "volt", Pa: "pascal", kPa: "kilopascal", Hz: "hertz", kHz: "kilohertz" } as Record<string, string>)[u]}` },
  { kind: "unit", lang: "en", re: /(?<=\d)\s?(kN|N|K|J|kJ|W|kW|V|Pa|Hz)(?![\p{L}\d])/gu,
    to: (_m, u) => ` ${({ kN: "kilonewtons", N: "newtons", K: "kelvin", J: "joules", kJ: "kilojoules", W: "watts", kW: "kilowatts", V: "volts", Pa: "pascals", Hz: "hertz" } as Record<string, string>)[u]}` },
  // a semicolon is a full stop to the voice
  { kind: "space", lang: "*", re: /\s*;\s*(\p{L}{1,2})/gu, to: (_m, c) => `. ${cap(c)}` },
  // "kWh/dag" is "per dag", never "eller dag" (before the version 2 slash rule)
  { kind: "slash", lang: "sv", re: /(\p{L}+)\s?\/\s?(dag|dygn|timme|timmen|år|året|månad|vecka|sekund|minut|person|elev|invånare|styck|liter|kilo)(?![\p{L}])/gu, to: "$1 per $2" },
  { kind: "slash", lang: "en", re: /(\p{L}+)\s?\/\s?(day|hour|year|month|week|second|minute|person|student|litre|liter|kilo)(?![\p{L}])/gu, to: "$1 per $2" },
  { kind: "unit", lang: "sv", re: /(?<![\p{L}])kWh(?![\p{L}])/gu, to: "kilowattimmar" },
  { kind: "unit", lang: "en", re: /(?<![\p{L}])kWh(?![\p{L}])/gu, to: "kilowatt hours" },
  { kind: "unit", lang: "en", re: /(?<=\d\+?)\s?(km|m|cm|mm|kg|g)(?![\p{L}\d²³])/gu,
    to: (_m, u) => ` ${({ km: "kilometres", m: "metres", cm: "centimetres", mm: "millimetres", kg: "kilograms", g: "grams" } as Record<string, string>)[u]}` },
  { kind: "symbol", lang: "en", re: /(\d+)\+(?=\s)/gu, to: "more than $1" },
  { kind: "symbol", lang: "sv", re: /(\d+)\+(?=\s)/gu, to: "fler än $1" },
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
/** K75: the version 3 rules that run before the text is made speakable (formulas, "w/", numbered lists). */
export function preVoice(text: string, lang = "", version = 3): string {
  if (version < 3) return text;
  const L = /^english$/i.test(lang) ? "en" : lang ? "other" : "sv";
  let t = text;
  for (const r of VOICE_RULES_PRE_V3) if (r.lang === "*" || r.lang === L) t = t.replace(r.re, r.to as never);
  return t;
}

export function polishVoice(text: string, lang = "", version = 2): string {
  const L: "sv" | "en" = /^english$/i.test(lang) ? "en" : lang ? "en" : "sv";
  // other foreign languages (Spanish, German ...) only get the language-neutral rules
  const only = lang && !/^english$/i.test(lang) ? "*" : null;
  let t = text;
  for (const r of [...(version >= 3 ? VOICE_RULES_V3 : []), ...VOICE_RULES]) {
    if (r.lang !== "*" && (only || r.lang !== L)) continue;
    t = t.replace(r.re, r.to as never);
  }
  const sentences = t.split(/(?<=[.!?])\s+(?=["“„«(]?[\p{Lu}\p{N}])/u);
  const out0 = sentences.flatMap((s) => splitLong(s, L)).join(" ").replace(/\s{2,}/g, " ").trim();
  const out = version >= 4 && L === "sv" && !only ? splitNine(out0) : out0;
  // K75: the text ends with a stop, so the voice ends calmly ("... med mera", "every 5 seconds" had lost theirs)
  return version >= 3 && out && !/[.!?…:]["”»)]*$/.test(out) ? `${out}.` : out;
}
