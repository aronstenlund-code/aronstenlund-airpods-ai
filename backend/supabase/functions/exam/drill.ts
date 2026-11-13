import { HttpError } from "../_shared/errors.ts";
import { sanitizeTagged } from "../answer/prompt.ts";
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
  /** R3: at most 8 words per question (5 or fewer preferred). */
  questionWordsMax: 8,
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
- questions: the number asked for in <count>, or fewer when questions_possible is lower: then exactly questions_possible plus at most 6 extra (the longest are removed afterwards, so make most of them short). Never pad with repeated, trivial or outside questions to reach the number. In Swedish, in the material's order, spread over ALL parts of the material in proportion to how much the material says about each. Each question:
  - short: at least four of every five questions have five words or fewer (count them: "Varför behövs klorofyll?" is three). Six to eight words only for a calculation question or when fewer words would not make sense when the question is only HEARD, with no text in front of the student. Never a fragment that needs the material to make sense ("Vad säger m?", "Mol metan i 16 g?" are wrong; "Vad visar m i en rät linje?", "Hur många mol är 16 gram metan?" are right). Cut filler such as "i naturen", "egentligen", "det att";
  - written as it is said: no symbols, formulas, units or abbreviations as signs ("syre", not "O2"; "kubikdecimeter", not "dm³"; "procent", not "%");
  - tests understanding, not only recall: at least three of every four questions ask why, how, what happens if, or compare ("Varför behövs klorofyll?", "Hur bildas en näringsväv?", "Vad händer om pH sjunker?", "Skillnad mellan väder och klimat?"); "Vad är X?", "Vad betyder X?" or "Vilka ...?" at most one in five, only for a key term the material defines;
  - is answered by the material (never a question the material does not cover, never a fact from outside it);
  - a real exam question a teacher would ask: no yes/no, no multiple choice, no "enligt texten", no page or task numbers, no question about the material itself;
  - different from every other question (no two that ask the same thing).
- When <correction> is given, it is the student's correction of your reading (subject, grade or what the exam covers): follow it.
No markdown, no other text.`;

export const SYSTEM_PROMPT_DRILL_ANSWERS =
  `You write the answers a Swedish student will listen to in their AirPods while revising for an exam. You get <context> (subject and grade), <notes> (the study material), <long_words> and <questions> (JSON: id and question). Return ONLY a JSON object {"answers": [{"id": "q1", "short": "...", "rest": "..."}]} with one entry per question, in the same order.
