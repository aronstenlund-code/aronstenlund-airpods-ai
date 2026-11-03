import type { Mode } from "./validate.ts";

export interface Meta {
  reconstructed_question: string;
  confidence: number;
  is_question: boolean;
  needs_confirmation: boolean;
}

export type ParserEvent = { type: "meta"; meta: Meta } | { type: "delta"; text: string };

/** Strips characters that TTS would read out loud or that signal markdown. */
export function sanitizeForSpeech(s: string): string {
  return s.replace(/[*#`~_]/g, "").replace(/ /g, " ");
}

function clamp01(n: unknown, dflt: number): number {
  const x = typeof n === "number" ? n : Number(n);
  return Number.isFinite(x) ? Math.min(1, Math.max(0, x)) : dflt;
}

/**
 * Incremental parser for the model's output: `{json header}` + newline + answer text.
 * Emits one `meta` as soon as the header's closing brace arrives, then `delta`s. Tolerates a
 * ```json fence, leading whitespace, and a missing/invalid header (fails safe, see below).
 */
export class ResponseParser {
  private buf = "";
  private metaDone = false;
  private skipLeading = true; // trim whitespace at the start of the answer
  private _meta: Meta | null = null;
  headerFailed = false;
  private isDirect = false;

  /**
   * `direct`: the model answers without a JSON header (explicit modes, lowest latency). The meta is
   * synthesised up front: the user asked on purpose, so is_question=true; the question is the
   * fragment as heard; a model-side confirmation question is just the answer text.
   */
  constructor(
    private mode: Mode,
    private fragment: string,
    private threshold: number,
    direct = false,
  ) {
    this.isDirect = direct;
    if (direct) {
      this.metaDone = true;
      this._meta = {
        reconstructed_question: fragment,
        confidence: 1,
        is_question: true,
        needs_confirmation: false,
      };
    }
  }

  /** The synthesised meta in direct mode (to be sent before any delta), else null. */
  get presetMeta(): Meta | null {
    return this.isDirect ? this._meta : null;
  }

  get meta(): Meta | null {
    return this._meta;
  }

  push(chunk: string): ParserEvent[] {
    if (this.metaDone) return this.delta(chunk);
    this.buf += chunk;
    return this.tryHeader(false);
  }

  /** Call when the stream ends. Guarantees a meta event was produced. */
  finish(): ParserEvent[] {
    if (this.metaDone) return [];
    return this.tryHeader(true);
  }

  private tryHeader(final: boolean): ParserEvent[] {
    let s = this.buf.replace(/^\s+/, "");
    const fence = /^```(?:json)?\s*/i.exec(s);
    if (fence) s = s.slice(fence[0].length);
    if (s === "" && !final) return [];

    if (s !== "" && s[0] !== "{") {
      // No header: the model ignored the format. Fail safe - treat all text as the answer, keep the
      // question gate closed in auto mode (no spurious spoken answers).
      return this.finishHeader(null, s);
    }
    const end = s === "" ? -1 : findObjectEnd(s);
    if (end === -1) {
      if (!final) return [];
      return this.finishHeader(null, ""); // truncated header
    }
    let parsed: Record<string, unknown> | null = null;
    try {
      parsed = JSON.parse(s.slice(0, end + 1));
    } catch { /* fall through */ }
    let rest = s.slice(end + 1);
    rest = rest.replace(/^\s*```\s*/, "");
    return this.finishHeader(parsed, rest);
  }

  private finishHeader(h: Record<string, unknown> | null, rest: string): ParserEvent[] {
    this.metaDone = true;
    this.buf = "";
    this.headerFailed = h === null;
    const isAuto = this.mode === "auto";
    const confidence = clamp01(h?.confidence, h ? 0.5 : 0.3);
    const question =
      typeof h?.reconstructed_question === "string" && h.reconstructed_question.trim()
        ? h.reconstructed_question.trim()
        : this.fragment;
    // Explicit modes: the user asked on purpose, so the gate is always open.
    const is_question = isAuto ? (h ? h.is_question === true : false) : true;
    this._meta = {
      reconstructed_question: question,
      confidence,
      is_question,
      needs_confirmation: is_question && confidence < this.threshold,
    };
    const out: ParserEvent[] = [{ type: "meta", meta: this._meta }];
    if (rest) out.push(...this.delta(rest));
    return out;
  }

  private delta(text: string): ParserEvent[] {
    let t = sanitizeForSpeech(text);
    if (this.skipLeading) {
      t = t.replace(/^\s+/, "");
      if (t === "") return [];
      this.skipLeading = false;
    }
    return t ? [{ type: "delta", text: t }] : [];
  }
}

/** Index of the `}` closing the object that starts at s[0], honouring strings/escapes; -1 if open. */
export function findObjectEnd(s: string): number {
  let depth = 0;
  let inStr = false;
  let esc = false;
  for (let i = 0; i < s.length; i++) {
    const c = s[i];
    if (inStr) {
      if (esc) esc = false;
      else if (c === "\\") esc = true;
      else if (c === '"') inStr = false;
      continue;
    }
    if (c === '"') inStr = true;
    else if (c === "{") depth++;
    else if (c === "}" && --depth === 0) return i;
  }
  return -1;
}
