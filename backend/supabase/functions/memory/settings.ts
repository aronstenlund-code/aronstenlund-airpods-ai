/**
 * K10.2-3 (owner 2026-11-08 21:26: "man ska aldrig behöva rätta Lumen två gånger i rad"): a correction right after
 * an answer ("kortare", "för långt", "enklare", "mer exempel", "det där var fel", with or without "Lumen") becomes a
 * structured setting with a SCOPE guessed from the answer that was corrected: {mode?, subject?, exam?, answer_type?};
 * an empty scope is global. The same correction in another subject or mode widens the scope. All in code (no model
 * call). /memory returns the new list and a short profile (<= 300 characters) of how the user wants answers; /answer
 * gets only the settings that apply to the current context, and the profile in a cached system block.
 */

export type SettingKey = "length" | "simplicity" | "examples" | "accuracy" | "more";
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

// K13 (Oscar O10: own words 3/20): whole utterances after the wrapper is removed ("Lumen", "nej", "kan du", "lite",
// "tack", "i fortsättningen" …); never a question about something else ("vad är kortare, en mil eller …").
const C: [RegExp, SettingKey, string][] = [
  [/^(?:kortare(?: svar)?|svara kortare|korta ner(?: det| svaret)?|(?:det (?:blev|var|är) )?(?:alldeles )?för långt|för långa svar|(?:du )?pratar för mycket|för mycket(?: text| prat)?|mindre text|inte så långt|kortfattat|kortfattare|korta svar|håll det kort(?:are)?|snabbare|fatta dig kort(?:are)?)$/u, "length", "shorter"],
  [/^(?:längre(?: svar)?|svara längre|(?:förklara|berätta) mer|utveckla(?: mer| det)?|(?:det (?:blev|var|är) )?för kort(?: utveckla(?: mer)?)?|mer detaljer|mer utförligt|utförligare|mer djup)$/u, "length", "longer"],
  [/^(?:enklare(?: ord)?|(?:förklara|säg) det enklare|förklara enklare|säg det på ett enklare sätt|(?:det (?:var|är|blev) )?för svårt|jag (?:förstår|fattar) inte(?: alls| vad du menar| ett ord)?|för svåra ord|(?:förklara )?som för en (?:tioåring|femåring|åttaåring|tolvåring|nybörjare|ett barn)|lättare|(?:det (?:var|är) )?för krångligt|inte så krångligt|mindre krångligt)$/u, "simplicity", "simpler"],
  [/^(?:mer exempel|fler exempel|(?:ge|ta) (?:mig )?(?:ett|några|fler|något) exempel|ge exempel|med exempel|ett exempel till|exempel|jag behöver exempel|(?:ett )?exempel (?:hade|skulle) (?:hjälpt|vara bra|hjälpa))$/u, "examples", "more"],
  [/^(?:(?:det )?(?:där )?(?:var|är) fel|fel|inte rätt|det (?:där )?stämmer inte(?: alls)?|du har fel|det (?:där )?är inte sant|det var inte sant)$/u, "accuracy", "careful"],
];

const LEAD = /^(?:(?:hej|okej|ok|nej|men|äh|alltså|du|hörru) )+/u;
const POLITE = /^(?:(?:kan|kunde|skulle) (?:du|ni)(?: snälla)? |snälla |jag vill att du |vill du )/u;
const DEGREE = /^(?:lite|mycket|lite mer|mycket mer|ännu|ännu mer|lite grann) /u;
const TAIL = / (?:tack|snälla|nästa gång|i fortsättningen|framöver|i framtiden|från och med nu|är du snäll|då)$/u;

/** The setting a spoken correction stands for, or null. */
export function detectCorrection(text: string): { key: SettingKey; value: string } | null {
  let t = text.toLowerCase().replace(/[^\p{L}\s]/gu, " ").replace(/\s+/g, " ").trim();
  for (let i = 0; i < 3; i++) {
    t = t.replace(/^lumen /u, "").replace(LEAD, "").replace(/^lumen /u, "").replace(POLITE, "").replace(TAIL, "").trim();
  }
  const forms = [t, t.replace(DEGREE, "")];
  for (const f of forms) for (const [re, key, value] of C) if (re.test(f)) return { key, value };
  return null;
}

