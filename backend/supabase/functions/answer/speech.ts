import { numbersToSpeech } from "./svnum.ts";
import { afterNumbers, beforeNumbers } from "./speechsym.ts";

/** Digits, symbols, formulas and abbreviations -> speakable Swedish (D46/D54). */
export const toSpeech = (t: string, ctx = ""): string =>
  afterNumbers(numbersToSpeech(beforeNumbers(t, ctx)));

/**
 * D46 post-processing of the streamed answer text, in code instead of more prompt text:
 *  1. DupGuard      - an answer that starts like an earlier answer for a different fragment is stopped
 *                     (the handler regenerates once).
 *  2. QuestionTrim  - a closing question back to the user ("Vill du att jag ...?") is dropped.
 *  3. NumberStream  - digits -> Swedish words, safe across chunk boundaries.
 * Each stage is `push(text) -> text to pass on` / `finish() -> rest`, so latency stays token-level.
 */

const norm = (s: string) => s.toLowerCase().replace(/[^\p{L}\p{N}]+/gu, "");

// ---------- 0. summary trailer (D48) ----------
export const SUMMARY_MARK = "[[SAMMANFATTNING]]";

/**
 * The model ends every answer with a line `[[SAMMANFATTNING]] <1-2 sentence summary>` (same call, no extra
 * request). Everything before the marker is spoken; everything after is the summary and never reaches TTS.
 * D65: the marker is recognised in every variant the model produces - `[[SAMMANFATTNING]]`, `[SAMMANFATTNING]`,
 * `SAMMANFATTNING:`, a line `Sammanfattning:` (any case, optional **bold**) - anywhere in the text, also when
 * no summary follows. A partial marker at the end of a chunk is held back so it is never spoken.
 */
