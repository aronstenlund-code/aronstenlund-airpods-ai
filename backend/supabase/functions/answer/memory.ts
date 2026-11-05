/**
 * D49: explicit memory. Only an explicit "kom ihåg ..." creates a memory (never inferred). The fact is
 * returned as `memory_add` in `done`; the app stores it on the device and sends all memories back as
 * `memories` (<= 30 x 200 chars) which the prompt treats as facts about the user.
 */
export const MEMORY_MAX_CHARS = 200;

const CMD =
  /^\s*(?:kan du |vill du |snälla |kom igen och )?(?:kom ihåg|minns att|glöm inte att|lägg på minnet)\s*(?:att\b|:)?\s*(.{3,})$/iu;

/** The fact to remember, or null when the fragment is not a "remember this" command. */
export function detectMemoryAdd(fragment: string): string | null {
  const m = CMD.exec(fragment.trim());
  if (!m) return null;
  let fact = m[1].trim().replace(/^["“«]+|["”»]+$/g, "").replace(/^att\s+/i, "").trim();
  fact = fact.replace(/[<>]/g, " ").replace(/\s+/g, " ");
  if (fact.length < 3 || /^(?:du|ni)\s/i.test(fact)) return null; // "minns du ..." is a question
  return fact.slice(0, MEMORY_MAX_CHARS);
}

export const MEMORY_ACK = { sv: "Okej, det kommer jag ihåg.", en: "Okay, I will remember that." };
export const MEMORY_SUMMARY = "Användaren bad om att få ett minne sparat.";
