import { cardinal, wordsToNumber } from "./svnum.ts";
import { dateCalc } from "./datecalc.ts";
import { zoneClock } from "./timezone.ts";

/**
 * D46: plain arithmetic, percentages and unit conversions are computed here, never by the LLM
 * ("mental maths" is where the model made errors). The result is handed to the model as `<computed>`
 * data that it only has to phrase. Returns null for anything that is not clearly one of these.
 */

export interface Computed {
  /** Human/LLM readable line, digits, Swedish decimal comma: "17 × 24 = 408". */
  text: string;
  value: number;
  /**
   * History fix (2026-11-08, "270 gånger 270" was said as 7 900): arithmetic and percentages are not only
   * computed but also SPOKEN by code (`spokenComputed`), no model call; the model never phrases numbers it
   * could get wrong. Unit conversions, dates and zone clocks keep the model (kind undefined).
   */
  kind?: "arith" | "percent" | "clock";
  /** The spoken expression with digits ("270 gånger 270"), set for arith / percent. */
  said?: string;
  /** A single binary operation (for the step-by-step line in Provläge). */
  binary?: { a: number; op: string; b: number };
  /** clock: hours and minutes of a bare "HH:MM". */
  clock?: { h: number; m: number };
}

export function fmtNumber(x: number): string {
  if (!Number.isFinite(x)) return String(x);
  if (Number.isInteger(x)) return String(x);
  let s = Math.abs(x) >= 1e6 ? x.toPrecision(10) : x.toFixed(4);
  if (s.includes(".")) s = s.replace(/0+$/, "").replace(/\.$/, "");
  return s.replace(".", ",");
}

const NUM_DIGITS = /^-?\d+(?:[.,]\d+)?$/;
function parseNum(tokens: string[]): number | null {
  const joined = tokens.join(" ").trim();
  if (!joined) return null;
  if (tokens.length === 1 && NUM_DIGITS.test(joined)) return Number(joined.replace(",", "."));
  if (/\d/.test(joined)) return null;
  const w = joined.toLowerCase();
  const dm = /^(.+?) komma (.+)$/.exec(w);
  if (dm) {
    const a = wordsToNumber(dm[1]);
    const digits = dm[2].split(/\s+/).map((x) => wordsToNumber(x));
    if (a === null || digits.some((d) => d === null || d > 9)) return null;
    return Number(`${a}.${digits.join("")}`);
  }
  return wordsToNumber(w);
}

const PREFIX =
  /^(?:vad är|vad blir|hur mycket är|hur mycket blir|räkna ut|beräkna|vad är svaret på|vad är resultatet av|what is|calculate)\s+/i;

type Tok = { t: "num"; v: number } | { t: "op"; v: string } | { t: "fn"; v: string };

function tokenize(input: string): Tok[] | null {
  if (/\b\d{1,2}:\d{2}\b/.test(input)) return null; // "20:20" is a clock time, not 20 ÷ 20
  let s = input.toLowerCase().trim().replace(/[?=!.]+$/g, "").trim().replace(PREFIX, "");
  s = s
    .replace(/\bupphöjt till\b|\bupphöjd till\b|\bin the power of\b/g, " ^ ")
    .replace(/\bi kvadrat\b|\bupphöjt till två\b|\bsquared\b/g, " ² ")
    .replace(/\bi kubik\b|\bcubed\b/g, " ³ ")
    .replace(/\b(?:kvadratroten|roten) (?:ur|av)\b|\bsquare root of\b|√/g, " √ ")
    .replace(/\bmultiplicerat med\b|\bgånger\b|\btimes\b|\bmultiplied by\b|[×*·]/g, " * ")
    .replace(/\bdividerat med\b|\bdelat med\b|\bdelat på\b|\bgenom\b|\bdivided by\b|[÷/:]/g, " / ")
    .replace(/\bplus\b|\+/g, " + ")
    .replace(/\bminus\b|\bsubtraherat med\b|(?<=[\d\p{L}])\s*[−–-]\s*(?=[\d\p{L}])/gu, " - ")
    .replace(/\s+x\s+/g, " * ")
    .replace(/[()]/g, " ");
  const parts = s.split(/\s+/).filter(Boolean);
  const toks: Tok[] = [];
  let numWords: string[] = [];
  const flush = (): boolean => {
    if (!numWords.length) return true;
    const v = parseNum(numWords);
    numWords = [];
    if (v === null) return false;
    toks.push({ t: "num", v });
    return true;
  };
  for (const p of parts) {
    if (["+", "-", "*", "/", "^"].includes(p)) {
      if (!flush()) return null;
      toks.push({ t: "op", v: p });
    } else if (p === "²" || p === "³") {
      if (!flush()) return null;
      toks.push({ t: "fn", v: p });
    } else if (p === "√") {
      if (!flush()) return null;
      toks.push({ t: "fn", v: "√" });
    } else numWords.push(p);
  }
  if (!flush()) return null;
  return toks;
}