- "short": the short answer (D162): ONE sentence, two only when one cannot hold it, at most 25 words, that on its own is a full, correct A-level answer: it states the answer itself (the cause, the mechanism, the fact, the difference), never an introduction that only names the topic. Wrong: "Fotosyntes är en viktig process i växterna." Right: "Växten använder ljusenergi för att bygga glukos av koldioxid och vatten, och syre blir över."
- "rest": what follows the short answer so that short + rest together is the long answer, a full A-level exam answer for that grade: it builds on the short answer with the concepts, the explanation, how things connect (cause and effect, compare) and a concrete example when it helps. Never repeat or rephrase the short answer. Short + rest together are about <long_words> words or fewer (count them); go over only when the answer would otherwise miss a concept or connection an A-level answer needs, and then by at most a fifth. Never pad an answer to reach the number.
- The grade never lowers the quality; it only decides which concepts are reasonable (no university concepts in åk 7-9).
- Base the answers on <notes>. Add school knowledge only where the notes are too thin, only facts you are certain of (textbook-level, widely known), and never contradict the notes; leave out a detail rather than guess it (O55: "stäppgräs har korta rötter" was wrong). Every fact must be correct: work every number out before you write it. Never add history, causes or examples the question did not ask for.
- The text is read aloud: plain spoken Swedish sentences, no markdown, lists, headings, brackets, abbreviations or symbols. Write chemical formulas and symbols in words ("koldioxid", not "CO2"; "pi", not "π"). Never mention the notes, the material, the exam or the grade.
No other text.`;

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
}
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
    if (!c || words(c) > DRILL_LIMITS.questionWordsMax || seen.has(key)) continue;
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
  const score = (q: string) => (leansOnMaterial(q) ? 200 : 0) + (isRecall(q) ? 100 : 0) + (words(q) > 5 ? 50 : 0) + words(q);
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
- Wrong or clumsy Swedish is fixed ("Vad jämför man nysvenska och fornsvenska?" -> "Hur skiljer sig nysvenska från fornsvenska?").
- Never make a question longer for any other reason; five words or fewer whenever it stays clear.
- Make each question five words or fewer when it stays clear and unambiguous within THIS exam: drop what the exam's subject already makes obvious and filler ("Varför är bönen viktig för muslimer?" -> "Varför ber muslimer?" in an exam on Islam; but keep "enligt buddhismen" when the exam covers several religions and the question would otherwise be unclear).
- The question must still ask the same thing: a why-question stays a why-question, the same concept, the same numbers in a calculation.
- A calculation question keeps its numbers and units, written as words or plain digits as given; never symbols.
- If a question cannot be made five words or fewer without becoming unclear, return it unchanged.
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
): Promise<{ questions: string[]; usage: StepUsage | null }> {
  const long = questions.map((q, i) => ({ i, q }));
  if (!long.length) return { questions, usage: null };
  try {
    const r = await runLLM(provider, {
      system: SYSTEM_PROMPT_DRILL_SHORTEN,
      user: `<exam>${sanitizeTagged(`${contextLine(exam.subject, exam.grade)}. ${exam.covers}`)}</exam>
