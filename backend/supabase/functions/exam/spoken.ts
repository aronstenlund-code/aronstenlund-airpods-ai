import { wordsToNumber } from "../answer/svnum.ts";

/**
 * K1.1 (Oscar 2026-11-08): the student answers out loud, so the final answer is read like speech:
 * "sexton komma fem" = 16,5, "en halv" = 0,5, "tre fjärdedelar" = 0,75, "två och en halv" = 2,5; the answer is
 * the number after the LAST "så" / "blir" / "är" / "=" / "lika med" that has one ("3x = 21 så x är sju" = 7);
 * "x är sju", "7 = x" and "x = 7" all give 7; a coefficient ("3x") is never the answer.
 */
const DENOM: Record<string, number> = {
  halv: 2, halva: 2, halvor: 2, tredjedel: 3, tredjedelar: 3, fjärdedel: 4, fjärdedelar: 4, femtedel: 5, femtedelar: 5,
  sjättedel: 6, sjättedelar: 6, åttondel: 8, åttondelar: 8, tiondel: 10, tiondelar: 10, hundradel: 100, hundradelar: 100,
};
const DIGIT: Record<string, string> = { noll: "0", ett: "1", en: "1", två: "2", tre: "3", fyra: "4", fem: "5", sex: "6", sju: "7", åtta: "8", nio: "9" };

const MARKERS = new Set(["så", "blir", "är", "=", "lika", "svar", "svaret", "alltså", "dvs"]);

interface Num {
  value: number;
  at: number; // token index where it ends
}

/** All numbers in a text, in order, from digits or Swedish words. */
export function spokenNumbers(text: string): { nums: Num[]; tokens: string[] } {
  const t = text.toLowerCase().replace(/−/g, "-").replace(/(\d)\s(?=\d{3}\b)/g, "$1").replace(/(\d),(\d)/g, "$1.$2")
    .replace(/=/g, " = ").replace(/([+*/^])/g, " $1 ").replace(/(\d)\s*-\s*(\d)/g, "$1 - $2");
  const tokens = t.split(/\s+/).filter(Boolean).map((w) => w.replace(/^[^\p{L}\p{N}=+\-*/^.]+|[^\p{L}\p{N}=+\-*/^.%]+$/gu, ""));
  const nums: Num[] = [];
  for (let i = 0; i < tokens.length; i++) {
    const w = tokens[i];
    if (!w) continue;
    // digits; a coefficient glued to a letter ("3x") is not a number
    const d = /^-?\d+(?:\.\d+)?%?$/.exec(w);
    if (d) {
      nums.push({ value: Number(w.replace("%", "")), at: i });
      continue;
    }
    // Swedish number words: the longest run (up to 5 words), then "komma <digits>", "och en halv", "<n> <fraction>"
    let best: { v: number; end: number } | null = null;
    for (let end = Math.min(tokens.length, i + 5); end > i; end--) {
      if (tokens[end - 1] === "och") continue; // "två och en halv": "och" belongs to the fraction
      const v = wordsToNumber(tokens.slice(i, end).join(" "));
      if (v !== null) {
        best = { v, end };
        break;
      }
    }
    if (!best) {
      if (w in DENOM && (tokens[i - 1] === "en" || tokens[i - 1] === "ett")) continue; // handled with its numerator
      continue;
    }
    let value = best.v;
    let j = best.end;
    if (tokens[j] === "komma") {
      const ds: string[] = [];
      let k = j + 1;
      while (k < tokens.length && tokens[k] in DIGIT && ds.length < 4) ds.push(DIGIT[tokens[k++]]);
      if (!ds.length && k < tokens.length) {
        const v2 = wordsToNumber(tokens[k]);
        if (v2 !== null) {
          ds.push(String(v2));
          k++;
        }
      }
      if (ds.length) {
        value = Number(`${value}.${ds.join("")}`);
        j = k;
      }
    } else if (tokens[j] in DENOM) {
      value = value / DENOM[tokens[j]]; // "tre fjärdedelar", "en halv"
      j++;
    } else if (tokens[j] === "och" && (tokens[j + 1] === "en" || tokens[j + 1] === "ett") && tokens[j + 2] in DENOM) {
      value = value + 1 / DENOM[tokens[j + 2]]; // "två och en halv"
      j += 3;
    }
    // "x blir minus tre": a spoken minus right before the number (not "fem minus två", which is a calculation)
    if (tokens[i - 1] === "minus" && (i < 2 || MARKERS.has(tokens[i - 2]) || tokens[i - 2] === "=")) value = -value;
    nums.push({ value, at: j - 1 });
    i = j - 1;
  }
  return { nums, tokens };
}


/** The student's final number, or null. */
export function finalNumber(text: string): number | null {
  const { nums, tokens } = spokenNumbers(text);
  if (!nums.length) return null;
  let lastMarker = -1;
  tokens.forEach((w, i) => {
    if (MARKERS.has(w)) lastMarker = i;
  });
  const after = nums.filter((n) => n.at > lastMarker);
  // "7 = x": nothing after the last marker but a letter: the number before it
  return (after.length ? after[after.length - 1] : nums[nums.length - 1]).value;
}

/** Is the answer only a number (with an optional unit or "x ="), no method shown? */
export function isBareNumber(text: string): boolean {
  const { nums, tokens } = spokenNumbers(text);
  if (nums.length !== 1) return false;
  const rest = tokens.filter((w) => w && !/^-?\d/.test(w) && !/^(det|blir|är|svaret|svar|x|y|=|kr|kronor|cm|m|ungefär|cirka|typ|jag|tror|fick|får)$/.test(w));
  // number words themselves are not "method"
  return rest.every((w) => wordsToNumber(w) !== null || w === "komma" || w in DENOM || w === "och" || w === "en" || w === "ett");
}
