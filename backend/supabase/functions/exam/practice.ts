/**
 * K15 (Aron 2026-11-09): a practice exam question by question, by voice. The app keeps the parsed tasks and where the
 * student is; this decides, in code, what a spoken utterance means during the run: go to the next or previous task,
 * a task by number ("fråga sju", "uppgift 3b"), skip, repeat, stop, the results, or an answer to grade.
 */
import { numbersToSpeech } from "../answer/svnum.ts";
import { spelledFormula } from "../drill/voicerules.ts";

export type NavAction = "next" | "prev" | "goto" | "skip" | "repeat" | "stop" | "results" | "answer";
export interface Nav {
  action: NavAction;
  /** index in the task list (0-based) for next, prev, goto, skip and repeat */
  index?: number;
}

const WORD_NUM: Record<string, number> = {
  ett: 1, en: 1, etta: 1, två: 2, tvåan: 2, tre: 3, trean: 3, fyra: 4, fyran: 4, fem: 5, femman: 5, sex: 6, sexan: 6,
  sju: 7, sjuan: 7, åtta: 8, åttan: 8, nio: 9, nian: 9, tio: 10, tian: 10, elva: 11, elvan: 11, tolv: 12, tolvan: 12,
  tretton: 13, fjorton: 14, femton: 15, sexton: 16, sjutton: 17, arton: 18, nitton: 19, tjugo: 20, tjugoett: 21,
  tjugoen: 21, tjugotvå: 22, tjugotre: 23, tjugofyra: 24, tjugofem: 25,
};

const norm = (t: string) =>
  t.toLowerCase().replace(/[^\p{L}\p{N}\s]/gu, " ").replace(/\s+/g, " ").trim()
    .replace(/^(?:(?:okej|ok|hej|nej|men) )?(?:lumen )?(?:(?:kan|kunde) (?:du|vi) |snälla |vi tar |ta |gå till |jag vill (?:ha|ta|göra) )*/u, "")
    .replace(/ (?:tack|nu|snälla|då)$/u, "")
    .trim();

/** The task number the student said: "7", "sju", "3b", "tre b", "fråga sjuan". */
function spokenNo(t: string): string | null {
  const m = /^(?:fråga|uppgift|uppgiften|nummer|nr|frågan|del) (?:nummer )?([\p{L}\p{N}]+)(?: ([a-f]))?$/u.exec(t);
  if (!m) return null;
  const base = /^\d{1,2}$/.test(m[1]) ? m[1] : /^\d{1,2}[a-f]$/.test(m[1]) ? m[1] : WORD_NUM[m[1]]?.toString();
  if (!base) return null;
  return (base + (m[2] ?? "")).toLowerCase();
}

export function practiceNav(utterance: string, current: number, nos: string[]): Nav {
  const t = norm(utterance);
  const n = nos.length;
  const clamp = (i: number) => Math.max(0, Math.min(n - 1, i));
  if (/^(?:nästa(?: fråga| uppgift)?|nästa tack|vidare|gå vidare|fortsätt|nästa då)$/u.test(t)) return { action: "next", index: clamp(current + 1) };
  if (/^(?:förra(?: fråga| uppgift(?:en)?)?|föregående(?: fråga)?|tillbaka|gå tillbaka|backa|den förra)$/u.test(t)) {
    return { action: "prev", index: clamp(current - 1) };
  }
  if (/^(?:hoppa över(?: den(?: här)?| den här frågan| frågan)?|skippa(?: den)?|jag hoppar över den|vet inte hoppa över|pass)$/u.test(t)) {
    return { action: "skip", index: clamp(current + 1) };
  }
  if (/^(?:upprepa(?: frågan)?|säg (?:den |frågan )?igen|en gång till|vad var frågan|läs (?:upp )?(?:den |frågan )?igen|repetera)$/u.test(t)) {
    return { action: "repeat", index: clamp(current) };
  }
  if (/^(?:sluta|avsluta(?: provet| övningsprovet)?|stopp|jag är klar|vi slutar|det räcker)$/u.test(t)) return { action: "stop" };
  if (/^(?:hur (?:gick|går) det|resultat(?:et)?|hur många (?:rätt|poäng)|vad fick jag)$/u.test(t)) return { action: "results" };
  const no = spokenNo(t);
  if (no) {
    const i = nos.findIndex((x) => x.toLowerCase() === no);
    if (i >= 0) return { action: "goto", index: i };
    const j = nos.findIndex((x) => x.toLowerCase().replace(/[a-f]$/, "") === no); // "fråga 3" = the first of 3a, 3b
    if (j >= 0) return { action: "goto", index: j };
  }
  return { action: "answer" };
}

