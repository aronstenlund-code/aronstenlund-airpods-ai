/**
 * D54: symbols, formulas and abbreviations that must never reach the speech engine as written.
 * `beforeNumbers` runs on the text before digits become words (powers, formulas, equations, abbreviations),
 * `afterNumbers` on the result (squared units, "km/s", leftover symbols).
 */

const LETTER_NAMES: Record<string, string> = {
  a: "a",
  b: "be",
  c: "se",
  d: "de",
  e: "e",
  f: "eff",
  g: "ge",
  h: "ha",
  i: "i",
  j: "ji",
  k: "ko",
  l: "ell",
  m: "emm",
  n: "enn",
  o: "o",
  p: "pe",
  q: "ku",
  r: "ärr",
  s: "ess",
  t: "te",
  u: "u",
  v: "ve",
  w: "dubbel-ve",
  x: "ex",
  y: "y",
  z: "säta",
};

const ELEMENTS = new Set(
  ("H He Li Be B C N O F Ne Na Mg Al Si P S Cl Ar K Ca Sc Ti V Cr Mn Fe Co Ni Cu Zn Ga Ge As Se Br Kr " +
    "Rb Sr Y Zr Nb Mo Tc Ru Rh Pd Ag Cd In Sn Sb Te I Xe Cs Ba La Ce Pr Nd Pm Sm Eu Gd Tb Dy Ho Er Tm Yb " +
    "Lu Hf Ta W Re Os Ir Pt Au Hg Tl Pb Bi Po At Rn Fr Ra Ac Th Pa U Np Pu Am Cm").split(" "),
);

const SMALL_NUMBERS = [
  "noll",
  "ett",
  "två",
  "tre",
  "fyra",
  "fem",
  "sex",
  "sju",
  "åtta",
  "nio",
  "tio",
  "elva",
  "tolv",
];
function digitsToWords(d: string): string {
  const n = Number(d);
  return n <= 12 ? SMALL_NUMBERS[n] : String(n);
}

/** "C12H22O11" -> "se tolv ha tjugotvå o elva" (the digits are left for the number converter). */
export function spellFormula(tok: string): string | null {
  const parts = tok.match(/[A-Z][a-z]?|\d+/g);
  if (!parts || parts.join("") !== tok) return null;
  const symbols = parts.filter((p) => /^[A-Z]/.test(p));
  if (!symbols.length || !symbols.every((p) => ELEMENTS.has(p))) return null;
  const hasDigit = parts.some((p) => /^\d/.test(p));
  const mixedCase = parts.some((p) => p.length === 2 && /^[A-Z][a-z]$/.test(p));
  // plain all-capital words (PIN, SOS, OK) are left alone unless they carry a digit
  if (!(hasDigit || (mixedCase && symbols.length >= 2))) return null;
  if (
    symbols.length < 2 && !(hasDigit && ["H", "O", "N", "F", "Cl", "Br", "I"].includes(symbols[0]))
  ) {
    return null;
  }
  return parts
    .map((p) =>
      /^\d/.test(p) ? p : p.toLowerCase().split("").map((c) => LETTER_NAMES[c] ?? c).join(" ")
    )
    .join(" ");
}

const ROMAN: Record<string, number> = {
  I: 1,
  II: 2,
  III: 3,
  IV: 4,
  V: 5,
  VI: 6,
  VII: 7,
  VIII: 8,
  IX: 9,
  X: 10,
  XI: 11,
  XII: 12,
  XIII: 13,
  XIV: 14,
  XV: 15,
  XVI: 16,
  XVII: 17,
  XVIII: 18,
  XIX: 19,
  XX: 20,
};
export function romanToInt(r: string): number | null {
  return ROMAN[r] ?? null;
}
const REGNAL = [
  "",
  "förste",
  "andre",
  "tredje",
  "fjärde",
  "femte",
  "sjätte",
  "sjunde",
  "åttonde",
  "nionde",
  "tionde",
  "elfte",
  "tolfte",
  "trettonde",
  "fjortonde",
  "femtonde",
  "sextonde",
  "sjuttonde",
  "artonde",
  "nittonde",
  "tjugonde",
];
/** "den förste", "den andre", "den tredje" ... (masculine, as for kings and popes). */
export const regnal = (n: number) => REGNAL[n] ?? String(n);

