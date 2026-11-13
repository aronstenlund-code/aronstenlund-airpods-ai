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
  extraQuestions: 4,
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
{"summary": {"subject": "Biologi", "grade": "åk 8", "covers": "..."}, "notes": "...", "questions": ["Varför behövs klorofyll?", "..."]}
- summary: "subject" the school subject in Swedish; "grade" the school year or course as Swedes say it ("åk 8", "Matematik 1b", "Svenska 1"), from <context> when given, else your best reading of the material; "covers" one or two Swedish sentences on what the exam covers (the main areas, in order).
- notes: every fact, concept, definition, formula, date, name, cause and example in the material, as compact Swedish plain text in the material's order (at most about 900 words). Only what the material says; the answers are written from these notes.
- questions: exactly the number asked for in <count> (the longest are removed afterwards, so make most of them short), in Swedish, in the material's order, spread over ALL parts of the material in proportion to how much the material says about each. Each question:
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
- "short": the short answer: one or two sentences (at most about 30 words) that answer the question correctly and completely on their own.
- "rest": what follows the short answer so that short + rest together is the long answer, a full A-level exam answer for that grade: the right concepts, the explanation, how things connect (cause and effect, compare) and a concrete example when it helps. Do not repeat the short answer. Short + rest together are about <long_words> words or fewer (count them); go over only when the answer would otherwise miss a concept or connection an A-level answer needs, and then by at most a fifth. Never pad an answer to reach the number.
- The grade never lowers the quality; it only decides which concepts are reasonable (no university concepts in åk 7-9).
- Base the answers on <notes>; add well-established school knowledge only where the notes are too thin, and never contradict them. Every fact must be correct: work every number out before you write it.
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

/** A question that asks only for a fact or a definition (R3 wants at least 70 % understanding questions). */
export function isRecall(q: string): boolean {
  return /^(?:vad (?:är|var|heter|betyder|kallas|står)|vilk(?:a|en|et) |när |vem |vilket år|enhet för|nämn )/i.test(q.trim());
}

/** Step 1 reply: the summary, the notes and at most `count` questions within the word limit (R3), no duplicates. */
export function parsePlan(text: string, count: number): { summary: DrillSummary; notes: string; questions: string[] } {
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
  // R3 (live 2026-11-13: 8 of 19 at most five words, then 59 of 100 understanding questions): the model writes a few
  // extra; plain recall questions go first, then the longest; the order stays
  const score = (q: string) => (isRecall(q) ? 100 : 0) + (words(q) > 5 ? 50 : 0) + words(q);
  while (questions.length > count) {
    let worst = 0;
    questions.forEach((q, i) => {
      if (score(q) >= score(questions[worst])) worst = i;
    });
    questions.splice(worst, 1);
  }
  return {
    summary: { subject: oneLine(s.subject, 60), grade: oneLine(s.grade, 60), covers: oneLine(s.covers, 400) },
    notes: clean(j.notes, DRILL_LIMITS.notes),
    questions,
  };
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

export function parseAnswers(text: string): Map<string, { short: string; long: string }> {
  const out = new Map<string, { short: string; long: string }>();
  const j = firstJson(text);
  for (const a of Array.isArray(j?.answers) ? j!.answers as Record<string, unknown>[] : []) {
    const id = oneLine(a?.id, 40);
    let short = spokenText(a?.short, 600);
    if (short && !/[.!?]$/.test(short)) short += ".";
    const long = composeLong(short, spokenText(a?.rest, 3000));
    if (id && short) out.set(id, { short, long });
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
  const ask = async (batch: { id: string; question: string }[]) => {
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
    for (const [id, a] of parseAnswers(r.text)) if (batch.some((b) => b.id === id)) got.set(id, a);
  };
  const batches: { id: string; question: string }[][] = [];
  for (let i = 0; i < items.length; i += DRILL_LIMITS.batch) batches.push(items.slice(i, i + DRILL_LIMITS.batch));
  const first = await Promise.allSettled(batches.map(ask));
  const missing = items.filter((it) => !got.has(it.id));
  if (missing.length) {
    const again: { id: string; question: string }[][] = [];
    for (let i = 0; i < missing.length; i += DRILL_LIMITS.batch) again.push(missing.slice(i, i + DRILL_LIMITS.batch));
    await Promise.allSettled(again.map(ask));
  }
  if (!got.size) {
    const err = first.find((r) => r.status === "rejected") as PromiseRejectedResult | undefined;
    if (err) throw err.reason;
    throw new HttpError(502, "drill_failed", "No answers could be written");
  }
  return {
    items: items.map((it) => ({ ...it, ...(got.get(it.id) ?? {}) })),
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

// ---------- the actions ----------

type Img = { mediaType: "image/jpeg" | "image/png" | "image/webp"; data: string };

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
    if (data.length > 3 * 1024 * 1024) throw new HttpError(413, "payload_too_large", `pages[${i}] is larger than 3 MB`);
    return { mediaType: mediaType as Img["mediaType"], data };
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
): Promise<{ body: Record<string, unknown>; steps: StepUsage[] }> {
  const longWords = intIn(b.long_words, DRILL_LIMITS.longWordsMin, DRILL_LIMITS.longWordsMax, DRILL_LIMITS.longWordsDefault);
  const subjectIn = oneLine(b.subject, 60);
  const gradeIn = oneLine(b.grade, 60);
  if (action === "drill") {
    const count = intIn(b.questions, DRILL_LIMITS.questionsMin, DRILL_LIMITS.questionsMax, DRILL_LIMITS.questionsDefault);
    const images = drillImages(b.pages);
    const text = clean(b.text, DRILL_LIMITS.text);
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
    const p = parsePlan(plan.text, count);
    if (!p.questions.length) throw new HttpError(502, "drill_unreadable", "No questions could be made from this material");
    const summary = { subject: p.summary.subject || subjectIn, grade: gradeIn && !correction ? gradeIn : p.summary.grade || gradeIn, covers: p.summary.covers };
    const base = p.questions.map((question, i) => ({ id: `q${i + 1}`, question }));
    const steps = [plan.usage];
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
        items,
        long_words: longWords,
        usage: {
          plan: plan.usage,
          ...(answers ? { answers } : {}),
          est_cost_usd: plan.usage.est_cost_usd + (answers?.est_cost_usd ?? 0),
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
