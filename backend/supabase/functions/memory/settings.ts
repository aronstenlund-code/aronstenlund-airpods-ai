/**
 * K10.2-3 (owner 2026-11-08 21:26: "man ska aldrig behöva rätta Lumen två gånger i rad"): a correction right after
 * an answer ("kortare", "för långt", "enklare", "mer exempel", "det där var fel", with or without "Lumen") becomes a
 * structured setting with a SCOPE guessed from the answer that was corrected: {mode?, subject?, exam?, answer_type?};
 * an empty scope is global. The same correction in another subject or mode widens the scope. All in code (no model
 * call). /memory returns the new list and a short profile (<= 300 characters) of how the user wants answers; /answer
 * gets only the settings that apply to the current context, and the profile in a cached system block.
 */

export type SettingKey = "length" | "simplicity" | "examples" | "accuracy";
export type AnswerKind = "fact" | "explanation" | "math";
export interface Scope {
  mode?: string;
  subject?: string;
  exam?: string;
  answer_type?: AnswerKind;
}
export interface Setting {
  key: SettingKey;
  value: string;
  scope: Scope;
  /** how many times the user gave this correction */
  n?: number;
}
export interface CorrectionContext {
  mode?: string;
  subject?: string;
  exam?: string;
  answer_type?: AnswerKind;
}

export const SETTINGS_LIMITS = { settings: 30, field: 80, text: 200 };

const C: [RegExp, SettingKey, string][] = [
  [/^(?:kortare|för långt|det var för långt|mindre text|korta svar|kortare svar|svara kortare|snabbare|inte så långt|kortfattat|för mycket)$/u, "length", "shorter"],
  [/^(?:längre|för kort|det var för kort|mer detaljer|utveckla mer|längre svar|svara längre|mer utförligt|utförligare)$/u, "length", "longer"],
  [/^(?:enklare|för svårt|det var för svårt|jag förstår inte|förklara enklare|enklare ord|lättare|för krångligt|inte så krångligt)$/u, "simplicity", "simpler"],
  [/^(?:mer exempel|fler exempel|ge exempel|med exempel|ett exempel till|exempel tack|jag behöver exempel)$/u, "examples", "more"],
  [/^(?:det där var fel|det var fel|fel|inte rätt|det stämmer inte|det är fel|du har fel|det där stämmer inte)$/u, "accuracy", "careful"],
];

/** The setting a spoken correction stands for, or null. */
export function detectCorrection(text: string): { key: SettingKey; value: string } | null {
  const t = text.toLowerCase().replace(/[^\p{L}\s]/gu, " ").replace(/\s+/g, " ").trim()
    .replace(/^(?:(?:hej|okej|ok) )?lumen /u, "").replace(/^(?:nej |men |äh |alltså )+/u, "").replace(/ (?:tack|snälla|nästa gång)$/u, "");
  for (const [re, key, value] of C) if (re.test(t)) return { key, value };
  return null;
}

const OPPOSITE: Record<string, string> = { shorter: "longer", longer: "shorter" };

/** Guess the scope from the answer that was corrected: maths answers by type, else the subject, else the exam/mode. */
export function guessScope(ctx: CorrectionContext): Scope {
  if (ctx.answer_type === "math") return { answer_type: "math" };
  if (ctx.subject) return { subject: ctx.subject };
  if (ctx.exam) return { exam: ctx.exam };
  if (ctx.mode) return { mode: ctx.mode };
  return {};
}

const same = (a: Scope, b: Scope) =>
  (a.mode ?? "") === (b.mode ?? "") && (a.subject ?? "").toLowerCase() === (b.subject ?? "").toLowerCase() &&
  (a.exam ?? "") === (b.exam ?? "") && (a.answer_type ?? "") === (b.answer_type ?? "");

/** The wider scope that covers both: another subject in the same mode = the mode; another mode = global. */
export function widen(a: Scope, b: Scope, ctx: CorrectionContext): Scope {
  if (a.answer_type && a.answer_type === b.answer_type) return { answer_type: a.answer_type };
  const modeA = a.mode ?? ctx.mode, modeB = b.mode ?? ctx.mode;
  if (modeA && modeA === modeB && !(a.mode && b.mode && a.mode !== b.mode)) return { mode: modeA };
  return {};
}

/** Apply one correction to the list: add, replace an opposite value, or widen the scope. */
export function applyCorrection(settings: Setting[], c: { key: SettingKey; value: string }, ctx: CorrectionContext): {
  settings: Setting[];
  changed: Setting;
  widened: boolean;
} {
  const scope = guessScope(ctx);
  const list = settings.map((s) => ({ ...s, scope: { ...s.scope } }));
  // the opposite value in an overlapping scope is replaced ("kortare" after "längre")
  const opp = OPPOSITE[c.value];
  const keep = list.filter((s) => !(s.key === c.key && s.value === opp && (same(s.scope, scope) || !Object.keys(s.scope).length)));
  const hit = keep.find((s) => s.key === c.key && s.value === c.value);
  if (hit) {
    hit.n = (hit.n ?? 1) + 1;
    if (!covers(hit.scope, ctx)) {
      hit.scope = widen(hit.scope, scope, { ...ctx, mode: hit.scope.mode ?? ctx.mode });
      return { settings: keep, changed: hit, widened: true };
    }
    return { settings: keep, changed: hit, widened: false };
  }
  const s: Setting = { key: c.key, value: c.value, scope, n: 1 };
  keep.push(s);
  return { settings: keep.slice(-SETTINGS_LIMITS.settings), changed: s, widened: false };
}