const PARTY: Record<string, string> = { M: "Moderaterna", S: "Socialdemokraterna", SD: "Sverigedemokraterna", C: "Centerpartiet", V: "Vänsterpartiet", KD: "Kristdemokraterna", L: "Liberalerna", MP: "Miljöpartiet" };
// deno-lint-ignore no-explicit-any
const ABBREVIATIONS: [RegExp, string | ((...m: any[]) => string)][] = [
  // Oscar O36/O34: "Läs s. 23" was "läs s. tjugotre"; "1 299,50 kronor" was "… komma fem noll kronor"
  [/(?<![\p{L}])(?:s|sid)\.\s?(?=\d)/gu, "sidan "],
  // live eval 2026-11-11 (webb-03): "Ulf Kristersson (M)" read the letter; the party is said (after a full name only)
  [/(\p{Lu}\p{Ll}+ \p{Lu}[\p{L}-]+)\s?\((M|S|SD|C|V|KD|L|MP)\)(\s*[.!?,;:]|$)?/gu,
    (_m: string, who: string, p: string, end?: string) => `${who}, ${PARTY[p]}${end ?? ","}`],
  // webb-04: an English connective at the start of a Swedish sentence ("Also, SMHI har …")
  [/(^|[.!?]\s+)(?:Also|However|Moreover|Additionally|Furthermore),\s+(\p{L})/gu, (_m: string, a: string, c: string) => a + c.toUpperCase()],
  // live eval 2026-11-11: the model wrote "sextiotta" itself (words, not digits)
  [/(?<![\p{L}])(tjugo|trettio|fyrtio|femtio|sextio|sjuttio|åttio|nittio)tta(?![\p{L}])/giu, "$1åtta"],
  [/(\d[.,]\d{1,2})\s?kronor(?![\p{L}])/gu, "$1 kr"],
  [/(?<![\p{L}])f\.\s?Kr\.?/gu, "före Kristus"],
  [/(?<![\p{L}])e\.\s?Kr\.?/gu, "efter Kristus"],
  [/(?<![\p{L}])t\.ex\.?/giu, "till exempel"],
  [/(?<![\p{L}])bl\.a\.?/giu, "bland annat"],
  [/(?<![\p{L}])m\.m\.?/giu, "med mera"],
  [/(?<![\p{L}])m\.fl\.?/giu, "med flera"],
  [/(?<![\p{L}])o\.s\.v\.?/giu, "och så vidare"],
  [/(?<![\p{L}])osv\.?(?![\p{L}])/giu, "och så vidare"],
  [/(?<![\p{L}])d\.v\.s\.?/giu, "det vill säga"],
  [/(?<![\p{L}])dvs\.?(?![\p{L}])/giu, "det vill säga"],
  [/(?<![\p{L}])ca\.?(?=\s)/gu, "cirka"],
  // K25 (Oscar O26): "Spår nr 7" -> "nummer sju", "kl. 14.30" -> "klockan fjorton och trettio"
  [/(?<![\p{L}])[Nn]r\.?(?=\s*\d)/gu, "nummer"],
  [/(?<![\p{L}])kl\.?(?=\s*\d)/gu, "klockan"],
  [/(?<![\p{L}])ev\.(?=\s)/gu, "eventuellt"],
  [/(?<![\p{L}])resp\.?(?=\s)/gu, "respektive"],
];

// ---------- phone numbers (D65) ----------
// The model must never state a phone number from memory. Only 112 (emergency), 1177 (healthcare advice) and
// 114 14 (police, non-emergency; only when the context is the police) pass; any other number written like a
// phone number next to a phone cue is replaced. The prompt says the same; this is the safety net.
// K13 (Oscar O10 #6: "omkring 800 000 människor" became the placeholder: "ring" in "omkring"): whole words only
const PHONE_CUE =
  /(?<![\p{L}])(?:ring|ringa|ringer|ringde|ringt|nummer|numret|numren|telefon(?:nummer|numret|en)?|tel|växel(?:n)?|jour(?:en|numret|nummer)?|spärr(?:a|tjänst|tjänsten|linjen)?|larmnummer|larmnumret|larmcentral(?:en)?|hjälplinje(?:n)?|support(?:en)?|kundtjänst(?:en)?|sms|sms:a|smsa|messa|swish(?:a|nummer|numret)?|skriv till|nås på|nå (?:dem|oss|honom|henne) på|stödlinje(?:n)?)(?![\p{L}])/iu;
