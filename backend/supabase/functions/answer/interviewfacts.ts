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
// word boundaries that also work for å ä ö (JS \b is ASCII only)
const B = String.raw`(?<![\p{L}\d])`, E = String.raw`(?![\p{L}\d])`;
const rx = (src: string) => new RegExp(src.replaceAll("<", B).replaceAll(">", E), "iu");
const AGE_WORD = String.raw`(?:\d{2}|sjutton|arton|nitton|tjugo\p{L}*|trettio\p{L}*)`;
const TOPICS: Topic[] = [
  { topic: "körkort", q: rx(String.raw`körkort|<kör(?:a)? bil>|<har du (?:egen )?bil>`), known: rx(String.raw`körkort|b-kort|<bil>`) },
  {
    topic: "ålder",
    q: rx(String.raw`hur gammal|din ålder|(?:när|vilket år) är du född|<är du (?:över |under )?${AGE_WORD}>|<fyllt ${AGE_WORD}>|<myndig>`),
    known: rx(String.raw`<\d{2} år>|<född>|ålder\s*:?\s*\d`),
  },
  {
    topic: "alkohol",
    // K8 (Oscar O7 I07): only a question about the user's own experience, never a situation question ("hur skulle
    // du hantera en full kund som vill köpa alkohol" is about how you work, and the answer must say "neka")
    q: rx(String.raw`<har du (?:jobbat|arbetat|erfarenhet|vana)(?: [\p{L}]+){0,3} (?:alkohol|sprit|öl|vin|bar|servering|bartender)|<dricker du>|serveringstillstånd|<har du (?:jobbat|arbetat) (?:i|på) (?:en )?bar>|<är du van vid (?:att )?(?:sälja|servera) (?:alkohol|öl|vin)`),
    known: rx(String.raw`alkohol|<sprit>|<öl>|<vin>|bartender|<bar>|serveringstillstånd|<krog|restaurang`),
  },
  {
    // eval 2026-11-11 (cv-04, ad only): "har du jobbat med kassa förut" -> "Jag har inte jobbat med kassa tidigare"
    topic: "arbetserfarenhet",
    q: rx(String.raw`<har du (?:jobbat|arbetat|extrajobbat|sommarjobbat)>|<vad har du för (?:arbets)?erfarenhet>|<har du (?:någon )?(?:tidigare )?(?:arbets)?erfarenhet>|<har du haft (?:något|ett) (?:jobb|extrajobb|sommarjobb)>`),
    known: rx(String.raw`<arbete\s*:|<erfarenhet\s*:|<extrajobb|<sommarjobb|<jobbat>|<arbetat>|<jobbar>|<arbetar>|<praktik|<anställ|<ideell|<ledare>|<tränare>|<barnvakt`),
  },
  {
    topic: "pendling",
    q: rx(String.raw`pendla|<tar? (?:du )?dig (?:hit|till (?:jobbet|arbetet))|<resa (?:hit|till (?:jobbet|arbetet))|<bor du (?:nära|långt)|hur långt bor|<hur kommer du (?:hit|till)`),
    known: rx(String.raw`pendl|<bor (?:i|på|nära)>|kollektivtrafik|<cykel|<bil>|körkort`),
  },
];

/** The CV part of persona_setup ("Jobbannons: … CV: …"): the ad is the job, never the user's facts. */
function userFacts(setup: string): string {
  const m = /\bCV\s*:/iu.exec(setup);
  // live eval intervju-06: without a CV the app sends the job ad alone, with no prefix (InterviewProfile.swift), so
  // "Extrajobb som vårdbiträde" is the job, never the user's own experience
  if (!m) return "";
  return setup.slice(m.index);
}

/** The missing topic the interviewer asks about, or null. */
export function missingFact(question: string, setup: string, memories: string[] = []): string | null {
  const known = `${userFacts(setup)}\n${memories.join("\n")}`;
  for (const t of TOPICS) if (t.q.test(question) && !t.known.test(known)) return t.topic;
  return null;
}

/** A sentence that still claims something about the missing topic, anywhere in the answer. */
const CLAIM: Record<string, RegExp> = {
  körkort: rx(String.raw`körkort|<kör (?:bil|själv)>|<egen bil>`),
  ålder: rx(String.raw`<(?:jag är|jag har fyllt|jag fyllde|jag fyller)\s+(?:över\s+|under\s+)?${AGE_WORD}>|<år gammal>|<min ålder>`),
  // K8: a claim of own experience, not a sentence that only names the word ("jag kontrollerar legitimation")
  alkohol: rx(String.raw`<jag har (?:jobbat|arbetat|sålt|serverat|hållit på)(?: [\p{L}]+){0,2} (?:med |i |på )?(?:alkohol|sprit|öl|vin|bar)|<jag dricker>|<jag har serveringstillstånd>|<jag är van vid (?:att )?(?:sälja|servera)`),
  arbetserfarenhet: rx(String.raw`<jag har (?:inte |aldrig |redan )?(?:jobbat|arbetat|extrajobbat|sommarjobbat)>|<jag har (?:ingen|någon|lite|mycket) (?:tidigare )?(?:arbets)?erfarenhet>|<när jag (?:jobbade|arbetade)>|<på mitt (?:förra|tidigare|senaste|nuvarande) (?:jobb|arbete)>`),
  pendling: rx(String.raw`<jag bor>|<bor (?:i|på|nära)>|kollektivtrafik|<buss(?:en)?>|<tåg(?:et)?>|<cykl|<med bil>|<pendla`),
};
export function claimsMissing(topic: string, sentence: string): boolean {
  return CLAIM[topic]?.test(sentence) ?? false;
}

export function missingFactNote(topic: string): string {
  return `The interviewer asks about ${topic}, which the CV and <memories> do not mention. Never answer ja or nej, never "det har jag inte", "jag har inte", "jag är … år" or any other claim about ${topic} either way (also not where you live or how you travel), and never say that it is missing: answer in first person with what the CV does show that matters for the question (reliability, how you work, relevant experience, what you look forward to in the role). The first sentence stands on its own: never open with "Det är just den …", "Det är precis det …" or "Det har lärt mig …" pointing at something you did not say.`;
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
