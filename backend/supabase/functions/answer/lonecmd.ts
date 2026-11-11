/**
 * K42.5 (Aron's phone test 18:58, again after K40/A62: "jaha" was heard as "utveckla" and gave a developed answer):
 * a lone command word right after an answer, without "Lumen", is carried out only when Scribe was sure of it and the
 * utterance took at least as long as the word takes to say; otherwise silence. The app sends `stt_confidence` and
 * `utterance_ms` (A74); without them nothing changes.
 */
export const LONE_SURE = 0.85;
const VOWELS = /[aeiouyåäö]/giu;

/** About 120 ms per syllable, at least 250 ms: "utveckla" 360 ms, "jaha" (2) 250 ms. */
export function minSpokenMs(text: string): number {
  return Math.max(250, (text.match(VOWELS)?.length ?? 1) * 120);
}

/** O51: "utveckla det", "berätta mer", "säg mer" are command words too (detectContinuation only knows bare forms). */
export const MORE_START = /^(?:och\s+)?(?:utveckla|fortsätt|berätta mer|säg mer|mer|förklara mer|mera)(?:\s+(?:det|då|tack|om det))?\s*[?.!]?\s*$/iu;

export function isLoneCommandWord(fragment: string): boolean {
  const t = fragment.trim().replace(/[?.!,]+$/u, "");
  if (/^(?:hej\s+)?(?:lumen|earmind)\b/iu.test(t)) return false;
  return t.split(/\s+/).length <= 3 && t.length > 0;
}

/** True when a lone command word should be ignored (said quietly, short or unsure). */
export function weakLoneCommand(fragment: string, ctx: { stt_confidence?: number; utterance_ms?: number; recent_qa: unknown[] }): boolean {
  if (!ctx.recent_qa.length || !isLoneCommandWord(fragment)) return false;
  if (ctx.stt_confidence !== undefined && ctx.stt_confidence < LONE_SURE) return true;
  if (ctx.utterance_ms !== undefined && ctx.utterance_ms < minSpokenMs(fragment)) return true;
  return false;
}
