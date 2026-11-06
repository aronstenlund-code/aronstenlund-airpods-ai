import { numbersToSpeech } from "./svnum.ts";
import { afterNumbers, beforeNumbers } from "./speechsym.ts";

/** Digits, symbols, formulas and abbreviations -> speakable Swedish (D46/D54). */
export const toSpeech = (t: string): string => afterNumbers(numbersToSpeech(beforeNumbers(t)));

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
 * D63: the marker is recognised in every variant the model produces - `[[SAMMANFATTNING]]`, `[SAMMANFATTNING]`,
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

export class QuestionTrim {
  /** True when a trailing question was dropped and nothing else of the answer was passed on. */
  droppedOnly = false;
  dropped = "";
  private emitted = false;
  private mode: "undecided" | "pass" | "hold" = "undecided";
  private cur = ""; // current sentence text not yet passed on (undecided / hold)
  private heldQuestion = ""; // a finished question sentence waiting to see if more text follows
  private prev = ""; // previous char

  constructor(private readonly enabled: boolean) {}

  push(text: string): string {
    if (!this.enabled) {
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
      if (sent.trimEnd().endsWith("?")) this.heldQuestion = sent;
      else out += sent;
    }
    return out;
  }

  finish(): string {
    if (!this.enabled) return "";
    let out = "";
    if (this.heldQuestion) {
      this.dropped = this.heldQuestion.trim();
      this.droppedOnly = !this.emitted;
      this.heldQuestion = "";
    }
    if (this.cur) {
      if (this.mode === "hold" && this.cur.trimEnd().endsWith("?")) {
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

  push(text: string): string {
    this.buf += text;
    // Complete tokens end at the last whitespace; the trailing partial token is always held back, and
    // so is the last complete token when it holds digits (its unit / next word is still to come).
    const lastWs = Math.max(this.buf.lastIndexOf(" "), this.buf.lastIndexOf("\n"));
    if (lastWs === -1) {
      if (this.buf.length <= 60) return "";
      const out = toSpeech(this.buf); // a very long token without spaces: do not hold it forever
      this.buf = "";
      return out;
    }
    let cut = lastWs + 1;
    const head = this.buf.slice(0, cut);
    const m = /((?:\d{1,3}[ \u00a0\u202f])*\S*\d\S*|[=≈≠]|\S*\^\S*)\s+$/.exec(head); // incl. "1 " of "1 789"
    if (m && this.buf.length - cut < 160) cut = head.length - m[0].length;
    const out = toSpeech(this.buf.slice(0, cut));
    this.buf = this.buf.slice(cut);
    return out;
  }

  finish(): string {
    const out = toSpeech(this.buf);
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
  /** D53: the stream starts with a `[[REL ...]]` relation tag that is split off. */
  relationTag?: boolean;
}

export class AnswerPost {
  readonly dup: DupGuard;
  readonly trim: QuestionTrim;
  private readonly tap = new SummaryTap();
  private readonly rel: RelationTap;
  private readonly gate: FirstLineGate;
  private readonly nums = new NumberStream();

  constructor(opts: PostOptions) {
    this.dup = new DupGuard(opts.previousAnswers);
    this.trim = new QuestionTrim(opts.trimQuestion);
    this.gate = new FirstLineGate(opts.firstLineOnly === true);
    this.rel = new RelationTap(opts.relationTag === true);
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
    return this.tap.summary;
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
    const a = this.dup.push(this.gate.push(this.tap.push(this.rel.push(raw))));
    if (!a) return "";
    return this.cap(this.nums.push(this.trim.push(a)));
  }

  finish(): string {
    const rest = this.trim.push(
      this.dup.push(this.gate.push(this.tap.push(this.rel.finish()) + this.tap.finish())) +
        this.dup.finish(),
    ) +
      this.trim.finish();
    return this.cap(this.nums.push(rest) + this.nums.finish());
  }
}