/** "800 000", "1 000 000", "12 000": a number grouped in thousands, never a phone number. */
const THOUSANDS = /^[1-9]\d{0,2}(?: \d{3})+$/;
const PHONE_RE =
  /(?<![\p{L}\d.,:+/-])(?:\+\d[\d -]{6,14}\d|0\d{1,3}[ -]?\d{2,3}(?:[ -]?\d{2,4}){1,3}|\d{2,5}(?:[ -]\d{2,4}){1,4}|\d{5,8})(?![\p{L}\d]|[.,]\d)/gu;
export const PHONE_PLACEHOLDER = "numret som står på deras webbplats";

/**
 * The numbers the assistant may give are spoken the way people say them: 112, 1177, 114 14 and (K23, checked
 * against bris.se, mind.se and 1177.se on 2026-11-10) the support lines 90101 (Självmordslinjen, Mind) and
 * 116 111 (Bris, under 18).
 */
const SOS_CUE = /(?<![\p{L}])(?:ring|ringa|ringer|larma|larmar|nödnummer(?:et)?|akut|akuten|i fara|sos|nödläge)(?![\p{L}])/iu;
const SUPPORT_CUE = /(?<![\p{L}])(?:ring|ringa|ringer|nås|nå|självmordslinjen|mind|bris|stödlinje(?:n)?|hjälplinje(?:n)?|chatta|sms|numret|nummer)(?![\p{L}])/iu;
function speakKnownNumbers(text: string, ctx: string): string {
  const full = ctx + text;
  let out = text;
  const cue = (i: number, re: RegExp) => re.test(full.slice(Math.max(0, i - 60), i));
  const swap = (re: RegExp, words: string, cueRe: RegExp, extra?: (b: string) => boolean) => {
    out = out.replace(re, (m, off: number) => {
      const before = full.slice(Math.max(0, ctx.length + off - 80), ctx.length + off);
      return cue(ctx.length + off, cueRe) && (!extra || extra(before)) ? words : m;
    });
  };
  // Oscar O29: "Nummer 112 i listan är Kina" is not the emergency number: only with a call or danger cue
  swap(/(?<![\d.,:\-+/])112(?![\d]|[.,]\d)/g, "ett ett två", SOS_CUE);
  swap(/(?<![\d.,:\-+/])90 ?101(?![\d]|[.,]\d)/g, "nittio ett noll ett", SUPPORT_CUE);
  swap(/(?<![\d.,:\-+/])116 ?111(?![\d]|[.,]\d)/g, "ett ett sex ett ett ett", SUPPORT_CUE);
  swap(
    /(?<![\d.,:\-+/])1177(?![\d]|[.,]\d)/g,
    "elva sjuttiosju",
    /(?:ring|nummer|vårdguiden|sjukvård|rådgivning|1177)/i,
  );
  swap(
    /(?<![\d.,:\-+/])114 14(?![\d])/g,
    "ett ett fyra, ett fyra",
    PHONE_CUE,
    (b) => /polis/i.test(b),
  );
  return out;
}

export function guardPhoneNumbers(text: string, ctx = ""): string {
  if (!/\d/.test(text)) return text;
  text = speakKnownNumbers(text, ctx);
  if (!/\d/.test(text)) return text;
  const full = ctx + text;
  let out = "";
  let last = 0;
  for (const m of full.matchAll(PHONE_RE)) {
    const start = m.index!;
    if (start < ctx.length) continue; // belongs to text already spoken
    const digits = m[0].replace(/\D/g, "");
    const before = full.slice(Math.max(0, start - 80), start);
    const national = /^0\d{6,}$/.test(digits) || /^\+/.test(m[0]);
    const cued = PHONE_CUE.test(before) || national;
    if (!cued || digits.length < 5 || THOUSANDS.test(m[0])) continue;
    out += full.slice(Math.max(last, ctx.length), start) + PHONE_PLACEHOLDER;
    last = start + m[0].length;
  }
  return out ? out + full.slice(last) : text;
}