/** Does the (wider) scope a cover the context b? */
export function covers(a: Scope, b: Scope | CorrectionContext): boolean {
  if (a.mode && a.mode !== b.mode) return false;
  if (a.subject && a.subject.toLowerCase() !== (b.subject ?? "").toLowerCase()) return false;
  if (a.exam && a.exam !== b.exam) return false;
  if (a.answer_type && a.answer_type !== b.answer_type) return false;
  return true;
}

/** The settings that apply in this context (for /answer). */
export function applicable(settings: Setting[], ctx: CorrectionContext): Setting[] {
  return settings.filter((s) => covers(s.scope, ctx));
}

const WORDS: Record<string, string> = {
  "length:shorter": "kortare svar",
  "length:longer": "längre, utförligare svar",
  "simplicity:simpler": "enklare förklaringar",
  "examples:more": "fler exempel",
  "accuracy:careful": "extra noggrann kontroll av fakta",
};
const MODE_NAMES: Record<string, string> = { prov: "Provläge", fragor: "Frågor", intervju: "Intervju", socialt: "Socialt", rizz: "Rizz" };
const KIND_NAMES: Record<AnswerKind, string> = { fact: "faktasvar", explanation: "förklaringar", math: "matte" };

/** "Kortare svar i matte", "Fler exempel inför Geografiprovet": the readable line (also for Minne in the app). */
export function describe(s: Setting): string {
  const what = WORDS[`${s.key}:${s.value}`] ?? `${s.key} ${s.value}`;
  const where = s.scope.answer_type
    ? ` i ${KIND_NAMES[s.scope.answer_type]}`
    : s.scope.subject
    ? ` i ${s.scope.subject.toLowerCase()}`
    : s.scope.exam
    ? ` inför ${s.scope.exam}`
    : s.scope.mode
    ? ` i ${MODE_NAMES[s.scope.mode] ?? s.scope.mode}`
    : "";
  return (what.charAt(0).toUpperCase() + what.slice(1) + where).trim();
}

/** The whole picture in at most 300 characters (no sensitive categories: the settings hold none). */
export function profileOf(settings: Setting[]): string {
  if (!settings.length) return "";
  const sorted = [...settings].sort((a, b) => (b.n ?? 1) - (a.n ?? 1));
  let out = "Användaren vill ha: ";
  const parts: string[] = [];
  for (const s of sorted) {
    const d = describe(s);
    const d0 = d.charAt(0).toLowerCase() + d.slice(1);
    if ((out + [...parts, d0].join("; ") + ".").length > 300) break;
    parts.push(d0);
  }
  return parts.length ? `${out}${parts.join("; ")}.` : "";
}

function str(v: unknown, max: number): string | undefined {
  if (typeof v !== "string") return undefined;
  const t = v.replace(/[\u0000-\u001f<>]/g, " ").replace(/\s+/g, " ").trim();
  return t ? t.slice(0, max) : undefined;
}
const KINDS = new Set(["fact", "explanation", "math"]);
const KEYS = new Set(["length", "simplicity", "examples", "accuracy"]);

export function readContext(v: unknown): CorrectionContext {
  const o = (v ?? {}) as Record<string, unknown>;
  const at = str(o.answer_type, 20);
  return {
    ...(str(o.mode, 20) ? { mode: str(o.mode, 20) } : {}),
    ...(str(o.subject, SETTINGS_LIMITS.field) ? { subject: str(o.subject, SETTINGS_LIMITS.field) } : {}),
    ...(str(o.exam, SETTINGS_LIMITS.field) ? { exam: str(o.exam, SETTINGS_LIMITS.field) } : {}),
    ...(at && KINDS.has(at) ? { answer_type: at as AnswerKind } : {}),
  };
}

/** The app's settings list, cleaned (anything malformed is dropped, at most 30). */
export function readSettings(v: unknown): Setting[] {
  if (!Array.isArray(v)) return [];
  const out: Setting[] = [];
  for (const x of v.slice(0, SETTINGS_LIMITS.settings)) {
    const o = (x ?? {}) as Record<string, unknown>;
    const key = str(o.key, 20), value = str(o.value, 20);
    if (!key || !KEYS.has(key) || !value) continue;
    const n = typeof o.n === "number" && Number.isInteger(o.n) && o.n > 0 ? Math.min(o.n, 1000) : 1;
    out.push({ key: key as SettingKey, value, scope: readContext(o.scope) as Scope, n });
  }
  return out;
}
