import { sentences } from "../exam/read.ts";

/**
 * K70 (D185): a text drill's part (heading or paragraph) as the voice reads it. Each sentence is voiced on its own and
 * joined with a space, so the spoken text has exactly as many sentences as the displayed one, and the character where
 * each spoken sentence ends is known (the sentence times come from ElevenLabs' character times, as D145).
 */
export const TEXT_LIMITS = { parts: 150, part: 1500, heading: 300, chars: 40_000 };

export function voicedPart(
  text: string,
  kind: "heading" | "para",
  voice: (s: string) => string,
): { spoken: string; display: string[]; ends: number[] } {
  const display = kind === "heading" ? [text.replace(/\s+/g, " ").trim()] : sentences(text);
  let spoken = "";
  const ends: number[] = [];
  const shown: string[] = [];
  for (const s of display) {
    let v = voice(s);
    if (!v) continue;
    // a heading is said as a sentence of its own (a short pause after it)
    if (kind === "heading" && !/[.!?…]$/.test(v)) v += ".";
    spoken = spoken ? `${spoken} ${v}` : v;
    ends.push(spoken.length);
    shown.push(s);
  }
  return { spoken, display: shown, ends };
}

/** [[start_ms, end_ms], ...] per sentence, from the character times and the characters where sentences end. */
export function sentenceTimes(starts: number[], ends: number[], sentenceEnds: number[] | null | undefined): number[][] | null {
  if (!sentenceEnds?.length || !ends.length) return null;
  const out: number[][] = [];
  let from = 0;
  for (const e of sentenceEnds) {
    const a = starts[Math.min(from, starts.length - 1)], b = ends[Math.min(e, ends.length) - 1];
    out.push([Math.round((Number.isFinite(a) ? a : 0) * 1000), Math.round((Number.isFinite(b) ? b : 0) * 1000)]);
    from = e + 1; // the space between sentences
  }
  return out;
}