const CLOCK_CUE_END = /(?:^|[^\p{L}])(?:klockan|kl\.?)\s+$/iu;

const EN_ONES = ["", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve",
  "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen"];
const EN_TENS = ["", "", "twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety"];
const en99 = (n: number) => n < 20 ? EN_ONES[n] : EN_TENS[Math.floor(n / 10)] + (n % 10 ? "-" + EN_ONES[n % 10] : "");

/** K2: a year in an English example as an English speaker says it: 2019 -> "twenty nineteen", 1066 -> "ten sixty-six". */
export function englishYear(y: number): string {
  if (y >= 2000 && y <= 2009) return y === 2000 ? "two thousand" : `two thousand and ${EN_ONES[y - 2000]}`;
  const hi = Math.floor(y / 100), lo = y % 100;
  if (lo === 0) return `${en99(hi)} hundred`;
  return `${en99(hi)} ${lo < 10 ? "oh " + EN_ONES[lo] : en99(lo)}`;
}

/** K2: English words that start a sentence before "I" ("If I had", "When I was"): never a regnal number. */
const EN_BEFORE_I = new Set(
  ("if when then and but so because as that what where why how who since until after before have had do did can " +
    "could would should will am was were yes no now here maybe today yesterday tomorrow once while unless though " +
    "although sometimes often never always also first last perhaps").split(" "),
);
const EN_AFTER_I = /^\s+(?:am|was|have|had|would|will|could|should|can|cannot|do|did|don't|didn't|think|thought|know|knew|like|liked|went|go|see|saw|love|want|wanted|need|needed|feel|felt|got|get|live|lived|studied|study|play|played|visited|visit|always|never|really|just|also)(?![\p{L}])/iu;

