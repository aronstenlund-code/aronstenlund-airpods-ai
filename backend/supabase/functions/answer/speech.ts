import { numbersToSpeech } from "./svnum.ts";

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
 * A partial marker at the end of a chunk is held back so it is never spoken.
 */
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
    const i = this.buf.indexOf(SUMMARY_MARK);
    if (i !== -1) {
      const spoken = this.buf.slice(0, i).replace(/\s+$/, "");
      this.sum = this.buf.slice(i + SUMMARY_MARK.length);
      this.buf = "";
      this.inSummary = true;
      return spoken;
    }
    let hold = 0; // chars kept back: a partial marker plus the whitespace in front of it
    for (let k = Math.min(SUMMARY_MARK.length - 1, this.buf.length); k > 0; k--) {
      if (SUMMARY_MARK.startsWith(this.buf.slice(-k))) {
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
    if (this.inSummary) return "";
    const out = this.buf;
    this.buf = "";
    return out;
  }

  /** Cleaned summary (no quotes, one line, <= 300 chars) or null. */
  get summary(): string | null {
    const t = this.sum.replace(/["“”«»]/g, "").replace(/\s+/g, " ").trim().slice(0, 300);
    return t.length >= 5 ? t : null;
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
      const out = numbersToSpeech(this.buf); // a very long token without spaces: do not hold it forever
      this.buf = "";
      return out;
    }
    let cut = lastWs + 1;
    const head = this.buf.slice(0, cut);
    const m = /((?:\d{1,3}[ \u00a0\u202f])*\S*\d\S*)\s+$/.exec(head); // incl. "1 " of "1 789"
    if (m && this.buf.length - cut < 160) cut = head.length - m[0].length;
    const out = numbersToSpeech(this.buf.slice(0, cut));
    this.buf = this.buf.slice(cut);
    return out;
  }

  finish(): string {
    const out = numbersToSpeech(this.buf);
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
}

export class AnswerPost {
  readonly dup: DupGuard;
  readonly trim: QuestionTrim;
  private readonly tap = new SummaryTap();
  private readonly nums = new NumberStream();

  constructor(opts: PostOptions) {
    this.dup = new DupGuard(opts.previousAnswers);
    this.trim = new QuestionTrim(opts.trimQuestion);
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

  push(raw: string): string {
    const a = this.dup.push(this.tap.push(raw));
    if (!a) return "";
    return this.nums.push(this.trim.push(a));
  }

  finish(): string {
    const rest = this.trim.push(this.dup.push(this.tap.finish()) + this.dup.finish()) +
      this.trim.finish();
    return this.nums.push(rest) + this.nums.finish();
  }
}
