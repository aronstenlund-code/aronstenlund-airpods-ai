/**
 * K15 (Aron 2026-11-09): a practice exam question by question, by voice. The app keeps the parsed tasks and where the
 * student is; this decides, in code, what a spoken utterance means during the run: go to the next or previous task,
 * a task by number ("fråga sju", "uppgift 3b"), skip, repeat, stop, the results, or an answer to grade.
 */
import { numbersToSpeech } from "../answer/svnum.ts";

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

/** The task as Lumen reads it aloud: its number, the text with numbers in words, and the points. */
export function spokenTask(no: string, text: string, points: { E: number; C: number; A: number }): string {
  const total = points.E + points.C + points.A;
  const body = numbersToSpeech(text.replace(/\s*\n\s*/g, ". ").replace(/\[([^\]]+)\]/g, "Bilden visar $1."));
  return `Fråga ${numbersToSpeech(no)}. ${body}${total ? ` Den ger ${total === 1 ? "en" : numbersToSpeech(String(total))} poäng.` : ""}`
    .replace(/\.\s*\./g, ".")
    .replace(/\s+/g, " ")
    .trim();
}
