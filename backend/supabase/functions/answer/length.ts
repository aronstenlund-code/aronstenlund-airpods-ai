export type AnswerType = "fact" | "study";
export type LengthPref = "short" | "adaptive" | "long";
export type Continuation = "more" | "simpler";

// Unicode-aware word boundaries (JS \b does not treat å/ä/ö as letters).
const B = "(?<![\\p{L}\\p{N}])";
const E = "(?![\\p{L}\\p{N}])";
const re = (alts: string) => new RegExp(`${B}(?:${alts})${E}`, "iu");

/** Intent words that mean "I want to understand this topic" rather than "give me one value". */
const STUDY_CUES = re(
  [
    "för- och nackdelar",
    "för och nackdelar",
    "fördelar",
    "nackdelar",
    "för och emot",
    "pros?\\s*(?:and|och|&)?\\s*cons?",
    "procons?",
    "pros",
    "cons",
    "pro och contra",
    "argument(?:en)?",
    "förklara",
    "förklaring(?:en)?",
    "beskriv(?:a)?",
    "berätta (?:om|mer om)",
    "redogör",
    "diskutera",
    "analysera",
    "sammanfatta",
    "sammanfattning(?:en)?",
    "varför",
    "hur fungerar",
    "hur funkar",
    "hur går det till",
    "hur uppstår",
    "hur bildas",
    "hur påverkar",
    "jämför(?:a)?",
    "jämförelse(?:n)?",
    "skillnad(?:en)? mellan",
    "likheter",
    "orsak(?:er|erna)?",
    "följd(?:er|erna)?",
    "konsekvens(?:er|erna)?",
    "bakgrund(?:en)?",
    "vad ledde till",
    "vad hände",
    "betydelse(?:n)?",
  ].join("|"),
);

const CONTINUE_MORE =
  /^\s*(?:och\s+)?(?:mer|mera|fortsätt|fortsätta|berätta mer|säg mer|utveckla|utförligare|mer detaljer|och sen|och sedan)\s*[?.!]?\s*$/iu;
const CONTINUE_SIMPLER =
  /^\s*(?:kan du |kan någon |kan ni )?(?:förklara (?:det )?(?:enklare|igen|annorlunda|på ett enklare sätt)|enklare|säg det enklare|på ett enklare sätt|förenkla)(?: (?:tack|igen))?\s*[?.!]?\s*$/iu;

/** 'mer' / 'fortsätt' / 'förklara enklare' continue the previous answer (only meaningful with history). */
export function detectContinuation(fragment: string): Continuation | null {
  const f = fragment.trim();
  if (CONTINUE_SIMPLER.test(f)) return "simpler";
  if (CONTINUE_MORE.test(f)) return "more";
  return null;
}

/**
 * Fact (1-2 sentences) vs study (developed spoken answer). Decided in code, before the LLM call, so the
 * right prompt and token budget are chosen with zero added latency.
 * - length "short" -> always fact; "long" -> always study; "adaptive" -> intent words decide.
 * - A continuation request is always study-sized ("mer" must be able to say more).
 */
export function classifyAnswerType(
  fragment: string,
  length: LengthPref,
  continuation: Continuation | null,
  opts: { tutor?: boolean; commands?: boolean } = {},
): AnswerType {
  // Tutor mode (D36) is always the pedagogical study style; a matched personal command (D37)
  // asks for a developed answer too. 'short' only wins for commands/continuations, not for tutor.
  if (opts.tutor) return "study";
  if (length === "short") return "fact";
  if (continuation || opts.commands || length === "long") return "study";
  return STUDY_CUES.test(fragment) ? "study" : "fact";
}
