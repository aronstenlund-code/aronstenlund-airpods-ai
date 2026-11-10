/**
 * K9 (A7 level 2): spoken "Lumen, …" instructions -> a `task`, by a rule table of expression families, with no extra
 * model call. The app sends a level-2 instruction as the fragment (its first default phrase, or the user's own
 * words); a whole utterance that matches a family becomes `<task>` plus that task's rule in the user message (the
 * cached system prompt is unchanged). What does not match is answered as before, and with `voice_instruction: true`
 * it is passed to the model as a free instruction in <commands>.
 *
 * Matching is on the WHOLE utterance after normalisation (lower case, no punctuation, "lumen" and polite wrappers
 * removed), so the words inside an ordinary sentence ("ge ett exempel på en reaktion") never trigger a task.
 */

export type Scope = "study" | "interview" | "social";

export interface CommandTask {
  /** e.g. "example", "quiz_topic", "interview_help:better", "social:funnier", "rizz:flirty", "alternatives:3" */
  task: string;
  /** The free argument (quiz_topic: the topic). */
  arg?: string;
  /** The rule sent to the model with the task (English, like the rest of the prompt). */
  rule: string;
}

interface Family {
  task: string;
  scope: Scope;
  re: RegExp;
  rule: string;
}

const WRAP_START =
  /^(?:(?:hej|okej|ok|du)\s+)?(?:lumen\s+)?(?:(?:kan|kunde|skulle) (?:du|ni)(?: snälla)? |snälla |jag vill (?:att du |ha )?|vill du |kom igen |nu )?/u;
const WRAP_END = /\s+(?:tack|snälla|nu|igen|är du snäll)$/u;
/** K12 (O9 #1): "för mig" is only a polite ending when the utterance does not match with it ("hur går det för mig"). */
const FOR_ME_END = /\s+för mig$/u;

/** Lower case, no punctuation, no "Lumen" and no polite wrapper: the form the families are written for. */
export function normalizeCommand(text: string): string {
  let t = text.toLowerCase().replace(/[^\p{L}\p{N}\s-]/gu, " ").replace(/\s+/g, " ").trim();
  for (let i = 0; i < 2; i++) {
    t = t.replace(WRAP_START, "").replace(WRAP_END, "").trim();
  }
  return t;
}

// every family matches the WHOLE normalised utterance (its alternatives are wrapped in ^(?: … )$)
// K12 (O9 #3): "kan du göra det roligare" = "gör det roligare": every "gör " in a family also takes "göra "
const F = (task: string, scope: Scope, re: RegExp, rule: string): Family => ({
  task, scope, rule, re: new RegExp(`^(?:${re.source.replaceAll("gör ", "göra? ")})$`, "u"),
});