/** Before digits become words. */
export function beforeNumbers(text: string, ctx = ""): string {
  // invisible characters (soft hyphen, zero-width) away; subscript digits (C₁₂H₂₂O₁₁) -> plain digits
  let s = guardPhoneNumbers(text, ctx).replace(/[\u00ad\u200b-\u200d\u2060\ufeff]/g, "").replace(
    /[\u2080-\u2089]/g,
    (c) => String(c.charCodeAt(0) - 0x2080),
  );
  // K2: a year after an English preposition is said in English ("in 2019" -> "in twenty nineteen", not
  // "in tvåtusen nitton"); Swedish never uses these words before a year
  s = s.replace(
    /(?<![\p{L}])((?:in|since|by|until|from|before|after|of) )(1[1-9]\d\d|20\d\d)(?!\d|[.,:]\d)/gu,
    (_m, pre: string, y: string) => pre + englishYear(Number(y)),
  );
  // ...also when the stream split "since " from "2015" (the preposition is in the text already spoken)
  if (/(?<![\p{L}])(?:in|since|by|until|from|before|after|of) $/u.test(ctx)) {
    s = s.replace(/^(1[1-9]\d\d|20\d\d)(?!\d|[.,:]\d)/u, (y: string) => englishYear(Number(y)));
  }
  // D65: clock times written with a dot after "klockan"/"kl": 17.40 -> "17:40" (read by the clock rule)
  s = s.replace(
    /((?:klockan|kl\.?|vid|runt|före|efter)\s+)([01]?\d|2[0-3])\.([0-5]\d)(?![\d])/giu,
    (_m, pre: string, h: string, m: string) => `${pre}${h}:${m}`,
  );
  s = s.replace(
    /((?:klockan|kl\.?)\s+)([01]?\d|2[0-3]),([0-5]\d)(?![\d])/giu,
    (_m, pre: string, h: string, m: string) => `${pre}${h}:${m}`,
  );
  // ...also when the stream split "klockan " from "17.40" (the cue word is in the text already spoken)
  if (CLOCK_CUE_END.test(ctx)) {
    s = s.replace(/^(\s*)([01]?\d|2[0-3])[.,]([0-5]\d)(?![\d])/u, "$1$2:$3");
  }
  s = rulerNumbers(s); // K20: "Erik 14", "Erik den XIV"
  // D65: roman numerals after a name are regnal numbers: "Oscar I" -> "Oscar den förste"
  s = s.replace(
    /(?<![\p{L}\d])(\p{Lu}[\p{L}]+) (XVIII|XVII|XIII|XIV|XVI|XIX|VIII|VII|III|XII|XV|XI|IX|IV|II|VI|XX|V|X|I)(?![\p{L}\d])(?!\s\p{Lu})/gu,
    (m: string, name: string, roman: string, offset: number, all: string) => {
      // K2: "If I had studied" is English, not "If den förste" (Oscar's D87 review, pl-117)
      if (roman === "I" && (EN_BEFORE_I.has(name.toLowerCase()) || EN_AFTER_I.test(all.slice(offset + m.length)))) return m;
      const n = romanToInt(roman);
      return n === null ? m : `${name} den ${regnal(n)}`;
    },
  );
  s = s.replace(
    /(?<![\p{L}\d])(\p{Lu}[\p{L}]+) (XVIII|XVII|XIII|XIV|XVI|XIX|VIII|VII|III|XII|XV|XI|IX|IV|II|VI|XX|V|X)(?= \p{Lu})/gu,
    (m: string, name: string, roman: string) => {
      const n = romanToInt(roman);
      return n === null ? m : `${name} den ${regnal(n)}`;
    },
  );
  // "2x" is "two times"; "5G"/"3D": a number directly before capital letters is read as number + letters.
  // K1.3 (Oscar D83: "derivatan av x i kvadrat är två gånger"): in maths "2x" is two x: when the text has an
  // equation or power ("=", "²", "^", "f′"), a bare variable x, or an operator right after the term.
  // K2 (pl-184, pl-187): also an operator in words after the term ("3x minus 7", "3x är lika med 21") or a power or
  // bracket before it ("e^{3x}", "(3x)"), and maths words in the text ("ekvationen", "derivatan", "lös").
  const algebra = /[=²³^′]|(?<![\p{L}\d])x(?![\p{L}\d])|\b(?:ekvation(?:en)?|derivat(?:a|an)|deriver\p{L}*|lös|funktionen)\b/iu.test(
    (ctx.slice(-120) + " " + s).replace(/(?<![\p{L}\d.,])\d+\s?x(?![\p{L}\d])/giu, ""),
  );
  // K2 full run (pl-184, "… plus sju blir 3x."): the term at the end of a sentence or clause is also x
  s = s.replace(
    /(?<![\p{L}\d.,])(\d+)(\s?)x(?![\p{L}\d])(?=(\s*(?:[+\-−=^²³)}/]|minus\b|plus\b|är lika med\b|delat med\b|i kvadrat\b|upphöjt\b|[.,;:](?=\s|$)|$))?)/gu,
    (_m: string, n: string, _sp: string, op: string | undefined, off: number, all: string) =>
      algebra || op || /[\^({]\s*$/.test(all.slice(0, off)) ? `${n} x` : `${n} gånger`,
  );
  s = s.replace(/(?<![\p{L}\d.,])(\d+)\s?X(?![\p{L}\d])/gu, "$1 gånger");
  s = s.replace(/(?<![\p{L}\d.,])(\d+)([A-Z]{1,2})(?![\p{L}\d])/gu, "$1 $2");
  for (const [re, to] of ABBREVIATIONS) s = s.replace(re, to);
  // powers: 10^23, x^2, 10^{-3}
  s = s.replace(
    /([\p{L}\d)]+)\s?\^\s?\{?(-?[\p{L}\d]+)\}?/gu,
    (_m, base: string, exp: string) => `${base} upphöjt till ${exp}`,
  );
  // letter+2/3 right after "=" is a square/cube (E = mc2): handled on tokens that contain "="
  s = s.replace(
    /(?<![\p{L}\d])([A-Za-z]{1,3})(=)([A-Za-z]{1,3})([23])(?![\p{L}\d])/gu,
    (_m, l: string, _eq: string, r: string, p: string) =>
      `${l.split("").join(" ")} = ${r.split("").join(" ")}${p === "2" ? "²" : "³"}`,
  );
  s = s.replace(
    /(=\s?)([A-Za-z]{1,3})([23])(?![\p{L}\d])/gu,
    (_m, eq: string, r: string, p: string) =>
      `${eq}${r.split("").join(" ")}${p === "2" ? "²" : "³"}`,
  );
  // chemical formulas: NaCl, H2O, C12H22O11
  s = s.replace(
    /(?<![\p{L}\d])((?:[A-Z][a-z]?\d*)+)(?![\p{L}\d])/gu,
    (m: string) => spellFormula(m) ?? m,
  );
  return s;
}

