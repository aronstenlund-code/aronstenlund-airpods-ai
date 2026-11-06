/**
 * Swedish number words, in code (D46). The model writes DIGITS (it is bad at spelling numbers and years
 * out and at doing so without self-corrections); this module turns them into speakable Swedish before
 * the text reaches the client / TTS. Also parses Swedish number words back to numbers (calc.ts).
 */

const UNITS = [
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
  "tretton",
  "fjorton",
  "femton",
  "sexton",
  "sjutton",
  "arton",
  "nitton",
];
const TENS = [
  "",
  "",
  "tjugo",
  "trettio",
  "fyrtio",
  "femtio",
  "sextio",
  "sjuttio",
  "åttio",
  "nittio",
];

export type Gender = "en" | "ett";

function below100(n: number, g: Gender): string {
  if (n < 20) return n === 1 ? g : UNITS[n];
  const t = Math.floor(n / 10), u = n % 10;
  return TENS[t] + (u ? (u === 1 ? g : UNITS[u]) : "");
}

function below1000(n: number, g: Gender): string {
  const h = Math.floor(n / 100), r = n % 100;
  const hs = h === 0 ? "" : (h === 1 ? "hundra" : UNITS[h] + "hundra");
  return hs + (r ? below100(r, g) : "");
}

/** Cardinal number as Swedish words (closed compounds below a thousand, spaces between big groups). */
export function cardinal(n: number, g: Gender = "ett"): string {
  if (!Number.isFinite(n) || n < 0 || n >= 1e15 || !Number.isInteger(n)) return String(n);
  if (n === 0) return "noll";
  const parts: string[] = [];
  const groups: [number, string, string][] = [
    [1e12, "biljon", "biljoner"],
    [1e9, "miljard", "miljarder"],
    [1e6, "miljon", "miljoner"],
  ];
  let rest = n;
  for (const [size, one, many] of groups) {
    const q = Math.floor(rest / size);
    if (q > 0) {
      parts.push(`${cardinal(q, "en")} ${q === 1 ? one : many}`);
      rest -= q * size;
    }
  }
  const th = Math.floor(rest / 1000);
  if (th > 0) {
    parts.push(th === 1 ? "tusen" : below1000(th, "ett") + "tusen");
    rest -= th * 1000;
  }
  if (rest > 0) parts.push(below1000(rest, g));
  return parts.join(" ");
}

/** 1100-1999 read as hundreds ("sjuttonhundraåttionio"), everything else as a cardinal. */
export function yearOrCardinal(n: number, g: Gender = "ett"): string {
  if (Number.isInteger(n) && n >= 1100 && n <= 1999) {
    const r = n % 100;
    return below100(Math.floor(n / 100), "ett") + "hundra" + (r ? below100(r, "ett") : "");
  }
  return cardinal(n, g);
}

const MONTHS = [
  "januari",
  "februari",
  "mars",
  "april",
  "maj",
  "juni",
  "juli",
  "augusti",
  "september",
  "oktober",
  "november",
  "december",
];
const ORDINALS: Record<number, string> = {
  1: "första",
  2: "andra",
  3: "tredje",
  4: "fjärde",
  5: "femte",
  6: "sjätte",
  7: "sjunde",
  8: "åttonde",
  9: "nionde",
  10: "tionde",
  11: "elfte",
  12: "tolfte",
  13: "trettonde",
  14: "fjortonde",
  15: "femtonde",
  16: "sextonde",
  17: "sjuttonde",
  18: "artonde",
  19: "nittonde",
  20: "tjugonde",
  30: "trettionde",
};
export function ordinal(n: number): string {
  if (ORDINALS[n]) return ORDINALS[n];
  if (n >= 100 && n % 100 !== 0) {
    // 106 -> "hundrasjätte", 121 -> "hundratjugoförsta": the last two digits are the ordinal part
    return cardinal(n - (n % 100)).replace(/ /g, "") + ordinal(n % 100);
  }
  if (n > 20 && n < 100 && n % 10 !== 0) return cardinal(n - (n % 10)) + ORDINALS[n % 10];
  return cardinal(n) + (n % 10 === 0 && n < 100 ? "nde" : "de");
}