const FAMILIES: Family[] = [
  // ---------- study (Provläge, Frågor) ----------
  F("example", "study",
    /^(?:(?:ge|säg|ta|visa) (?:mig |oss )?(?:ett |något |ytterligare ett |ett till |ett annat )?exempel(?: till| på det(?: där)?| på det här)?|(?:ett |något )?exempel(?: tack)?|har du (?:ett|något) exempel|kan jag få ett exempel|example|give me an example)$/u,
    "Give ONE concrete, new example of the last answer's topic in <recent_qa> (not the example already given there), and say in one sentence how it shows the point. Two to four sentences."),
  F("summary", "study",
    /^(?:sammanfatta|summera)(?: det| det viktigaste| allt| kort| det här| svaret| ämnet)?|(?:vad är|säg) det viktigaste|ge mig det viktigaste|(?:en )?kort sammanfattning|summarize|sum it up$/u,
    "Summarise the most important points of the topic studied in <recent_qa> (all recent turns on it, not only the last answer) in three or four short sentences, the key terms included. Nothing new, and no check question at the end unless the student asked for one."),
  F("a_level", "study",
    /^(?:förklara |svara |säg det |ge mig )?(?:det )?(?:på |som |för )?(?:a-?nivå|a nivå|ett a|ett a-svar|a-svar|a svar)(?:-?nivå)?|hur får jag (?:ett )?a(?: på det här| på det)?$/u,
    "Explain the last answer's topic again as an answer that would earn the top grade A for the student's grade and course: the concepts, how they connect (cause and effect, comparison), one example and the conclusion. Do not say the grade or 'A-nivå' aloud."),
  F("harder_question", "study",
    /^(?:ställ |ge mig |fråga )?(?:en )?(?:svår|svårare|klurig|kluring) fråga|fråga (?:mig )?något svårare|utmana mig|en svårare$/u,
    "Ask ONE hard check question on the topic of <recent_qa> (when nothing was studied yet: the subject and exam in <profile>, never another subject) that needs reasoning at the A level of the grade (why, how, compare). Only the question, nothing before it. Never a question in <already_asked>."),
  F("quick_quiz", "study",
    /^snabbförhör(?: mig)?|snabbquiz|(?:ge mig |ställ |kör )?fem (?:snabba |korta )?frågor(?: i rad)?|quick quiz$/u,
    "Quick quiz: ask the FIRST of five short check questions in a row on the topic of <recent_qa> (or the exam in <profile>), each answerable with a word or a short phrase. Say only \"Fråga ett:\" and the question. The student's reply will be graded in the next turn."),
  F("yes_no_quiz", "study",
    /^(?:ställ |ge mig |kör )?ja[- ]?(?:eller[- ])?nej[- ]?frågor|förhör mig med ja och nej|ja nej förhör$/u,
    "Ask ONE check question on the topic of <recent_qa> that is answered with ja or nej. Only the question."),
  // K20 (Deangelo: "jag vet inte ens vad jag ska fråga" in Provläge was silence): help the student get started
  F("get_started", "study",
    /^(?:jag vet inte (?:ens )?vad jag ska (?:fråga|plugga|börja med|göra)|vad ska jag (?:fråga|plugga|börja med)|var ska jag börja|hjälp mig (?:att )?(?:komma igång|börja)|jag vet inte var jag ska börja|jag kommer inte på (?:något|nåt) att fråga)$/u,
    "The student does not know where to start. In two or three short spoken sentences suggest three concrete things to study first for the exam in <profile> (its subject, grade and topics; the ones in <recent_qa> or <concept_stats> that went wrong first), then ask ONE easy first question on the first of them. Never silence."),
  F("weak_areas", "study",
    /^(?:testa|förhör|öva|fråga) (?:mig )?(?:på )?mina (?:svagaste|svaga|sämsta) (?:områden|delar|sidor|begrepp)|vad kan jag sämst|vad behöver jag öva (?:mer )?på|vad är jag sämst på$/u,
    "<concept_stats> lists how the student did per concept (right/wrong). Pick the concept with the most wrong answers (or the lowest share right) and ask ONE check question on it. Only the question. Without <concept_stats>, ask about a core concept of <profile> not yet in <recent_qa>."),
  F("quiz_topic", "study",
    /^(?:förhör|testa|quizza|fråga ut|förhöra) mig (?:på|om|i|inom) (?!mina )(.{2,60})$/u,
    "Ask ONE check question about the topic given in <task_arg>, at the A level of the grade in <profile>. Only the question, nothing before it. Never a question in <already_asked>."),
  F("self_assessment", "study",
    /^hur bra kan jag (?:det här|det|detta|ämnet|det här ämnet)|hur ligger jag till|kan jag det här|hur går det för mig$/u,
    "Tell the student in two or three spoken sentences how well they know this, from <concept_stats> (right/wrong per concept) and the graded replies in <recent_qa>: what is secure and the one concept to practise next. Numbers in words. Never invent results: without data say there are no quiz results yet and offer one practice question."),
  F("careful", "study",
    /^(?:var säker|dubbelkolla|var noggrann|kolla noga|kontrollera noga|är du säker)(?: det| det där| svaret| på det| på det där)?$/u,
    "Check the last answer in <recent_qa> carefully, fact by fact. If everything holds, say so in one sentence and give the answer again briefly; if something was wrong, say \"Rättelse:\" and give the correct version."),
  F("catch_up", "study",
    /^vad (?:missade jag|har jag missat|sa (?:de|hon|han|hen|läraren|dom))|sammanfatta vad som (?:sagts|sades)|vad pratade (?:de|dom) om$/u,
    "Summarise what was said in <transcript> (the last minutes of the session) in two to four short sentences: the topic, the main points and anything the student should do. Nothing that is not in <transcript>; without <transcript> say in one sentence that nothing was heard."),
  F("brief_style", "study",
    /^(?:hjälp mig |svara )?diskret|kort och diskret|(?:svara )?(?:med )?bara en mening|en mening$/u,
    "Answer the last question in <recent_qa> (or the fragment's topic) in ONE short, natural sentence."),
  // ---------- interview ----------
  F("interview_help:professional", "interview",
    /^(?:hjälp mig (?:att )?)?svara professionellt|vad borde jag säga|hjälp mig svara|vad ska jag säga|vad säger jag$/u,
    "Give the user's answer to the last interviewer question in <recent_qa>, in first person, professional and concrete, in the interview style above."),
  F("interview_help:better", "interview",
    /^(?:ge mig |säg )?(?:ett )?bättre svar|gör (?:det|svaret) bättre|förbättra (?:det|svaret)$/u,
    "Rewrite the user's last answer (or your last suggestion) to the interviewer's question so it is clearly better: more concrete, tied to the job, first person. Only the new answer."),
  F("interview_help:confident", "interview",
    /^(?:mer självsäkert|mer självsäker|låt (?:mer )?säker|säkrare|mer säker|mer övertygande)$/u,
    "Say the user's last answer again more confidently: active verbs, no hedging, same facts. Only the new answer."),
  F("interview_help:counter_question", "interview",
    /^(?:ge mig )?(?:en )?motfråga|vad kan jag fråga (?:dem|tillbaka|henne|honom)|en bra fråga att ställa$/u,
    "Give ONE good question the user can ask the interviewer about the job or the workplace, in first person."),
  F("interview_help:stuck", "interview",
    /^(?:hjälp|jag fastnar|hjälp jag fastnar|jag har fastnat|jag vet inte vad jag ska säga|jag kommer inte på något)$/u,
    "The user is stuck on the last interviewer question: give a short first-person answer to start with (one or two sentences) the user can say right now."),
  // ---------- social / rizz (from social.calibrate) ----------
  F("social:reply", "social",
    /^vad (?:ska|kan|bör) jag (?:svara|säga)|vad svarar jag$/u, "A reply to the last thing the other person said."),
  F("social:funnier", "social", /^(?:roligare|gör det roligare|mer humor|mer skämt)$/u, "funnier"),
  F("social:natural", "social", /^(?:mer naturligt|naturligare|mindre stelt|mer avslappnat)$/u, "more natural, less stiff"),
  F("social:change_topic", "social",
    /^(?:byt ämne|hjälp mig byta ämne|nytt ämne|något annat att prata om)$/u,
    "A natural line that moves the conversation to a new topic that fits the situation."),
  F("social:follow_up", "social",
    /^(?:ge mig )?(?:en )?(?:smart |bra )?följdfråga$/u, "A smart follow-up question on what the other person just said."),
  F("social:what_meant", "social",
    /^vad menade (?:hon|han|hen|de|dom|personen)(?: med det)?$/u,
    "A line that checks lightly what the other person meant, without sounding unsure."),
  F("rizz:more", "social", /^(?:ge mig )?(?:lite )?(?:mer )?rizz$/u, "A line with more charm (rizz) for this moment."),
  F("rizz:confident", "social", /^(?:mer självsäker|mer självsäkert|säkrare)$/u, "more confident"),
  F("rizz:flirty", "social", /^(?:flirtigare|mer flirtig|mer flörtig|flörtigare)$/u, "more flirty"),
  F("rizz:subtle", "social", /^(?:mer subtil|subtilare|lugnare|mer diskret)$/u, "more subtle"),
  F("rizz:cocky", "social", /^(?:kaxigare|mer kaxig|mer kaxigt)$/u, "cockier, playful"),
  F("rizz:rescue", "social",
    /^(?:rädda mig|hjälp det går dåligt|det går dåligt|rädda situationen)$/u,
    "A light line that saves the moment after an awkward silence or a bad line."),
  F("rizz:less_cringe", "social", /^(?:mindre cringe|mindre pinsamt|mindre pinsam)$/u, "less cringe, more relaxed"),
  F("alternatives:3", "social", /^(?:ge mig )?tre (?:alternativ|förslag|varianter|repliker)|ge mig tre$/u, "Three different lines."),
];