const UNIT_SPOKEN: Record<string, string> = {
  km: "kilometer",
  m: "meter",
  ghz: "gigahertz",
  mhz: "megahertz",
  khz: "kilohertz",
  hz: "hertz",
  kw: "kilowatt",
  kwh: "kilowattimmar",
  mw: "megawatt",
  cm: "centimeter",
  mm: "millimeter",
  kg: "kilogram",
  g: "gram",
  mg: "milligram",
  l: "liter",
  ml: "milliliter",
  s: "sekund",
  h: "timme",
  min: "minut",
  kilometer: "kilometer",
  meter: "meter",
  centimeter: "centimeter",
  millimeter: "millimeter",
  kilogram: "kilogram",
  gram: "gram",
  liter: "liter",
  sekund: "sekund",
  timme: "timme",
  minut: "minut",
  mol: "mol",
  joule: "joule",
  watt: "watt",
};

/**
 * K20 (Deangelo's reality test: "Erik den fjorton", "Johan den tre"): a king's or queen's number after the name is
 * an ordinal, also when the model wrote it as a digit ("Erik 14") or as a cardinal word ("Erik den fjorton").
 */
const RULERS = String.raw`Erik|Johan|Karl|Gustav|Gustaf|Kristian|Christian|Oscar|Oskar|Fredrik|Adolf Fredrik|Gustav Adolf|Magnus|Håkan|Valdemar|Sten|Sverker|Knut|Kristoffer|Albrekt|Birger|Olof|Ulrika Eleonora|Kristina|Margareta|Louis|Ludvig|Henrik|Henry|Edvard|Edward|Richard|Elizabeth|Elisabet|Filip|Philip|Frederik|Haakon|Olav|Napoleon|Peter|Katarina|Nikolaj|Aleksandr|Alexander|Wilhelm|Vilhelm|Frans|Ferdinand|Leopold|Pius|Johannes Paulus|Benedictus|Innocentius|Gregorius|Urban|Leo`;
const CARD_TO_ORD: Record<string, string> = {
  en: "förste", ett: "förste", två: "andre", tre: "tredje", fyra: "fjärde", fem: "femte", sex: "sjätte", sju: "sjunde",
  åtta: "åttonde", nio: "nionde", tio: "tionde", elva: "elfte", tolv: "tolfte", tretton: "trettonde", fjorton: "fjortonde",
  femton: "femtonde", sexton: "sextonde", sjutton: "sjuttonde", arton: "artonde", nitton: "nittonde", tjugo: "tjugonde",
};
const RULER_DIGIT = new RegExp(String.raw`(?<![\p{L}])(${RULERS}) (den )?([1-9]|1\d|20)(?::e|:a)?(?![\p{L}\d.,:]|\s?(?:år|kr|kronor|procent|%|st|gånger|minuter|timmar|januari|februari|mars|april|maj|juni|juli|augusti|september|oktober|november|december))`, "gu");
// K25 (Oscar O24: "Peter 5 äpplen", "Leo 10 cm", "Filip 8, Ludvig 6" became kings): a bare "Name digit" is a regnal
// number only when the text is about rulers; "Karl den 12" always is
const RULER_CONTEXT = /kung|drottning|regent|monark|påve|kejsar|tsar|krön|regera|tron(?:en|följ|arvinge)?(?![\p{L}])|dynasti|envälde|furste|hertig|riket|stormakt|ätten|huset (?:Vasa|Bernadotte|Habsburg|Tudor|Bourbon|Romanov)/iu;
const RULER_WORD = new RegExp(String.raw`(?<![\p{L}])(${RULERS}) den (en|ett|två|tre|fyra|fem|sex|sju|åtta|nio|tio|elva|tolv|tretton|fjorton|femton|sexton|sjutton|arton|nitton|tjugo)(?![\p{L}])`, "gu");
const RULER_ROMAN_DEN = new RegExp(String.raw`(?<![\p{L}])(${RULERS}) den (XVIII|XVII|XIII|XIV|XVI|XIX|VIII|VII|III|XII|XV|XI|IX|IV|II|VI|XX|V|X|I)(?![\p{L}])`, "gu");
export function rulerNumbers(text: string): string {
  return text
    .replace(RULER_ROMAN_DEN, (m, name: string, r: string) => {
      const n = romanToInt(r);
      return n === null ? m : `${name} den ${regnal(n)}`;
    })
    .replace(RULER_DIGIT, (m, name: string, den: string | undefined, n: string) =>
      den || RULER_CONTEXT.test(text) ? `${name} den ${regnal(Number(n))}` : m);
}