function evaluate(toks: Tok[]): { value: number; text: string } | null {
  // Pass 1: unary sqrt + postfix power; build a flat list of numbers and binary operators.
  const items: (number | string)[] = [];
  const shown: string[] = [];
  for (let i = 0; i < toks.length; i++) {
    const k = toks[i];
    if (k.t === "fn" && k.v === "√") {
      const n = toks[i + 1];
      if (!n || n.t !== "num" || n.v < 0) return null;
      items.push(Math.sqrt(n.v));
      shown.push(`√${fmtNumber(n.v)}`);
      i++;
    } else if (k.t === "fn") {
      const prev = items[items.length - 1];
      if (typeof prev !== "number") return null;
      const p = k.v === "²" ? 2 : 3;
      items[items.length - 1] = prev ** p;
      shown[shown.length - 1] = `${shown[shown.length - 1]}${k.v}`;
    } else if (k.t === "num") {
      items.push(k.v);
      shown.push(fmtNumber(k.v));
    } else {
      items.push(k.v);
      shown.push(k.v === "*" ? "×" : k.v === "/" ? "÷" : k.v);
    }
  }
  // alternate number / operator
  if (items.length < 1 || items.length % 2 === 0) return null;
  for (let i = 0; i < items.length; i++) {
    if ((i % 2 === 0) !== (typeof items[i] === "number")) return null;
  }
  if (items.length === 1 && toks.length === 1) return null; // a lone number is not a calculation
  // Pass 2: ^ then * / then + -
  const apply = (ops: string[]) => {
    for (let i = 1; i < items.length - 1;) {
      if (ops.includes(items[i] as string)) {
        const a = items[i - 1] as number, b = items[i + 1] as number, op = items[i] as string;
        const r = op === "^"
          ? a ** b
          : op === "*"
          ? a * b
          : op === "/"
          ? a / b
          : op === "+"
          ? a + b
          : a - b;
        items.splice(i - 1, 3, r);
      } else i += 2;
    }
  };
  apply(["^"]);
  apply(["*", "/"]);
  apply(["+", "-"]);
  const value = items[0] as number;
  if (typeof value !== "number" || !Number.isFinite(value)) return null;
  return { value, text: shown.join(" ") };
}

// ---------- percentages ----------
const PCT =
  /^(?:vad är |hur mycket är |räkna ut |beräkna )?(.+?)\s*(?:procent|%)\s+av\s+(.+?)[?.!]*$/i;
function percent(input: string): Computed | null {
  const m = PCT.exec(input.trim());
  if (!m) return null;
  const a = parseNum(m[1].trim().split(/\s+/)), b = parseNum(m[2].trim().split(/\s+/));
  if (a === null || b === null) return null;
  const v = (a * b) / 100;
  return {
    value: v,
    text: `${fmtNumber(a)} % av ${fmtNumber(b)} = ${fmtNumber(v)}`,
    kind: "percent",
    said: `${fmtNumber(a)} procent av ${fmtNumber(b)}`,
  };
}

// ---------- clock times ----------
const CLOCK =
  /^(?:hej|okej|du)?[,!]?\s*(?:vad är|vad betyder|vilken tid är|hur mycket är|vad är klockan)?\s*(?:klockan\s+)?([01]?\d|2[0-3])[:.]([0-5]\d)\s*[?.!]*$/i;
function clockTime(input: string): Computed | null {
  const m = CLOCK.exec(input.trim());
  if (!m || !/[:]/.test(input) && !/klockan/i.test(input)) return null;
  const h = Number(m[1]), mm = Number(m[2]);
  return {
    value: h * 60 + mm,
    text: `${m[1]}:${m[2]} = klockan ${h}:${m[2]} (24-timmarsklocka)`,
    kind: "clock",
    clock: { h, m: mm },
  };
}