// Units written after a number. `one` is used for exactly 1, `many` otherwise; `g` is the gender of the
// noun (matters for "en"/"ett").
const UNIT_WORDS: Record<string, { one: string; many: string; g: Gender }> = {
  "%": { one: "procent", many: "procent", g: "en" },
  GHz: { one: "gigahertz", many: "gigahertz", g: "ett" },
  MHz: { one: "megahertz", many: "megahertz", g: "ett" },
  kHz: { one: "kilohertz", many: "kilohertz", g: "ett" },
  Hz: { one: "hertz", many: "hertz", g: "ett" },
  kWh: { one: "kilowattimme", many: "kilowattimmar", g: "en" },
  kW: { one: "kilowatt", many: "kilowatt", g: "ett" },
  MW: { one: "megawatt", many: "megawatt", g: "ett" },
  "°C": { one: "grad celsius", many: "grader celsius", g: "en" },
  "°F": { one: "grad fahrenheit", many: "grader fahrenheit", g: "en" },
  "°": { one: "grad", many: "grader", g: "en" },
  "km/h": { one: "kilometer i timmen", many: "kilometer i timmen", g: "en" },
  "m/s": { one: "meter per sekund", many: "meter per sekund", g: "en" },
  ml: { one: "milliliter", many: "milliliter", g: "en" },
  cl: { one: "centiliter", many: "centiliter", g: "en" },
  dl: { one: "deciliter", many: "deciliter", g: "en" },
  l: { one: "liter", many: "liter", g: "en" },
  mg: { one: "milligram", many: "milligram", g: "ett" },
  g: { one: "gram", many: "gram", g: "ett" },
  kg: { one: "kilogram", many: "kilogram", g: "ett" },
  mm: { one: "millimeter", many: "millimeter", g: "en" },
  cm: { one: "centimeter", many: "centimeter", g: "en" },
  m: { one: "meter", many: "meter", g: "en" },
  km: { one: "kilometer", many: "kilometer", g: "en" },
  kr: { one: "krona", many: "kronor", g: "en" },
  min: { one: "minut", many: "minuter", g: "en" },
  st: { one: "stycke", many: "stycken", g: "ett" },
};

// Nouns that take "en" (the model writes "1 liter", "21 personer"); everything else defaults to "ett".
const EN_NOUNS = new Set(
  (
    "liter deciliter centiliter milliliter meter centimeter millimeter kilometer mil minut timme sekund krona " +
    "procent gång person dag vecka månad kopp tesked matsked kvart halvtimme natt kväll morgon sida bit " +
    "personer gånger minuter timmar sekunder dagar veckor månader kronor koppar skedar bitar sidor mil mol"
  ).split(" "),
);

function readDecimals(d: string): string {
  return d.split("").map((c) => UNITS[Number(c)]).join(" ");
}

/** Converts all numbers, years, percentages, units and times in `text` to Swedish words. */
export function numbersToSpeech(text: string): string {
  if (!/\d/.test(text)) return text;
  let s = text;
  // thousands separators: "1 500", "12 500 000" (nbsp / thin space always, plain space only for 1-3 digit lead)
  s = s.replace(
    /(?<![\d.,])(\d{1,3})((?:[\u00a0\u202f ]\d{3})+)(?![\d])/g,
    (_m, a: string, b: string) => a + b.replace(/[\u00a0\u202f ]/g, ""),
  );
  // decades / centuries: "1800-talet" -> "artonhundratalet", "90-talet" -> "nittiotalet"
  s = s.replace(
    /(?<![\p{L}\d])(\d{2,4})-?tal(et|ets|en|s)?(?![\p{L}])/gu,
    (_m, n: string, suf: string | undefined) => {
      const v = Number(n);
      const w = v >= 1100 && v <= 1999 ? yearOrCardinal(v) : cardinal(v);
      return w.replace(/ /g, "") + "tal" + (suf ?? "");
    },
  );
  // ISO dates 2026-11-04 -> "den fjärde november tvåtusen tjugosex"
  s = s.replace(
    /(?<![\d-])(\d{4})-(\d{2})-(\d{2})(?![\d-])/g,
    (m: string, y: string, mo: string, d: string) => {
      const mi = Number(mo) - 1, di = Number(d);
      return mi < 0 || mi > 11 || di < 1 || di > 31
        ? m
        : `den ${ordinal(di)} ${MONTHS[mi]} ${yearOrCardinal(Number(y))}`;
    },
  );
  // clock times 14:30
  s = s.replace(/(?<![\d:])([01]?\d|2[0-3]):([0-5]\d)(?![\d:])/g, (_m, h: string, m: string) => {
    const mm = Number(m);
    return cardinal(Number(h)) +
      (mm === 0 ? "" : mm < 10 ? " noll " + cardinal(mm) : " och " + cardinal(mm));
  });
  // ordinals 1:a 2:a 3:e ...
  s = s.replace(/(?<![\d])(\d{1,4}):(?:a|e)(?![\p{L}\d])/gu, (_m, n: string) => ordinal(Number(n)));
  // ranges 5-10 / 5–10 (not dates 2026-11-04)
  s = s.replace(/(?<![\d-])(\d+(?:[.,]\d+)?)\s*[–-]\s*(\d+(?:[.,]\d+)?)(?![\d-])/g, "$1 till $2");
  // negative numbers
  s = s.replace(/(?<![\p{L}\d)])-(?=\d)/gu, "minus ");
  const re =
    /(?<![\p{L}\d.,])(\d+)(?:[.,](\d+))?(?:\s*(%|°C|°F|°|km\/h|m\/s)|\s?(GHz|MHz|kHz|Hz|kWh|kW|MW|ml|cl|dl|kg|mg|cm|mm|km|kr|min|st|l|g|m)(?![\p{L}\d]))?/gu;
  s = s.replace(
    re,
    (
      m: string,
      int: string,
      dec: string | undefined,
      u1: string | undefined,
      u2: string | undefined,
      off: number,
      whole: string,
    ) => {
      const unitKey = u1 ?? u2;
      const unit = unitKey ? UNIT_WORDS[unitKey] : undefined;
      const next = /^\s+(\p{L}+)/u.exec(whole.slice(off + m.length))?.[1]?.toLowerCase();
      const n = Number(int);
      if (!Number.isSafeInteger(n) || n >= 1e15) return m;
      const gender: Gender = unit ? unit.g : next && EN_NOUNS.has(next) ? "en" : "ett";
      let words: string;
      if (dec !== undefined) words = yearOrCardinal(n, "ett") + " komma " + readDecimals(dec);
      else words = yearOrCardinal(n, gender);
      if (unit) {
        const one = dec === undefined && n === 1;
        words += " " + (one ? unit.one : unit.many);
      }
      return words;
    },
  );
  return s;
}