/** After digits became words. */
export function afterNumbers(text: string): string {
  let s = text;
  s = s.replace(RULER_WORD, (_m, name: string, w: string) => `${name} den ${CARD_TO_ORD[w] ?? w}`);
  // "mol" is an en-word ("en mol"), a recurring slip in the model's Swedish
  s = s.replace(/(?<![\p{L}])([Ee])tt mol(?![\p{L}])/gu, (_m, e: string) => `${e}n mol`);
  // K2 (Oscar's D87 review): the commonest gender slips, only article directly before the noun.
  // -ning/-ring/-het/-tion/-molekyl/-metall/-cell/-process/-förklaring are en-words; -system/-block are ett-words.
  s = s.replace(/(?<![\p{L}])([Ee])tt ((?:[\p{L}-]*(?:ning|ring|het|tion|molekyl|metall|process))|[\p{L}]*cell|icke-metall)(?![\p{L}])/gu,
    (_m, e: string, w: string) => `${e}n ${w}`);
  s = s.replace(/(?<![\p{L}])([Ee])n ([\p{L}]*(?:system|block))(?![\p{L}])/gu, (_m, e: string, w: string) => `${e}tt ${w}`);
  // squared / cubed units: "meter²" -> "kvadratmeter"
  s = s.replace(
    /(kilometer|meter|centimeter|millimeter|decimeter)([²³])/g,
    (_m, u: string, p: string) => (p === "²" ? "kvadrat" : "kubik") + u,
  );
  s = s.replace(/²/g, " i kvadrat").replace(/³/g, " i kubik");
  // a/b between units: "km/s" -> "kilometer per sekund"
  s = s.replace(
    /(?<![\p{L}\d/])(km|cm|mm|kg|mg|ml|min|[mglsh]|[\p{L}]{4,})\/(km|cm|mm|kg|mg|ml|min|[mglsh]|[\p{L}]{4,})(?![\p{L}\d/])/gu,
    (m: string, a: string, b: string) =>
      UNIT_SPOKEN[a.toLowerCase()] && UNIT_SPOKEN[b.toLowerCase()]
        ? `${UNIT_SPOKEN[a.toLowerCase()]} per ${UNIT_SPOKEN[b.toLowerCase()]}`
        : m,
  );
  // remaining math symbols
  s = s
    .replace(/\s?≈\s?/g, " är ungefär lika med ")
    .replace(/\s?≠\s?/g, " är inte lika med ")
    .replace(/\s?≤\s?/g, " är mindre än eller lika med ")
    .replace(/\s?≥\s?/g, " är större än eller lika med ")
    .replace(/\s?=\s?/g, " är lika med ")
    .replace(/\s?→\s?/g, " ger ")
    .replace(/\s[×·]\s?|(?<=[\p{L}\d])[×·](?=[\p{L}\d])/gu, " gånger ")
    .replace(/\s÷\s?/g, " delat med ")
    .replace(/\s?±\s?/g, " plus minus ")
    .replace(/(?<=\s|^)\+(?=\s)/g, "plus")
    .replace(/√/g, "roten ur ")
    .replace(/π/g, "pi")
    .replace(/Δ/g, "delta ")
    .replace(/∞/g, "oändligheten");
  return s.replace(/ {2,}/g, " ");
}