// ---------- unit conversions ----------
type Dim = "volume" | "mass" | "length" | "time" | "speed";
const UNITS: Record<string, { dim: Dim; f: number; name: string }> = {
  liter: { dim: "volume", f: 1, name: "liter" },
  l: { dim: "volume", f: 1, name: "liter" },
  deciliter: { dim: "volume", f: 0.1, name: "deciliter" },
  dl: { dim: "volume", f: 0.1, name: "deciliter" },
  centiliter: { dim: "volume", f: 0.01, name: "centiliter" },
  cl: { dim: "volume", f: 0.01, name: "centiliter" },
  milliliter: { dim: "volume", f: 0.001, name: "milliliter" },
  ml: { dim: "volume", f: 0.001, name: "milliliter" },
  kilo: { dim: "mass", f: 1000, name: "kilogram" },
  kilogram: { dim: "mass", f: 1000, name: "kilogram" },
  kg: { dim: "mass", f: 1000, name: "kilogram" },
  hekto: { dim: "mass", f: 100, name: "hekto" },
  gram: { dim: "mass", f: 1, name: "gram" },
  g: { dim: "mass", f: 1, name: "gram" },
  milligram: { dim: "mass", f: 0.001, name: "milligram" },
  mg: { dim: "mass", f: 0.001, name: "milligram" },
  kilometer: { dim: "length", f: 1000, name: "kilometer" },
  km: { dim: "length", f: 1000, name: "kilometer" },
  mil: { dim: "length", f: 10000, name: "mil" },
  meter: { dim: "length", f: 1, name: "meter" },
  m: { dim: "length", f: 1, name: "meter" },
  centimeter: { dim: "length", f: 0.01, name: "centimeter" },
  cm: { dim: "length", f: 0.01, name: "centimeter" },
  millimeter: { dim: "length", f: 0.001, name: "millimeter" },
  mm: { dim: "length", f: 0.001, name: "millimeter" },
  timme: { dim: "time", f: 3600, name: "timmar" },
  timmar: { dim: "time", f: 3600, name: "timmar" },
  h: { dim: "time", f: 3600, name: "timmar" },
  minut: { dim: "time", f: 60, name: "minuter" },
  minuter: { dim: "time", f: 60, name: "minuter" },
  min: { dim: "time", f: 60, name: "minuter" },
  sekund: { dim: "time", f: 1, name: "sekunder" },
  sekunder: { dim: "time", f: 1, name: "sekunder" },
  s: { dim: "time", f: 1, name: "sekunder" },
  dygn: { dim: "time", f: 86400, name: "dygn" },
  // imperial units (D65, for follow-ups such as "och i fot")
  fot: { dim: "length", f: 0.3048, name: "fot" },
  fötter: { dim: "length", f: 0.3048, name: "fot" },
  feet: { dim: "length", f: 0.3048, name: "fot" },
  ft: { dim: "length", f: 0.3048, name: "fot" },
  tum: { dim: "length", f: 0.0254, name: "tum" },
  inch: { dim: "length", f: 0.0254, name: "tum" },
  inches: { dim: "length", f: 0.0254, name: "tum" },
  yard: { dim: "length", f: 0.9144, name: "yard" },
  yards: { dim: "length", f: 0.9144, name: "yard" },
  mile: { dim: "length", f: 1609.344, name: "engelska mil" },
  miles: { dim: "length", f: 1609.344, name: "engelska mil" },
  pund: { dim: "mass", f: 453.59237, name: "pund" },
  lb: { dim: "mass", f: 453.59237, name: "pund" },
  lbs: { dim: "mass", f: 453.59237, name: "pund" },
  uns: { dim: "mass", f: 28.349523, name: "uns" },
  ounce: { dim: "mass", f: 28.349523, name: "uns" },
  oz: { dim: "mass", f: 28.349523, name: "uns" },
};
const CONV =
  /^(?:vad är |hur många |hur mycket är |omvandla |konvertera |räkna om )*([\d.,]+|[a-zåäö ]+?)\s*(\p{L}+)\s+(?:i|till|to|in|är hur många|blir)\s+(\p{L}+)[?.!]*$/iu;
