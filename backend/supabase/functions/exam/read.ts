import { HttpError } from "../_shared/errors.ts";
import { sanitizeTagged } from "../answer/prompt.ts";
import type { LLMProvider } from "../answer/llm/types.ts";
import {
  clean,
  type DrillConfig,
  examLanguage,
  drillImages,
  gradeName,
  MATERIAL,
  type MaterialStore,
  materialImages,
  runLLM,
  type StepUsage,
  sumUsage,
} from "./drill.ts";

/**
 * K72 (O67 fynd 1): the language a text is READ in, from the text itself (a history text in English is read in
 * English), with the subject as the tie-break. "" = Swedish (as examLanguage), otherwise "English".
 */
export function textLanguage(text: string, subject = ""): string {
  const w = text.toLowerCase().match(/\p{L}+/gu) ?? [];
  const EN = new Set(["the", "and", "of", "to", "in", "is", "was", "that", "with", "for", "are", "were", "it", "this", "by", "from"]);
  const SV = new Set(["och", "att", "det", "som", "en", "är", "på", "av", "för", "med", "till", "var", "den", "har", "inte", "om"]);
  let en = 0, sv = 0;
  for (const x of w) {
    if (EN.has(x)) en++;
    if (SV.has(x)) sv++;
  }
  if (en >= 5 && en > 2 * sv) return "English";
  if (sv >= 5 && sv > 2 * en) return "";
  return examLanguage(subject);
}

/**
 * K70 (D185): Läsläget. `POST /exam {"action":"read", "pages"?|"page_paths"?|"text"?, "subject"?, "grade"?, "title"?}`
 *   -> {"kind":"text", "title", "subject", "grade", "parts": [{"kind":"heading"|"para", "text"}], "chars", "counts_as",
 *       "usage"}
 * The material cleaned for reading aloud: headings kept as headings, page numbers, running heads and footers gone, OCR
 * errors (broken words, hyphenation, stray characters) mended, nothing shortened, summarised or added. Photos are read
 * in parallel batches, text in parallel chunks (Haiku, the same model as step 1). Nothing is stored here (B4): the app
 * saves the parts with `/drill save` and `"kind":"text"`, which makes the audio (one file per part, sentence times).
 */
export const READ_LIMITS = {
  /** characters sent per text call (the reply is about as long as the input) */
  chunk: 6000,
  /** photos per call */
  pagesPerCall: 4,
  /** the cleaned text, in all (D185 quota: every started 800 characters = one question) */
  maxChars: 40_000,
  /** one part (paragraph) at most; a longer paragraph is split at a sentence end */
  partChars: 1500,
  parts: 150,
};

export const SYSTEM_PROMPT_READ =
  `You prepare study material to be READ ALOUD, word for word, to a Swedish student in their AirPods. You get page photos or text (notes, textbook pages, a document). Write out the material's running text in reading order, cleaned for listening:
- Keep every sentence of the content, in the original language and wording. Never shorten, summarise, explain, translate, reorder or add anything.
- Remove what is not content: page numbers, running heads and footers repeated on pages, "Sida 3 av 8", URLs in footers, copyright lines, image credits, exercise numbers standing alone.
- Mend reading errors: words broken by hyphenation at a line end ("foto-\\nsyntes" -> "fotosyntes"), lines broken inside a sentence, OCR mistakes with an obvious right word ("fotosyntcs" -> "fotosyntes", "0" for "O" in words), stray characters. Never change a fact, a number or a name.
- A heading (a chapter or section title) on its own line, starting with "# ". Body text as paragraphs separated by one empty line. A list becomes sentences in a paragraph (each item its own sentence, ending with a period).
- A table: each row as one sentence ("Måndag: 12 grader."). A figure or image: skip it, unless it holds text that is part of the content.
- Plain text only: no markdown other than "# " for headings, no bullets, no comments about the material.
If nothing can be read at all, write only: [oläslig]`;

export interface ReadPart {
  kind: "heading" | "para";
  text: string;
}

