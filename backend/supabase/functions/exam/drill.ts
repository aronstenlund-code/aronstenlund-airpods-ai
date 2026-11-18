import { wordsToNumber } from "../answer/svnum.ts";
import { HttpError } from "../_shared/errors.ts";
import { sanitizeTagged } from "../answer/prompt.ts";
import { allocate, codeCap, coverage, nearDuplicate, partCount, placeQuestions, sectionParts, shares, splitParts } from "./coverage.ts";
import type { LLMProvider, LLMRequest } from "../answer/llm/types.ts";

/**
 * K45 (D142, D145, D146): Repetitionsläget, material to questions and answers. `POST /exam` actions:
 *  {"action":"drill", "pages"?: [{media_type,data}] (<= 20), "text"?: "<free text and document text>",
 *   "subject"?, "grade"?, "correction"?: "<one line from the user>", "questions"?: 20, "long_words"?: 90,
 *   "answers"?: true}
 *    -> {"summary": {"subject","grade","covers"}, "notes": "<the material as compact text>",
 *        "items": [{"id","question","short"?,"long"?}], "usage": {...}}
 *    Step 1 (Haiku, vision): summary, notes and the questions. Step 2 (Sonnet, batches of 5 in parallel): the answers.
 *    With "answers": false only step 1 runs (fast: the app shows the questions while it asks drill_answers).
 *    A correction is re-run from the notes, never from the photos again: {"text": notes, "correction": "..."}.
 *  {"action":"drill_answers", "subject"?, "grade"?, "notes"?, "items": [{"id","question"}], "long_words"?}
 *    -> {"items": [{"id","question","short","long"}], "usage"}       (edited or added questions)
 *  {"action":"drill_one", "subject"?, "grade"?, "notes"?, "question", "id"?, "long_words"?} -> {"item", "usage"}
 *  {"action":"doc_text", "data": "<base64 .docx>"} -> {"text"}        (in code, no model, no cost)
 * D145: the long answer always starts with the short answer word for word: the model writes the short answer and
 * the rest, and the long answer is put together in code (short + " " + rest), so it can never differ.
 * Nothing is stored here (B4: the material is never kept); K46 stores the questions and answers per account.
 */
export const DRILL_LIMITS = {
  pages: 20,
  text: 40_000,
  correction: 300,
  notes: 12_000,
  questionsDefault: 20,
  questionsMin: 3,
  questionsMax: 60,
  longWordsDefault: 90,
  longWordsMin: 40,
  longWordsMax: 200,
  batch: 5,
  /** R3: questions asked for beyond the count; the longest are dropped in code. */
  extraQuestions: 6,
  docxBase64: 14 * 1024 * 1024,
};

export interface DrillConfig {
  /** Step 1 (questions): the provider's default (Haiku 5.5) unless set. */
  planModel?: string;
  planPriceIn: number;
  planPriceOut: number;
  /** Step 2 (answers): Sonnet 5.5 (correctness matters, K2/D97). */
  answerModel: string;
  answerPriceIn: number;
  answerPriceOut: number;
}

/** Verified 2026-11-13 (claude-api reference): Haiku 5.5 $0.10/$0.50, Sonnet 5.5 $2/$10 per million tokens. */
export const DEFAULT_DRILL_CONFIG: DrillConfig = {
  planPriceIn: 0.10,
  planPriceOut: 0.50,
  answerModel: "claude-sonnet-5-5",
  answerPriceIn: 2,
  answerPriceOut: 10,
};

export const SYSTEM_PROMPT_DRILL_PLAN =
  `You prepare a Swedish student's revision list for an exam ("prov") from their study material (page photos, notes, a document's text). The student will listen to the questions and answers in their AirPods. Return ONLY a JSON object:
{"summary": {"subject": "Biologi", "grade": "åk 8", "covers": "..."}, "notes": "...", "questions_possible": 12, "questions": ["Varför behövs klorofyll?", "..."]}
When the material cannot be read at all (blurred, cut off, a screen photo you cannot make out, no school content), return ONLY {"unreadable": "<one short Swedish sentence on why, for example 'Texten på bilderna går inte att läsa.'>"}.
- summary: "subject" the school subject in Swedish; "grade" the school year or course as Swedes say it ("åk 8", "Matematik 1b", "Svenska 1", "Engelska 6", "Samhällskunskap 1b"): from <context> when given; else from the material itself: a course name or code, a textbook title, "åk"/"årskurs", or content that only fits one level (a gymnasium course's topics such as derivatives, molar mass or language history are gymnasium; never guess "åk 8" by default); else "" (empty: the app then asks the student, D159/K52); "covers" one or two Swedish sentences on what the exam covers (the main areas, in order).
- notes: every fact, concept, definition, formula, date, name, cause and example in the material, as compact Swedish plain text in the material's order (at most about 900 words). Only what the material says; the answers are written from these notes.
- questions_possible: how many good, different exam questions the material really supports (D159: never more than the material carries; a short text may support 4). Count before you write.
- Language (D182): when the subject is a foreign language (Engelska, Spanska, Tyska, Franska, Italienska, Kinesiska, Japanska and other modern languages), the exam is in that language: write "covers", the notes and the questions in that language. Every other subject in Swedish, even when the material is in English.
- questions: the number asked for in <count>, or fewer when questions_possible is lower: then exactly questions_possible plus at most 6 extra (the weakest are removed afterwards). Never pad with repeated, trivial or outside questions to reach the number. In the exam's language, in the material's order, spread over ALL parts of the material in proportion to how much the material says about each. Each question:
  - clear when only HEARD, with no text in front of the student: as short as it can be while it stays clear and natural Swedish (D176: there is no word limit; a long question with a long answer costs more, so do not make it longer than it needs to be). Never a fragment that needs the material to make sense ("Vad säger m?", "Mol metan i 16 g?" are wrong; "Vad visar m i en rät linje?", "Hur många mol är 16 gram metan?" are right). Cut filler such as "i naturen", "egentligen", "det att";
  - written as it is said: no symbols, formulas, units or abbreviations as signs ("syre", not "O2"; "kubikdecimeter", not "dm³"; "procent", not "%");
  - tests understanding, not only recall: at least three of every four questions ask why, how, what happens if, or compare ("Varför behövs klorofyll?", "Hur bildas en näringsväv?", "Vad händer om pH sjunker?", "Skillnad mellan väder och klimat?"); "Vad är X?", "Vad betyder X?" or "Vilka ...?" at most one in five, only for a key term the material defines;
  - is answered by the material (never a question the material does not cover, never a fact from outside it);
  - asks "Varför ...?" only when the material itself states the cause or the reason (K97, O79: "Varför fick Gustav Vasa med sig bönderna?" is wrong when the material only says that they joined him) (a "because", "därför att", "eftersom", "leder till", "beror på" or an explained mechanism); a fact stated with no reason ("tredje ståndet betalade nästan alla skatter", "taking the train is better than flying") gets "Vad ...?", "Hur ...?" or "Vilka följder ...?" instead; when the material only states that something is so (a rule, a law, a definition), ask "Vad ...?" or "Hur ...?" instead (O63: "Varför bestämmer antalet protoner vilket grundämne atomen är?" has no answer in a material that only says it; the answer becomes circular);
  - never claims anything the material does not say or that contradicts it (O63: "Varför kallas medierna den fjärde statsmakten?" when the material says "tredje");
  - a real exam question a teacher would ask: no yes/no, no multiple choice, no "enligt texten", no page or task numbers, no question about the material itself;
  - different from every other question (no two that ask the same thing). K97 (O79): before you return, compare every pair: when the material gives two questions the same answer (the same fact, cause or effect in other words: "Varför kan ljud inte spridas i vakuum?" and "Varför är det tyst i rymden?"; "Varför får de med fasta inkomster det sämre?" and "Varför får pensionärer det sämre?"), keep only the better one and ask about something else the material says.
- When <correction> is given, it is the student's correction of your reading (subject, grade or what the exam covers): follow it.
No markdown, no other text.`;