function convert(input: string): Computed | null {
  const t = input.trim().toLowerCase();
  // temperature
  const tm =
    /^(?:vad är |omvandla |konvertera )?(-?\d+(?:[.,]\d+)?)\s*(?:°\s*)?(c|f|celsius|fahrenheit|grader celsius|grader fahrenheit)\s+(?:i|till|to|in)\s+(c|f|celsius|fahrenheit)[?.!]*$/
      .exec(t);
  if (tm) {
    const v = Number(tm[1].replace(",", ".")),
      from = tm[2][0] === "c" || tm[2].endsWith("celsius") ? "c" : "f";
    const to = tm[3][0];
    if (from === to) return null;
    const r = from === "c" ? v * 9 / 5 + 32 : (v - 32) * 5 / 9;
    return {
      value: r,
      text: `${fmtNumber(v)} °${from.toUpperCase()} = ${fmtNumber(r)} °${to.toUpperCase()}`,
    };
  }
  let m = CONV.exec(t);
  let qa: string, qf: string, qt: string;
  if (m) [qa, qf, qt] = [m[1], m[2], m[3]];
  else {
    // "hur många gram är 2 kg"
    m =
      /^hur många (\p{L}+) (?:är|går det på|finns det i|blir) ([\d.,]+|[a-zåäö ]+?)\s*(\p{L}+)[?.!]*$/iu
        .exec(t);
    if (!m) return null;
    [qt, qa, qf] = [m[1], m[2], m[3]];
  }
  const a = parseNum(qa.trim().split(/\s+/));
  const from = UNITS[qf], to = UNITS[qt];
  if (a === null || !from || !to || from.dim !== to.dim) return null;
  const v = (a * from.f) / to.f;
  return { value: v, text: `${fmtNumber(a)} ${from.name} = ${fmtNumber(v)} ${to.name}` };
}

const FOLLOW_UNIT =
  /^(?:och |men |då |så )?(?:hur mycket är det |vad är det |hur många )?(?:i|till|på|som)?\s*(\p{L}+)\??$/u;

/**
 * D65: "och i fot" after an answer that stated a length/mass/temperature: the value comes from the previous
 * ANSWER (spoken numbers or digits), the conversion is done here. Returns null when the fragment is not a bare
 * unit or the previous answer holds no quantity of the same kind.
 */
