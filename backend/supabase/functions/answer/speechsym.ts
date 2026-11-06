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

const ABBREVIATIONS: [RegExp, string][] = [
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
  [/(?<![\p{L}])ev\.(?=\s)/gu, "eventuellt"],
  [/(?<![\p{L}])resp\.?(?=\s)/gu, "respektive"],
];

/** Before digits become words. */
export function beforeNumbers(text: string): string {
  // subscript digits (C₁₂H₂₂O₁₁) -> plain digits, so the formula rules see them
  let s = text.replace(/[\u2080-\u2089]/g, (c) => String(c.charCodeAt(0) - 0x2080));
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

/** After digits became words. */
export function afterNumbers(text: string): string {
  let s = text;
  // "mol" is an en-word ("en mol"), a recurring slip in the model's Swedish
  s = s.replace(/(?<![\p{L}])([Ee])tt mol(?![\p{L}])/gu, (_m, e: string) => `${e}n mol`);
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