const OPPOSITE: Record<string, string> = { shorter: "longer", longer: "shorter" };

/**
 * Guess the scope from the answer that was corrected: maths answers by type, else the subject, else the exam, else
 * the mode. K13 (Oscar O10 #1): the mode is kept in every scope, so a later correction elsewhere can tell whether it
 * came from another mode (then the setting becomes global) and the setting never moves away from where it was given.
 */
export function guessScope(ctx: CorrectionContext): Scope {
  const m = ctx.mode ? { mode: ctx.mode } : {};
  if (ctx.answer_type === "math") return { ...m, answer_type: "math" };
  if (ctx.subject) return { ...m, subject: ctx.subject };
  if (ctx.exam) return { ...m, exam: ctx.exam };
  return m;
}

const same = (a: Scope, b: Scope) =>
  (a.mode ?? "") === (b.mode ?? "") && (a.subject ?? "").toLowerCase() === (b.subject ?? "").toLowerCase() &&
  (a.exam ?? "") === (b.exam ?? "") && (a.answer_type ?? "") === (b.answer_type ?? "");

/** The wider scope that covers both: another subject in the same mode = the mode; another mode = global. */
export function widen(a: Scope, b: Scope, _ctx?: CorrectionContext): Scope {
  const sameMode = (a.mode ?? "") === (b.mode ?? "");
  if (a.answer_type && a.answer_type === b.answer_type) {
    return sameMode && a.mode ? { mode: a.mode, answer_type: a.answer_type } : { answer_type: a.answer_type };
  }
  if (sameMode && a.mode) return { mode: a.mode };
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
      hit.scope = widen(hit.scope, scope);
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
  const what = s.key === "more"
    ? `Svar på "mer?": ${[...s.value].map((c) => (c === "y" ? "ja" : "nej")).join(", ") || "inga än"}`
    : WORDS[`${s.key}:${s.value}`] ?? `${s.key} ${s.value}`;
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
  const sorted = settings.filter((s) => s.key !== "more").sort((a, b) => (b.n ?? 1) - (a.n ?? 1));
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

/**
 * K13.2 (owner 2026-11-09 21:33): the student's answer to "mer?" after a short answer is a signal. The last three
 * signals per scope are kept ("more" = e.g. "yny"); two yes of the last three (the last one a yes) make "längre svar"
 * the default there (the long answer at once), and the history starts over. "kortare" (a correction) brings the
 * short answer first back, in the scope of the correction (it replaces "längre", see applyCorrection). A no or silence
 * is a weak signal: it only counts against the two yes. Nothing but these letters is stored.
 */
export function applySignal(settings: Setting[], signal: "yes" | "no", ctx: CorrectionContext): {
  settings: Setting[];
  history: string;
  longFirst: boolean;
  changed: Setting | null;
} {
  const scope = guessScope(ctx);
  let list = settings.map((s) => ({ ...s, scope: { ...s.scope } }));
  let h = list.find((s) => s.key === "more" && same(s.scope, scope));
  if (!h) {
    h = { key: "more", value: "", scope, n: 1 };
    list.push(h);
  }
  h.value = (h.value + (signal === "yes" ? "y" : "n")).slice(-3);
  const yes = [...h.value].filter((c) => c === "y").length;
  let changed: Setting | null = null;
  if (signal === "yes" && yes >= 2) {
    list = list.filter((s) => !(s.key === "length" && same(s.scope, scope)));
    changed = { key: "length", value: "longer", scope, n: 1 };
    list.push(changed);
    h.value = "";
  }
  const longFirst = applicable(list, ctx).some((s) => s.key === "length" && s.value === "longer");
  return { settings: list.slice(-SETTINGS_LIMITS.settings), history: h.value, longFirst, changed };
}

function str(v: unknown, max: number): string | undefined {
  if (typeof v !== "string") return undefined;
  const t = v.replace(/[\u0000-\u001f<>]/g, " ").replace(/\s+/g, " ").trim();
  return t ? t.slice(0, max) : undefined;
}
const KINDS = new Set(["fact", "explanation", "math"]);
const KEYS = new Set(["length", "simplicity", "examples", "accuracy", "more"]);

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
