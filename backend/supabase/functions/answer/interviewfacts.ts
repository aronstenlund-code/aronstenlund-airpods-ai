/**
 * K1.5 (Oscar D81-D84, 2026-11-08): the mock interview answered yes or no about facts the CV does not give
 * ("har du körkort" -> "Det har jag inte", "har du jobbat med alkohol" -> "Ja …", "hur gammal är du" -> "Jag är
 * tjugo år", from the ad's age limit). Code spots such a question when the CV (and the user's memories) say nothing
 * about the topic; the model then gets a note, and a yes/no opening is never spoken.
 */
interface Topic {
  topic: string;
  q: RegExp;
  known: RegExp;
}
const TOPICS: Topic[] = [
  { topic: "körkort", q: /körkort|\bkör(?:a)? bil\b|\bhar du (?:egen )?bil\b/iu, known: /körkort|b-kort|\bbil\b/iu },
  {
    topic: "ålder",
    q: /hur gammal|din ålder|(?:när|vilket år) är du född|\bär du (?:över |under )?\d{2}\b|fyllt \d{2}|\bmyndig\b/iu,
    known: /\b\d{2} år\b|\bfödd\b|ålder\s*:?\s*\d/iu,
  },
  {
    topic: "alkohol",
    q: /alkohol|\bsprit\b|\böl\b|\bvin\b|drinkar|bartender|serveringstillstånd/iu,
    known: /alkohol|\bsprit\b|\böl\b|\bvin\b|bartender|\bbar\b|serveringstillstånd|krog|restaurang/iu,
  },
  {
    topic: "pendling",
    q: /pendla|tar? (?:du )?dig (?:hit|till (?:jobbet|arbetet))|resa (?:hit|till (?:jobbet|arbetet))|bor du (?:nära|långt)|hur långt bor|hur kommer du (?:hit|till)/iu,
    known: /pendl|\bbor (?:i|på|nära)\b|kollektivtrafik|\bcykel\b|\bbil\b|körkort/iu,
  },
];

/** The CV part of persona_setup ("Jobbannons: … CV: …"): the ad is the job, never the user's facts. */
function userFacts(setup: string): string {
  const m = /\bCV\s*:/iu.exec(setup);
  if (!m) return /jobbannons\s*:/iu.test(setup) ? "" : setup;
  return setup.slice(m.index);
}

/** The missing topic the interviewer asks about, or null. */
export function missingFact(question: string, setup: string, memories: string[] = []): string | null {
  const known = `${userFacts(setup)}\n${memories.join("\n")}`;
  for (const t of TOPICS) if (t.q.test(question) && !t.known.test(known)) return t.topic;
  return null;
}

export function missingFactNote(topic: string): string {
  return `The interviewer asks about ${topic}, which the CV and <memories> do not mention. Never answer ja or nej, never "det har jag inte", "jag har inte", "jag är … år" or any other claim about ${topic} either way, and never say that it is missing: answer in first person with what the CV does show that matters for the question (reliability, how you work, relevant experience, what you look forward to in the role).`;
}

/** A yes/no or has/lacks opening about the missing fact (only the first sentence is checked). */
const YES_NO_LEAD =
  /^(?:ja|nej|japp|absolut|självklart|jo|det har jag(?: inte)?|det gör jag(?: inte)?|det är jag(?: inte)?|jag har (?:inte|inget|ingen)|jag har (?:b-)?körkort|jag har jobbat med alkohol|jag är (?:\d{2}|sjutton|arton|nitton|tjugo\p{L}*|trettio\p{L}*) år)\b[^.!?]*[.!?]?\s*/iu;
export function stripYesNoLead(sentence: string): string {
  const t = sentence.trimStart();
  const m = YES_NO_LEAD.exec(t);
  if (!m) return sentence;
  // "Ja, och det jag tar med mig är …": keep what follows a comma after a bare ja/nej
  const bare = /^(?:ja|nej|jo|japp|absolut|självklart)\s*[,!]\s*(?:och\s+|men\s+)?(.+)$/isu.exec(t);
  if (bare && !/^(?:det (?:har|gör|är) jag|jag har|jag är)\b/iu.test(bare[1])) return bare[1].charAt(0).toUpperCase() + bare[1].slice(1);
  return "";
}