/** Social families that ask for a new line (a suggestion request), not a style change (a calibration). */
const SOCIAL_REQUESTS = new Set(["social:reply", "social:change_topic", "social:follow_up", "social:what_meant", "rizz:more", "rizz:rescue", "alternatives:3"]);

/** The task for a whole utterance in the given scope, or null. */
export function commandTask(text: string, scope: Scope): CommandTask | null {
  const t = normalizeCommand(text);
  if (!t || t.split(" ").length > 12) return null;
  const forms = FOR_ME_END.test(t) ? [t, t.replace(FOR_ME_END, "").trim()] : [t];
  for (const form of forms) {
    for (const f of FAMILIES) {
      if (f.scope !== scope) continue;
      const m = f.re.exec(form);
      if (!m) continue;
      const arg = m[1]?.trim();
      return { task: f.task, ...(arg ? { arg } : {}), rule: f.rule };
    }
  }
  return null;
}

/** K9: a social family that asks for new lines, with how many (null = not a request; a calibration or nothing). */
export function socialRequest(text: string): { count: number; request: string } | null {
  const c = commandTask(text, "social");
  if (!c || !SOCIAL_REQUESTS.has(c.task)) return null;
  return { count: c.task === "alternatives:3" ? 3 : 1, request: c.rule };
}