export function computeFollowUp(fragment: string, lastAnswer: string | undefined): Computed | null {
  if (!lastAnswer) return null;
  const f = fragment.trim().toLowerCase().replace(/[?!.]+$/g, "");
  if (f.split(/\s+/).length > 6) return null;
  const m = FOLLOW_UNIT.exec(f);
  const key = m?.[1];
  if (!key) return null;
  const tokens = lastAnswer.toLowerCase().replace(/[.,;:!?()"]/g, " ").split(/\s+/).filter(Boolean);
  // temperature: "tjugo grader celsius" -> fahrenheit and back
  if (["fahrenheit", "celsius"].includes(key)) {
    for (let i = 0; i < tokens.length; i++) {
      if (tokens[i] !== (key === "fahrenheit" ? "celsius" : "fahrenheit")) continue;
      for (let len = 6; len >= 1; len--) {
        const nums = tokens.slice(Math.max(0, i - len - 1), i).filter((t) =>
          t !== "grader" && t !== "grad"
        );
        const v = nums.length ? parseNum(nums.slice(-len)) : null;
        if (v !== null) {
          const r = key === "fahrenheit" ? v * 9 / 5 + 32 : (v - 32) * 5 / 9;
          return {
            value: r,
            text: `${fmtNumber(v)} °${key === "fahrenheit" ? "C" : "F"} = ${fmtNumber(r)} °${
              key === "fahrenheit" ? "F" : "C"
            }`,
          };
        }
      }
    }
    return null;
  }
  const to = UNITS[key];
  if (!to) return null;
  for (let i = 0; i < tokens.length; i++) {
    const from = UNITS[tokens[i]];
    if (!from || from.dim !== to.dim || from.name === to.name) continue;
    for (let len = 5; len >= 1; len--) {
      if (i - len < 0) continue;
      const v = parseNum(tokens.slice(i - len, i));
      if (v !== null) {
        const r = (v * from.f) / to.f;
        return { value: r, text: `${fmtNumber(v)} ${from.name} = ${fmtNumber(r)} ${to.name}` };
      }
    }
  }
  return null;
}

export function computeFragment(fragment: string, now: Date = new Date()): Computed | null {
  const f = fragment.trim();
  if (!f || f.length > 120) return null;
  const k = clockTime(f);
  if (k) return k;
  const z = zoneClock(f, now) ?? dateCalc(f, now);
  if (z) return z;
  const p = percent(f);
  if (p) return p;
  const c = convert(f);
  if (c) return c;
  const toks = tokenize(f);
  if (!toks || !toks.length) return null;
  const r = evaluate(toks);
  if (!r) return null;
  const exact = Number.isInteger(r.value) ||
    Math.abs(r.value * 1e4 - Math.round(r.value * 1e4)) < 1e-6;
  const said = r.text.replace(/×/g, "gånger").replace(/÷/g, "delat med").replace(/\^/g, "upphöjt till")
    .replace(/²/g, " i kvadrat").replace(/³/g, " i kubik").replace(/√/g, "roten ur ").replace(/(?<=\s)-(?=\s)/g, "minus")
    .replace(/\+/g, "plus").replace(/\s+/g, " ").trim();
  const binary = toks.length === 3 && toks[0].t === "num" && toks[1].t === "op" && toks[2].t === "num"
    ? { a: toks[0].v, op: toks[1].v, b: toks[2].v }
    : undefined;
  return {
    value: r.value,
    text: `${r.text} = ${fmtNumber(r.value)}${exact ? "" : " (avrundat till fyra decimaler)"}`,
    kind: "arith",
    said,
    binary,
  };
}

/** Digits with a space every three (Swedish), so the speech step reads "72 900" as one number. */
function grouped(x: number): string {
  const t = fmtNumber(x);
  const [i, d] = t.split(",");
  const neg = i.startsWith("-");
  const g = (neg ? i.slice(1) : i).replace(/\B(?=(\d{3})+(?!\d))/g, " ");
  return (neg ? "-" : "") + g + (d ? "," + d : "");
}

const HOUR_WORD = (h: number) => cardinal(h % 12 === 0 ? 12 : h % 12);
function dayPart(h: number): string {
  return h < 5 ? "på natten" : h < 10 ? "på morgonen" : h < 12 ? "på förmiddagen" : h < 18
    ? "på eftermiddagen"
    : "på kvällen";
}
function twelveHour(h: number, m: number): string {
  const next = (h + 1) % 24;
  const part = dayPart(m > 30 ? next : h);
  if (m === 0) return `${HOUR_WORD(h)} ${part}`;
  if (m === 15) return `kvart över ${HOUR_WORD(h)} ${part}`;
  if (m === 30) return `halv ${HOUR_WORD(next)} ${part}`;
  if (m === 45) return `kvart i ${HOUR_WORD(next)} ${part}`;
  if (m < 30) return `${cardinal(m)} över ${HOUR_WORD(h)} ${part}`;
  return `${cardinal(60 - m)} i ${HOUR_WORD(next)} ${part}`;
}

/**
 * The complete spoken answer for arithmetic, percentages and a bare clock time (digits are turned into words
 * by the normal speech step). Provläge also gets the steps of a multiplication, all computed here.
 * null = let the model phrase it (conversions, dates).
 */
export function spokenComputed(c: Computed, tutor = false): string | null {
  if (c.kind === "clock" && c.clock) {
    const { h, m } = c.clock;
    const twentyFour = m === 0 ? `klockan ${cardinal(h)}` : `klockan ${cardinal(h)} och ${cardinal(m)}`;
    return `${twentyFour.charAt(0).toUpperCase()}${twentyFour.slice(1)} är ${twelveHour(h, m)}.`;
  }
  if ((c.kind !== "arith" && c.kind !== "percent") || !c.said) return null;
  const exact = Number.isInteger(c.value) || Math.abs(c.value * 1e4 - Math.round(c.value * 1e4)) < 1e-6;
  const said = c.said.replace(/-?\d+(?:,\d+)?/g, (d) => grouped(Number(d.replace(",", "."))));
  const v = exact ? c.value : Math.round(c.value * 100) / 100; // spoken: two decimals are enough
  const head = `${said.charAt(0).toUpperCase()}${said.slice(1)} är ${exact ? "" : "ungefär "}${grouped(v)}.`;
  const bin = c.binary;
  if (!tutor || !bin || bin.op !== "*" || !Number.isInteger(bin.a) || !Number.isInteger(bin.b)) return head;
  const [a, b] = Math.abs(bin.a) >= Math.abs(bin.b) ? [bin.a, bin.b] : [bin.b, bin.a];
  if (Math.abs(b) < 11 || Math.abs(a) < 11) return head;
  const mag = 10 ** Math.floor(Math.log10(Math.abs(b)));
  const hi = Math.trunc(b / mag) * mag, lo = b - hi;
  if (lo === 0) return head;
  const p1 = a * hi, p2 = a * lo;
  return `${head} Räkna ${grouped(a)} gånger ${grouped(hi)}, som är ${grouped(p1)}, och ${grouped(a)} gånger ${
    grouped(lo)
  }, som är ${grouped(p2)}. Tillsammans blir det ${grouped(p1 + p2)}.`;
}
