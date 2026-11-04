import { wordsToNumber } from "./svnum.ts";

/**
 * D46: plain arithmetic, percentages and unit conversions are computed here, never by the LLM
 * ("mental maths" is where the model made errors). The result is handed to the model as `<computed>`
 * data that it only has to phrase. Returns null for anything that is not clearly one of these.
 */

export interface Computed {
  /** Human/LLM readable line, digits, Swedish decimal comma: "17 × 24 = 408". */
  text: string;
  value: number;
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
  let s = input.toLowerCase().trim().replace(/[?=!.]+$/g, "").trim().replace(PREFIX, "");
  s = s
    .replace(/\bupphöjt till\b|\bupphöjd till\b|\bin the power of\b/g, " ^ ")
    .replace(/\bi kvadrat\b|\bupphöjt till två\b|\bsquared\b/g, " ² ")
    .replace(/\bi kubik\b|\bcubed\b/g, " ³ ")
    .replace(/\b(?:kvadratroten|roten) (?:ur|av)\b|\bsquare root of\b|√/g, " √ ")
    .replace(/\bmultiplicerat med\b|\bgånger\b|\btimes\b|\bmultiplied by\b|[×*·]/g, " * ")
    .replace(/\bdividerat med\b|\bdelat med\b|\bdelat på\b|\bdivided by\b|[÷/:]/g, " / ")
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
  return { value: v, text: `${fmtNumber(a)} % av ${fmtNumber(b)} = ${fmtNumber(v)}` };
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

export function computeFragment(fragment: string): Computed | null {
  const f = fragment.trim();
  if (!f || f.length > 120) return null;
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
  return {
    value: r.value,
    text: `${r.text} = ${fmtNumber(r.value)}${exact ? "" : " (avrundat till fyra decimaler)"}`,
  };
}