/** K9: a social style family as a clear calibration instruction ("roligare" -> "funnier"), or null. */
export function socialStyle(text: string): string | null {
  const c = commandTask(text, "social");
  return c && !SOCIAL_REQUESTS.has(c.task) ? c.rule : null;
}

/** The table as data, for docs/COMMANDS.md and tests. */
export const COMMAND_FAMILIES: ReadonlyArray<{ task: string; scope: Scope }> = FAMILIES.map(({ task, scope }) => ({ task, scope }));

// ---------- standing rules from the user's own words (D80 rules) ----------
/**
 * K9 (Aron 21:20: "fortsätt att du i framtiden bara ska ställa korta svar under en mening alltså det är minnet",
 * ignored): a wish about how to answer from now on is a standing rule, not a question. Only in Provläge and Frågor,
 * only when it is clearly about the answers ("i framtiden ska du …", "från och med nu …", "svara alltid …",
 * "… det är minnet"). The rule text is returned as `memory_add` "Regel: …" (the app sends it back among the memories,
 * which the prompt treats as standing rules) and as `rule_add`.
 */
const RULE_CUE =
  /(?:^|\s)(?:i framtiden|från och med nu|från nu|framöver|hädanefter|varje gång|alltid|aldrig mer|det är minnet|kom ihåg det här som en regel)(?:\s|$)/u;
const RULE_ABOUT_ME = /(?:^|\s)(?:du|lumen)(?:\s|$)|^(?:svara|förklara|ställ|ge|säg|var|använd|prata|ta|skippa|hoppa)\s/u;
const RULE_ANSWER_WORDS =
  /svar|svara|förklar|mening|kort|längre|enkl|exempel|fråg|språk|engelska|svenska|ton|formell|lugn|snabb|långsam|detaljer|steg|siffror|ord/u;

export function detectRule(text: string): { rule: string; ack: string } | null {
  const raw = text.trim();
  const t = normalizeCommand(raw);
  if (!t || t.length > 220 || !RULE_CUE.test(` ${t} `)) return null;
  if (/\?\s*$/.test(raw)) return null; // a question about the future is a question
  const cleaned = t
    .replace(/^(?:fortsätt (?:att )?)?/u, "")
    .replace(/\s*(?:alltså |så )?det är minnet$/u, "")
    .replace(/^(?:att )?(?:du )?(?:i framtiden|från och med nu|från nu|framöver|hädanefter)\s+/u, "")
    .replace(/^(?:ska|skall|bör) du\s+/u, "")
    .replace(/^du (?:ska|skall|bör)\s+/u, "")
    .trim();
  if (!RULE_ABOUT_ME.test(t) && !RULE_ABOUT_ME.test(cleaned)) return null;
  if (!RULE_ANSWER_WORDS.test(cleaned)) return null;
  const rule = (cleaned.charAt(0).toUpperCase() + cleaned.slice(1)).replace(/\s+/g, " ").slice(0, 180) + ".";
  return { rule, ack: ruleAck(cleaned) };
}

function ruleAck(r: string): string {
  if (/kort|en mening|kortare/u.test(r)) return "Okej, korta svar.";
  if (/längre|utförlig|mer detaljer/u.test(r)) return "Okej, längre svar.";
  if (/enkl/u.test(r)) return "Okej, enklare förklaringar.";
  if (/exempel/u.test(r)) return "Okej, med exempel.";
  if (/engelska/u.test(r)) return "Okej, på engelska.";
  return "Okej, så gör jag från och med nu.";
}
