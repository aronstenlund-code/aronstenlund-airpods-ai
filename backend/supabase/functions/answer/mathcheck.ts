import { wordsToNumber } from "./svnum.ts";
import { type Computed, fmtNumber } from "./calc.ts";

/**
 * K1.3 (Oscar D83, 2026-11-08): "derivatan av x i kvadrat är två gånger" (the x was lost). Math claims that code
 * can check are computed here and handed to the model as <computed>: the derivative of a polynomial and the
 * solution of a linear equation, spoken or written ("derivera tre x i kvadrat plus två x", "lös 3x − 7 = 14",
 * "två x plus nio är lika med tre"). The model only explains them at the student's level. Anything else: null.
 */

/** Spoken Swedish maths to a plain expression: "tre x i kvadrat plus två x" -> "3x^2+2x". */
export function normalizeMath(text: string): string {
  let t = ` ${text.toLowerCase().replace(/−/g, "-").replace(/,(?=\d)/g, ".")} `;
  t = t.replace(/\s+(?:upphöjt|upphöjd|upphöjda)\s+(?:till|med)\s+/g, "^")
    .replace(/\s+i\s+kvadrat\b/g, "^2").replace(/\s+i\s+kubik\b/g, "^3").replace(/²/g, "^2").replace(/³/g, "^3")
    .replace(/\s+är\s+lika\s+med\s+|\s+lika\s+med\s+/g, " = ")
    .replace(/\bplus\b/g, " + ").replace(/\bminus\b/g, " - ").replace(/\bgånger\b|·|\*/g, " ");
  // number words -> digits (longest run of plain words first; operators and "x" are never part of a run)
  const toks = t.replace(/\^/g, " ^ ").replace(/([+=])/g, " $1 ").split(/\s+/).filter(Boolean);
  const word = (w: string) => /^\p{L}+$/u.test(w) && w !== "x";
  const out: string[] = [];
  for (let i = 0; i < toks.length; i++) {
    let done = false;
    for (let end = Math.min(toks.length, i + 4); end > i && word(toks[i]); end--) {
      if (!toks.slice(i, end).every(word)) continue;
      const v = wordsToNumber(toks.slice(i, end).join(" "));
      if (v !== null) {
        out.push(String(v));
        i = end - 1;
        done = true;
        break;
      }
    }
    if (!done) out.push(toks[i]);
  }
  // "x^ 2" / "x ^2" and "3 x" -> "3x"
  return out.join(" ").replace(/\s*\^\s*/g, "^").replace(/(\d)\s+x\b/g, "$1x").replace(/\s+/g, "");
}

interface Term {
  c: number;
  p: number;
}

/** "3x^2+2x-5" -> terms, or null when it is not a polynomial in x. */
export function parsePoly(expr: string): Term[] | null {
  if (!expr || !/^[0-9x+\-^.]+$/.test(expr) || !/[0-9x]/.test(expr)) return null;
  const parts = expr.replace(/-/g, "+-").split("+").filter((s) => s !== "");
  const terms: Term[] = [];
  for (const raw of parts) {
    const m = /^(-?)(\d+(?:\.\d+)?)?(x(?:\^(\d+))?)?$/.exec(raw);
    if (!m || (!m[2] && !m[3])) return null;
    const c = (m[1] ? -1 : 1) * (m[2] ? Number(m[2]) : 1);
    const p = m[3] ? (m[4] ? Number(m[4]) : 1) : 0;
    if (p > 12) return null;
    terms.push({ c, p });
  }
  return terms.length ? terms : null;
}

function combine(terms: Term[]): Term[] {
  const by = new Map<number, number>();
  for (const t of terms) by.set(t.p, (by.get(t.p) ?? 0) + t.c);
  return [...by.entries()].filter(([, c]) => Math.abs(c) > 1e-12).sort((a, b) => b[0] - a[0]).map(([p, c]) => ({ c, p }));
}

/** Terms as text with a Swedish decimal comma: "6x² + 2x − 5". */
export function polyText(terms: Term[]): string {
  const t = combine(terms);
  if (!t.length) return "0";
  const sup: Record<number, string> = { 2: "²", 3: "³" };
  return t.map((x, i) => {
    const abs = Math.abs(x.c);
    const coef = x.p > 0 && abs === 1 ? "" : fmtNumber(abs);
    const pow = x.p === 0 ? "" : x.p === 1 ? "x" : `x${sup[x.p] ?? `^${x.p}`}`;
    const sign = x.c < 0 ? (i === 0 ? "−" : " − ") : i === 0 ? "" : " + ";
    return `${sign}${coef}${pow}`;
  }).join("");
}

export function derivative(terms: Term[]): Term[] {
  return combine(terms.filter((t) => t.p > 0).map((t) => ({ c: t.c * t.p, p: t.p - 1 })));
}

const DERIV = /(?:derivatan|derivata|derivera|deriverar|derivering)(?:\s+(?:av|till|på|för))?\s+(?:funktionen\s+)?(?:f\(x\)|y)?\s*(?:=|är)?\s*(.+?)\s*\??$/iu;
const SOLVE = /^(?:(?:hur\s+)?(?:lös|löser\s+(?:man|jag)|lösa)(?:\s+ekvationen)?\s+|vad\s+är\s+x\s+(?:om|när)\s+|ekvationen\s+)?(.+?)\s*\??$/iu;

/** The derivative or the solution of a linear equation as <computed>, or null. */
export function computeMath(fragment: string): Computed | null {
  const f = fragment.trim();
  if (!f || f.length > 140) return null;
  const d = DERIV.exec(f);
  if (d) {
    const terms = parsePoly(normalizeMath(d[1]));
    if (!terms || !terms.some((t) => t.p > 0)) return null;
    const dt = derivative(terms);
    return { value: NaN, text: `Om f(x) = ${polyText(terms)} så är f′(x) = ${polyText(dt)} (beräknat i kod)` };
  }
  const s = SOLVE.exec(f);
  if (!s) return null;
  const n = normalizeMath(s[1]);
  const sides = n.split("=");
  if (sides.length !== 2 || !n.includes("x")) return null;
  const L = parsePoly(sides[0]), R = parsePoly(sides[1]);
  if (!L || !R || [...L, ...R].some((t) => t.p > 1)) return null;
  const a = [...L.filter((t) => t.p === 1).map((t) => t.c), ...R.filter((t) => t.p === 1).map((t) => -t.c)].reduce((x, y) => x + y, 0);
  const b = [...R.filter((t) => t.p === 0).map((t) => t.c), ...L.filter((t) => t.p === 0).map((t) => -t.c)].reduce((x, y) => x + y, 0);
  if (Math.abs(a) < 1e-12) return null;
  const x = b / a;
  const exact = Math.abs(x * 1e4 - Math.round(x * 1e4)) < 1e-6;
  return {
    value: x,
    text: `${polyText(L)} = ${polyText(R)} ger x = ${fmtNumber(exact ? x : Math.round(x * 1e4) / 1e4)}${exact ? "" : " (avrundat)"} (beräknat i kod)`,
  };
}