/** O107 F3 (Oscar): formulas, symbols and abbreviations in a task said as words ("3x + 5 = 20" -> "3 x plus 5 är lika med 20"). */
const SUBSCRIPT = "₀₁₂₃₄₅₆₇₈₉";
export function mathWords(t: string, en: boolean): string {
  const w = en
    ? { plus: "plus", minus: "minus", times: "times", div: "divided by", eq: "equals", sq: "squared", cube: "cubed", root: "the square root of" }
    : { plus: "plus", minus: "minus", times: "gånger", div: "delat med", eq: "är lika med", sq: "i kvadrat", cube: "i kub", root: "roten ur" };
  return t
    // a chemical formula with subscripts (H₂SO₄): read as written, as O105-3
    .replace(/(?<![\p{L}])(?:[A-Z][a-z]?[₀-₉]*){1,6}(?![\p{L}])/gu, (m) => /[₀-₉]/.test(m) ? spelledFormula(m.replace(/[₀-₉]/g, (d) => String(SUBSCRIPT.indexOf(d))), en ? "en" : "sv") : m)
    .replace(/√\s*/g, ` ${w.root} `)
    .replace(/([\p{L}\d)])²/gu, `$1 ${w.sq}`)
    .replace(/([\p{L}\d)])³/gu, `$1 ${w.cube}`)
    .replace(/(\d)([a-zA-Z])(?![\p{L}])/gu, "$1 $2") // "3x" -> "3 x" (not "trex")
    .replace(/\s*[·×*]\s*/g, ` ${w.times} `)
    .replace(/\s*÷\s*/g, ` ${w.div} `)
    .replace(/\s+\+\s+/g, ` ${w.plus} `)
    .replace(/\s+[−-]\s+/g, ` ${w.minus} `)
    .replace(/\s*=\s*/g, ` ${w.eq} `)
    .replace(/(?<![\p{L}])milj\./giu, en ? "million" : "miljoner")
    .replace(/(?<![\p{L}])mdr\./giu, "miljarder")
    .replace(/(?<![\p{L}])t\.\s?ex\./giu, "till exempel")
    .replace(/(?<![\p{L}])bl\.\s?a\./giu, "bland annat");
}

/** O107 F2: the language of an exam's task texts (short imperatives: "Name the gas …", "Förklara varför …"). */
const TASK_EN = new Set("the and is of to in that it for with are as this which or an be name explain describe why what how write which give list calculate solve show find compare use who when where does do your".split(" "));
const TASK_SV = new Set("och att det är som en ett på av för med den till inte har när där eller nämn förklara beskriv varför vad hur skriv vilken vilket vilka ge räkna beräkna lös visa jämför använd vem var gör din ditt".split(" "));
export function taskLanguage(text: string): "sv" | "en" {
  let en = 0, sv = (text.match(/[åäö]/gi) ?? []).length / 3;
  for (const x of text.toLowerCase().match(/\p{L}+/gu) ?? []) {
    if (TASK_EN.has(x)) en++;
    if (TASK_SV.has(x)) sv++;
  }
  return en >= 2 && en > sv * 1.5 ? "en" : "sv";
}

const EN_NUM = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve"];
/** The task as Lumen reads it aloud: its number, the text with numbers in words, and the points (O107: per level). */
export function spokenTask(no: string, text: string, points: { E: number; C: number; A: number }, lang?: "sv" | "en"): string {
  const total = points.E + points.C + points.A;
  // O107 F2 (Oscar): an English exam gets an English frame (the English voice reads the digits itself); the caller
  // decides for the whole exam (a short task alone is too short to tell)
  const en = (lang ?? taskLanguage(text)) === "en";
  const n = (k: number) => en ? (EN_NUM[k] ?? String(k)) : k === 1 ? "en" : numbersToSpeech(String(k));
  const said = mathWords(text.replace(/\s*\n\s*/g, ". "), en).replace(/\[([^\]]+)\]/g, (_m, inner: string) =>
    // a table or a figure with its own name is said as it is; anything else is what the picture shows
    /^\s*(?:tabell|table|figur|figure|diagram|graf|graph|karta|map)\b/iu.test(inner) ? `${inner.trim()}.` : en ? `The picture shows ${inner}.` : `Bilden visar ${inner}.`);
  let body = (en ? said : numbersToSpeech(said)).replace(/\s+/g, " ").trim();
  if (body && !/[.!?]$/.test(body)) body += ".";
  const levels = (["E", "C", "A"] as const).filter((l) => points[l] > 0);
  const split = levels.length > 1
    ? `, ${levels.map((l) => `${n(points[l])} ${l}${en ? " point" + (points[l] > 1 ? "s" : "") : "-poäng"}`).join(en ? " and " : " och ").replace(/ and (?=.* and )/, ", ").replace(/ och (?=.* och )/, ", ")}`
    : "";
  const pts = total
    ? en ? ` It gives ${n(total)} point${total === 1 ? "" : "s"}${split}.` : ` Den ger ${n(total)} poäng${split}.`
    : "";
  return `${en ? "Question" : "Fråga"} ${en ? (EN_NUM[Number(no)] ?? no) : numbersToSpeech(no)}. ${body}${pts}`
    .replace(/\.\s*\./g, ".")
    .replace(/\s+/g, " ")
    .trim();
}