export const SYSTEM_PROMPT_DRILL_ANSWERS =
  `You write the answers a Swedish student will listen to in their AirPods while revising for an exam. You get <context> (subject and grade), <notes> (the study material), <long_words>, <questions> (JSON: id and question) and maybe <language> and <may_fix>. Return ONLY a JSON object {"answers": [{"id": "q1", "short": "...", "rest": "..."}]} with one entry per question, in the same order.
- Language (D182): write in <language> when it is given (a language exam: the questions are in that language too); else in Swedish.
- When <may_fix> is given and a question cannot be answered well from the notes, put a better question in "question" and answer that one: a question with a claim the notes contradict gets the notes' fact ("fjärde statsmakten" -> "tredje statsmakten" when the notes say so); a "Varför ...?" whose cause the notes do not give becomes a "Vad ...?" or "Hur ...?" question the notes answer. Otherwise leave "question" out.
- K97 (O79): never invent a cause, motive or reason the notes do not give ("bönderna var missnöjda med danskarnas styre", "för att göra makten säker för släkten", "kriget mot Danmark" when the notes only say "efter kriget"). A why-question whose cause the notes do not state: with <may_fix>, ask a "Vad ...?" or "Hur ...?" question the notes answer; without it, answer only with what the notes do say about it, and say plainly that the reason is not known from this ("Varför det blev så är inte känt här, men ..."; in English "Why is not explained here, but ...") rather than guess; never name the notes, a material or what you have ("the notes do not say", "det material jag har" are wrong). School knowledge may fill out a mechanism the notes name, never supply a cause they leave out.
- Never answer a why-question by repeating its claim ("Det beror på att sidorna alltid har just det sambandet", "De ansåg att makten skulle komma från folket"): give the reason, or (with <may_fix>) ask a better question.
- "short": the short answer (D162): ONE sentence, two only when one cannot hold it, at most 25 words, that on its own is a full, correct A-level answer: it states the answer itself (the cause, the mechanism, the fact, the difference), never an introduction that only names the topic. Wrong: "Fotosyntes är en viktig process i växterna." Right: "Växten använder ljusenergi för att bygga glukos av koldioxid och vatten, och syre blir över."
- "rest": what follows the short answer so that short + rest together is the long answer, a full A-level exam answer for that grade: it builds on the short answer with the concepts, the explanation, how things connect (cause and effect, compare) and a concrete example when it helps. Never repeat or rephrase the short answer. Short + rest together are about <long_words> words or fewer (count them); go over only when the answer would otherwise miss a concept or connection an A-level answer needs, and then by at most a fifth. Never pad an answer to reach the number.
- The grade never lowers the quality; it only decides which concepts are reasonable (no university concepts in åk 7-9).
- Base the answers on <notes>. K97 (O79): never add a cause, motive, mechanism, consequence, advice or general claim the notes do not give ("efter blodbadet var han själv i fara", "Latin förstod bara de lärda", "banker utgår från styrräntan", "sänk volymen i hörlurarna" are wrong when the notes do not say them); when the notes give no reason, say so in a few words instead of explaining. School knowledge only to name or define a concept the notes use, only facts you are certain of (textbook-level), and never contradict the notes; leave out a detail rather than guess it (O55: "stäppgräs har korta rötter" was wrong). Every fact must be correct: work every number out before you write it. Never add history, causes or examples the question did not ask for. Never add a general rule about a whole group ("alla", "alltid", "aldrig", "inga", "kan alltså vara") that the notes do not state (O63: "Alla föreningar kan alltså vara molekyler" is wrong: salt is a compound but not molecules).
- The text is read aloud: plain spoken sentences, no markdown, lists, headings, brackets, abbreviations or symbols. K97 (O79): write numbers, years, dates, decimals and percentages with digits exactly as the notes have them ("1527", "85 decibel", "340 meter per sekund", "2 procent", "den 6 juni 1523"): the voice turns them into words, and digits are never mixed up. Write formulas and symbols in words ("koldioxid", not "CO2"; "pi", not "π"). Never mention the notes, the material, the text, the book, the exam or the grade: the student only hears the answer ("i materialet", "enligt texten" are wrong).
- "display" (K66): the student also sees the text on screen, where 1850, 3,14, a² + b², CO₂ and 25 % are easier to read than words. When the question, "short" or "rest" has a number, year, decimal, formula, unit or symbol written as words, also return "display": {"question": "...", "short": "...", "rest": "..."} with the same sentences written as a textbook prints them, and only the fields that differ. Every year, date, percent, decimal, measurement and number above twelve gets its digits there ("den fjortonde juli sjuttonhundraåttionio" -> "den 14 juli 1789", "fyra procent" -> "4 %", "eighteen fifty" -> "1850", "one point two degrees" -> "1.2 degrees"); only small counts in running text stay words ("två orsaker"). Division is "/" or a fraction on screen ("s / t") and "delat med" / "divided by" in the spoken text. No numbers or formulas: leave "display" out.
No other text.`;

/** K69: step 1 in two calls at the same time (one system prompt, cached): the questions, and the notes. */
export const PART_QUESTIONS =
  '<part>questions</part> Return the JSON object with "summary", "questions_possible" and "questions" (or "unreadable"), but WITHOUT "notes": another step writes the notes at the same time.';
export const PART_NOTES =
  '<part>notes</part> Return ONLY {"notes": "..."}: the notes exactly as described (every fact, concept, definition, formula, date, name, cause and example, in the material\'s order and the exam\'s language). Another step writes the summary and the questions at the same time. When the material cannot be read, return {"notes": ""}.';

export interface DrillSummary {
  subject: string;
  grade: string;
  covers: string;
}
export interface DrillItem {
  id: string;
  question: string;
  short?: string;
  long?: string;
  /** K52: the answer could not be written (never an empty answer). */
  error?: string;
  /**
   * K66 (O63 punkt 4): the text the app SHOWS, only the fields that differ from the spoken text (numbers and
   * formulas as a textbook prints them: 1850, 3,14, a² + b²). The voice always reads question/short/long.
   */
  screen?: Screen;
}
export interface Screen { question?: string; short?: string; long?: string }
export interface StepUsage {
  model: string;
  input_tokens: number;
  output_tokens: number;
  est_cost_usd: number;
  ms: number;
}

export function clean(s: unknown, max: number): string {
  if (typeof s !== "string") return "";
  return s.replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f]/g, " ").trim().slice(0, max);
}
const oneLine = (s: unknown, max: number) => clean(s, max).replace(/\s+/g, " ");
export const words = (s: string) => s.trim().split(/\s+/).filter(Boolean).length;

/** K52: the app's profile codes (StudyProfile.Grade) as Swedes say them; anything else as it is. */
export function gradeName(g: string): string {
  const m: Record<string, string> = {
    y6: "åk 6", y7: "åk 7", y8: "åk 8", y9: "åk 9", gy1: "gymnasiet år 1", gy2: "gymnasiet år 2", gy3: "gymnasiet år 3",
    university: "högskola", other: "",
  };
  return m[g.trim().toLowerCase()] ?? g;
}

export function intIn(v: unknown, min: number, max: number, dflt: number): number {
  const n = Math.round(Number(v));
  return Number.isFinite(n) && v !== null && v !== undefined && v !== "" ? Math.min(max, Math.max(min, n)) : dflt;
}

function firstJson(text: string): Record<string, unknown> | null {
  const m = /\{[\s\S]*\}/.exec(text);
  if (!m) return null;
  try {
    return JSON.parse(m[0]);
  } catch {
    return null;
  }
}