/** Sentences of a paragraph: a sentence end is . ! ? (or …) followed by a space and a capital letter, digit or quote. */
export function sentences(text: string): string[] {
  const t = text.replace(/\s+/g, " ").trim();
  if (!t) return [];
  const out: string[] = [];
  // not after common Swedish abbreviations or a single letter/number ("t.ex.", "bl.a.", "s. 4", "1. ")
  const abbr = /(?:\b(?:t\.ex|bl\.a|m\.m|s\.k|d\.v\.s|dvs|ca|kap|nr|jfr|f\.d|e\.Kr|f\.Kr|t\.o\.m|fr\.o\.m|resp|vs|Dr|Mr|Mrs|St)\.|\b\p{L}\.|\b\d{1,3}\.)$/u;
  let start = 0;
  const re = /[.!?…]+["”»)]*(?=\s+["“«(]?[\p{Lu}\d])/gu;
  let m: RegExpExecArray | null;
  while ((m = re.exec(t))) {
    const end = m.index + m[0].length;
    if (abbr.test(t.slice(start, m.index + 1))) continue;
    out.push(t.slice(start, end).trim());
    start = end;
  }
  const rest = t.slice(start).trim();
  if (rest) out.push(rest);
  return out.filter(Boolean);
}

/** The model's plain text to parts: "# " lines are headings, empty lines end a paragraph; long paragraphs split. */
export function parseRead(text: string): ReadPart[] {
  const parts: ReadPart[] = [];
  let para: string[] = [];
  const flush = () => {
    const p = para.join(" ").replace(/\s+/g, " ").trim();
    para = [];
    if (!p) return;
    // a paragraph longer than partChars is split at sentence ends (one audio file per part)
    let cur = "";
    for (const s of sentences(p)) {
      if (cur && cur.length + 1 + s.length > READ_LIMITS.partChars) {
        parts.push({ kind: "para", text: cur });
        cur = s;
      } else cur = cur ? `${cur} ${s}` : s;
    }
    while (cur.length > READ_LIMITS.partChars) {
      // one sentence longer than a part (rare): cut at a space
      const cut = cur.lastIndexOf(" ", READ_LIMITS.partChars);
      parts.push({ kind: "para", text: cur.slice(0, cut > 0 ? cut : READ_LIMITS.partChars) });
      cur = cur.slice(cut > 0 ? cut + 1 : READ_LIMITS.partChars);
    }
    if (cur) parts.push({ kind: "para", text: cur });
  };
  for (const raw of text.replace(/\r/g, "").split("\n")) {
    const line = raw.trim();
    if (/^\[oläslig( sida)?\]$/i.test(line)) continue;
    const h = /^#{1,6}\s+(.+)$/.exec(line);
    if (h) {
      flush();
      const t = h[1].replace(/[#*_]+/g, "").trim().slice(0, 300);
      if (t) parts.push({ kind: "heading", text: t });
    } else if (!line) flush();
    else para.push(line.replace(/^[-•*]\s+/, "").replace(/\*\*/g, ""));
  }
  flush();
  // the same heading repeated right after itself (running heads that slipped through) only once
  return parts.filter((p, i) => !(p.kind === "heading" && i > 0 && parts[i - 1].kind === "heading" && parts[i - 1].text === p.text));
}

/** Text chunks of about `max` characters, cut at a paragraph or line break. */
export function chunks(text: string, max = READ_LIMITS.chunk): string[] {
  const out: string[] = [];
  let rest = text.trim();
  while (rest.length > max) {
    let cut = rest.lastIndexOf("\n\n", max);
    if (cut < max / 2) cut = rest.lastIndexOf("\n", max);
    if (cut < max / 2) cut = rest.lastIndexOf(". ", max) + 1;
    if (cut < max / 2) cut = max;
    out.push(rest.slice(0, cut).trim());
    rest = rest.slice(cut).trim();
  }
  if (rest) out.push(rest);
  return out;
}

/** D185: every started 800 characters counts as one question (drill_settings.text_chars_per_question). */
export const countsAs = (chars: number, per = 800) => chars <= 0 ? 0 : Math.ceil(chars / Math.max(1, per));

type Img = { mediaType: "image/jpeg" | "image/png" | "image/webp"; data: string };

export async function handleRead(
  b: Record<string, unknown>,
  provider: LLMProvider,
  cfg: DrillConfig,
  signal?: AbortSignal,
  material?: { userId: string; store: MaterialStore | null },
  perQuestion = 800,
): Promise<{ body: Record<string, unknown>; steps: StepUsage[] }> {
  const paths = Array.isArray(b.page_paths) ? b.page_paths : [];
  if (paths.length) {
    // K53: uploaded photos are read by path and deleted right after, also when it fails (B4)
    if (!material?.store) throw new HttpError(503, "unconfigured", "Uploads are not configured");
    const got = await materialImages(material.userId, paths, material.store).catch(async (e) => {
      await material.store!.remove(paths.map(String).filter((p) => p.startsWith(`${material.userId}/`))).catch(() => {});
      throw e;
    });
    try {
      return await handleRead({ ...b, page_paths: undefined, uploaded: got.images }, provider, cfg, signal, undefined, perQuestion);
    } finally {
      await material.store.remove(got.paths).catch(() => {});
    }
  }
  const images = [...drillImages(b.pages), ...((b.uploaded as Img[] | undefined) ?? [])];
  if (images.length > MATERIAL.maxPhotos) throw new HttpError(400, "invalid_request", `at most ${MATERIAL.maxPhotos} photos`);
  const text = clean(b.text, READ_LIMITS.maxChars + 10_000);
  if (!images.length && !text) throw new HttpError(400, "invalid_request", "pages or text is required");

  const calls: { user: string; images?: Img[]; maxTokens: number }[] = [];
  for (let i = 0; i < images.length; i += READ_LIMITS.pagesPerCall) {
    const batch = images.slice(i, i + READ_LIMITS.pagesPerCall);
    calls.push({ user: `Write out these ${batch.length} pages for reading aloud (pages ${i + 1}-${i + batch.length}).`, images: batch, maxTokens: 6000 });
  }
  for (const c of chunks(text)) {
    calls.push({ user: `<material>\n${sanitizeTagged(c)}\n</material>\nWrite out this material for reading aloud.`, maxTokens: Math.min(8000, Math.ceil(c.length / 2.2) + 500) });
  }
  // in parallel, at most MATERIAL.concurrency at a time; the order is kept
  const results: { text: string; usage: StepUsage }[] = new Array(calls.length);
  let next = 0;
  await Promise.all(Array.from({ length: Math.min(MATERIAL.concurrency, calls.length) }, async () => {
    while (next < calls.length) {
      const k = next++;
      const c = calls[k];
      results[k] = await runLLM(provider, {
        system: SYSTEM_PROMPT_READ,
        user: c.user,
        ...(c.images ? { images: c.images } : {}),
        maxTokens: c.maxTokens,
        cacheSystem: true,
        model: cfg.planModel,
        noThinking: true,
        timeoutMs: 90_000,
        signal,
      }, cfg.planPriceIn, cfg.planPriceOut);
    }
  }));
  let parts = parseRead(results.map((r) => r.text.trim()).join("\n\n"));
  // the cleaned text's cap (40 000 characters, 150 parts): whole parts only, the rest is said to be left out
  let total = 0, cut = false;
  parts = parts.filter((p) => {
    if (cut) return false;
    if (total + p.text.length > READ_LIMITS.maxChars || parts.indexOf(p) >= READ_LIMITS.parts) {
      cut = true;
      return false;
    }
    total += p.text.length;
    return true;
  });
  if (!parts.some((p) => p.kind === "para")) {
    // T28 (Toby): why nothing could be read, without the material itself (B4): sizes and the reply's shape only
    console.warn("read_unreadable", JSON.stringify({
      images: images.length, text_chars: text.length, calls: calls.length, parts: parts.length,
      replies: results.map((r) => ({ chars: r.text.length, lines: r.text.split("\n").length, headings: (r.text.match(/^#/gm) ?? []).length,
        starts: r.text.trim().slice(0, 1), out: r.usage.output_tokens })),
    }));
    throw new HttpError(422, "drill_unreadable", "Det gick inte att läsa materialet. Fotografera rakt ovanifrån i bra ljus, eller klistra in texten.");
  }
  const firstHeading = parts.find((p) => p.kind === "heading")?.text ?? "";
  const title = clean(b.title, 120) || firstHeading.slice(0, 120);
  return {
    body: {
      kind: "text",
      title,
      subject: clean(b.subject, 60),
      grade: gradeName(clean(b.grade, 60)),
      parts,
      chars: total,
      counts_as: countsAs(total, perQuestion),
      language: textLanguage(parts.map((p) => p.text).join(" "), clean(b.subject, 60)) || "sv",
      usage: sumUsage(results.map((r) => r.usage), cfg.planModel ?? provider.model),
      ...(cut ? { truncated: true, warning: `Texten är lång. De första ${total} tecknen läses upp.` } : {}),
    },
    steps: results.map((r) => r.usage),
  };
}