const MARKERS: RegExp[] = [
  /\[{1,2}\s*sammanfattning\s*\]{1,2}\s*:?/i,
  /(?:^|\n)[ \t]*(?:\*\*)?sammanfattning(?:\*\*)?[ \t]*[:\-–—]/i,
  /(?<!\[[ \t]*)SAMMANFATTNING\b[ \t]*:?/,
];

/** First marker in `s`: [index where the spoken text ends, index where the summary starts]. */
export function findSummaryMarker(s: string): [number, number] | null {
  let best: [number, number] | null = null;
  for (const re of MARKERS) {
    const m = re.exec(s);
    if (!m) continue;
    const start = m.index + (m[0].startsWith("\n") ? 1 : 0);
    if (!best || start < best[0]) best = [start, m.index + m[0].length];
  }
  return best;
}

/** Length of the tail of `buf` that may still turn into a marker (held back, not spoken yet). */
function markerHold(buf: string): number {
  let hold = 0;
  const tail = buf.slice(-24);
  for (let br = tail.indexOf("["); br !== -1; br = tail.indexOf("[", br + 1)) {
    const t = tail.slice(br).toLowerCase().replace(/\s+/g, "");
    if ("[[sammanfattning]]:".startsWith(t) || "[sammanfattning]:".startsWith(t)) {
      hold = tail.length - br;
      break;
    }
  }
  const caps = /[A-ZÅÄÖ]+$/.exec(buf)?.[0] ?? "";
  if (caps && ("SAMMANFATTNING".startsWith(caps) || caps === "SAMMANFATTNING")) {
    hold = Math.max(hold, caps.length);
  }
  const line = buf.slice(buf.lastIndexOf("\n") + 1);
  const l = line.replace(/^[ \t]*(?:\*\*)?/, "").toLowerCase();
  if (l && ("sammanfattning**".startsWith(l) || l === "sammanfattning")) {
    hold = Math.max(hold, line.length);
  }
  if (/^[ \t]*\*{1,2}$/.test(line)) hold = Math.max(hold, line.length);
  return hold;
}

export class SummaryTap {
  private buf = "";
  private sum = "";
  private inSummary = false;

  push(text: string): string {
    if (this.inSummary) {
      this.sum += text;
      return "";
    }
    this.buf += text;
    const f = findSummaryMarker(this.buf);
    if (f) {
      const spoken = this.buf.slice(0, f[0]).replace(/\s+$/, "");
      this.sum = this.buf.slice(f[1]);
      this.buf = "";
      this.inSummary = true;
      return spoken;
    }
    let hold = markerHold(this.buf);
    while (hold < this.buf.length && /\s/.test(this.buf[this.buf.length - hold - 1])) hold++;
    const out = this.buf.slice(0, this.buf.length - hold);
    this.buf = this.buf.slice(this.buf.length - hold);
    return out;
  }

  finish(): string {
    if (this.inSummary) return "";
    const out = this.buf;
    this.buf = "";
    return out;
  }

  /** Cleaned summary (no quotes, one line, <= 300 chars) or null. */
  get summary(): string | null {
    const t = this.sum.replace(/^[\s:\]\-–—*]+/, "").replace(/["“”«»]/g, "").replace(/\s+/g, " ")
      .trim()
      .slice(0, 300);
    return t.length >= 5 ? t : null;
  }
}

// ---------- 0a. relation tag (D53) ----------
export type Relation = "continues" | "refines" | "new_topic";
export const RELATIONS: readonly Relation[] = ["continues", "refines", "new_topic"];
export function parseRelation(v: unknown): Relation | null {
  const t = typeof v === "string" ? v.toLowerCase().replace(/[^a-z_]/g, "") : "";
  return RELATIONS.find((r) => r === t) ?? null;
}

/**
 * The model's first line is `[[REL <relation>]]` (decided before the answer). It is split off here and
 * never spoken. If the text does not start with the tag the stream is passed on unchanged.
 */
export class RelationTap {
  relation: Relation | null = null;
  private buf = "";
  private strip = false; // drop the whitespace between the tag and the answer, across chunks
  private decided: boolean;
  constructor(enabled: boolean) {
    this.decided = !enabled;
  }
  push(text: string): string {
    if (this.decided) {
      if (!this.strip) return text;
      const r = text.replace(/^\s+/, "");
      if (r) this.strip = false;
      return r;
    }
    this.buf += text;
    const t = this.buf.trimStart();
    const open = "[[REL";
    if (t.length < open.length) {
      if (open.startsWith(t.toUpperCase())) return ""; // could still become the tag
      return this.release();
    }
    if (!t.toUpperCase().startsWith(open)) return this.release();
    const end = t.indexOf("]]");
    if (end === -1) return t.length > 40 ? this.release() : "";
    this.relation = parseRelation(t.slice(open.length, end));
    this.decided = true;
    this.strip = true;
    this.buf = "";
    const r = t.slice(end + 2).replace(/^\s+/, "");
    if (r) this.strip = false;
    return r;
  }
  finish(): string {
    return this.decided ? "" : this.release();
  }
  private release(): string {
    this.decided = true;
    const b = this.buf;
    this.buf = "";
    return b;
  }
}

// ---------- 0a2. web answers: source line + English sentences (D65) ----------
/** Spoken name of a domain: "scb.se" -> "SCB", "riksdagen.se" -> "Riksdagen", "developer.mozilla.org" -> "Mozilla". */
export function spokenSource(domain: string): string {
  const labels = domain.toLowerCase().replace(/^www\./, "").split(".").filter(Boolean);
  const sld = new Set(["co", "com", "org", "gov", "ac"]);
  let i = labels.length - 2;
  if (
    labels.length >= 3 && labels[labels.length - 1].length === 2 &&
    sld.has(labels[labels.length - 2])
  ) i--;
  const name = labels[Math.max(0, i)] ?? domain;
  return name.length <= 4 ? name.toUpperCase() : name[0].toUpperCase() + name.slice(1);
}

/**
 * Web answers end with `källa: <domain>`. That line is never read out as written ("scb punkt se"): it is cut
 * from the stream, exposed as `source` (for the screen) and spoken as "Källa: SCB.".
 */
export class SourceTap {
  source: string | null = null;
  private buf = "";
  private inSource = false;
  private src = "";
  constructor(private readonly enabled: boolean) {}
  private static readonly RE = /(?:^|\n|\s)källa\s*:/i;

  push(text: string): string {
    if (!this.enabled) return text;
    if (this.inSource) {
      this.src += text;
      return "";
    }
    this.buf += text;
    const m = SourceTap.RE.exec(this.buf);
    if (m) {
      const at = m.index + (/^\s/.test(m[0]) ? 1 : 0);
      const spoken = this.buf.slice(0, at).replace(/\s+$/, "");
      this.src = this.buf.slice(m.index + m[0].length);
      this.buf = "";
      this.inSource = true;
      return spoken;
    }
    // hold back a tail that may still become "källa:"
    const tail = this.buf.slice(-8).toLowerCase();
    let hold = 0;
    for (let k = Math.min(6, tail.length); k > 0; k--) {
      if ("källa:".startsWith(tail.slice(-k))) {
        hold = k;
        break;
      }
    }
    while (hold < this.buf.length && /\s/.test(this.buf[this.buf.length - hold - 1])) hold++;
    const out = this.buf.slice(0, this.buf.length - hold);
    this.buf = this.buf.slice(this.buf.length - hold);
    return out;
  }

  finish(): string {
    if (!this.enabled) return "";
    if (!this.inSource) {
      const out = this.buf;
      this.buf = "";
      return out;
    }
    const d = /([a-z0-9][a-z0-9-]*(?:\.[a-z0-9-]+)*\.[a-z]{2,})/i.exec(this.src)?.[1] ?? null;
    this.source = d ? d.toLowerCase().replace(/^www\./, "") : null;
    this.inSource = false;
    return this.source ? ` Källa: ${spokenSource(this.source)}.` : "";
  }
}

const EN = new Set(
  "the of and is are was were he she it they to in since as with for by that this has have had been who which serves served from at on be an or his her their its not but also king queen ruler rulers reigned ruled succeeded succeeding became born died during until years"
    .split(" "),
);
const SV = new Set(
  "och att är som det en ett på av för med har till den i inte var de hon han vi du man om vid från efter under över sedan blev blir kan ska sig sin sitt dess"
    .split(" "),
);
/** True for a sentence that is clearly English (web answers must be Swedish; a copied source sentence is dropped). */
export function isEnglishSentence(sentence: string): boolean {
  const w = sentence.toLowerCase().match(/\p{L}+/gu) ?? [];
  if (w.length < 5) return false;
  let en = 0, sv = 0;
  for (const x of w) {
    if (EN.has(x)) en++;
    else if (SV.has(x)) sv++;
  }
  if (en >= 3 && en > 1.5 * sv) return true;
  // Oscar round 2 / D72 live test: an English source fragment inside a Swedish sentence
  // ("Ordningen stämmer också med Succeeding rulers were his son ..."): 3+ English and no Swedish
  // function words within 5 consecutive words.
  for (let i = 0; i + 5 <= w.length; i++) {
    const win = w.slice(i, i + 5);
    if (win.filter((x) => EN.has(x)).length >= 3 && !win.some((x) => SV.has(x))) return true;
  }
  return false;
}

/**
 * Oscar round 2 (F16): in web mode the model sometimes narrates its own decision ("Det här är en historisk
 * fråga som jag kan svara på direkt, utan sökning.", "Jag söker på ..."). Such a sentence is system talk.
 */
const SEARCH_META =
  /(?:utan (?:att )?(?:beh\u00f6va |ha )?s\u00f6k|jag har inte s\u00f6kt|om du vill vara (?:helt )?s\u00e4ker|^\s*hmm\b|jag \u00e4r s\u00e4ker p\u00e5 (?:detta|det h\u00e4r|det)\b|(?:beh\u00f6ver|beh\u00f6vs) (?:inte |ingen )?s\u00f6k|ingen s\u00f6kning|jag kan svara (?:p\u00e5 )?(?:den |det |fr\u00e5gan )?direkt|^\s*(?:jag|l\u00e5t mig) (?:ska |kan |vill |m\u00e5ste |beh\u00f6ver )?(?:s\u00f6ka|s\u00f6ker|kolla|kollar|letar|leta)\b|^\s*det h\u00e4r \u00e4r en \p{L}+ fr\u00e5ga)/iu;
export function isSearchMeta(sentence: string): boolean {
  return SEARCH_META.test(sentence);
}

/** Drops whole English sentences (web mode only, unless the user asked for a translation), and sentences
 *  that only narrate the search decision. */
export class EnglishGate {
  private buf = "";
  constructor(private readonly enabled: boolean) {}
  push(text: string): string {
    if (!this.enabled) return text;
    this.buf += text;
    let out = "";
    for (;;) {
      const m = /[.!?](?:\s+|$)|\n/.exec(this.buf);
      if (!m || m.index + m[0].length >= this.buf.length && !/\s$/.test(m[0]) && m[0] !== "\n") {
        break;
      }
      const end = m.index + m[0].length;
      const sentence = this.buf.slice(0, end);
      this.buf = this.buf.slice(end);
      if (!isEnglishSentence(sentence) && !isSearchMeta(sentence)) out += sentence;
    }
    return out;
  }
  finish(): string {
    if (!this.enabled) return "";
    const r = isEnglishSentence(this.buf) || isSearchMeta(this.buf) ? "" : this.buf;
    this.buf = "";
    return r;
  }
}

// ---------- 0a. D75: silence in Provläge / Auto ----------
/** The model's "say nothing" marker (prompt.ts SILENT_MARK); everything after it is dropped. */
const SILENT_OPEN = "[[TYST";
export class SilenceTap {
  silent = false;
  private buf = "";
  private decided: boolean;
  constructor(enabled: boolean) {
    this.decided = !enabled;
  }
  push(text: string): string {
    if (this.silent) return "";
    if (this.decided) return text;
    this.buf += text;
    const t = this.buf.trimStart().toUpperCase();
    if (t.length < SILENT_OPEN.length) {
      return SILENT_OPEN.startsWith(t) ? "" : this.release();
    }
    if (t.startsWith(SILENT_OPEN)) {
      this.silent = true;
      this.buf = "";
      return "";
    }
    return this.release();
  }
  finish(): string {
    if (this.silent || this.decided) return "";
    // a reply that is only "[[T" or "[[" is not an answer either
    if (this.buf.trim() && SILENT_OPEN.startsWith(this.buf.trim().toUpperCase())) {
      this.silent = true;
      this.buf = "";
      return "";
    }
    return this.release();
  }
  private release(): string {
    this.decided = true;
    const b = this.buf;
    this.buf = "";
    return b;
  }
}

/**
 * D75 (first device run): the model commented on what the student seemed to think ("Det låter som att du
 * tänker på …") or asked for clarification ("Berätta gärna ordet …") instead of answering. Such a
 * sentence is never spoken in Provläge or Auto; when nothing else remains the reply is silence.
 */
const META_REPLY = new RegExp(
  [
    String.raw`^(?:det|detta|det här) (?:låter|verkar|känns|tycks) (?:som )?(?:att|om) (?:du|ni)\b`,
    String.raw`^(?:det|detta|det här) (?:låter|verkar) som (?:en|ett) (?:ofullständig|avbruten|avbrutet|ofullständigt|halv)`,
    String.raw`^(?:du|ni) (?:verkar|låter|tycks|kanske) (?:tänka|mena|syfta|undra|vilja|fundera|prata)`,
    String.raw`^(?:jag )?(?:förstår|uppfattade|uppfattar|hörde|fattar|kunde inte (?:höra|uppfatta|förstå)) (?:tyvärr )?(?:inte|riktigt|helt)?`,
    String.raw`^jag (?:är )?(?:inte (?:helt )?säker på|osäker på) vad (?:du|ni)`,
    String.raw`^jag (?:kunde|kan) inte (?:höra|uppfatta|tolka|förstå)`,
    String.raw`^berätta (?:gärna|lite|mer|vad (?:du|ni) (?:menar|vill|tänker|syftar))`,
    String.raw`^(?:kan|kunde|vill) (?:du|ni) (?:förtydliga|upprepa|utveckla|precisera|säga (?:det )?igen|säga (?:lite )?mer|berätta (?:lite )?mer|ge (?:mig )?(?:mer|lite) )`,
    String.raw`^(?:vad|vilket|vilken|vem) (?:menar|syftar|tänker) (?:du|ni)`,
    String.raw`^menar (?:du|ni)\b`,
    String.raw`^tänker (?:du|ni) på\b`,
    String.raw`^syftar (?:du|ni) på\b`,
    String.raw`^om (?:du|ni) (?:menar|syftar|tänker) (?:på )?`,
    String.raw`^(?:säg|ge|nämn) (?:gärna |mig )+(?:ordet|vilket|vad|mer)`,
    String.raw`^hörde jag rätt`,
    String.raw`^jag gissar (?:att|på att) (?:du|ni)`,
    String.raw`^(?:det|det där|det här) (?:är|var) (?:lite )?(?:svårt|oklart) att (?:förstå|veta|tolka|höra|säga)`,
  ].join("|"),
  "iu",
);
export function isMetaReply(sentence: string): boolean {
  return META_REPLY.test(sentence.trim().replace(/^[\s"'„”»«-]+/, ""));
}

export class MetaGate {
  dropped = 0;
  private buf = "";
  constructor(private readonly enabled: boolean) {}
  push(text: string): string {
    if (!this.enabled) return text;
    this.buf += text;
    let out = "";
    for (;;) {
      const m = /[.!?](?:\s+|$)|\n/.exec(this.buf);
      if (!m || m.index + m[0].length >= this.buf.length && !/\s$/.test(m[0]) && m[0] !== "\n") {
        break;
      }
      const end = m.index + m[0].length;
      out += this.keep(this.buf.slice(0, end));
      this.buf = this.buf.slice(end);
    }
    return out;
  }
  finish(): string {
    if (!this.enabled) return "";
    const r = this.keep(this.buf);
    this.buf = "";
    return r;
  }
  private keep(sentence: string): string {
    if (sentence.trim() && isMetaReply(sentence)) {
      this.dropped++;
      return "";
    }
    return sentence;
  }
}

// ---------- 0b. first line only (social lines) ----------
/** The social line is ONE line: whatever the model adds after the first line break (tips, requests for
 *  more context) is dropped in code, whatever the prompt said. */
export class FirstLineGate {
  private started = false;
  private closed = false;
  constructor(private readonly enabled: boolean) {}
  push(text: string): string {
    if (!this.enabled) return text;
    if (this.closed) return "";
    let out = "";
    for (const ch of text) {
      if (ch === "\n") {
        if (this.started) {
          this.closed = true;
          break;
        }
        continue; // leading blank lines
      }
      if (!/\s/.test(ch)) this.started = true;
      out += ch;
    }
    return out;
  }
}

// ---------- 1. duplicate guard ----------
const DUP_PREFIX = 40;
const DUP_PROBE = 12;

export class DupGuard {
  tripped = false;
  /** The earlier answer that was about to be repeated. */
  matched: string | null = null;
  private held = "";
  private decided: boolean;
  private readonly cands: string[];
  private readonly originals: string[];

  /** `previous`: earlier answers of this session whose question differs from the current fragment. */
  constructor(previous: string[]) {
    this.originals = previous.filter((p) => norm(p).length >= DUP_PREFIX);
    this.cands = this.originals.map((p) => norm(p).slice(0, DUP_PREFIX));
    this.decided = this.cands.length === 0;
  }

  push(text: string): string {
    if (this.decided || this.tripped) return this.tripped ? "" : text;
    this.held += text;
    const n = norm(this.held);
    if (n.length < DUP_PROBE) return ""; // too early to tell
    const alive = this.cands.some((c) => c.startsWith(n.slice(0, DUP_PREFIX)));
    if (!alive) return this.release();
    if (n.length >= DUP_PREFIX) {
      this.tripped = true;
      this.matched = this.originals[this.cands.findIndex((c) => c === n.slice(0, DUP_PREFIX))] ??
        null;
      this.held = "";
      return "";
    }
    return "";
  }

  finish(): string {
    if (this.decided || this.tripped) return "";
    return this.release();
  }

  private release(): string {
    this.decided = true;
    const h = this.held;
    this.held = "";
    return h;
  }
}

// ---------- 2. closing question trim ----------
// First words of Swedish/English questions put to the user. Only sentences starting with one are held
// back until their end is known; everything else streams straight through.
const Q_WORDS = new Set(
  (
    "vill önskar behöver kan skulle ska har är menar tycker finns får vad hur varför vilken vilket vilka när " +
    "var vem undrar want would do does is are can could should shall need have"
  ).split(" "),
);

/** Tutor check questions: short, one question, answerable in a word (no "..., och vilken ...?" pairs). */
export function tutorQuestionOk(sentence: string): boolean {
  const t = sentence.trim();
  if ((t.match(/\?/g) ?? []).length > 1) return false;
  if (t.split(/\s+/).length > 14) return false;
  return !/,?\s+och\s+(?:vilken|vilket|vilka|vad|hur|varför|när|var|vem)\s/i.test(t);
}

export class QuestionTrim {
  /** True when a trailing question was dropped and nothing else of the answer was passed on. */
  droppedOnly = false;
  dropped = "";
  private emitted = false;
  private mode: "undecided" | "pass" | "hold" = "undecided";
  private cur = ""; // current sentence text not yet passed on (undecided / hold)
  private heldQuestion = ""; // a finished question sentence waiting to see if more text follows
  private prev = ""; // previous char

  constructor(private readonly enabled: boolean, private readonly tutor = false) {}

  push(text: string): string {
    if (!this.enabled && !this.tutor) {
      if (text.trim()) this.emitted = true;
      return text;
    }
    let out = "";
    for (const ch of text) {
      out += this.char(ch);
      this.prev = ch;
    }
    if (out.trim()) this.emitted = true;
    return out;
  }

  private char(ch: string): string {
    let out = "";
    if (this.heldQuestion && !/\s/.test(ch)) {
      out += this.heldQuestion; // more text follows: it was a question inside the answer
      this.heldQuestion = "";
      this.mode = "undecided";
      this.cur = "";
    }
    if (this.mode === "pass") {
      out += ch;
      if (/\s/.test(ch) && /[.!?]/.test(this.prev)) {
        this.mode = "undecided";
        this.cur = "";
      }
      return out;
    }
    this.cur += ch;
    if (this.mode === "undecided") {
      const lead = /^\s*(\p{L}+)[^\p{L}]$/u.exec(this.cur);
      if (lead) {
        if (Q_WORDS.has(lead[1].toLowerCase())) this.mode = "hold";
        else {
          out += this.cur;
          this.cur = "";
          this.mode = "pass";
          if (/\s/.test(ch) && /[.!?]/.test(this.prev)) this.mode = "undecided";
        }
      } else if (/^\s*[^\s\p{L}]/u.test(this.cur) || this.cur.length > 40) {
        out += this.cur; // starts with a digit or symbol: not a question opener
        this.cur = "";
        this.mode = "pass";
      }
      if (this.mode !== "hold") return out;
    }
    // hold: wait for the sentence end
    if (/\s/.test(ch) && /[.!?]/.test(this.prev)) {
      const sent = this.cur;
      this.cur = "";
      this.mode = "undecided";
      if (this.tutor) {
        if (sent.trimEnd().endsWith("?") && !tutorQuestionOk(sent)) this.dropped = sent.trim();
        else out += sent;
      } else if (sent.trimEnd().endsWith("?")) this.heldQuestion = sent;
      else out += sent;
    }
    return out;
  }

  finish(): string {
    if (!this.enabled && !this.tutor) return "";
    let out = "";
    if (this.heldQuestion) {
      this.dropped = this.heldQuestion.trim();
      this.droppedOnly = !this.emitted;
      this.heldQuestion = "";
    }
    if (this.cur) {
      if (
        this.mode === "hold" && this.cur.trimEnd().endsWith("?") &&
        (!this.tutor || !tutorQuestionOk(this.cur))
      ) {
        this.dropped = this.cur.trim();
        this.droppedOnly = !this.emitted && !out.trim();
      } else out += this.cur;
      this.cur = "";
    }
    if (out.trim()) this.emitted = true;
    return out;
  }
}

// ---------- 3. digits -> words across chunk boundaries ----------
export class NumberStream {
  private buf = "";
  private tail = ""; // last raw text already passed on (context for the phone-number guard)

  private say(raw: string): string {
    const out = toSpeech(raw, this.tail);
    this.tail = (this.tail + raw).slice(-120);
    return out;
  }

  push(text: string): string {
    this.buf += text;
    // Complete tokens end at the last whitespace; the trailing partial token is always held back, and
    // so is the last complete token when it holds digits (its unit / next word is still to come).
    const lastWs = Math.max(this.buf.lastIndexOf(" "), this.buf.lastIndexOf("\n"));
    if (lastWs === -1) {
      if (this.buf.length <= 60) return "";
      const out = this.say(this.buf); // a very long token without spaces: do not hold it forever
      this.buf = "";
      return out;
    }
    let cut = lastWs + 1;
    const head = this.buf.slice(0, cut);
    const m = /((?:\d{1,3}[ \u00a0\u202f])*\S*\d\S*|[=≈≠]|\S*\^\S*)\s+$/.exec(head) ?? // incl. "1 " of "1 789"
      // D72 live test: "Karl " must wait for a possible "XV" (a regnal number is read as a pair with the
      // name), and a "Karl XV." pair is passed on together.
      /(?:\p{Lu}\p{L}+\s+)?(?:XVIII|XVII|XIII|XIV|XVI|XIX|VIII|VII|III|XII|XV|XI|IX|IV|II|VI|XX|V|X|I)[.,!?;:]?\s+$|\p{Lu}\p{L}+\s+$/u
        .exec(head);
    if (m && this.buf.length - cut < 160) cut = head.length - m[0].length;
    const out = this.say(this.buf.slice(0, cut));
    this.buf = this.buf.slice(cut);
    return out;
  }

  finish(): string {
    const out = this.say(this.buf);
    this.buf = "";
    return out;
  }
}

// ---------- pipeline ----------
export interface PostOptions {
  /** Earlier answers (for different fragments) to guard against repeating; empty disables the guard. */
  previousAnswers: string[];
  /** Drop a closing question to the user (false in tutoring, personas, confirmations). */
  trimQuestion: boolean;
  /** Social lines: keep only the first line (D51: no tips, no questions about context). */
  firstLineOnly?: boolean;
  /** D65: tutor mode: check questions must be short single questions (others are dropped). */
  tutor?: boolean;
  /** D53: the stream starts with a `[[REL ...]]` relation tag that is split off. */
  relationTag?: boolean;
  /** D65: web answer: `källa:` line to `source`, English sentences dropped. */
  web?: boolean;
  /** D75: Provläge / Auto: the `[[TYST]]` marker and meta comments mean "say nothing". */
  silence?: boolean;
}

export class AnswerPost {
  readonly dup: DupGuard;
  readonly trim: QuestionTrim;
  private readonly tap = new SummaryTap();
  private readonly rel: RelationTap;
  private readonly sil: SilenceTap;
  private readonly meta: MetaGate;
  private readonly src: SourceTap;
  private spoke = false;
  private readonly en: EnglishGate;
  private readonly gate: FirstLineGate;
  private readonly nums = new NumberStream();

  constructor(opts: PostOptions) {
    this.dup = new DupGuard(opts.previousAnswers);
    this.trim = new QuestionTrim(opts.trimQuestion, opts.tutor === true);
    this.gate = new FirstLineGate(opts.firstLineOnly === true);
    this.rel = new RelationTap(opts.relationTag === true);
    this.sil = new SilenceTap(opts.silence === true);
    this.meta = new MetaGate(opts.silence === true);
    this.src = new SourceTap(opts.web === true);
    this.en = new EnglishGate(opts.web === true);
  }

  /** Domain of the web source (from the `källa:` line), or null. */
  get source(): string | null {
    return this.src.source;
  }

  /** D53 relation reported by the model (tag), or null. */
  get relation(): Relation | null {
    return this.rel.relation;
  }

  get duplicate(): boolean {
    return this.dup.tripped;
  }
  /** The model produced only a question to the user (nothing else could be said). */
  get questionOnly(): boolean {
    return this.trim.droppedOnly;
  }

  /** D48 summary of this exchange (from the trailer line), or null. */
  get summary(): string | null {
    return this.silent ? null : this.tap.summary;
  }

  /** D75: the model chose silence, or every sentence was a meta comment (nothing was spoken). */
  get silent(): boolean {
    return this.sil.silent || (this.meta.dropped > 0 && !this.spoke);
  }

  /** D75: the silence marker was seen (the stream can stop at once). */
  get silenceMarked(): boolean {
    return this.sil.silent;
  }

  private capitalised = false;
  /** The answer starts with a capital letter (digits-to-words and the model can leave it lower case). */
  private cap(t: string): string {
    if (this.capitalised || !t.trim()) return t;
    this.capitalised = true;
    return t.replace(
      /^(\s*)(\p{Ll})(?![\p{L}]*\p{Lu})/u,
      (_m, ws: string, c: string) => ws + c.toUpperCase(),
    );
  }

  push(raw: string): string {
    const a = this.dup.push(
      this.gate.push(
        this.meta.push(this.en.push(this.src.push(this.tap.push(this.sil.push(this.rel.push(raw)))))),
      ),
    );
    if (!a) return "";
    const out = this.cap(this.nums.push(this.trim.push(a)));
    if (out.trim()) this.spoke = true;
    return out;
  }

  finish(): string {
    const t = this.tap.push(this.sil.push(this.rel.finish()) + this.sil.finish()) + this.tap.finish();
    const s = this.src.push(t) + this.src.finish();
    const e0 = this.en.push(s) + this.en.finish();
    const e = this.meta.push(e0) + this.meta.finish();
    const rest = this.trim.push(this.dup.push(this.gate.push(e)) + this.dup.finish()) +
      this.trim.finish();
    const out = this.cap(this.nums.push(rest) + this.nums.finish());
    // D72 live test: when every answer sentence was filtered, a lone "Källa: X." is not an answer
    // (nothing is spoken, so the handler reports empty_answer and the app falls back).
    if (!this.spoke && /^\s*Källa: [^.]*\.\s*$/.test(out)) return "";
    if (out.trim()) this.spoke = true;
    return out;
  }
}