// ---------- words -> number (for calc.ts) ----------

const UNIT_VALUES: Record<string, number> = {
  noll: 0,
  en: 1,
  ett: 1,
  två: 2,
  tre: 3,
  fyra: 4,
  fem: 5,
  sex: 6,
  sju: 7,
  åtta: 8,
  nio: 9,
  tio: 10,
  elva: 11,
  tolv: 12,
  tretton: 13,
  fjorton: 14,
  femton: 15,
  sexton: 16,
  sjutton: 17,
  arton: 18,
  nitton: 19,
};
const TENS_VALUES: Record<string, number> = {
  tjugo: 20,
  trettio: 30,
  fyrtio: 40,
  femtio: 50,
  sextio: 60,
  sjuttio: 70,
  åttio: 80,
  nittio: 90,
};

function parseBelow100(s: string): number | null {
  if (s === "") return 0;
  if (s in UNIT_VALUES) return UNIT_VALUES[s];
  for (const [t, v] of Object.entries(TENS_VALUES)) {
    if (s === t) return v;
    if (s.startsWith(t)) {
      const u = UNIT_VALUES[s.slice(t.length)];
      if (u !== undefined && u >= 1 && u <= 9) return v + u;
    }
  }
  return null;
}

function parseBelow1000(s: string): number | null {
  const i = s.indexOf("hundra");
  if (i === -1) return parseBelow100(s);
  const head = s.slice(0, i);
  const h = head === "" ? 1 : UNIT_VALUES[head];
  if (h === undefined || h < 1 || h > 9) return null;
  const r = parseBelow100(s.slice(i + 6));
  return r === null ? null : h * 100 + r;
}

function parseWhole(s: string): number | null {
  for (
    const [word, size] of [["miljard", 1e9], ["miljon", 1e6], ["tusen", 1000]] as [string, number][]
  ) {
    const m = new RegExp(`^(.*?)${word}(?:er)?(.*)$`).exec(s);
    if (m) {
      const head = m[1] === "" || m[1] === "et" ? 1 : (parseWhole(m[1]) ?? NaN);
      const tail = m[2] === "" ? 0 : (parseWhole(m[2]) ?? NaN);
      const v = head * size + tail;
      return Number.isFinite(v) ? v : null;
    }
  }
  return parseBelow1000(s);
}

/** "tjugofem" / "tre tusen femhundra" / "hundra" -> number; null when the words are not a number. */
export function wordsToNumber(words: string): number | null {
  const s = words.toLowerCase().replace(/\boch\b/g, " ").replace(/[\s-]+/g, "");
  if (!s) return null;
  return parseWhole(s);
}