/** A question as spoken: one line, ends with "?", no numbering or quotes. */
export function cleanQuestion(q: unknown): string {
  let s = oneLine(q, 200).replace(/^(?:\d+[.)]|[-•*])\s*/, "").replace(/^["'„”»«]+|["'„”»«]+$/g, "").trim();
  if (!s) return "";
  s = s.replace(/[.!:;,]+$/, "");
  if (!s.endsWith("?")) s += "?";
  return s[0].toUpperCase() + s.slice(1);
}

/** A question that points at the material ("i texten", "exemplet", "på bilden"): unclear when only heard (O55). */
export function leansOnMaterial(q: string): boolean {
  return /\b(?:i texten|enligt texten|nämns|i materialet|på bilden|i bilden|i figuren|i tabellen|i exemplet|\w*exemplet|uppgiften|ovan)\b/i.test(q);
}

/** A question that asks only for a fact or a definition (R3 wants at least 70 % understanding questions). */
export function isRecall(q: string): boolean {
  return /^(?:vad (?:är|var|heter|betyder|kallas|står)|vilk(?:a|en|et) |när |vem |vilket år|enhet för|nämn )/i.test(q.trim());
}

/** Step 1 reply: the summary, the notes and at most `count` questions within the word limit (R3), no duplicates. */
export function parsePlan(
  text: string,
  count: number,
): { summary: DrillSummary; notes: string; questions: string[]; questionsPossible?: number; unreadable?: string } {
  const j = firstJson(text) ?? {};
  const s = (j.summary ?? {}) as Record<string, unknown>;
  const seen = new Set<string>();
  const questions: string[] = [];
  for (const q of Array.isArray(j.questions) ? j.questions : []) {
    const c = cleanQuestion(q);
    const key = c.toLowerCase().replace(/[^a-zåäö0-9]/g, "");
    if (!c || seen.has(key)) continue;
    seen.add(key);
    questions.push(c);
  }
  return {
    summary: { subject: oneLine(s.subject, 60), grade: oneLine(s.grade, 60), covers: oneLine(s.covers, 400) },
    notes: clean(j.notes, DRILL_LIMITS.notes),
    questions: trimQuestions(questions, count),
    ...(Number.isFinite(Number(j.questions_possible)) && Number(j.questions_possible) > 0
      ? { questionsPossible: Math.round(Number(j.questions_possible)) }
      : {}),
    ...(typeof j.unreadable === "string" && j.unreadable.trim() ? { unreadable: oneLine(j.unreadable, 200) } : {}),
  };
}

/**
 * R3 (live 2026-11-13: 8 of 19 at most five words, then 59 of 100 understanding questions): the model writes a few
 * extra; plain recall questions go first, then questions over five words, then the longest; the order stays.
 */
export function trimQuestions(list: string[], count: number): string[] {
  const questions = [...list];
  // D176: no word limit; the weakest go (leaning on the material, then plain recall), the last of equals first
  const score = (q: string) => (leansOnMaterial(q) ? 200 : 0) + (isRecall(q) ? 100 : 0);
  while (questions.length > count) {
    let worst = 0;
    questions.forEach((q, i) => {
      if (score(q) >= score(questions[worst])) worst = i;
    });
    questions.splice(worst, 1);
  }
  return questions;
}

export const SYSTEM_PROMPT_DRILL_SHORTEN =
  `You check Swedish exam questions that a student will only HEAR (no text in front of them). You get <exam> (subject, grade and what the exam covers) and <questions> (JSON: i and q). Return ONLY a JSON object {"questions": [{"i": 0, "q": "..."}]} with ONLY the questions you changed (none = {"questions": []}).
- A question that only makes sense with the material in front of the student is rewritten so that it is clear when heard alone ("Hur bygger man gymmodellen?" -> "Hur ställer man upp en linjär kostnadsmodell?", "Skillnad mot past simple?" -> "Skillnad mellan present perfect och past simple?").
- Symbols, formulas, units and abbreviations are written as they are said ("3x + 5 = 20" -> "tre x plus fem är lika med tjugo", "O2" -> "syre", "dm³" -> "kubikdecimeter").
- Wrong or clumsy language is fixed ("Vad jämför man nysvenska och fornsvenska?" -> "Hur skiljer sig nysvenska från fornsvenska?"). The question stays in its language (D182: an English exam's questions stay English); never translate, except: when <language> is given, every question that is not in that language is returned translated into it (K67: a language exam's questions are in the exam's language).
- Never make a question longer for any other reason. Filler that adds nothing may go ("i naturen", "egentligen").
- The question must still ask the same thing: a why-question stays a why-question, the same concept, the same numbers in a calculation.
- A calculation question keeps its numbers and units, written as words or plain digits as given; never symbols.
- K97 (O79): with <material>, read it first: two questions are the same when the material gives them the same answer. Two questions whose answers would be the same (the same fact, cause or effect asked in other words: "Hur påverkar inflation hushållens köpkraft?" and "Vad händer med köpkraften när inflationen stiger?"; "Varför får personer med fasta inkomster det sämre?" and "Varför får pensionärer med fast pension det sämre?"): return the LATER one as {"i": N, "drop": true}. Only when a student would give the same answer to both; two questions on one topic that ask different things both stay.
No other text.`;

/**
 * K45/K52: every question checked by a cheap model: shortened, made clear without the material, symbols in words,
 * Swedish fixed. A reply that is empty, broken, a duplicate or longer than eight words keeps the original.
 */
export async function shortenQuestions(
  provider: LLMProvider,
  cfg: DrillConfig,
  questions: string[],
  exam: DrillSummary,
  signal?: AbortSignal,
  material = "",
): Promise<{ questions: string[]; usage: StepUsage | null; dropped?: number }> {
  const lang = examLanguage(exam.subject);
  const long = questions.map((q, i) => ({ i, q }));
  if (!long.length) return { questions, usage: null };
  try {
    const r = await runLLM(provider, {
      system: SYSTEM_PROMPT_DRILL_SHORTEN,
      user: `<exam>${sanitizeTagged(`${contextLine(exam.subject, exam.grade)}. ${exam.covers}`)}</exam>
<questions>${sanitizeTagged(JSON.stringify(long))}</questions>${material ? `
<material>${sanitizeTagged(material.slice(0, 6000))}</material>` : ""}${lang ? `
<language>${lang}</language>` : ""}`,
      maxTokens: 300 + long.length * (lang ? 60 : 30),
      cacheSystem: true,
      model: cfg.planModel,
      timeoutMs: 30_000,
      signal,
    }, cfg.planPriceIn, cfg.planPriceOut);
    const out = [...questions];
    const j = firstJson(r.text);
    const drop = new Set<number>();
    for (const x of Array.isArray(j?.questions) ? j!.questions as Record<string, unknown>[] : []) {
      const i = Number(x?.i);
      // K97 (O79): a question with the same answer as an earlier one goes (never the first, at most a third)
      if (x?.drop === true && Number.isInteger(i) && i > 0 && i < out.length) {
        drop.add(i);
        continue;
      }
      const q = cleanQuestion(x?.q);
      if (!Number.isInteger(i) || i < 0 || i >= out.length || !q) continue;
      // K52 live: rewrites that only made questions longer cost R3 (65 % at most five words). A longer rewrite is kept
      // only when the original had signs or leaned on the material; otherwise only a shorter or equal one.
      const mayGrow = /[=+*/^²³%<>]|\d/.test(out[i]) || leansOnMaterial(out[i]);
      // D176: no word limit, but the check never pads a question (at most two words more when signs become words)
      // K67: a translation into the exam's language may be longer (English needs more words than Swedish)
      const translated = !!lang && looksSwedish(out[i]) && !looksSwedish(q);
      if (words(q) >= 2 && (words(q) <= words(out[i]) + (mayGrow ? 2 : 0) || (translated && words(q) <= words(out[i]) * 2 + 2)) && !leansOnMaterial(q) &&
        !out.some((o, k) => k !== i && o.toLowerCase() === q.toLowerCase())) out[i] = q;
    }
    const gone = [...drop].sort((a, b) => a - b).slice(0, Math.floor(out.length / 3));
    const kept = out.filter((_, i) => !gone.includes(i));
    return { questions: kept.length ? kept : out, usage: r.usage, dropped: kept.length ? gone.length : 0 };
  } catch (e) {
    console.warn("drill_shorten_failed", e instanceof Error ? e.message.slice(0, 120) : String(e));
    return { questions, usage: null };
  }
}

/**
 * Oscar O79 omtest (F1–F3): the last check of the finished list against the material, after the parts have been
 * filled (the part calls' questions were never checked before). One call to the answer model (correctness, K2/D97).
 */
export const SYSTEM_PROMPT_DRILL_FINAL_CHECK =
  `You check the finished list of questions for a spoken practice exam against the material it was made from. You get <material> and <questions> (JSON: i and q). Return ONLY {"questions": [...]} with an entry for each question you change or remove (none = {"questions": []}):
- Every fact a question takes for granted (who, what, which war, who owed whom, a cause, a result, a date) must be what the material says. When a question takes for granted something the material does not say, or says differently, rewrite it as little as possible so that it assumes only what the material says: {"i": N, "q": "..."}. Example: the material says "skulder till Lübeck efter kriget" and the war was against Denmark; "Varför behövde kronan pengar efter kriget med Lübeck?" is wrong; write "Varför hade kronan skulder till Lübeck?".
- A why-question whose cause the material does not give: rewrite it into an understanding question the material does carry, never into a what-, when- or who-question (D230): "Förklara hur X hänger ihop med Y", "Vad blev följden av X?", "Jämför X och Y", "Hur påverkade X Y?" (or the same in the exam's language): {"i": N, "q": "..."}. The new question may only ask about a link the material itself makes.
- At least half of the questions must be understanding questions (why, how, explain, compare, what followed). When fewer are, rewrite plain recall questions (what is, when, who, which) into understanding questions the material carries, the earliest first, until half are.
- A question whose right answer would be the same as, or part of, the answer to an EARLIER question in the list (the same fact, cause or effect asked in other words): {"i": N, "drop": true, "same_as": M}. Two questions on one topic that ask different things both stay.
- Never change anything else: same language, same length or shorter, clear when only heard. No other text.`;

/** D230: a question that asks for understanding (a cause, a link, a result, a comparison), not a recalled fact. */
export function isUnderstanding(q: string): boolean {
  const t = q.trim().toLowerCase();
  return /^(?:varför|hur |förklara|jämför|beskriv hur|på vilket sätt|vad (?:blev|blir) följden|vad (?:hände|händer|händer det) (?:när|om|med|efter)|vilka följder|vilken betydelse|vad betydde|why|how |explain|compare|in what way|what (?:happened|happens) (?:when|if|to|after)|what (?:was|were) the (?:effects?|results?|consequences?))/.test(t) ||
    /hänger ihop|skillnaden mellan|leder till|ledde till|påverka|the difference between|led to|lead to|affect/.test(t);
}

export const SYSTEM_PROMPT_DRILL_REFILL =
  `You write extra questions for a spoken practice exam. You get <material>, <kept> (the questions the exam already has) and <count>. Return ONLY {"questions": ["...", ...]} with exactly <count> new questions:
- Each is an understanding question the material carries (why, how, explain how X is linked to Y, what followed, compare), answered by the material itself. Never assume a fact, cause or link the material does not state.
- Never ask what a kept question asks, in any words: a question whose answer would be the same as, or part of, a kept question's answer is wrong.
- Spread them over parts of the material that the kept questions touch least. The language of the material; short and clear when only heard. No other text.`;

/** D230: questions removed as duplicates are made up for, so the exam has the count it should (one call). */
export async function refillQuestions(
  provider: LLMProvider,
  cfg: DrillConfig,
  kept: string[],
  n: number,
  material: string,
  signal?: AbortSignal,
): Promise<{ questions: string[]; usage: StepUsage | null }> {
  if (n <= 0 || !material) return { questions: [], usage: null };
  try {
    const r = await runLLM(provider, {
      system: SYSTEM_PROMPT_DRILL_REFILL,
      user: `<material>${sanitizeTagged(material.slice(0, 8000))}</material>\n<kept>${sanitizeTagged(JSON.stringify(kept))}</kept>\n<count>${n}</count>`,
      maxTokens: 150 + n * 80,
      cacheSystem: true,
      model: cfg.answerModel,
      timeoutMs: 40_000,
      signal,
    }, cfg.answerPriceIn, cfg.answerPriceOut);
    const out: string[] = [];
    const j = firstJson(r.text);
    for (const x of Array.isArray(j?.questions) ? j!.questions as unknown[] : []) {
      const q = cleanQuestion(x);
      if (!q || words(q) < 2 || leansOnMaterial(q) || out.length >= n) continue;
      if ([...kept, ...out].some((k) => k.toLowerCase() === q.toLowerCase() || nearDuplicate(k, q))) continue;
      out.push(q);
    }
    return { questions: out, usage: r.usage };
  } catch (e) {
    console.warn("drill_refill_failed", e instanceof Error ? e.message.slice(0, 120) : String(e));
    return { questions: [], usage: null };
  }
}

/** Oscar O79 omtest: the result of the last check (questions fixed or removed; the order kept). */
export async function finalCheck(
  provider: LLMProvider,
  cfg: DrillConfig,
  questions: string[],
  parts: number[],
  material: string,
  signal?: AbortSignal,
): Promise<{ questions: string[]; parts: number[]; usage: StepUsage | null; fixed: number; dropped: number }> {
  if (questions.length < 2 || !material) return { questions, parts, usage: null, fixed: 0, dropped: 0 };
  try {
    const r = await runLLM(provider, {
      system: SYSTEM_PROMPT_DRILL_FINAL_CHECK,
      user: `<material>${sanitizeTagged(material.slice(0, 8000))}</material>\n<questions>${sanitizeTagged(JSON.stringify(questions.map((q, i) => ({ i, q }))))}</questions>`,
      maxTokens: 200 + questions.length * 60,
      cacheSystem: true,
      model: cfg.answerModel,
      timeoutMs: 40_000,
      signal,
    }, cfg.answerPriceIn, cfg.answerPriceOut);
    const out = [...questions];
    const drop = new Set<number>();
    let fixed = 0;
    for (const x of Array.isArray(firstJson(r.text)?.questions) ? firstJson(r.text)!.questions as Record<string, unknown>[] : []) {
      const i = Number(x?.i);
      if (!Number.isInteger(i) || i < 0 || i >= out.length) continue;
      if (x?.drop === true) {
        const m = Number(x?.same_as);
        if (i > 0 && Number.isInteger(m) && m >= 0 && m < i) drop.add(i);
        continue;
      }
      const q = cleanQuestion(x?.q);
      if (!q || words(q) < 2 || words(q) > words(out[i]) + 4 || leansOnMaterial(q) || out.some((o, k) => k !== i && o.toLowerCase() === q.toLowerCase())) continue;
      if (q !== out[i]) (out[i] = q, fixed++);
    }
    // never the first, at most a third, and never the last question of a part (every part keeps one)
    const left = new Map<number, number>();
    for (const p of parts) left.set(p, (left.get(p) ?? 0) + 1);
    const gone: number[] = [];
    for (const i of [...drop].sort((a, b) => a - b)) {
      if (gone.length >= Math.floor(out.length / 3)) break;
      const p = parts[i] ?? -1;
      if (p >= 0 && (left.get(p) ?? 0) <= 1) continue;
      left.set(p, (left.get(p) ?? 0) - 1);
      gone.push(i);
    }
    return {
      questions: out.filter((_, i) => !gone.includes(i)),
      parts: parts.filter((_, i) => !gone.includes(i)),
      usage: r.usage, fixed, dropped: gone.length,
    };
  } catch (e) {
    console.warn("drill_final_check_failed", e instanceof Error ? e.message.slice(0, 120) : String(e));
    return { questions, parts, usage: null, fixed: 0, dropped: 0 };
  }
}

/** K67: a question in Swedish (Swedish question word or å/ä/ö). */
export function looksSwedish(q: string): boolean {
  return /^(?:vad|varför|hur|vilk|vem|när|var |vilket|beskriv|förklara|jämför|ge )/i.test(q.trim()) || /[åäö]/i.test(q);
}

/** Plain spoken text: no markdown, list marks or doubled spaces (fewer characters for the voice too, D144). */
export function spokenText(s: unknown, max = 3000): string {
  return clean(s, max)
    .replace(/\*\*|__|`|#+\s/g, "")
    .replace(/^\s*(?:[-•*]|\d+[.)])\s+/gm, "")
    .replace(/\s+/g, " ")
    .trim();
}

/** D145 in code: long = short + " " + rest, so the long answer starts with the short answer word for word. */
export function composeLong(short: string, rest: string): string {
  const sh = short.trim();
  let r = rest.trim();
  // the model sometimes repeats the short answer at the start of the rest: never twice
  if (r.startsWith(sh)) r = r.slice(sh.length).trim();
  if (!sh) return r;
  if (!r) return sh;
  return `${/[.!?]$/.test(sh) ? sh : `${sh}.`} ${r}`;
}

/**
 * K54 (D162): a short answer that only introduces the topic ("Fotosyntes är en viktig process i växterna.",
 * "Det finns flera orsaker.") or is longer than about 35 words is not the answer itself.
 */
const INTRO = /^(?:[\p{L}\p{N}-]+\s+){0,6}?(?:är en (?:viktig|central|grundläggande|komplex|intressant|avgörande)(?![\p{L}\p{N}])|handlar om(?![\p{L}\p{N}])|det finns (?:flera|många|olika|tre|två)(?![\p{L}\p{N}])|det beror på (?:flera|många)(?![\p{L}\p{N}])|det är (?:viktigt|intressant) att(?![\p{L}\p{N}])|det här är(?![\p{L}\p{N}])|man kan säga att(?![\p{L}\p{N}])|svaret är att(?![\p{L}\p{N}])|frågan handlar(?![\p{L}\p{N}]))/iu;
export function isIntroShort(short: string): boolean {
  const s = short.trim();
  const sentences = s.split(/(?<=[.!?])\s+/).filter(Boolean).length;
  return INTRO.test(s) || words(s) > 35 || sentences > 2 || /[:]$/.test(s);
}

/** K66 (O63): the answer points at the material, which the student never hears ("i materialet", "enligt texten"). */
export function mentionsMaterial(s: string): boolean {
  // K67 (O64 punkt 3): on every exam language (D182)
  return /(?<![\p{L}])(?:materialet|i texten|enligt texten|texten säger|anteckningarna|notes säger|enligt notes|i notes|det material jag har|det jag har|i mitt material|the notes do not|my notes|enligt boken|i boken|the material|the notes|the text|in the text|the passage|the reading|el material|las notas|el texto|das material|die notizen|im text|der text|le matériel|les notes|le texte|dans le texte)(?![\p{L}])/iu.test(s);
}

/**
 * K66 (O63 punkt 1): a why-question answered by repeating its own claim: the short answer adds fewer than two
 * content words (five letters or more) that the question does not have, or says "just det sambandet".
 */
export function isCircular(question: string, short: string): boolean {
  if (!/^(?:varför|why)\b/i.test(question.trim())) return false;
  if (/\b(?:just det sambandet|det är bara så|så är det bara|helt enkelt så)\b/i.test(short)) return true;
  const stem = (w: string) => w.toLowerCase().replace(/[^\p{L}\p{N}]/gu, "").slice(0, 5);
  const q = new Set(question.split(/\s+/).map(stem));
  const fresh = new Set(short.split(/\s+/).map(stem).filter((w) => w.length >= 5 && !q.has(w)));
  return fresh.size < 2;
}

/** K66: the display text: only kept when it is a real variant of the spoken text (not empty, not far longer). */
function screenText(v: unknown, spoken: string, max: number): string | undefined {
  const s = spokenText(v, max);
  if (!s || s === spoken || s.length > spoken.length * 1.5 + 20 || s.length < spoken.length * 0.25) return undefined;
  return s;
}

const TEENS: Record<string, number> = { tio: 10, elva: 11, tolv: 12, tretton: 13, fjorton: 14, femton: 15, sexton: 16, sjutton: 17, arton: 18, nitton: 19, tjugo: 20 };
const YEAR_WORDS = new RegExp(
  `(?<!\\p{L})(${Object.keys(TEENS).join("|")})\\s?hundra(?:\\s?(\\p{L}+))?(?!\\p{L})|(?<!\\p{L})tvåtusen(?:\\s?(\\p{L}+))(?!\\p{L})`, "giu");

/**
 * K97 (O79 F4): a year written in words in the shown text becomes digits ("femton hundra tjugosju" and
 * "femtonhundratjugosju" -> "1527", "tvåtusentjugotvå" -> "2022"). Only year shapes (10–20 hundred, two thousand and
 * a number below 100), so amounts ("femhundra kronor") stay as they are. The spoken text keeps its words.
 */
export function yearsToDigits(text: string): string {
  return text.replace(YEAR_WORDS, (m, head?: string, tail?: string, tail2?: string) => {
    if (head) {
      const h = TEENS[head.toLowerCase()];
      if (!tail) return String(h * 100);
      const t = wordsToNumber(tail);
      if (t !== null && t >= 1 && t < 100) return String(h * 100 + t);
      // "sextonhundratalet" -> "1600-talet", "artonhundrasjuttiotalet" -> "1870-talet"
      const dec = /^(\p{L}*?)(tal(?:et|s)?)$/iu.exec(tail);
      if (dec) {
        const n = dec[1] ? wordsToNumber(dec[1]) : 0;
        if (n !== null && n >= 0 && n < 100) return `${h * 100 + n}-${dec[2]}`;
      }
      return m; // anything else ("femtonhundra år" as a length of time) keeps its words
    }
    const t = tail2 ? wordsToNumber(tail2) : null;
    return t !== null && t >= 1 && t < 100 ? String(2000 + t) : m;
  });
}

export function parseAnswers(text: string, strict = false): Map<string, { short: string; long: string; question?: string; screen?: Screen }> {
  const out = new Map<string, { short: string; long: string; question?: string; screen?: Screen }>();
  const j = firstJson(text);
  for (const a of Array.isArray(j?.answers) ? j!.answers as Record<string, unknown>[] : []) {
    const id = oneLine(a?.id, 40);
    let short = spokenText(a?.short, 600);
    const rest = spokenText(a?.rest, 3000);
    // K52 (O55: one empty answer): an empty, one-word or cut-off answer is not accepted; the question is asked again
    if (!id || words(short) < 2 || (rest && !/[.!?]["”')]?$/.test(rest))) continue;
    if (strict && isIntroShort(short)) continue; // K54: asked again; accepted on the last try rather than no answer
    if (strict && mentionsMaterial(`${short} ${rest}`)) continue; // K66 (O63): asked again
    if (!/[.!?]$/.test(short)) short += ".";
    const question = typeof a?.question === "string" ? cleanQuestion(a.question) : "";
    const long = composeLong(short, rest);
    const d = (a?.display ?? null) as Record<string, unknown> | null;
    let screen: Screen | undefined;
    if (d && typeof d === "object") {
      const dq = typeof d.question === "string" ? cleanQuestion(d.question) : "";
      let ds = screenText(d.short, short, 600);
      if (ds && !/[.!?]$/.test(ds)) ds += ".";
      const dr = screenText(d.rest, rest, 3000);
      const dl = ds || dr ? composeLong(ds ?? short, dr ?? rest) : undefined;
      screen = {
        ...(dq ? { question: dq } : {}),
        ...(ds ? { short: ds } : {}),
        ...(dl && dl !== long ? { long: dl } : {}),
      };
      if (!Object.keys(screen).length) screen = undefined;
    }
    out.set(id, { short, long, ...(question ? { question } : {}), ...(screen ? { screen } : {}) });
  }
  return out;
}

/**
 * D182: the language of a language exam ("Engelska 6" -> "English"), or "" (Swedish). Swedish itself is "".
 */
export function examLanguage(subject: string): string {
  const s = subject.toLowerCase();
  const m: [RegExp, string][] = [
    [/engelska|english/, "English"], [/spanska|español|spanish/, "Spanish"], [/tyska|deutsch|german/, "German"],
    [/franska|français|french/, "French"], [/italienska|italian/, "Italian"], [/kinesiska|chinese/, "Chinese"],
    [/japanska|japanese/, "Japanese"], [/arabiska|arabic/, "Arabic"], [/finska|finnish/, "Finnish"],
  ];
  for (const [re, lang] of m) if (re.test(s)) return lang;
  return "";
}

export async function runLLM(provider: LLMProvider, req: LLMRequest, priceIn: number, priceOut: number) {
  const t0 = Date.now();
  let text = "";
  let inTok = 0, outTok = 0;
  for await (const c of provider.stream(req)) {
    if (c.type === "text") text += c.text;
    else if (c.type === "usage") {
      inTok = c.inputTokens ?? inTok;
      outTok = c.outputTokens ?? outTok;
    }
  }
  const usage: StepUsage = {
    model: req.model ?? provider.model,
    input_tokens: inTok,
    output_tokens: outTok,
    est_cost_usd: (inTok * priceIn + outTok * priceOut) / 1e6,
    ms: Date.now() - t0,
  };
  return { text, usage };
}

export function sumUsage(steps: StepUsage[], model: string): StepUsage {
  return {
    model,
    input_tokens: steps.reduce((a, s) => a + s.input_tokens, 0),
    output_tokens: steps.reduce((a, s) => a + s.output_tokens, 0),
    est_cost_usd: steps.reduce((a, s) => a + s.est_cost_usd, 0),
    ms: steps.reduce((a, s) => Math.max(a, s.ms), 0),
  };
}

export function contextLine(subject: string, grade: string): string {
  return [subject && `Ämne: ${subject}`, grade && `Årskurs: ${grade}`].filter(Boolean).join(". ") || "okänt";
}

/** Step 2: the answers in batches of 5 in parallel; a batch that fails or misses a question is asked once more. */
export async function answerItems(
  provider: LLMProvider,
  cfg: DrillConfig,
  items: { id: string; question: string }[],
  ctx: { subject: string; grade: string; notes: string; longWords: number; mayFix?: boolean },
  signal?: AbortSignal,
): Promise<{ items: DrillItem[]; usage: StepUsage }> {
  const steps: StepUsage[] = [];
  const got = new Map<string, { short: string; long: string; question?: string; screen?: Screen }>();
  const lang = examLanguage(ctx.subject);
  const ask = async (batch: { id: string; question: string }[], strict = true) => {
    const r = await runLLM(provider, {
      system: SYSTEM_PROMPT_DRILL_ANSWERS,
      user: `<context>${sanitizeTagged(contextLine(ctx.subject, ctx.grade))}</context>\n<notes>\n${
        sanitizeTagged(ctx.notes || "(inga anteckningar)")
      }\n</notes>\n<long_words>${ctx.longWords}</long_words>${lang ? `\n<language>${lang}</language>` : ""}${
        ctx.mayFix ? "\n<may_fix>yes</may_fix>" : ""
      }\n<questions>${sanitizeTagged(JSON.stringify(batch))}</questions>`,
      maxTokens: Math.min(8000, 400 + batch.length * Math.round(ctx.longWords * 3.2)),
      cacheSystem: true,
      model: cfg.answerModel,
      noThinking: true,
      timeoutMs: 90_000,
      signal,
    }, cfg.answerPriceIn, cfg.answerPriceOut);
    steps.push(r.usage);
    for (const [id, a] of parseAnswers(r.text, strict)) {
      const b = batch.find((x) => x.id === id);
      if (!b) continue;
      // K66: a fixed question only where it may be fixed (generated questions, never the student's own)
      const q = ctx.mayFix && a.question && a.question.toLowerCase() !== b.question.toLowerCase() ? a.question : b.question;
      if (strict && isCircular(q, a.short)) continue; // K66 (O63 punkt 1): asked again; accepted on the last try
      got.set(id, { ...a, question: q !== b.question ? q : undefined });
    }
  };
  const batches: { id: string; question: string }[][] = [];
  for (let i = 0; i < items.length; i += DRILL_LIMITS.batch) batches.push(items.slice(i, i + DRILL_LIMITS.batch));
  const first = await Promise.allSettled(batches.map((x) => ask(x)));
  // K52: missing, empty or cut-off answers are asked again, first in batches, then one by one
  for (const size of [DRILL_LIMITS.batch, 1]) {
    const missing = items.filter((it) => !got.has(it.id));
    if (!missing.length) break;
    const again: { id: string; question: string }[][] = [];
    for (let i = 0; i < missing.length; i += size) again.push(missing.slice(i, i + size));
    await Promise.allSettled(again.map((x) => ask(x, size !== 1)));
  }
  if (!got.size) {
    const err = first.find((r) => r.status === "rejected") as PromiseRejectedResult | undefined;
    if (err) throw err.reason;
    throw new HttpError(502, "drill_failed", "No answers could be written");
  }
  return {
    // an answer that still could not be written says so (the app offers "Gör om"), never an empty answer
    items: items.map((it) => {
      const a = got.get(it.id);
      if (!a) return { ...it, error: "Svaret kunde inte skrivas. Gör om frågan." };
      const out: DrillItem = { ...it, question: a.question ?? it.question, short: a.short, long: a.long };
      // the display question belongs to the question that was answered; dropped when it was fixed without one
      const screen: Screen = { ...(a.screen ?? {}) };
      // K97 (O79 F4): years in words on screen become digits, also when the model gave no display text
      for (const k of ["short", "long"] as const) {
        const shown = yearsToDigits(screen[k] ?? out[k]!);
        if (shown !== out[k]) screen[k] = shown;
      }
      const sq = yearsToDigits(screen.question ?? out.question);
      if (sq !== out.question) screen.question = sq;
      if (screen.question && (screen.question === out.question || (a.question && screen.question === it.question))) delete screen.question;
      if (Object.keys(screen).length) out.screen = screen;
      return out;
    }),
    usage: sumUsage(steps, cfg.answerModel),
  };
}

export function validItems(v: unknown, max: number): { id: string; question: string }[] {
  const out: { id: string; question: string }[] = [];
  const seen = new Set<string>();
  (Array.isArray(v) ? v : []).forEach((x, i) => {
    const o = (x ?? {}) as Record<string, unknown>;
    const question = cleanQuestion(o.question);
    let id = oneLine(o.id, 40) || `q${i + 1}`;
    if (seen.has(id)) id = `${id}-${i + 1}`;
    if (!question) return;
    seen.add(id);
    out.push({ id, question });
  });
  if (!out.length) throw new HttpError(400, "invalid_request", "items: at least one question");
  if (out.length > max) throw new HttpError(400, "invalid_request", `items: at most ${max} questions`);
  return out;
}

// ---------- doc_text: Word (.docx) to text, in code (no library, no model) ----------

const u16 = (b: Uint8Array, o: number) => b[o] | (b[o + 1] << 8);
const u32 = (b: Uint8Array, o: number) => (b[o] | (b[o + 1] << 8) | (b[o + 2] << 16) | (b[o + 3] << 24)) >>> 0;

async function inflateRaw(data: Uint8Array): Promise<Uint8Array> {
  const ds = new DecompressionStream("deflate-raw");
  const out = new Response(new Blob([new Uint8Array(data)]).stream().pipeThrough(ds));
  return new Uint8Array(await out.arrayBuffer());
}

/** One file from a zip archive (stored or deflated), or null. */
export async function unzipEntry(zip: Uint8Array, name: string): Promise<Uint8Array | null> {
  // end of central directory: the last "PK\x05\x06" within the final 64 KiB + 22 bytes
  let eocd = -1;
  for (let i = zip.length - 22; i >= Math.max(0, zip.length - 65_557); i--) {
    if (u32(zip, i) === 0x06054b50) {
      eocd = i;
      break;
    }
  }
  if (eocd < 0) return null;
  const count = u16(zip, eocd + 10);
  let p = u32(zip, eocd + 16);
  const dec = new TextDecoder();
  for (let n = 0; n < count && p + 46 <= zip.length; n++) {
    if (u32(zip, p) !== 0x02014b50) return null;
    const method = u16(zip, p + 10);
    const csize = u32(zip, p + 20);
    const nlen = u16(zip, p + 28), xlen = u16(zip, p + 30), clen = u16(zip, p + 32);
    const local = u32(zip, p + 42);
    const fname = dec.decode(zip.subarray(p + 46, p + 46 + nlen));
    if (fname === name) {
      if (u32(zip, local) !== 0x04034b50) return null;
      const start = local + 30 + u16(zip, local + 26) + u16(zip, local + 28);
      const body = zip.subarray(start, start + csize);
      if (method === 0) return body;
      if (method === 8) return await inflateRaw(body);
      return null;
    }
    p += 46 + nlen + xlen + clen;
  }
  return null;
}

const ENTITIES: Record<string, string> = { amp: "&", lt: "<", gt: ">", quot: '"', apos: "'" };
/** word/document.xml to plain text: one line per paragraph, tabs and line breaks kept. */
export function docxXmlToText(xml: string): string {
  return xml
    .replace(/<w:tab\/>/g, "\t")
    .replace(/<w:br[^>]*\/>/g, "\n")
    .replace(/<\/w:p>/g, "\n")
    .replace(/<[^>]+>/g, "")
    .replace(/&(#x[0-9a-f]+|#\d+|[a-z]+);/gi, (m, e: string) =>
      e[0] === "#" ? String.fromCodePoint(e[1] === "x" || e[1] === "X" ? parseInt(e.slice(2), 16) : parseInt(e.slice(1), 10)) : ENTITIES[e] ?? m)
    .replace(/[ \t]+\n/g, "\n")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

export async function docxText(base64: string): Promise<string> {
  const data = base64.replace(/^data:[^,]+,/, "").replace(/\s+/g, "");
  if (!data) throw new HttpError(400, "invalid_request", "data (base64 .docx) is required");
  if (data.length > DRILL_LIMITS.docxBase64) throw new HttpError(413, "payload_too_large", "The document is larger than 10 MB");
  let bytes: Uint8Array;
  try {
    bytes = Uint8Array.from(atob(data), (c) => c.charCodeAt(0));
  } catch {
    throw new HttpError(400, "invalid_request", "data is not base64");
  }
  const xml = await unzipEntry(bytes, "word/document.xml").catch(() => null);
  if (!xml) throw new HttpError(422, "docx_unreadable", "Det gick inte att läsa Word-filen. Spara den som PDF och försök igen.");
  return docxXmlToText(new TextDecoder().decode(xml)).slice(0, DRILL_LIMITS.text);
}

// ---------- K53: many photos, uploaded one by one ----------

/** The private bucket drill_material: signed upload URLs, reading a photo, deleting after the analysis (B4). */
export interface MaterialStore {
  /** One signed upload URL per path (PUT the image bytes with its content-type), valid for two hours. */
  sign(paths: string[]): Promise<{ path: string; url: string }[]>;
  /** The photo as base64, or null when it is not there. */
  get(path: string): Promise<string | null>;
  remove(paths: string[]): Promise<void>;
}
export const MATERIAL = { maxPhotos: 40, perTranscription: 10, concurrency: 8 };
const MATERIAL_PATH = /^[0-9a-f-]{36}\/[0-9a-f-]{36}\.(?:jpg|png|webp)$/;

/** K53: `{"action":"upload_urls","count":30,"type"?:"jpg"|"png"|"webp"}` -> paths under the user's own folder. */
export async function uploadUrls(userId: string, b: Record<string, unknown>, store: MaterialStore) {
  const n = intIn(b.count, 1, MATERIAL.maxPhotos, 1);
  const ext = b.type === "png" || b.type === "webp" ? b.type : "jpg";
  const paths = Array.from({ length: n }, () => `${userId}/${crypto.randomUUID()}.${ext}`);
  const signed = await store.sign(paths);
  return {
    uploads: signed.map((x) => ({ path: x.path, url: x.url, method: "PUT", content_type: ext === "jpg" ? "image/jpeg" : `image/${ext}` })),
    expires_in: 7200,
  };
}

/** The user's own uploaded photos as images; another account's path or a missing photo is refused. */
export async function materialImages(userId: string, paths: unknown, store: MaterialStore): Promise<{ images: Img[]; paths: string[] }> {
  const list = Array.isArray(paths) ? paths.map(String) : [];
  if (list.length > MATERIAL.maxPhotos) throw new HttpError(400, "invalid_request", `page_paths: at most ${MATERIAL.maxPhotos} photos`);
  for (const p of list) {
    if (!MATERIAL_PATH.test(p) || !p.startsWith(`${userId}/`)) throw new HttpError(403, "forbidden", "Bilden tillhör inte det här kontot.");
  }
  const out: (Img | null)[] = new Array(list.length).fill(null);
  for (let i = 0; i < list.length; i += MATERIAL.concurrency) {
    await Promise.all(list.slice(i, i + MATERIAL.concurrency).map(async (p, k) => {
      const data = await store.get(p);
      if (!data) return;
      const real = sniffImage(data);
      if (real === "unsupported" || real === null) return;
      out[i + k] = { mediaType: real, data };
    }));
  }
  const missing = out.filter((x) => !x).length;
  if (missing) {
    throw new HttpError(422, "material_missing", `${missing} av ${list.length} bilder kom inte fram. Ladda upp dem igen.`);
  }
  return { images: out as Img[], paths: list };
}

export const SYSTEM_PROMPT_DRILL_TRANSCRIBE =
  `You write out study material from photos for a Swedish student. You get page photos (notes, textbook pages, screens, whiteboards). Write out EVERYTHING that is on them, in reading order, as plain text: headings, all body text, every row of a table, formulas as written, and a one-line description of each figure in [brackets]. Keep the original language. No comments, no summary, no markdown. If a page cannot be read at all, write [oläslig sida].`;

/** K53: more than 10 photos are written out as text in parallel batches of 10 (Haiku), then planned from the text. */
export async function transcribe(provider: LLMProvider, cfg: DrillConfig, images: Img[], signal?: AbortSignal) {
  const batches: Img[][] = [];
  for (let i = 0; i < images.length; i += MATERIAL.perTranscription) batches.push(images.slice(i, i + MATERIAL.perTranscription));
  const results = await Promise.all(batches.map((batch, k) =>
    runLLM(provider, {
      system: SYSTEM_PROMPT_DRILL_TRANSCRIBE,
      user: `Write out these ${batch.length} pages (pages ${k * MATERIAL.perTranscription + 1}-${k * MATERIAL.perTranscription + batch.length}).`,
      images: batch,
      maxTokens: 6000,
      cacheSystem: true,
      model: cfg.planModel,
      timeoutMs: 90_000,
      signal,
    }, cfg.planPriceIn, cfg.planPriceOut)
  ));
  return {
    text: results.map((r, k) => `[Sidor ${k * MATERIAL.perTranscription + 1}-${k * MATERIAL.perTranscription + batches[k].length}]\n${r.text.trim()}`).join("\n\n"),
    usage: results.map((r) => r.usage),
  };
}

// ---------- the actions ----------

type Img = { mediaType: "image/jpeg" | "image/png" | "image/webp"; data: string };

/** The image format from the first bytes of base64 data: jpeg, png, webp, "unsupported" (HEIC, GIF, PDF ...) or null. */
export function sniffImage(b64: string): Img["mediaType"] | "unsupported" | null {
  let head: Uint8Array;
  try {
    head = Uint8Array.from(atob(b64.slice(0, 24)), (c) => c.charCodeAt(0));
  } catch {
    return null;
  }
  const at = (i: number, ...xs: number[]) => xs.every((x, k) => head[i + k] === x);
  if (at(0, 0xff, 0xd8, 0xff)) return "image/jpeg";
  if (at(0, 0x89, 0x50, 0x4e, 0x47)) return "image/png";
  if (at(0, 0x52, 0x49, 0x46, 0x46) && at(8, 0x57, 0x45, 0x42, 0x50)) return "image/webp";
  if (at(4, 0x66, 0x74, 0x79, 0x70)) return "unsupported"; // ftyp: HEIC/HEIF/AVIF
  if (at(0, 0x47, 0x49, 0x46) || at(0, 0x25, 0x50, 0x44, 0x46)) return "unsupported"; // GIF, PDF
  return null;
}

export function drillImages(pages: unknown): Img[] {
  const list = Array.isArray(pages) ? pages : [];
  if (list.length > DRILL_LIMITS.pages) throw new HttpError(400, "invalid_request", `pages: at most ${DRILL_LIMITS.pages} images per call`);
  return list.map((p, i) => {
    const o = (p ?? {}) as Record<string, unknown>;
    const mediaType = String(o.media_type ?? "image/jpeg");
    const data = typeof o.data === "string" ? o.data.replace(/^data:[^,]+,/, "") : "";
    if (!["image/jpeg", "image/png", "image/webp"].includes(mediaType) || !data) {
      throw new HttpError(400, "invalid_request", `pages[${i}] needs media_type (jpeg/png/webp) and base64 data`);
    }
    if (data.length > 3 * 1024 * 1024) {
      throw new HttpError(413, "payload_too_large", `Bild ${i + 1} är för stor (högst 3 MB). Förminska bilderna innan de skickas.`);
    }
    // K51 (Aron 22:13): the app labels every page image/jpeg; the real format comes from the first bytes
    const real = sniffImage(data);
    if (real === "unsupported") {
      throw new HttpError(415, "unsupported_image", `Bild ${i + 1} har ett format som inte stöds (till exempel HEIC). Skicka JPEG, PNG eller WebP.`);
    }
    return { mediaType: (real ?? mediaType) as Img["mediaType"], data };
  });
}

/** The cost weight of an action in the exam rate limiter (a drill is several model calls). */
export const DRILL_WEIGHT: Record<string, number> = { drill: 4, drill_answers: 3, drill_one: 1 };

export async function handleDrill(
  action: "drill" | "drill_answers" | "drill_one",
  b: Record<string, unknown>,
  provider: LLMProvider,
  cfg: DrillConfig,
  signal?: AbortSignal,
  material?: { userId: string; store: MaterialStore | null },
): Promise<{ body: Record<string, unknown>; steps: StepUsage[] }> {
  // K53: uploaded photos are read by path and deleted right after the analysis, also when it fails (B4)
  const paths = Array.isArray(b.page_paths) ? b.page_paths : [];
  if (action === "drill" && paths.length) {
    if (!material?.store) throw new HttpError(503, "unconfigured", "Uploads are not configured");
    const got = await materialImages(material.userId, paths, material.store).catch(async (e) => {
      await material.store!.remove(paths.map(String).filter((p) => p.startsWith(`${material.userId}/`))).catch(() => {});
      throw e;
    });
    try {
      return await handleDrill(action, { ...b, page_paths: undefined, uploaded: got.images }, provider, cfg, signal);
    } finally {
      await material.store.remove(got.paths).catch((e) => console.warn("drill_material_remove_failed", e instanceof Error ? e.message : String(e)));
    }
  }
  const longWords = intIn(b.long_words, DRILL_LIMITS.longWordsMin, DRILL_LIMITS.longWordsMax, DRILL_LIMITS.longWordsDefault);
  const subjectIn = oneLine(b.subject, 60);
  const gradeIn = gradeName(oneLine(b.grade, 60));
  if (action === "drill") {
    // K61 (D175): /exam caps the count at what the month has left (may be fewer than questionsMin)
    const cap = Number(b._max_questions);
    const count = Math.min(intIn(b.questions, DRILL_LIMITS.questionsMin, DRILL_LIMITS.questionsMax, DRILL_LIMITS.questionsDefault),
      Number.isFinite(cap) && cap >= 1 ? Math.floor(cap) : Number.MAX_SAFE_INTEGER);
    let images = [...drillImages(b.pages), ...((b.uploaded as Img[] | undefined) ?? [])];
    if (images.length > MATERIAL.maxPhotos) throw new HttpError(400, "invalid_request", `at most ${MATERIAL.maxPhotos} photos`);
    let text = clean(b.text, DRILL_LIMITS.text);
    const transcribed: StepUsage[] = [];
    if (images.length > MATERIAL.perTranscription) {
      // K53: many photos: written out as text in parallel batches first, then planned from the text
      const t = await transcribe(provider, cfg, images, signal);
      text = [text, t.text].filter(Boolean).join("\n\n").slice(0, DRILL_LIMITS.text);
      transcribed.push(...t.usage);
      images = [];
    }
    if (!images.length && !text) throw new HttpError(400, "invalid_request", "pages or text is required");
    const correction = oneLine(b.correction, DRILL_LIMITS.correction);
    const t0 = Date.now();
    // K69: the notes (most of step 1's output, about 2 400 characters) are written in a second call at the same time:
    // the same model, the same system prompt (cached) and the same material, so the questions and the check no longer
    // wait for them. Only the questions decide when "Stämmer det här?" can show.
    const planUser = (part: string) => [
      (subjectIn || gradeIn) && `<context>${sanitizeTagged(contextLine(subjectIn, gradeIn))}</context>`,
      correction && `<correction>${sanitizeTagged(correction)}</correction>`,
      `<count>${count + DRILL_LIMITS.extraQuestions}</count>`,
      text && `<material>\n${sanitizeTagged(text)}\n</material>`,
      images.length ? `Read the ${images.length} page images${text ? " and the material above" : ""}.` : "Read the material above.",
      part,
    ].filter(Boolean).join("\n");
    const planReq = (part: string, maxTokens: number): LLMRequest => ({
      system: SYSTEM_PROMPT_DRILL_PLAN,
      user: planUser(part),
      ...(images.length ? { images } : {}),
      maxTokens,
      cacheSystem: true,
      model: cfg.planModel,
      timeoutMs: 120_000,
      signal,
    });
    const notesCall = runLLM(provider, planReq(PART_NOTES, 3500), cfg.planPriceIn, cfg.planPriceOut);
    notesCall.catch(() => {}); // awaited below; never an unhandled rejection while the questions run
    let plan = await runLLM(provider, planReq(PART_QUESTIONS, 1500 + (count + DRILL_LIMITS.extraQuestions) * 60), cfg.planPriceIn, cfg.planPriceOut);
    let p = parsePlan(plan.text, Number.MAX_SAFE_INTEGER); // all candidates; trimmed after shortening
    if (!p.questions.length && !p.unreadable) {
      // K69 live (10 photos: a reply with no questions and no reason): the one-call plan as before, never a false 422
      console.warn("drill_questions_part_empty", JSON.stringify({ images: images.length, reply_chars: plan.text.length }));
      plan = await runLLM(provider, planReq("", 4000 + (count + DRILL_LIMITS.extraQuestions) * 40), cfg.planPriceIn, cfg.planPriceOut);
      p = parsePlan(plan.text, Number.MAX_SAFE_INTEGER);
    }
    if (!p.questions.length) {
      // K51 (Aron 22:12, two photos of a screen: 502 after 4 s): not a server error; say why, log only the reason
      console.warn("drill_unreadable", JSON.stringify({ images: images.length, text_chars: text.length, reply_chars: plan.text.length,
        reason: p.unreadable?.slice(0, 120) ?? null, in: plan.usage.input_tokens, out: plan.usage.output_tokens }));
      throw new HttpError(422, "drill_unreadable",
        `${p.unreadable ?? "Det gick inte att läsa materialet."} Fotografera rakt ovanifrån i bra ljus, eller klistra in texten.`);
    }
    // D159: never more questions than the material carries
    const possible = Math.max(1, Math.min(count, p.questionsPossible ?? count, p.questions.length));
    const summary = { subject: p.summary.subject || subjectIn, grade: gradeIn && !correction ? gradeIn : p.summary.grade || gradeIn, covers: p.summary.covers };
    const [sh, notesRun] = await Promise.all([
      shortenQuestions(provider, cfg, p.questions, summary, signal, text),
      notesCall.catch(async () => await runLLM(provider, planReq(PART_NOTES, 3500), cfg.planPriceIn, cfg.planPriceOut)), // once more
    ]);
    // the notes call's reply; an old-style reply with notes in the questions call is kept (never both empty)
    p.notes = clean(firstJson(notesRun.text)?.notes, DRILL_LIMITS.notes) || p.notes;
    const steps = [...transcribed, plan.usage, notesRun.usage, ...(sh.usage ? [sh.usage] : [])];
    // K83 (D206) + K86 (D207): the questions are spread over the whole material, decided in code. The material's own
    // text (else the notes, which follow its order) is cut into equal parts; each part gets a share by its length
    // (at most half from one part when there are three or more); the code's own cap (1 per 600 characters, at most
    // what was asked) applies when the model's questions_possible is lower. Step 1's spare candidates fill the shares
    // first; a part still short gets a call of its own. Every question passes the same checks (cleanQuestion, no
    // question that leans on the material, no duplicate).
    const material = (text || p.notes || "").trim();
    const before = trimQuestions(sh.questions, possible);
    const target = material ? Math.max(possible, codeCap(material.length, count)) : possible;
    // O79 F1 (Oscar): the material's own sections (headings, else paragraphs) are the parts; length only as a fallback
    const sections = sectionParts(material, target);
    const byLength = partCount(material.length, target);
    const parts = sections ?? (byLength > 1 ? splitParts(material, byLength) : [material]);
    const k = parts.length;
    let qs = before;
    let qParts: number[] = before.map(() => -1);
    let fcRefill: StepUsage | null = null;
    let cov: { parts: number; by: "sections" | "length"; before: number; after: number; added: number; target: number; max_share: number } | null = null;
    if (material && (k > 1 || target > before.length)) {
      const weak = (q: string) => (leansOnMaterial(q) ? 2 : 0) + (isRecall(q) ? 1 : 0);
      // candidates: step 1's (shortened) questions, the weak ones last within their part
      const cands = sh.questions.filter((q) => !leansOnMaterial(q));
      const placedAll = k > 1 ? placeQuestions(cands, parts) : cands.map(() => 0);
      const order = cands.map((_, i) => i).sort((x, y) => (placedAll[x] - placedAll[y]) || (weak(cands[x]) - weak(cands[y])) || (x - y));
      const share = shares(parts.map((t) => t.length), target);
      const al = allocate(order.map((i) => placedAll[i]), share);
      const chosen: { q: string; part: number }[] = al.keep.map((j) => ({ q: cands[order[j]], part: placedAll[order[j]] }));
      const seen = new Set(chosen.map((c) => c.q.toLowerCase()));
      const beforeCovered = k > 1 ? coverage(before, parts).covered : 1;
      let added = 0;
      const short = al.need.map((n, i) => ({ n, i })).filter((x) => x.n > 0);
      if (short.length) {
        const got = await Promise.all(short.map(async ({ n, i }) => {
          const r = await runLLM(provider, {
            system: SYSTEM_PROMPT_DRILL_PLAN,
            user: [
              (summary.subject || summary.grade) && `<context>${sanitizeTagged(contextLine(summary.subject, summary.grade))}</context>`,
              `<count>${n + 1}</count>`,
              `<material>\n${sanitizeTagged(parts[i])}\n</material>`,
              k > 1 ? "Read the material above (one part of a longer material: ask only about this part)." : "Read the material above.",
              // K97 (O79): the questions already chosen, so this part's questions never ask the same thing again
              chosen.length ? `<already_asked>${sanitizeTagged(JSON.stringify(chosen.map((c) => c.q)))}</already_asked>\nNever ask anything these questions already ask, in any words; a question whose answer would be the same as one of theirs is wrong.` : "",
              PART_QUESTIONS,
            ].filter(Boolean).join("\n"),
            maxTokens: 300 + (n + 1) * 80,
            cacheSystem: true,
            model: cfg.planModel,
            timeoutMs: 60_000,
            signal,
          }, cfg.planPriceIn, cfg.planPriceOut).catch(() => null);
          if (!r) return [];
          steps.push(r.usage);
          const out: { q: string; part: number }[] = [];
          for (const q of parsePlan(r.text, n + 1).questions) {
            if (out.length >= n || leansOnMaterial(q) || seen.has(q.toLowerCase())) continue;
            // the same question in other words as one already chosen (or another call's) is not a new question
            if (chosen.some((c) => nearDuplicate(c.q, q)) || out.some((c) => nearDuplicate(c.q, q))) continue;
            seen.add(q.toLowerCase());
            out.push({ q, part: i });
          }
          return out;
        }));
        for (const g of got) (chosen.push(...g), added += g.length);
      }
      // calls that came back short: fill with the dropped candidates (within the half cap first, then any)
      const capPer = parts.length >= 3 ? Math.max(1, Math.floor(target / 2)) : target;
      const per = (p: number) => chosen.filter((c) => c.part === p).length;
      for (const pass of [true, false]) {
        for (const j of al.dropped) {
          if (chosen.length >= target) break;
          const q = cands[order[j]], part = placedAll[order[j]];
          if (chosen.some((c) => c.q === q || nearDuplicate(c.q, q)) || (pass && part >= 0 && per(part) >= capPer)) continue;
          chosen.push({ q, part });
        }
      }
      // the material's order: by part, then as they came
      const sorted = chosen.map((c, i) => ({ ...c, i })).sort((x, y) => ((x.part < 0 ? 1e9 : x.part) - (y.part < 0 ? 1e9 : y.part)) || x.i - y.i);
      if (sorted.length) (qs = sorted.map((c) => c.q), qParts = sorted.map((c) => c.part));
      const counts = parts.map((_, i) => sorted.filter((c) => c.part === i).length);
      cov = { parts: parts.length, by: sections ? "sections" : "length", before: beforeCovered, after: counts.filter((n) => n > 0).length, added, target, max_share: Math.max(...counts) };
    }
    // the last check of the finished list against the material (claims, why without a cause, same answer)
    const fc = material ? await finalCheck(provider, cfg, qs, qParts, material, signal) : null;
    let refilled = 0;
    if (fc) {
      qs = fc.questions;
      qParts = fc.parts;
      if (fc.usage) steps.push(fc.usage);
      // D230 (2): the removed duplicates are made up for, placed in the part they draw on (the material's order)
      if (fc.dropped > 0) {
        const rf = await refillQuestions(provider, cfg, qs, fc.dropped, material, signal);
        if (rf.usage) steps.push(rf.usage);
        if (rf.questions.length) {
          const at = parts.length > 1 ? placeQuestions(rf.questions, parts) : rf.questions.map(() => 0);
          const all = [...qs.map((q, i) => ({ q, part: qParts[i] ?? -1, i })), ...rf.questions.map((q, k) => ({ q, part: at[k], i: qs.length + k }))];
          all.sort((x, y) => ((x.part < 0 ? 1e9 : x.part) - (y.part < 0 ? 1e9 : y.part)) || x.i - y.i);
          qs = all.map((x) => x.q);
          qParts = all.map((x) => x.part);
          refilled = rf.questions.length;
        }
        fcRefill = rf.usage;
      }
    }
    const base = qs.map((question, i) => ({ id: `q${i + 1}`, question }));
    let items: DrillItem[] = base;
    let answers: StepUsage | null = null;
    if (b.answers !== false) {
      const r = await answerItems(provider, cfg, base, { subject: summary.subject, grade: summary.grade, notes: p.notes, longWords, mayFix: true }, signal);
      items = r.items;
      answers = r.usage;
      steps.push(r.usage);
    }
    return {
      body: {
        summary,
        notes: p.notes,
        questions_asked: count,
        questions_possible: base.length,
        ...(base.length < count ? { note: `Materialet räckte till ${base.length} ${base.length === 1 ? "fråga" : "frågor"}.` } : {}),
        items,
        long_words: longWords,
        usage: {
          ...(transcribed.length ? { transcribe: sumUsage(transcribed, cfg.planModel ?? "default") } : {}),
          plan: plan.usage,
          notes: notesRun.usage,
          ...(sh.usage ? { shorten: sh.usage } : {}),
          ...(answers ? { answers } : {}),
          ...(cov ? { coverage: cov } : {}),
          ...(fc?.usage ? { final_check: { ...fc.usage, fixed: fc.fixed, dropped: fc.dropped, refilled, ...(fcRefill ? { refill_ms: fcRefill.ms } : {}), understanding: qs.filter(isUnderstanding).length, questions: qs.length } } : {}),
          est_cost_usd: steps.reduce((n, u) => n + u.est_cost_usd, 0), // K83: the coverage calls included
          ms: Date.now() - t0,
        },
      },
      steps,
    };
  }
  const items = action === "drill_one"
    ? validItems([{ id: b.id, question: b.question }], 1)
    : validItems(b.items, DRILL_LIMITS.questionsMax);
  const notes = clean(b.notes, DRILL_LIMITS.notes);
  // K67 (O64): the app's path (drill with answers false, then drill_answers) may let generated questions be fixed too
  const mayFix = action === "drill_answers" && b.may_fix === true;
  const r = await answerItems(provider, cfg, items, { subject: subjectIn, grade: gradeIn, notes, longWords, mayFix }, signal);
  const usage = { answers: r.usage, est_cost_usd: r.usage.est_cost_usd };
  return {
    body: action === "drill_one" ? { item: r.items[0], long_words: longWords, usage } : { items: r.items, long_words: longWords, usage },
    steps: [r.usage],
  };
}
