/**
 * K61 (D176): a question's length is the question plus the long answer, in characters sent to ElevenLabs. Three
 * classes with limits from drill_settings (length_normal_max, length_longer_max), as D155: no new code to change them.
 * Nothing is charged yet (D157); the class is stored per question and shown in the app.
 */
export type LengthClass = "normal" | "longer" | "too_long";
export interface LengthLimits { normalMax: number; longerMax: number }
export const DEFAULT_LENGTH_LIMITS: LengthLimits = { normalMax: 800, longerMax: 1600 };

export function lengthClass(chars: number, l: LengthLimits = DEFAULT_LENGTH_LIMITS): LengthClass {
  return chars <= l.normalMax ? "normal" : chars <= l.longerMax ? "longer" : "too_long";
}

export function lengthLimits(settings: Record<string, number> | null | undefined): LengthLimits {
  const n = Number(settings?.length_normal_max), m = Number(settings?.length_longer_max);
  const normalMax = Number.isFinite(n) && n > 0 ? n : DEFAULT_LENGTH_LIMITS.normalMax;
  const longerMax = Number.isFinite(m) && m > normalMax ? m : Math.max(normalMax, DEFAULT_LENGTH_LIMITS.longerMax);
  return { normalMax, longerMax };
}

/** K61 (D177): the same question in /help try and in /drill save (case, spaces and punctuation do not matter). */
export function questionKey(q: string): string {
  return q.toLowerCase().normalize("NFC").replace(/[^\p{L}\p{N}]+/gu, " ").trim().slice(0, 300);
}