<questions>${sanitizeTagged(JSON.stringify(long))}</questions>`,
      maxTokens: 300 + long.length * 30,
      cacheSystem: true,
      model: cfg.planModel,
      timeoutMs: 30_000,
      signal,
    }, cfg.planPriceIn, cfg.planPriceOut);
    const out = [...questions];
    const j = firstJson(r.text);
    for (const x of Array.isArray(j?.questions) ? j!.questions as Record<string, unknown>[] : []) {
      const i = Number(x?.i);
      const q = cleanQuestion(x?.q);
      if (!Number.isInteger(i) || i < 0 || i >= out.length || !q) continue;
      // K52 live: rewrites that only made questions longer cost R3 (65 % at most five words). A longer rewrite is kept
      // only when the original had signs or leaned on the material; otherwise only a shorter or equal one.
      const mayGrow = /[=+*/^²³%<>]|\d/.test(out[i]) || leansOnMaterial(out[i]);
      if (words(q) >= 2 && words(q) <= DRILL_LIMITS.questionWordsMax && (mayGrow || words(q) <= words(out[i])) && !leansOnMaterial(q) &&
        !out.some((o, k) => k !== i && o.toLowerCase() === q.toLowerCase())) out[i] = q;
    }
    return { questions: out, usage: r.usage };
  } catch (e) {
    console.warn("drill_shorten_failed", e instanceof Error ? e.message.slice(0, 120) : String(e));
    return { questions, usage: null };
  }
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

export function parseAnswers(text: string, strict = false): Map<string, { short: string; long: string }> {
  const out = new Map<string, { short: string; long: string }>();
  const j = firstJson(text);
  for (const a of Array.isArray(j?.answers) ? j!.answers as Record<string, unknown>[] : []) {
    const id = oneLine(a?.id, 40);
    let short = spokenText(a?.short, 600);
    const rest = spokenText(a?.rest, 3000);
    // K52 (O55: one empty answer): an empty, one-word or cut-off answer is not accepted; the question is asked again
    if (!id || words(short) < 2 || (rest && !/[.!?]["”')]?$/.test(rest))) continue;
    if (strict && isIntroShort(short)) continue; // K54: asked again; accepted on the last try rather than no answer
    if (!/[.!?]$/.test(short)) short += ".";
    out.set(id, { short, long: composeLong(short, rest) });
  }
  return out;
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
  ctx: { subject: string; grade: string; notes: string; longWords: number },
  signal?: AbortSignal,
): Promise<{ items: DrillItem[]; usage: StepUsage }> {
  const steps: StepUsage[] = [];
  const got = new Map<string, { short: string; long: string }>();
  const ask = async (batch: { id: string; question: string }[], strict = true) => {
    const r = await runLLM(provider, {
      system: SYSTEM_PROMPT_DRILL_ANSWERS,
      user: `<context>${sanitizeTagged(contextLine(ctx.subject, ctx.grade))}</context>\n<notes>\n${
        sanitizeTagged(ctx.notes || "(inga anteckningar)")
      }\n</notes>\n<long_words>${ctx.longWords}</long_words>\n<questions>${sanitizeTagged(JSON.stringify(batch))}</questions>`,
      maxTokens: Math.min(8000, 400 + batch.length * Math.round(ctx.longWords * 3.2)),
      cacheSystem: true,
      model: cfg.answerModel,
      noThinking: true,
      timeoutMs: 90_000,
      signal,
    }, cfg.answerPriceIn, cfg.answerPriceOut);
    steps.push(r.usage);
    for (const [id, a] of parseAnswers(r.text, strict)) if (batch.some((b) => b.id === id)) got.set(id, a);
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
    items: items.map((it) => got.has(it.id) ? { ...it, ...got.get(it.id)! } : { ...it, error: "Svaret kunde inte skrivas. Gör om frågan." }),
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
    const count = intIn(b.questions, DRILL_LIMITS.questionsMin, DRILL_LIMITS.questionsMax, DRILL_LIMITS.questionsDefault);
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
    const plan = await runLLM(provider, {
      system: SYSTEM_PROMPT_DRILL_PLAN,
      user: [
        (subjectIn || gradeIn) && `<context>${sanitizeTagged(contextLine(subjectIn, gradeIn))}</context>`,
        correction && `<correction>${sanitizeTagged(correction)}</correction>`,
        `<count>${count + DRILL_LIMITS.extraQuestions}</count>`,
        text && `<material>\n${sanitizeTagged(text)}\n</material>`,
        images.length ? `Read the ${images.length} page images${text ? " and the material above" : ""}.` : "Read the material above.",
      ].filter(Boolean).join("\n"),
      ...(images.length ? { images } : {}),
      maxTokens: 4000 + (count + DRILL_LIMITS.extraQuestions) * 40,
      cacheSystem: true,
      model: cfg.planModel,
      timeoutMs: 120_000,
      signal,
    }, cfg.planPriceIn, cfg.planPriceOut);
    const p = parsePlan(plan.text, Number.MAX_SAFE_INTEGER); // all candidates; trimmed after shortening
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
    const sh = await shortenQuestions(provider, cfg, p.questions, summary, signal);
    const base = trimQuestions(sh.questions, possible).map((question, i) => ({ id: `q${i + 1}`, question }));
    const steps = [...transcribed, plan.usage, ...(sh.usage ? [sh.usage] : [])];
    let items: DrillItem[] = base;
    let answers: StepUsage | null = null;
    if (b.answers !== false) {
      const r = await answerItems(provider, cfg, base, { subject: summary.subject, grade: summary.grade, notes: p.notes, longWords }, signal);
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
          ...(sh.usage ? { shorten: sh.usage } : {}),
          ...(answers ? { answers } : {}),
          est_cost_usd: transcribed.reduce((n, u) => n + u.est_cost_usd, 0) + plan.usage.est_cost_usd + (sh.usage?.est_cost_usd ?? 0) + (answers?.est_cost_usd ?? 0),
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
  const r = await answerItems(provider, cfg, items, { subject: subjectIn, grade: gradeIn, notes, longWords }, signal);
  const usage = { answers: r.usage, est_cost_usd: r.usage.est_cost_usd };
  return {
    body: action === "drill_one" ? { item: r.items[0], long_words: longWords, usage } : { items: r.items, long_words: longWords, usage },
    steps: [r.usage],
  };
}
