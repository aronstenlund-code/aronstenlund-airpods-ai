import type { Authenticator } from "../_shared/auth.ts";
import { CORS_HEADERS, errorResponse, HttpError, toHttpError } from "../_shared/errors.ts";
import { enforceLimits, type Limits, type RateLimiter } from "../_shared/ratelimit.ts";
import { readLimitedJson } from "../answer/validate.ts";
import { toSpeech } from "../answer/speech.ts";
import { wordsToNumber } from "../answer/svnum.ts";
import { pronounce } from "../tts/handler.ts";
import { sentenceTimes, TEXT_LIMITS, voicedPart } from "./text.ts";
import { polishVoice, preVoice, V4_MODEL, VOICE_RULES_VERSION, withPauseTag } from "./voicerules.ts";
import { type QuotaAnswer, walletFields } from "../_shared/wallet.ts";
import { cleanStyle, mapOffset, STYLE_MODEL, styledKey, type Styler } from "./style.ts";
import { textLanguage } from "../exam/read.ts";
import { composeLong, examLanguage, spokenText } from "../exam/drill.ts";
import { importText } from "./import_text.ts";
import { lengthClass, lengthLimits } from "./length.ts";
import { currentTest, TEST_VOICE_ID } from "../_shared/testmode.ts";
import { type AnalysisRow, pressStats, saveRows, statsRow } from "./analysis.ts";

/** K62b (D180): test traffic never shares a file with real users and never reaches ElevenLabs (silent files). */
const voiceFor = (real: string | null) => currentTest()?.test ? TEST_VOICE_ID : real;

/**
 * K46 (D142, D143, D144, D145): Repetitionsläget, drills and their audio per account. `POST /drill` with an action:
 *  {"action":"save", "drill": {"id"?, "title"?, "subject"?, "grade"?, "covers"?, "long_words"?},
 *   "items": [{"id"?, "question", "short", "long"}]}            -> the drill as "get" returns it
 *     Replaces the drill's list (order = play order). Each item needs two audio files: the question and the long
 *     answer; the short answer is the start of the long file (D145), up to `short_end_ms`. A file is named by the
 *     hash of the exact text sent to the voice, the voice and the model: when ANY account already has it, nothing is
 *     generated (D144). New files are queued in play order and made in the background.
 *  {"action":"get"|"status", "id"} -> {"drill", "items": [{..., "audio": {"question": {...}, "long": {...}}}],
 *     "audio": {"done", "total", "failed", "chars", "est_usd", "bytes"}}   (signed URLs for done files, 1 hour)
 *     "status" also moves the queue on (if a background run stopped, polling finishes the work).
 *  {"action":"list"} -> {"drills": [{"id","title","subject","grade","items","audio":{"done","total"},"updated_at"}]}
 *  {"action":"delete", "id"} -> {"deleted": true}
 * K47 (D143), sharing with classmates (spec §9: anyone with the code and an account; the copy is the recipient's own):
 *  {"action":"share", "id"} -> {"code", "url", "app_url"}   only when 100 % of the audio is done, else 409 with the
 *     progress ("Delas när ljudet är klart (54 av 90)"). The same code again for the same drill until it is revoked.
 *  {"action":"unshare", "id"} -> {"revoked": n}               the owner turns the share off
 *  {"action":"share_info", "code"} -> {"title","subject","grade","items"}   what the link holds, before importing
 *  {"action":"import", "code"} -> the copy as "get" returns it   questions and answers copied, the same audio files
 *     (0 ElevenLabs calls); the recipient's edits make files only for what they change and never touch the original.
 * K49 (D149, D150), Publicera prov (spec §11):
 *  {"action":"schools", "q"} -> {"schools": [{"code","name","locality"}]}   active units of Skolverket's register
 *  {"action":"publish", "id", "school_code", "subject", "exam_date": "YYYY-MM-DD", "show_name"?, "display_name"?}
 *     -> {"publication"}   409 "publish_incomplete" with "missing": ["school","subject","date","audio"] otherwise
 *  {"action":"unpublish", "id"}   the publisher removes it at any time
 *  {"action":"search", "school_code"?, "subject"?, "my_school"?, "from"?, "to"?}
 *     -> {"results": [{"id","title","subject","school":{"code","name","locality"},"exam_date","items","display_name"?}]}
 *     the student's own school first, then exams at most 30 days back, then older; hidden ones never; no account ever
 *  {"action":"import", "publication_id"} -> the copy (as "get"), 0 characters; counted (number only)
 *  {"action":"report", "publication_id", "reason": "fel"|"krankande"|"upphovsratt"|"annat"} -> {"reports","hidden"}
 *  {"action":"played", "id"} (the user's own copy) -> {"counted"}   one play counted on the publication it came from
 *  {"action":"moderate", "publication_id", "hidden": false}   Aron only
 * K58 (D169), the answer pasted from ChatGPT under "Skriv text":
 *  {"action":"import_text", "text"} -> {"items": [{"id","question","short","long"}], "skipped": [{"line","text","reason"}],
 *     "warnings": [...], "count"}   no Claude call, nothing shortened; save the items with "save" as any drill.
 *     422 "import_unreadable" (with "skipped") when no question could be read.
 * The material is never stored (B4). Characters for NEW files count against a daily limit per account and globally.
 */
export const DRILL_STORE_LIMITS = {
  bodyBytes: 512 * 1024,
  items: 60,
  question: 300,
  short: 600,
  long: 4000, // K60: a pasted ChatGPT answer is kept whole up to 4 000 characters (import_text warns over 3 000)
  drillsPerUser: 200,
};

/** K88: a client_id is a UUID (any version), lower-cased; anything else is null. */
export function clientIdOf(v: unknown): string | null {
  return typeof v === "string" && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(v.trim()) ? v.trim().toLowerCase() : null;
}

export interface DrillRow {
  id: string;
  user_id: string;
  title: string;
  subject: string;
  grade: string;
  covers: string;
  long_words: number;
  shared_from?: string | null;
  /** K50 (D151): the voice model, chosen before the audio is made and locked after. */
  voice_model?: string;
  /** K70 (D185): "questions" (default) or "text" (Läsläget: the items are the text's parts, read aloud in order). */
  kind?: "questions" | "text";
  /** K71 (D190): when Starta prov (or an old app's save) queued the audio; null = text only, editable for free. */
  audio_started_at?: string | null;
  /** K78 (D200): questions of this drill given back because their audio could not be made. */
  refunded?: number | null;
  /** K72: the language a text drill is read in ("" or null = by the subject, as before; "sv"; "English" ...). */
  language?: string | null;
  /** K74: the voice text's rules version (1 = before K74, kept for old drills so their hashes stay; 2 = now). */
  voice_rules?: number;
  /** K90 (D213): credits (characters) charged for this drill's audio and given back when it could not be made. */
  charged_chars?: number;
  refunded_chars?: number;
  /** Angela Fable (T28): a Säg text (not an exam); set at the first save, kept, never copied by share or import. */
  said?: boolean | null;
  /** K99 (D223): "Blanda röster": each part (or question) gets a catalog voice by lot at its first save. */
  mix_voices?: boolean | null;
  /** K96 (D220): the drill's own voice from the catalog (null = the default voice); locked at the first save (D151). */
  voice_id?: string | null;
  /** K95 (D220): "Hur ska det låta?" (null = none); with a style the audio is eleven_v3 with tags. */
  style?: string | null;
  /** K88 (D211): the app's own id for the exam (its local UUID): the same id from the same account is one exam. */
  client_id?: string | null;
  created_at?: string;
  updated_at?: string;
}
export interface ItemRow {
  id?: string;
  drill_id: string;
  user_id: string;
  position: number;
  question: string;
  short: string;
  long: string;
  question_hash: string;
  long_hash: string;
  /** K66 (O63 punkt 4): what the app shows where it differs from the spoken text (1850, a² + b²); never voiced. */
  screen?: { question?: string; short?: string; long?: string } | null;
  /** K61 (D176): question + long answer, characters sent to ElevenLabs, and the class */
  voice_chars?: number | null;
  length_class?: string | null;
  /** K70: a text drill's part ("heading" or "para"); null for a question. */
  part?: "heading" | "para" | null;
  /** K99 (D223): this item's own voice when the drill mixes voices (null = the drill's voice). */
  voice_id?: string | null;
}
export interface AudioRow {
  hash: string;
  kind: "question" | "long" | "text";
  text: string;
  short_chars?: number | null;
  model: string;
  voice_id: string;
  status?: "pending" | "working" | "done" | "failed";
  attempts?: number;
  chars?: number | null;
  bytes?: number | null;
  duration_ms?: number | null;
  short_end_ms?: number | null;
  words?: number[][] | null;
  /** K70: a text file's sentence ends (characters, when queued) and [[start_ms, end_ms], ...] per sentence (when made). */
  sentence_ends?: number[] | null;
  sentences?: number[][] | null;
  /** K50: what ElevenLabs charged for the file (`character-cost`), when it said. */
  credits?: number | null;
  seq?: number;
  queued_at?: string;
  error?: string | null;
  done_at?: string | null;
}

/** K62 (Angela b58678d): the app shows "Ljudet kan inte göras just nu" for this code on a failed file. */
export const AUDIO_UNAVAILABLE = "audio_unavailable";
/** K62: files that failed because ElevenLabs had no credits are tried again after this long (when someone looks). */
export const UNAVAILABLE_RETRY_MS = 10 * 60_000;
/**
 * K78 (D200): what the app shows when ElevenLabs has no credits. The questions and answers are text as usual; the
 * user is never charged a question for audio that was not made, and the audio is made the next time once credits
 * are back (Starta prov again, or status after UNAVAILABLE_RETRY_MS).
 */
export const AUDIO_UNAVAILABLE_NOTICE = { code: AUDIO_UNAVAILABLE, message: "Uppläsningen är tillfälligt avstängd. Texten fungerar som vanligt." };

export interface DrillDb {
  drill(id: string): Promise<DrillRow | null>;
  drills(userId: string): Promise<DrillRow[]>;
  saveDrill(row: DrillRow, isNew: boolean): Promise<void>;
  /** K88 (D211): the account's exam saved with this client_id, or null. */
  drillByClient?(userId: string, clientId: string): Promise<DrillRow | null>;
  items(drillIds: string[]): Promise<(ItemRow & { id: string })[]>;
  replaceItems(drillId: string, keepIds: string[], rows: ItemRow[]): Promise<void>;
  deleteDrill(id: string): Promise<void>;
  audio(hashes: string[]): Promise<AudioRow[]>;
  enqueue(rows: AudioRow[]): Promise<void>;
  claim(n: number): Promise<AudioRow[]>;
  finish(hash: string, patch: Partial<AudioRow> & { status: string; error?: string | null; done_at?: string }): Promise<void>;
  /** K47 */
  shareOf(drillId: string): Promise<ShareRow | null>;
  shareByCode(code: string): Promise<ShareRow | null>;
  createShare(row: ShareRow): Promise<void>;
  revokeShares(drillId: string): Promise<number>;
  countImport(code: string): Promise<void>;
  /** K49 */
  schools(q: string, limit: number): Promise<SchoolRow[]>;
  school(code: string): Promise<SchoolRow | null>;
  publicationOf(drillId: string): Promise<PublicationRow | null>;
  publication(id: string): Promise<PublicationRow | null>;
  savePublication(row: PublicationRow): Promise<void>;
  deletePublication(drillId: string): Promise<void>;
  searchPublications(f: { school?: string; subject?: string; from?: string; to?: string }): Promise<PublicationRow[]>;
  report(publicationId: string, userId: string, reason: string): Promise<{ reports: number; hidden: boolean }>;
  bump(publicationId: string, field: "imports" | "plays"): Promise<void>;
  setHidden(publicationId: string, hidden: boolean): Promise<void>;
  /** K55: is anything still waiting or being made? (the generator waits instead of stopping while others work) */
  pending(): Promise<boolean>;
  /** K55: files that failed are queued again when someone saves the same text. */
  requeue(hashes: string[]): Promise<void>;
  /** K50: adds n generated questions when within the limit (n = 0 only reads); atomic in the database. */
  /** K93 (D216): an admin (credit_admins) answers unlimited, is never counted and never refused (lim = used + a large number). */
  useQuota(userId: string, n: number): Promise<QuotaAnswer>;
  /** K78 (D200): gives back n questions counted for audio that could not be made (never below 0). */
  refundQuota?(userId: string, n: number): Promise<void>;
  /** K78: a real file failed for lack of ElevenLabs credits since this time (then nothing new is sent now). */
  recentUnavailable?(sinceIso: string, testVoice: boolean): Promise<boolean>;
  /** K78: remember how many of a drill's questions were given back, so they are given back once. */
  setRefunded?(drillId: string, n: number): Promise<void>;
  /** K64: which of these file hashes some question (drill_items) still uses. */
  referenced?(hashes: string[]): Promise<string[]>;
  /** K61 (D176): drill_settings (length_normal_max, length_longer_max, ...). */
  settings?(): Promise<Record<string, number>>;
  /** K96 (D220): is this voice in the curated catalog (voice_catalog, enabled)? */
  voiceAllowed?(voiceId: string): Promise<boolean>;
  /** K99 (D223): the catalog's voices everyone may use (enabled, not under review), for mixing and the AI's choice. */
  catalogVoices?(): Promise<{ voice_id: string; name: string; description?: string | null; accent?: string | null; gender?: string | null; age?: string | null }[]>;
  /** K61 (D177): which of these question keys were already counted in /help try, and dropping them once used. */
  tryCredits?(userId: string, keys: string[]): Promise<string[]>;
  dropTryCredits?(userId: string, keys: string[]): Promise<void>;
}
export interface SchoolRow {
  code: string;
  name: string;
  locality?: string | null;
  status?: string;
}
export interface PublicationRow {
  id: string;
  drill_id: string;
  user_id: string;
  school_code: string;
  subject: string;
  exam_date: string;
  display_name: string | null;
  hidden?: boolean;
  reports?: number;
  imports?: number;
  plays?: number;
}
export interface ShareRow {
  code: string;
  drill_id: string;
  user_id: string;
  revoked_at?: string | null;
}
/** K47: the link that opens EarMind (universal link once earmind.ai serves apple-app-site-association; scheme until then). */
export const SHARE_URL = (code: string) => `https://earmind.ai/p/${code}`;
export const SHARE_APP_URL = (code: string) => `earmind://prov/${code}`;
export function newShareCode(): string {
  const abc = "abcdefghjkmnpqrstuvwxyz23456789"; // no 0/o, 1/l/i: easy to read aloud and type
  const b = crypto.getRandomValues(new Uint8Array(10));
  return Array.from(b, (x) => abc[x % abc.length]).join("");
}
export interface AudioStorage {
  upload(path: string, bytes: Uint8Array): Promise<void>;
  sign(paths: string[]): Promise<Record<string, string>>;
}
export interface Synth {
  /** One file: mp3 bytes and the start/end time of every character of `text` (ElevenLabs "with-timestamps"). */
  speak(text: string, model: string, voiceId: string): Promise<{ audio: Uint8Array; starts: number[]; ends: number[]; credits?: number | null }>;
}

export interface DrillDeps {
  authenticate: Authenticator;
  /** K77 (D197, D116): rows for Aron's analysis (table qa_log); never for test accounts. */
  analysis?: (rows: AnalysisRow[]) => Promise<void>;
  rateLimiter: RateLimiter;
  db: DrillDb;
  storage: AudioStorage;
  synth: Synth | null;
  /** The default voice model (D151: A = Multilingual v2). A drill may choose another of VOICE_MODELS. */
  model: string;
  voiceId: string | null;
  /** USD per 1 000 characters at list price (verified 2026-11-13: v2/v3 0.08, Flash 0.04); see usdPer1k(). */
  usdPer1kChars: number;
  /** Characters of NEW audio per account and day, and for everyone (D144). */
  charLimits: Limits;
  /** Runs the generator after the response (EdgeRuntime.waitUntil); tests await it. */
  background?: (p: Promise<unknown>) => void;
  now?: () => number;
  /** K55: waiting between tries when ElevenLabs is busy (tests pass a no-op). */
  sleep?: (ms: number) => Promise<void>;
  /** K98 (D224): the account started its audio (Starta prov / Spela): an invitation is rewarded on the first one. */
  onStarted?: (userId: string) => Promise<unknown>;
  /** K99 (D223): Haiku picks the catalog voice that fits a style; null = keep the default voice. */
  voicePicker?: (style: string, voices: { voice_id: string; name: string; description?: string | null; accent?: string | null; gender?: string | null; age?: string | null }[]) => Promise<{ voice_id: string; reason: string } | null>;
  /** K95 (D220): adds v3 tags for a style (Haiku); without it a styled file is made from the untagged text. */
  styler?: Styler;
  /** K49: Aron (OWNER_EMAIL, signed in by e-mail) shows a hidden publication again. */
  ownerEmails?: string[];
}

// ---------- text and hashes ----------

/** Exactly what the voice reads: no markdown, numbers and symbols in words, measured spellings (K18). */
export function voiceText(s: string, lang = "", rules = 1): string {
  // K74: rules version 2 adds the table in voicerules.ts (abbreviations, brackets, slashes, symbols, quotes, long
  // sentences); version 1 is exactly the text before K74 (drills made earlier keep their hashes)
  if (lang) {
    const f = foreignVoice(preVoice(spokenText(s, 4000), lang, rules));
    return rules >= 2 ? polishVoice(f, lang, rules) : f;
  }
  // a sentence end as the context: each text starts a sentence ("6 koldioxid" -> "Sex koldioxid")
  const t = divided(pronounce(toSpeech(preVoice(spokenText(s, 4000), "", rules), "Start. "), "sv"), "delat med").replace(/\s+/g, " ").trim();
  return rules >= 2 ? polishVoice(t, "", rules) : t;
}

/**
 * K67 (Oscar O64 punkt 1): a "/" left in a formula after toSpeech ("v är lika med s / t", "b gånger h / två") is
 * "delat med". Units were already said ("km/h" -> "kilometer i timmen"). Two ordinary words ("och/eller") keep it.
 */
export function divided(t: string, word: string): string {
  return t.replace(/([\p{L}\p{N})²³]+)\s*\/\s*([\p{L}\p{N}(]+)/gu, (m, a: string, b: string) => {
    // two ordinary words ("och/eller", "ja/nej", "him/her") keep it; a single letter is a variable ("s / t", "F/A")
    const plain = (w: string) => /^\p{L}{2,}$/u.test(w) && wordsToNumber(w.toLowerCase()) === null;
    return plain(a) && plain(b) ? m : `${a} ${word} ${b}`;
  });
}

/**
 * K67 (O64 punkt 3, D182): a language exam's text: digits stay digits (the voice reads them in the text's language;
 * the Swedish number words made "Since about artonhundrafemtio"), only formula signs become English words.
 */
export function foreignVoice(t: string): string {
  // O65: units and common fractions first ("12 km/h" was "12 km divided by h", "3/4" was "3 divided by 4")
  const UNITS: [RegExp, string][] = [[/\bkm\/h\b/g, "kilometres per hour"], [/\bm\/s²/g, "metres per second squared"], [/\bm\/s\b/g, "metres per second"],
    [/\bkg\/m³/g, "kilograms per cubic metre"], [/\bg\/cm³/g, "grams per cubic centimetre"], [/\bmph\b/g, "miles per hour"]];
  const FRACTIONS: Record<string, string> = { "1/2": "one half", "1/3": "one third", "2/3": "two thirds", "1/4": "a quarter", "3/4": "three quarters", "1/5": "one fifth", "1/10": "one tenth" };
  let u = t;
  for (const [re, w] of UNITS) u = u.replace(re, w);
  u = u.replace(/(?<![\d/])(\d{1,2})\/(\d{1,2})(?![\d/])/g, (m) => FRACTIONS[m] ?? m.replace("/", " over "));
  return divided(u, "divided by")
    .replace(/(\d)\s*%/g, "$1 percent")
    .replace(/²/g, " squared").replace(/³/g, " cubed")
    .replace(/\s*[·×]\s*/g, " times ").replace(/\s+=\s+/g, " equals ").replace(/\s+\+\s+/g, " plus ")
    .replace(/\s+/g, " ").trim();
}
/** K66: the display text sent with save (only strings, the store's limits); null when there is none. */
export function screenOf(v: unknown): { question?: string; short?: string; long?: string } | null {
  if (!v || typeof v !== "object") return null;
  const o = v as Record<string, unknown>;
  const q = clean(o.question, DRILL_STORE_LIMITS.question), s = clean(o.short, DRILL_STORE_LIMITS.short), l = clean(o.long, DRILL_STORE_LIMITS.long);
  const out = { ...(q ? { question: q } : {}), ...(s ? { short: s } : {}), ...(l ? { long: l } : {}) };
  return Object.keys(out).length ? out : null;
}

/** D145: the long file is the short answer, then the rest; the boundary is known to the character. */
export function longVoice(short: string, long: string, lang = "", rules = 1): { text: string; shortChars: number } {
  const s = voiceText(short, lang, rules);
  const rest = long.startsWith(short) ? long.slice(short.length) : long;
  const r = voiceText(rest, lang, rules);
  return { text: r ? `${s} ${r}` : s, shortChars: s.length };
}
export async function audioHash(text: string, model: string, voiceId: string): Promise<string> {
  const data = new TextEncoder().encode(JSON.stringify(["drill-audio-v1", text, model, voiceId, "mp3_44100_64"]));
  const d = new Uint8Array(await crypto.subtle.digest("SHA-256", data));
  return Array.from(d, (b) => b.toString(16).padStart(2, "0")).join("");
}
export const audioPath = (hash: string) => `${hash.slice(0, 2)}/${hash}.mp3`;

/** Word timings from character timings: [[start_ms, end_ms], ...], and where the short answer ends. */
export function timings(text0: string, starts: number[], ends: number[], shortChars?: number | null) {
  // K95: a v3 tag ("[calm]") is not a word; blanked out with the same length so the character times still match
  const text = text0.replace(/\[[a-z ]{1,30}\]/g, (m) => " ".repeat(m.length));
  const words: number[][] = [];
  let i = 0;
  while (i < text.length) {
    while (i < text.length && /\s/.test(text[i])) i++;
    if (i >= text.length) break;
    const s = i;
    while (i < text.length && !/\s/.test(text[i])) i++;
    const a = starts[s], b = ends[i - 1];
    if (Number.isFinite(a) && Number.isFinite(b)) words.push([Math.round(a * 1000), Math.round(b * 1000)]);
  }
  const last = ends.length ? ends[ends.length - 1] : 0;
  const shortEnd = shortChars && shortChars > 0 && shortChars <= ends.length ? Math.round(ends[shortChars - 1] * 1000) : null;
  return { words, duration_ms: Math.round(last * 1000), short_end_ms: shortEnd };
}

// ---------- Kelly N1 / Angela: fixed cues in the drill's own voice ----------

/** Spoken once per voice ever (the same hash cache): never counted against the limit, about 25 characters each. */
export const CUES: Record<string, string> = { press_for_answer: "Tryck en gång för svaret." };

// ---------- K50 helpers ----------

/** D151: A = Multilingual v2 (default), B = v3, C = Flash v2.5. Also accepted as "A"/"B"/"C" or "v2"/"v3"/"flash". */
export const VOICE_MODELS = ["eleven_multilingual_v2", "eleven_v3", "eleven_flash_v2_5", "eleven_v4"] as const;
export function voiceModel(v: unknown): string | null {
  if (typeof v !== "string") return null;
  const k = v.trim().toLowerCase();
  const alias: Record<string, string> = { a: VOICE_MODELS[0], v2: VOICE_MODELS[0], b: VOICE_MODELS[1], v3: VOICE_MODELS[1], c: VOICE_MODELS[2], flash: VOICE_MODELS[2] };
  return (VOICE_MODELS as readonly string[]).includes(k) ? k : alias[k] ?? null;
}
/** K52 (D155): the limit is per calendar month in Swedish time; the first day of the next month, "YYYY-MM-DD". */
const MONTHS = ["januari", "februari", "mars", "april", "maj", "juni", "juli", "augusti", "september", "oktober", "november", "december"];
/** K64 (Kelly, repetition-texter §6): "Nya frågor går att göra från den 1 december." (abonnemang kommer senare, HJALP.md) */
export function newFrom(nowMs: number): string {
  return `Nya frågor går att göra från den 1 ${MONTHS[Number(nextMonthStart(nowMs).slice(5, 7)) - 1]}.`;
}

export function nextMonthStart(nowMs: number): string {
  const ym = new Intl.DateTimeFormat("sv-SE", { timeZone: "Europe/Stockholm", year: "numeric", month: "2-digit" }).format(new Date(nowMs));
  const [y, m] = ym.split("-").map(Number);
  return m === 12 ? `${y + 1}-01-01` : `${y}-${String(m + 1).padStart(2, "0")}-01`;
}

/** K90 (D213): "1 december" for the 402 text and the capsule. */
export function resetsDay(nowMs: number): string {
  return `1 ${MONTHS[Number(nextMonthStart(nowMs).slice(5, 7)) - 1]}`;
}

/**
 * K90 (D213): what new audio costs, in credits = characters of the shown text (Aron: "764 tecken kostar 764
 * krediter"), per audio file: a text part's text, a question's question and its long answer. Audio that already
 * exists (any account's, D144) costs 0, and so do repeats.
 */
export function creditCost(display: Map<string, number>, hashes: Iterable<string>): number {
  let n = 0;
  for (const h of new Set(hashes)) n += display.get(h) ?? 0;
  return n;
}

/** The shown characters per audio file of a drill's items (see creditCost). */
export function displayChars(items: { part?: string | null; question: string; long: string; question_hash: string; long_hash: string }[]): Map<string, number> {
  const m = new Map<string, number>();
  for (const i of items) {
    if (i.part) m.set(i.long_hash, (i.long ?? "").length);
    else {
      m.set(i.question_hash, (i.question ?? "").length);
      m.set(i.long_hash, (i.long ?? "").length);
    }
  }
  return m;
}

/** K90 (Kelly Ke71): "2 011" with a no-break space between the thousands, so the number never breaks. */
export function thousands(n: number): string {
  return String(Math.round(n)).replace(/\B(?=(\d{3})+(?!\d))/g, "\u00a0");
}

/** K90: the 402 when the credits do not reach; nothing was saved or started. Old fields kept for older apps. */
export function creditsRefused(cost: number, used: number, limit: number, nowMs: number) {
  const remaining = Math.max(0, limit - used);
  return {
    error: {
      code: "quota_exceeded",
      message: `Det här kostar ${thousands(cost)} krediter. Du har ${thousands(remaining)} kvar. Nya krediter den ${resetsDay(nowMs)}.`,
      fallback: false,
    },
    unit: "chars", cost, remaining, limit, used, resets: nextMonthStart(nowMs),
    needed: cost, per: "month",
  };
}

/** List price per 1 000 characters (ElevenLabs API page, 2026-11-13): Flash half of v2/v3. */
export const usdPer1k = (model: string, base: number) => /flash|turbo/i.test(model) ? base / 2 : base;

// ---------- K49 helpers ----------

/** "YYYY-MM-DD" within two years back and one year ahead of `nowMs`, or null. */
export function validDate(v: unknown, nowMs: number): string | null {
  if (typeof v !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(v)) return null;
  const t = Date.parse(`${v}T00:00:00Z`);
  if (!Number.isFinite(t) || new Date(t).toISOString().slice(0, 10) !== v) return null;
  return t > nowMs - 2 * 365 * 864e5 && t < nowMs + 366 * 864e5 ? v : null;
}
export const daysBetween = (a: string, b: string) => Math.round((Date.parse(`${b}T00:00:00Z`) - Date.parse(`${a}T00:00:00Z`)) / 864e5);

/** What anyone may see of a published drill: never the account, photos or documents (B4, D149/D150). */
/** K65 (Kelly P1, A87 punkt 5): what a publication shows before "Lägg till": the first questions and the first audio. */
export interface PublicPreview {
  preview: { question: string; short: string; part?: string; screen?: { question?: string; short?: string } }[];
  first_audio_url: string | null;
}
/** K65 + K66 (A102): a preview row, with the display text for the question and the short answer when it differs. */
export function previewItem(i: {
  question?: string; short?: string; long?: string; text?: string; part?: string | null;
  screen?: { question?: string; short?: string; long?: string } | null;
}) {
  // K70 (D185): a text part shows its text as the row (no answer)
  if (i.part) return { question: (i.text ?? i.long ?? "").slice(0, 300), short: "", part: i.part };
  const sc = { ...(i.screen?.question ? { question: i.screen.question } : {}), ...(i.screen?.short ? { short: i.screen.short } : {}) };
  return { question: i.question ?? "", short: i.short ?? "", ...(Object.keys(sc).length ? { screen: sc } : {}) };
}
export const PREVIEW_QUESTIONS = 4;
export function publicView(r: PublicationRow, school: SchoolRow, title: string, items: number, pv?: PublicPreview) {
  return {
    id: r.id,
    title,
    subject: r.subject,
    school: { code: school.code, name: school.name, locality: school.locality ?? null },
    exam_date: r.exam_date,
    items,
    ...(r.display_name ? { display_name: r.display_name } : {}),
    ...(pv ? { preview: pv.preview, first_audio_url: pv.first_audio_url } : {}),
  };
}

// ---------- the handler ----------

const clean = (s: unknown, max: number) =>
  typeof s === "string" ? s.replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f]/g, " ").replace(/\s+/g, " ").trim().slice(0, max) : "";
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function createDrillHandler(deps: DrillDeps) {
  const now = deps.now ?? Date.now;
  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json", "cache-control": "no-store", ...CORS_HEADERS } });

  /**
   * K62b (Oscar O61 fynd 1): a test request never starts the shared queue (it would make other people's files with
   * the real voice). It makes only its own files, which all have the silent test voice, right here.
   */
  async function testPump(hashes: string[]): Promise<number> {
    if (!deps.synth || !hashes.length) return 0;
    let made = 0;
    const mode = currentTest()?.mode ?? null;
    if (mode === "slow") return 0; // K64: Oscar and Toby can test "Ljud: 0 av 6 klara" (the files stay pending)
    for (const j of (await deps.db.audio(hashes)).filter((a) => a.voice_id === TEST_VOICE_ID && a.status !== "done")) {
      if (mode === "unavailable") {
        // K64: as if ElevenLabs had no credits: the app's "Ljudet kan inte göras just nu" without a real call
        await deps.db.finish(j.hash, { status: "failed", error: `${AUDIO_UNAVAILABLE}: test (x-earmind-test: unavailable)`, done_at: new Date(now()).toISOString() });
        continue;
      }
      try {
        const r = await deps.synth.speak(j.text, j.model, j.voice_id);
        await deps.storage.upload(audioPath(j.hash), r.audio);
        const t = timings(j.text, r.starts, r.ends, j.short_chars);
        await deps.db.finish(j.hash, {
          status: "done", chars: j.text.length, bytes: r.audio.length, duration_ms: t.duration_ms, short_end_ms: t.short_end_ms,
          words: t.words, credits: 0, error: null, done_at: new Date(now()).toISOString(),
          ...(j.sentence_ends?.length ? { sentences: sentenceTimes(r.starts, r.ends, j.sentence_ends) } : {}),
        });
        made++;
      } catch (e) {
        console.error("drill_test_audio_failed", j.hash.slice(0, 12), e instanceof Error ? e.message.slice(0, 120) : String(e));
      }
    }
    return made;
  }
  /** Starts making files: the shared queue for real traffic, only the request's own silent files for a test. */
  const kick = (hashes: string[], wait = false): Promise<unknown> | void => {
    const p = currentTest()?.test ? testPump(hashes) : pump();
    if (deps.background && !wait) deps.background(p);
    else return p;
  };

  /** Makes queued files until the queue is empty or the time is up. Never throws. */
  async function pump(budgetMs = 110_000): Promise<number> {
    if (!deps.synth) return 0;
    const t0 = now();
    let made = 0;
    const seenYoung = new Set<string>(); // K64: files put back because their drill may be saving
    const sleep = deps.sleep ?? ((ms: number) => new Promise<void>((r) => setTimeout(r, ms)));
    try {
      while (now() - t0 < budgetMs) {
        // K55: the database keeps at most drill_settings.tts_concurrency files in the making, for all instances
        const jobs = await deps.db.claim(3);
        if (!jobs.length) {
          if (!(await deps.db.pending())) break;
          await sleep(1500); // others are making files: wait for a free slot instead of stopping
          continue;
        }
        // K64 (Oscar O61 fynd 2): no credits for audio no question uses (a deleted drill). Cues (seq < 0) are
        // always used; a file queued in the last 2 minutes may belong to a drill being saved right now.
        const used = deps.db.referenced ? new Set(await deps.db.referenced(jobs.filter((j) => (j.seq ?? 0) >= 0).map((j) => j.hash)).catch(() => jobs.map((j) => j.hash))) : null;
        const skip = new Set<string>();
        let fresh = 0;
        if (used) {
          for (const j of jobs) {
            if ((j.seq ?? 0) < 0 || used.has(j.hash)) continue;
            skip.add(j.hash);
            const young = now() - Date.parse(j.queued_at ?? "1970-01-01") < 120_000;
            if (young && !seenYoung.has(j.hash)) fresh++;
            if (young) seenYoung.add(j.hash);
            await deps.db.finish(j.hash, young
              ? { status: "pending", attempts: Math.max(0, (j.attempts ?? 1) - 1), error: null }
              : { status: "failed", attempts: 3, error: "unused: no question uses this file (K64)" }).catch(() => {});
          }
        }
        // only recent files already seen this round: stop (the next save or status picks them up)
        if (skip.size === jobs.length && !fresh && jobs.every((j) => seenYoung.has(j.hash))) break;
        await Promise.all(jobs.filter((j) => !skip.has(j.hash)).map(async (j) => {
          try {
            const r = await deps.synth!.speak(j.text, j.model, j.voice_id);
            await deps.storage.upload(audioPath(j.hash), r.audio);
            const t = timings(j.text, r.starts, r.ends, j.short_chars);
            await deps.db.finish(j.hash, {
              status: "done",
              chars: j.text.length,
              bytes: r.audio.length,
              duration_ms: t.duration_ms,
              short_end_ms: t.short_end_ms,
              words: t.words,
              credits: r.credits ?? null,
              error: null,
              done_at: new Date(now()).toISOString(),
              ...(j.sentence_ends?.length ? { sentences: sentenceTimes(r.starts, r.ends, j.sentence_ends) } : {}),
            });
            made++;
          } catch (e) {
            const msg = e instanceof Error ? e.message.slice(0, 300) : String(e).slice(0, 300);
            if (/\b429\b|concurrent_limit|rate_limit/i.test(msg)) {
              // K55: ElevenLabs is busy (plan: 3 at a time): back in the queue, not counted as a try
              await deps.db.finish(j.hash, { status: "pending", attempts: Math.max(0, (j.attempts ?? 1) - 1), error: null }).catch(() => {});
              await sleep(1500);
              return;
            }
            console.error("drill_audio_failed", j.hash.slice(0, 12), msg);
            if (/quota|credit|\b401\b|\b402\b/i.test(msg)) {
              // K62: out of credits: the file says so (the app shows "Ljudet kan inte göras just nu"), files that are
              // done stay playable, and it is tried again later (status, after UNAVAILABLE_RETRY_MS) without counting a try
              await deps.db.finish(j.hash, {
                status: "failed", attempts: Math.max(0, (j.attempts ?? 1) - 1), error: `${AUDIO_UNAVAILABLE}: ${msg.slice(0, 200)}`,
                done_at: new Date(now()).toISOString(),
              }).catch(() => {});
              throw e; // stop: the other files would fail the same way
            }
            await deps.db.finish(j.hash, { status: (j.attempts ?? 1) >= 3 ? "failed" : "pending", error: msg }).catch(() => {});
          }
        }));
      }
    } catch (e) {
      console.error("drill_pump_stopped", e instanceof Error ? e.message.slice(0, 200) : String(e));
    }
    return made;
  }

  async function view(drill: DrillRow) {
    const items = (await deps.db.items([drill.id])).sort((a, b) => a.position - b.position);
    const hashes = [...new Set(items.flatMap((i) => [i.question_hash, i.long_hash]).filter(Boolean))];
    const audio = new Map((await deps.db.audio(hashes)).map((a) => [a.hash, a]));
    const done = hashes.filter((h) => audio.get(h)?.status === "done");
    const urls = done.length ? await deps.storage.sign(done.map(audioPath)) : {};
    const file = (h: string) => {
      const a = audio.get(h);
      if (!a) return { status: "missing" };
      return {
        status: a.status,
        ...(a.status === "failed" ? { error: (a.error ?? "").startsWith(AUDIO_UNAVAILABLE) ? AUDIO_UNAVAILABLE : "audio_failed" } : {}),
        ...(a.status === "done"
          ? {
            url: urls[audioPath(h)] ?? null, duration_ms: a.duration_ms, ...(a.kind === "long" ? { short_end_ms: a.short_end_ms } : {}),
            ...(a.kind === "text" ? { sentences: a.sentences ?? null } : {}),
            // K97/D220 "Skriv i takt": [start_ms, end_ms] per spoken word, in order (null for files made before)
            ...(a.kind === "text" || a.kind === "long" ? { words: a.words ?? null } : {}),
          }
          : {}),
      };
    };
    const chars = hashes.reduce((n, h) => n + (audio.get(h)?.text.length ?? 0), 0);
    const cue = await cueView(drill.voice_model ?? deps.model, drill.voice_id);
    const model = drill.voice_model ?? deps.model;
    // K50: what ElevenLabs actually charged (character-cost), for the files that report it
    const charged = hashes.map((h) => audio.get(h)).filter((a) => a?.status === "done" && typeof a.credits === "number");
    return {
      drill: {
        id: drill.id, title: drill.title, subject: drill.subject, grade: drill.grade, covers: drill.covers,
        long_words: drill.long_words, shared_from: drill.shared_from ?? null, voice_model: model, kind: drill.kind ?? "questions",
        style: drill.style ?? null, voice_id: drill.voice_id ?? null, mix_voices: !!drill.mix_voices, said: !!drill.said,
        audio_started: !!drill.audio_started_at, ...(drill.kind === "text" ? { language: drill.language ?? null } : {}),
        created_at: drill.created_at, updated_at: drill.updated_at,
      },
      cue,
      items: items.map((i) => i.part
        ? {
          // K70 (D185): a text part; "sentences" are the displayed sentences, the audio's "sentences" their times
          id: i.id, position: i.position, part: i.part, text: i.long,
          sentences: voicedPart(i.long, i.part, (x) => voiceText(x, drill.language ? (drill.language === "sv" ? "" : drill.language) : examLanguage(drill.subject))).display,
          voice_chars: i.voice_chars ?? null, audio: { text: file(i.long_hash) }, ...(i.voice_id ? { voice_id: i.voice_id } : {}),
        }
        : {
          id: i.id, position: i.position, question: i.question, short: i.short, long: i.long, ...(i.screen ? { screen: i.screen } : {}),
          voice_chars: i.voice_chars ?? null, length_class: i.length_class ?? null, ...(i.voice_id ? { voice_id: i.voice_id } : {}),
          audio: { question: file(i.question_hash), long: file(i.long_hash) },
        }),
      audio: {
        done: done.length,
        total: hashes.length,
        // K90 (D213): what Starta prov would cost now, in credits (shown characters of files not made or failed)
        cost: creditCost(displayChars(items), hashes.filter((h) => !audio.get(h) || audio.get(h)!.status === "failed")),
        unit: "chars",
        failed: hashes.filter((h) => audio.get(h)?.status === "failed").length,
        // R10: what this drill's audio costs (whoever generated it first), and its size
        chars,
        est_usd: Math.round(chars * usdPer1k(model, deps.usdPer1kChars) / 10) / 100,
        credits: charged.length ? charged.reduce((n, a) => n + (a!.credits ?? 0), 0) : null,
        credits_chars: charged.length ? charged.reduce((n, a) => n + a!.text.length, 0) : null,
        bytes: done.reduce((n, h) => n + (audio.get(h)?.bytes ?? 0), 0),
        model,
      },
    };
  }

  /** The cue files for a voice: {name: {status, url?, duration_ms?}}; missing ones are queued (tiny, free). */
  async function cueView(model: string, voiceId?: string | null) {
    const vid = voiceFor(voiceId || deps.voiceId);
    if (!vid) return {};
    const entries = await Promise.all(Object.entries(CUES).map(async ([name, text]) => {
      const t = voiceText(text);
      return { name, text: t, hash: await audioHash(t, model, vid) };
    }));
    const have = new Map((await deps.db.audio(entries.map((e) => e.hash))).map((a) => [a.hash, a]));
    // K62: a cue that failed for lack of credits is made again after a while (else it would stay silent)
    const stale = entries.filter((e) => {
      const a = have.get(e.hash);
      return a?.status === "failed" && (a.error ?? "").startsWith(AUDIO_UNAVAILABLE) &&
        now() - Date.parse(a.done_at ?? a.queued_at ?? "1970-01-01") > UNAVAILABLE_RETRY_MS;
    }).map((e) => e.hash);
    if (stale.length) {
      await deps.db.requeue(stale).catch(() => {});
      void kick(stale);
    }
    const missing = entries.filter((e) => !have.has(e.hash));
    if (missing.length) {
      await deps.db.enqueue(missing.map((e) => ({
        hash: e.hash, kind: "question" as const, text: e.text, short_chars: null, model, voice_id: vid,
        status: "pending" as const, seq: -1, queued_at: new Date(now()).toISOString(),
      }))).catch(() => {});
      await kick(missing.map((e) => e.hash));
    }
    const done = entries.filter((e) => have.get(e.hash)?.status === "done");
    const urls = done.length ? await deps.storage.sign(done.map((e) => audioPath(e.hash))) : {};
    return Object.fromEntries(entries.map((e) => {
      const a = have.get(e.hash);
      return [e.name, a?.status === "done"
        ? { status: "done", url: urls[audioPath(e.hash)] ?? null, duration_ms: a.duration_ms ?? null }
        : { status: a?.status ?? "pending" }];
    }));
  }

  /** K47/K49: the recipient's own copy; questions, answers and hashes copied (the same audio, 0 new characters). */
  async function copyDrill(src: DrillRow, userId: string) {
    const rl = await enforceLimits(deps.rateLimiter, "drill_import", userId, { perMinute: 10, perDay: 50, globalPerDay: 50_000 }, 1);
    if (!rl.allowed) throw new HttpError(429, "rate_limited", "För många prov på kort tid. Vänta en stund.", { retryAfterSec: rl.retryAfterSec });
    if ((await deps.db.drills(userId)).length >= DRILL_STORE_LIMITS.drillsPerUser) {
      throw new HttpError(409, "too_many_drills", "Du har många prov sparade. Ta bort några gamla först.");
    }
    const copy: DrillRow = {
      id: crypto.randomUUID(), user_id: userId, title: src.title, subject: src.subject, grade: src.grade,
      covers: src.covers, long_words: src.long_words, shared_from: src.id, voice_model: src.voice_model ?? deps.model,
      kind: src.kind ?? "questions",
      language: src.language ?? null,
      voice_rules: src.voice_rules ?? 1, // the copy has the original's files
      ...(src.style ? { style: src.style } : {}), // K95: the same styled files
      ...(src.voice_id ? { voice_id: src.voice_id } : {}), // K96: the same voice
      ...(src.mix_voices ? { mix_voices: true } : {}), // K99: the same mixed voices
      // the copy's files are the original's (finished: sharing and publishing need all of it)
      audio_started_at: new Date(now()).toISOString(),
    };
    const its = (await deps.db.items([src.id])).sort((a, b) => a.position - b.position);
    await deps.db.saveDrill(copy, true);
    await deps.db.replaceItems(copy.id, [], its.map((i) => ({
      drill_id: copy.id, user_id: userId, position: i.position, question: i.question, short: i.short, long: i.long, screen: i.screen ?? null,
      question_hash: i.question_hash, long_hash: i.long_hash, voice_chars: i.voice_chars ?? null, length_class: i.length_class ?? null,
      ...(i.voice_id ? { voice_id: i.voice_id } : {}),
      part: i.part ?? null,
    })));
    return { ...(await view((await deps.db.drill(copy.id)) ?? copy)), new_chars: 0 };
  }

  async function publicationFor(id: unknown, includeHidden = false): Promise<PublicationRow> {
    const s = typeof id === "string" ? id : "";
    const p = UUID.test(s) ? await deps.db.publication(s) : null;
    if (!p || (p.hidden && !includeHidden)) throw new HttpError(404, "not_found", "Provet finns inte längre.");
    return p;
  }

  async function owned(userId: string, id: unknown): Promise<DrillRow> {
    const s = typeof id === "string" ? id : "";
    if (!UUID.test(s)) throw new HttpError(400, "invalid_request", "id is required");
    const d = await deps.db.drill(s);
    if (!d || d.user_id !== userId) throw new HttpError(404, "not_found", "Provet finns inte");
    return d;
  }

  /**
   * The save. K71 (D190): with "defer_audio": true and a drill whose audio has not been started, nothing is queued or
   * counted (the text can be edited for free until Starta prov). After start, a save queues only what changed (hashes).
   * `queue` = true is the start itself (and an old app without the flag: as before, the audio is made at save).
   */
  async function saveDrill(user: { id: string }, b: Record<string, unknown> | null, queueNow: boolean, dry = false): Promise<Response> {
    const di = (b?.drill ?? {}) as Record<string, unknown>;
    const rawItems = Array.isArray(b?.items) ? b!.items as Record<string, unknown>[] : [];
    if (!rawItems.length) throw new HttpError(400, "invalid_request", "items: at least one question");
    if (rawItems.length > DRILL_STORE_LIMITS.items) throw new HttpError(400, "invalid_request", `items: at most ${DRILL_STORE_LIMITS.items}`);
    if (!voiceFor(deps.voiceId)) throw new HttpError(503, "provider_unconfigured", "No voice configured");
    let existing: DrillRow | null = null;
    // K88 (D211): an optional client_id (the app's UUID for the exam). The same id from the same account again
    // (a save sent twice, e.g. two tasks at once) answers with the exam already saved and creates nothing new.
    const clientId = di.id === undefined || di.id === null ? clientIdOf(di.client_id) : null;
    if (di.client_id !== undefined && di.client_id !== null && clientIdOf(di.client_id) === null) {
      throw new HttpError(400, "invalid_request", "drill.client_id must be a UUID");
    }
    if (clientId && deps.db.drillByClient && !dry) {
      const same = await deps.db.drillByClient(user.id, clientId);
      if (same) return await alreadySaved(same);
    }
    if (di.id !== undefined && di.id !== null) existing = await owned(user.id, di.id);
    else if (!dry && (await deps.db.drills(user.id)).length >= DRILL_STORE_LIMITS.drillsPerUser) {
      throw new HttpError(409, "too_many_drills", "Du har många prov sparade. Ta bort några gamla först.");
    }
    // K96 (D220): the drill's voice from the catalog, chosen at the first save and locked after (D151)
    const askedVoice = typeof di.voice_id === "string" ? di.voice_id.trim() : "";
    if (askedVoice && !/^[A-Za-z0-9]{10,40}$/.test(askedVoice)) throw new HttpError(400, "invalid_request", "drill.voice_id is not a voice");
    if (askedVoice && existing && (existing.voice_id ?? "") !== askedVoice) {
      throw new HttpError(409, "voice_locked", "Rösten är redan vald för det här provet. Gör ett nytt prov för en annan röst.");
    }
    if (askedVoice && !existing && !(await deps.db.voiceAllowed?.(askedVoice).catch(() => false))) {
      throw new HttpError(400, "voice_not_in_catalog", "Den rösten går inte att välja.");
    }
    // K99 (D223): "Blanda röster" (chosen at the first save, then fixed) and the AI's choice of voice for a style
    const mix = existing ? !!existing.mix_voices : di.mix_voices === true;
    const styleAsked = typeof di.style === "string" ? cleanStyle(di.style) : "";
    const catalog = (mix || (styleAsked && !askedVoice && !existing)) && deps.db.catalogVoices
      ? (await deps.db.catalogVoices().catch(() => [])).slice().sort((a, b) => a.voice_id.localeCompare(b.voice_id))
      : [];
    let picked: { voice_id: string; reason: string } | null = null;
    if (!existing && !askedVoice && !mix && styleAsked && catalog.length && deps.voicePicker) {
      picked = await deps.voicePicker(styleAsked, catalog).catch(() => null);
      if (picked && !catalog.some((v) => v.voice_id === picked!.voice_id)) picked = null;
    }
    const ownVoice = existing ? existing.voice_id ?? null : askedVoice || picked?.voice_id || null;
    const vid = voiceFor(ownVoice || deps.voiceId)!;
    // a part's voice when mixing: kept from before for the same item, else by lot. O81 F1: the seed is the part's own
    // text, so the same text gets the same voice in any drill and its audio is reused (no new cost)
    const oldVoices = new Map<string, string | null>();
    const lot = async (seed: string) => {
      if (!mix || catalog.length < 2) return null;
      const d = new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(`mix:${seed}`)));
      return catalog[((d[0] << 8) | d[1]) % catalog.length].voice_id;
    };
    const lw = Math.round(Number(di.long_words));
    // K50 (D151): the voice is chosen before the audio is made; after that it is locked (never regenerated)
    const asked = di.voice_model === undefined || di.voice_model === null ? null : voiceModel(di.voice_model);
    if (di.voice_model !== undefined && di.voice_model !== null && !asked) {
      throw new HttpError(400, "invalid_request", "voice_model must be eleven_multilingual_v2, eleven_v3 or eleven_flash_v2_5 (A, B or C)");
    }
    const settings0 = await deps.db.settings?.().catch(() => null) ?? null;
    if (asked === V4_MODEL && Number(settings0?.allow_eleven_v4) !== 1 && !(existing && (existing.voice_model ?? deps.model) === V4_MODEL)) {
      // K74 part 2: prepared, not on (no ElevenLabs v4 call until Aron says yes)
      throw new HttpError(409, "voice_model_unavailable", "Den rösten går inte att välja än.");
    }
    const lockedModel = existing ? existing.voice_model ?? deps.model : null;
    if (lockedModel && asked && asked !== lockedModel) {
      throw new HttpError(409, "voice_locked", "Rösten är redan vald för det här provet. Gör ett nytt prov för en annan röst.");
    }
    // K95 (D220): a style is read by eleven_v3 (tags); the voice stays locked per drill (D151)
    const style = di.style !== undefined && di.style !== null ? cleanStyle(di.style) : (existing?.style ?? "");
    if (style && lockedModel && lockedModel !== STYLE_MODEL) {
      throw new HttpError(409, "voice_locked", "Rösten är redan vald för det här provet. Gör ett nytt prov för att välja hur det ska låta.");
    }
    const voice = lockedModel ?? (style ? STYLE_MODEL : asked ?? deps.model);
    // K70 (D185): a drill is questions or a text, chosen at the first save and never changed after
    const kindAsked = di.kind === "text" || di.kind === "questions" ? di.kind : di.kind === undefined || di.kind === null ? null : "bad";
    if (kindAsked === "bad") throw new HttpError(400, "invalid_request", "drill.kind must be questions or text");
    const kind: "questions" | "text" = existing ? existing.kind ?? "questions" : kindAsked ?? "questions";
    if (existing && kindAsked && kindAsked !== kind) throw new HttpError(409, "kind_locked", "Provet kan inte byta mellan frågor och text. Gör ett nytt prov.");
    const isText = kind === "text";
    if (isText && rawItems.length > TEXT_LIMITS.parts) throw new HttpError(400, "invalid_request", `items: at most ${TEXT_LIMITS.parts} parts`);
    const drill: DrillRow = {
      id: existing?.id ?? crypto.randomUUID(),
      user_id: user.id,
      title: clean(di.title, 120) || existing?.title || "",
      subject: clean(di.subject, 60) || existing?.subject || "",
      grade: clean(di.grade, 60) || existing?.grade || "",
      covers: clean(di.covers, 400) || existing?.covers || "",
      long_words: Number.isFinite(lw) && lw >= 40 && lw <= 200 ? lw : existing?.long_words ?? 90,
      shared_from: existing?.shared_from ?? null,
      voice_model: voice,
      kind,
      language: existing?.language ?? null,
      voice_rules: existing ? existing.voice_rules ?? 1 : VOICE_RULES_VERSION,
      ...(existing ? {} : clientId ? { client_id: clientId } : {}),
      ...(style || existing?.style ? { style: style || null } : {}),
      ...(ownVoice ? { voice_id: ownVoice } : {}),
      ...(mix ? { mix_voices: true } : {}),
      ...((existing ? !!existing.said : di.said === true) ? { said: true } : {}),
    };
    const oldItems = existing ? await deps.db.items([existing.id]) : [];
    const oldIds = new Set(oldItems.map((i) => i.id));
    for (const i of oldItems) oldVoices.set(i.id, i.voice_id ?? null);
    const rows: (ItemRow & { keep?: string })[] = [];
    const files = new Map<string, AudioRow>();
    const limits = lengthLimits(settings0);
    const pauseTag = drill.voice_model === V4_MODEL && Number(settings0?.v4_pause_tag) === 1;
    // K67 (D182): an English exam is read in English. K72 (O67): a text by its own language (asked, or detected)
    if (isText) {
      const asked = typeof di.language === "string" ? di.language.trim() : "";
      const known = asked === "sv" ? "sv" : examLanguage(asked) || null;
      drill.language = known ?? drill.language ??
        (textLanguage(rawItems.map((it) => String(it?.text ?? "")).join(" "), drill.subject) || "sv");
    }
    const lang = isText && drill.language ? (drill.language === "sv" ? "" : drill.language) : examLanguage(drill.subject);
    let textChars = 0;
    for (const [pos, it] of isText ? rawItems.entries() : []) {
      // K70 (D185): one file per part; question_hash = long_hash; the sentence ends are kept for the times
      const part = it?.kind === "heading" ? "heading" as const : "para" as const;
      const text = clean(it?.text, part === "heading" ? TEXT_LIMITS.heading : TEXT_LIMITS.part);
      if (!text) throw new HttpError(400, "invalid_request", `items[${pos}].text is required`);
      textChars += text.length;
      if (textChars > TEXT_LIMITS.chars) throw new HttpError(400, "invalid_request", `the text is at most ${TEXT_LIMITS.chars} characters`);
      const v = voicedPart(text, part, (x) => voiceText(x, lang, drill.voice_rules));
      if (!v.spoken) throw new HttpError(400, "invalid_request", `items[${pos}].text has nothing to read`);
      const id = typeof it?.id === "string" && oldIds.has(it.id) ? it.id : undefined;
      const own = mix ? (id && oldVoices.get(id)) || await lot(v.spoken) : null;
      const pv = own ? voiceFor(own)! : vid;
      const h = await audioHash(style ? styledKey(v.spoken, style) : v.spoken, voice, pv);
      files.set(h, files.get(h) ?? { hash: h, kind: "text", text: v.spoken, model: voice, voice_id: pv, seq: pos * 2, sentence_ends: v.ends });
      rows.push({
        ...(id ? { id } : {}), drill_id: drill.id, user_id: user.id, position: pos, question: "", short: "", long: text, screen: null,
        question_hash: h, long_hash: h, voice_chars: v.spoken.length, length_class: null, part, ...(own ? { voice_id: own } : {}),
      });
    }
    for (const [pos, it] of isText ? [] : rawItems.entries()) {
      const question = clean(it?.question, DRILL_STORE_LIMITS.question);
      if (!question) throw new HttpError(400, "invalid_request", `items[${pos}].question is required`);
      const short = clean(it?.short, DRILL_STORE_LIMITS.short);
      if (!short) throw new HttpError(400, "invalid_request", `items[${pos}].short is required`);
      // D145: the long answer starts with the short one; an edited short answer is put in front again
      let long = clean(it?.long, DRILL_STORE_LIMITS.long) || short;
      if (!long.startsWith(short)) long = composeLong(short, long).slice(0, DRILL_STORE_LIMITS.long);
      const q = voiceText(question, lang, drill.voice_rules);
      const l0 = longVoice(short, long, lang, drill.voice_rules);
      const l = pauseTag ? withPauseTag(l0.text, l0.shortChars) : l0;
      const id = typeof it?.id === "string" && oldIds.has(it.id) ? it.id : undefined;
      const own = mix ? (id && oldVoices.get(id)) || await lot(q) : null;
      const pv = own ? voiceFor(own)! : vid;
      const qh = await audioHash(style ? styledKey(q, style) : q, voice, pv);
      const lh = await audioHash(style ? styledKey(l.text, style) : l.text, voice, pv);
      files.set(qh, files.get(qh) ?? { hash: qh, kind: "question", text: q, model: voice, voice_id: pv, seq: pos * 2 });
      files.set(lh, files.get(lh) ?? { hash: lh, kind: "long", text: l.text, short_chars: l.shortChars, model: voice, voice_id: pv, seq: pos * 2 + 1 });
      const chars = q.length + l.text.length; // D176: what ElevenLabs gets for this question
      rows.push({
        ...(id ? { id } : {}), drill_id: drill.id, user_id: user.id, position: pos, question, short, long, screen: screenOf(it?.screen), question_hash: qh, long_hash: lh,
        voice_chars: chars, length_class: lengthClass(chars, limits), ...(own ? { voice_id: own } : {}),
      });
    }
    // D144: only files no account has yet are generated and counted
    const queue = queueNow || !!existing?.audio_started_at || b?.defer_audio !== true;
    if (queue) drill.audio_started_at = existing?.audio_started_at ?? new Date(now()).toISOString();
    else drill.audio_started_at = null;
    const existingAudio = await deps.db.audio([...files.keys()]);
    const have = new Set(existingAudio.map((a) => a.hash));
    // K55: a file that failed earlier is made again now (the text is wanted again); free, it was paid for nothing
    const failed = existingAudio.filter((a) => a.status === "failed").map((a) => a.hash);
    const fresh = [...files.values()].filter((f) => !have.has(f.hash));
    const newChars = fresh.reduce((n, f) => n + f.text.length, 0);
    if (dry) {
      // K92 (D215 punkt 8): the cost before saving, counted exactly as the save would; nothing written or queued
      const q = await deps.db.useQuota(user.id, 0);
      const c = creditCost(displayChars(rows), fresh.map((f) => f.hash));
      return json({
        cost: c, remaining: Math.max(0, q.lim - q.used), limit: q.lim, unit: "chars", enough: c <= q.lim - q.used, ...(q.unlimited ? { unlimited: true } : {}), ...walletFields(q),
        ...(picked ? { voice_id: picked.voice_id, voice_reason: picked.reason } : {}),
      });
    }
    // K78 (D200): ElevenLabs has just said it has no credits: nothing is sent, nothing is counted, the drill stays as
    // text (not started) and the app is told; the next Starta prov once credits are back makes the audio as usual
    const out = queue && (fresh.length > 0 || failed.length > 0) && await creditsOut();
    if (out) drill.audio_started_at = existing?.audio_started_at ?? null;
    if (queue && !out && failed.length) await deps.db.requeue(failed);
    // K90 (D213): the cost in credits (shown characters of the files that need new audio), known before anything is saved
    const display = displayChars(rows);
    const cost = creditCost(display, fresh.map((f) => f.hash));
    if (!queue && !existing && cost > 0) {
      // D212 (3): a new drill whose audio the credits cannot pay is not saved (no unstarted drill is left behind)
      const q0 = await deps.db.useQuota(user.id, 0);
      if (cost > q0.lim - q0.used) return json(creditsRefused(cost, q0.used, q0.lim, now()), 402);
    }
    if (!queue || out) {
      // K71 (D190): saved as text only; the audio (and the count) waits for Starta prov
      const lost = await saveOrSame(drill, !existing, 0);
      if (lost) return lost;
      await deps.db.replaceItems(drill.id, rows.map((r) => r.id).filter((x): x is string => !!x), rows);
      await analyse(saveRows(kind, oldItems, rows));
      const saved = await deps.db.drill(drill.id);
      return json({
        ...(await view(saved ?? drill)), new_chars: 0, chars_on_start: newChars, generated_questions: 0, cost, unit: "chars",
        ...(picked ? { voice_reason: picked.reason } : {}),
        ...(out ? { audio_unavailable: true, notice: AUDIO_UNAVAILABLE_NOTICE } : {}),
      });
    }
    if (newChars > 0) {
      const rl = await enforceLimits(deps.rateLimiter, "drill_tts", user.id, deps.charLimits, newChars);
      if (!rl.allowed) {
        throw new HttpError(429, "rate_limited", "Du har gjort mycket ljud i dag. Spara provet igen i morgon, så görs resten.", {
          retryAfterSec: rl.retryAfterSec,
        });
      }
    }
    // K90 (D213): the credits are characters of new audio (cost above); audio any account already made is free.
    // generated_questions stays for older apps: the questions (or text parts) that get new audio.
    const freshSet = new Set(fresh.map((f) => f.hash));
    const generated = rows.filter((r) => freshSet.has(r.question_hash) || freshSet.has(r.long_hash)).length;
    if (cost > 0) {
      const q = await deps.db.useQuota(user.id, cost);
      if (!q.ok) return json(creditsRefused(cost, q.used, q.lim, now()), 402);
      if (!q.unlimited) drill.charged_chars = (existing?.charged_chars ?? 0) + cost; // K93: an admin is charged nothing
    }
    // K95 (D220): the files made new get their tags now (Haiku), only those; the words are checked in code (style.ts)
    if (style && deps.styler && fresh.length) {
      await Promise.all(fresh.map(async (f) => {
        // O80 F2: the text's own square brackets ([1], [sic]) would be taken for tags and stop the style: read them as
        // round ones (the same length, so every offset still holds)
        const plain = f.text.replace(/\[/g, "(").replace(/\]/g, ")");
        const tagged = await deps.styler!(plain, style).catch(() => null);
        if (!tagged || tagged === plain) return;
        if (f.sentence_ends) f.sentence_ends = f.sentence_ends.map((e) => mapOffset(tagged, e));
        if (typeof f.short_chars === "number") f.short_chars = mapOffset(tagged, f.short_chars);
        f.text = tagged;
      }));
    }
    // the audio is queued first: a failure leaves no half-saved drill (a queued file nobody uses costs nothing)
    if (fresh.length) {
      const at = new Date(now()).toISOString();
      // every row with the same keys (PostgREST bulk insert, live 2026-11-13: HTTP 400 otherwise)
      await deps.db.enqueue(fresh.map((f) => ({
        hash: f.hash, kind: f.kind, text: f.text, short_chars: f.short_chars ?? null, model: f.model,
        voice_id: f.voice_id, status: "pending", seq: f.seq ?? 0, queued_at: at, sentence_ends: f.sentence_ends ?? null,
      })));
    }
    const lost = await saveOrSame(drill, !existing, cost);
    if (lost) return lost;
    await deps.db.replaceItems(drill.id, rows.map((r) => r.id).filter((x): x is string => !!x), rows);
    await analyse(saveRows(kind, oldItems, rows));
    if (fresh.length || failed.length) await kick([...files.keys()]);
    const saved = await deps.db.drill(drill.id);
    return json({ ...(await view(saved ?? drill)), new_chars: newChars, generated_questions: generated, cost, unit: "chars", ...(picked ? { voice_reason: picked.reason } : {}) });
  }

  /** K88: the answer to a save whose client_id was already saved: that exam, in the same form, nothing new. */
  async function alreadySaved(d: DrillRow): Promise<Response> {
    return json({ ...(await view(d)), new_chars: 0, generated_questions: 0, already_saved: true });
  }

  /**
   * K88: saves the drill; when two saves with the same client_id race, the database's unique index stops the second.
   * That one gives back the questions it had counted and answers with the first exam (its items were never written).
   */
  async function saveOrSame(drill: DrillRow, isNew: boolean, counted: number): Promise<Response | null> {
    try {
      await deps.db.saveDrill(drill, isNew);
      return null;
    } catch (e) {
      const cid = isNew ? drill.client_id : null;
      const same = cid && deps.db.drillByClient ? await deps.db.drillByClient(drill.user_id, cid).catch(() => null) : null;
      if (!same || same.id === drill.id) throw e;
      if (counted > 0) await deps.db.refundQuota?.(drill.user_id, counted).catch(() => {});
      console.warn("drill_client_id_race", same.id);
      return await alreadySaved(same);
    }
  }

  /** K78: ElevenLabs has no credits right now (a real file failed for that within UNAVAILABLE_RETRY_MS). */
  async function creditsOut(): Promise<boolean> {
    // a test sees only the test voice's fake failures (x-earmind-test: unavailable), real traffic only real ones
    const test = !!currentTest()?.test;
    if (!deps.db.recentUnavailable) return false;
    return await deps.db.recentUnavailable(new Date(now() - UNAVAILABLE_RETRY_MS).toISOString(), test).catch(() => false);
  }

  /**
   * K78 (D200): questions counted at start whose audio then failed for lack of credits are given back, once per
   * question (drills.refunded). Their files are made again later for free (a failed file is never counted again).
   */
  async function refundUnavailable(d: DrillRow, userId: string) {
    // K90 (D213): in credits (characters), and never more than this drill was charged in characters (a drill
    // started before K90 was counted in questions and gives nothing back here)
    const charged = d.charged_chars ?? 0;
    if (!deps.db.refundQuota || !deps.db.setRefunded || (d.shared_from ?? null) || charged <= 0) return 0;
    const its = await deps.db.items([d.id]);
    const audio = new Map((await deps.db.audio([...new Set(its.flatMap((i) => [i.question_hash, i.long_hash]))])).map((a) => [a.hash, a]));
    const bad = (h: string) => { const a = audio.get(h); return a?.status === "failed" && (a.error ?? "").startsWith(AUDIO_UNAVAILABLE); };
    const unavailable = Math.min(charged, creditCost(displayChars(its), [...audio.keys()].filter(bad)));
    const back = unavailable - (d.refunded_chars ?? 0);
    if (back <= 0) return 0;
    await deps.db.refundQuota(userId, back);
    await deps.db.setRefunded(d.id, unavailable);
    return back;
  }

  /** K77: to Aron's analysis (D197); a test account never, and a failure never stops the save. */
  async function analyse(rows: AnalysisRow[]) {
    if (!rows.length || !deps.analysis || currentTest()?.test) return;
    await deps.analysis(rows).catch((e) => console.error("analysis_log_failed", e instanceof Error ? e.message.slice(0, 120) : String(e)));
  }

  async function share(d: DrillRow, userId: string): Promise<Response> {
    let sh = await deps.db.shareOf(d.id);
    if (!sh || sh.revoked_at) {
      sh = { code: newShareCode(), drill_id: d.id, user_id: userId };
      await deps.db.createShare(sh);
    }
    return json({ code: sh.code, url: SHARE_URL(sh.code), app_url: SHARE_APP_URL(sh.code) });
  }

  /** K71: the stored drill saved again with its audio queued (the same hashes: only what is missing is made). */
  async function startAudio(user: { id: string }, d: DrillRow): Promise<Response> {
    const its = (await deps.db.items([d.id])).sort((x, y) => x.position - y.position);
    const items = its.map((i) => i.part
      ? { id: i.id, kind: i.part, text: i.long }
      : { id: i.id, question: i.question, short: i.short, long: i.long, ...(i.screen ? { screen: i.screen } : {}) });
    return await saveDrill(user, { drill: { id: d.id }, items }, true);
  }

  return async (req: Request): Promise<Response> => {
    if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS_HEADERS });
    try {
      if (req.method !== "POST") throw new HttpError(405, "method_not_allowed", "Use POST");
      const user = await deps.authenticate(req);
      const b = (await readLimitedJson(req, DRILL_STORE_LIMITS.bodyBytes)) as Record<string, unknown> | null;
      const action = String(b?.action ?? "");
      if (action === "import_text") {
        const rl = await enforceLimits(deps.rateLimiter, "drill_import_text", user.id, { perMinute: 20, perDay: 200, globalPerDay: 200_000 }, 1);
        if (!rl.allowed) throw new HttpError(429, "rate_limited", "För många försök just nu. Vänta en liten stund.", { retryAfterSec: rl.retryAfterSec });
        const r = importText(b?.text);
        if (!r.items.length) {
          return json({
            error: { code: "import_unreadable", message: "Det gick inte att hitta några frågor. Varje fråga ska börja med \"Fråga:\" och svaret med \"Svar:\".", fallback: false },
            skipped: r.skipped.slice(0, 20),
          }, 422);
        }
        return json({ ...r, count: r.items.length });
      }
      if (action === "quota") {
        // K90 (D213): credits are characters of new audio, 1 500 a month (drill_settings.free_chars_per_month)
        const q = await deps.db.useQuota(user.id, 0);
        const left = Math.max(0, q.lim - q.used);
        const st = await deps.db.settings?.().catch(() => null) ?? null;
        const lim = lengthLimits(st);
        return json({
          unit: "chars", limit: q.lim, used: q.used, remaining: left, resets: nextMonthStart(now()), resets_day: resetsDay(now()),
          ...(q.unlimited ? { unlimited: true } : {}), // K93 (D216): the capsule says "Obegränsat"
          ...walletFields(q), // K94 (D218): monthly_free, purchased, subscription
          // kept for older apps (K61/K82): left is now credits; suggest is how many questions Nytt prov may offer
          left, suggest: left > 0 ? 20 : 0, per: "month",
          prices: {
            unit: "chars", per_char: 1,
            classes: [
              { class: "normal", max_chars: lim.normalMax, questions: 1, tokens: 40 },
              { class: "longer", min_chars: lim.normalMax + 1, max_chars: lim.longerMax, questions: 1, tokens: 60 },
              { class: "too_long", min_chars: lim.longerMax + 1, max_chars: DRILL_STORE_LIMITS.long, questions: 1, tokens: 80 },
            ],
            read: { chars_per_question: 1 },
            free: ["shared", "published", "imported", "existing_audio", "repeats"],
          },
        });
      }
      if (action === "list") {
        const drills = await deps.db.drills(user.id);
        const items = drills.length ? await deps.db.items(drills.map((d) => d.id)) : [];
        const hashes = [...new Set(items.flatMap((i) => [i.question_hash, i.long_hash]).filter(Boolean))];
        const doneSet = new Set((hashes.length ? await deps.db.audio(hashes) : []).filter((a) => a.status === "done").map((a) => a.hash));
        const q = await deps.db.useQuota(user.id, 0);
        return json({
          quota: { unit: "chars", used: q.used, limit: q.lim, left: Math.max(0, q.lim - q.used), remaining: Math.max(0, q.lim - q.used), per: "month", resets: nextMonthStart(now()), ...(q.unlimited ? { unlimited: true } : {}), ...walletFields(q) },
          drills: drills.map((d) => {
            const its = items.filter((i) => i.drill_id === d.id);
            const hs = [...new Set(its.flatMap((i) => [i.question_hash, i.long_hash]))];
            return {
              id: d.id, title: d.title, subject: d.subject, grade: d.grade, items: its.length, updated_at: d.updated_at,
              shared_from: d.shared_from ?? null, voice_model: d.voice_model ?? deps.model, kind: d.kind ?? "questions", audio_started: !!d.audio_started_at, said: !!d.said,
              audio: { done: hs.filter((h) => doneSet.has(h)).length, total: hs.length },
            };
          }),
        });
      }
      if (action === "get" || action === "status") {
        const d = await owned(user.id, b?.id);
        const v = await view(d);
        if (action === "status") {
          // K62: files that failed for lack of credits are tried again after a while (when credits are back)
          const its = await deps.db.items([d.id]);
          const hs = [...new Set(its.flatMap((i) => [i.question_hash, i.long_hash]))];
          // never for test traffic: it must not make real-voice files again (D180)
          const again = currentTest()?.test ? [] : (await deps.db.audio(hs)).filter((a) =>
            a.status === "failed" && (a.error ?? "").startsWith(AUDIO_UNAVAILABLE) &&
            now() - Date.parse(a.done_at ?? a.queued_at ?? "1970-01-01") > UNAVAILABLE_RETRY_MS
          ).map((a) => a.hash);
          if (again.length) await deps.db.requeue(again);
          if (again.length || v.audio.done + v.audio.failed < v.audio.total) await kick(hs);
        }
        // K78 (D200): never charged for audio that was not made; the app shows the text with the notice
        const refunded = await refundUnavailable(d, user.id).catch(() => 0);
        const unavailable = v.items.some((i) => Object.values(i.audio as unknown as Record<string, { error?: string } | undefined>).some((f) => f?.error === AUDIO_UNAVAILABLE)) ||
          // K78: audio still missing while ElevenLabs is out (a drill kept as text by start) says so too
          (v.audio.done < v.audio.total && await creditsOut());
        return json({ ...v, ...(unavailable ? { audio_unavailable: true, notice: AUDIO_UNAVAILABLE_NOTICE } : {}), ...(refunded ? { refunded_credits: refunded, refunded_questions: refunded } : {}) });
      }
      if (action === "share") {
        const d = await owned(user.id, b?.id);
        let v = await view(d);
        if (v.audio.total === 0 || v.audio.done < v.audio.total) {
          // K71 (D190): a drill never started gets its audio now (counted as at Starta prov); shared when it is done
          if (!d.audio_started_at) {
            const r = await startAudio(user, d);
            if (r.status !== 200) return r;
            v = await view((await deps.db.drill(d.id)) ?? d);
            if (v.audio.done >= v.audio.total && v.audio.total > 0) return await share(d, user.id);
          }
          // D143: sharing before the audio is done would make the recipient pay for the same audio again
          return json({
            error: { code: "audio_not_ready", message: `Delas när ljudet är klart (${v.audio.done} av ${v.audio.total})`, fallback: false },
            done: v.audio.done,
            total: v.audio.total,
            audio_started: true,
          }, 409);
        }
        return await share(d, user.id);
      }
      if (action === "unshare") {
        const d = await owned(user.id, b?.id);
        return json({ revoked: await deps.db.revokeShares(d.id) });
      }
      if (action === "import" && b?.publication_id !== undefined) {
        const pub = await publicationFor(b.publication_id);
        const src = await deps.db.drill(pub.drill_id);
        if (!src) throw new HttpError(404, "not_found", "Provet finns inte längre.");
        const v = await view(src);
        if (v.audio.done < v.audio.total) {
          throw new HttpError(409, "audio_not_ready", `Delas när ljudet är klart (${v.audio.done} av ${v.audio.total})`);
        }
        const body = await copyDrill(src, user.id);
        await deps.db.bump(pub.id, "imports").catch(() => {});
        return json(body);
      }
      if (action === "share_info" || action === "import") {
        const code = typeof b?.code === "string" ? b.code.trim().toLowerCase().replace(/^.*\/(?:p|prov)\//, "").replace(/[^a-z0-9]/g, "") : "";
        const sh = /^[a-z0-9]{8,16}$/.test(code) ? await deps.db.shareByCode(code) : null;
        const src = sh && !sh.revoked_at ? await deps.db.drill(sh.drill_id) : null;
        if (!sh || !src) throw new HttpError(404, "share_not_found", "Länken fungerar inte längre. Be om en ny.");
        const v = await view(src);
        if (action === "share_info") {
          return json({ title: src.title, subject: src.subject, grade: src.grade, items: v.items.length, audio_ready: v.audio.done === v.audio.total });
        }
        if (v.audio.done < v.audio.total) {
          throw new HttpError(409, "audio_not_ready", `Delas när ljudet är klart (${v.audio.done} av ${v.audio.total})`);
        }
        const body = await copyDrill(src, user.id);
        await deps.db.countImport(sh.code).catch(() => {});
        return json(body);
      }
      if (action === "schools") {
        const q = clean(b?.q, 60);
        if (q.length < 2) return json({ schools: [] });
        const rows = await deps.db.schools(q, 20);
        return json({ schools: rows.map((r) => ({ code: r.code, name: r.name, locality: r.locality ?? null })) });
      }
      if (action === "publish") {
        const d = await owned(user.id, b?.id);
        let v = await view(d);
        if (!d.audio_started_at && (v.audio.total === 0 || v.audio.done < v.audio.total)) {
          // K71 (D190): publishing a drill never started makes its audio now (the 409 below says how far it is)
          const r = await startAudio(user, d);
          if (r.status !== 200) return r;
          v = await view((await deps.db.drill(d.id)) ?? d);
        }
        const code = typeof b?.school_code === "string" ? b.school_code.trim() : "";
        const school = /^[0-9]{6,10}$/.test(code) ? await deps.db.school(code) : null;
        const subject = clean(b?.subject, 60) || d.subject;
        const date = validDate(b?.exam_date, now());
        const missing = [
          ...(!school || school.status !== "AKTIV" ? ["school"] : []),
          ...(!subject ? ["subject"] : []),
          ...(!date ? ["date"] : []),
          ...(v.audio.total === 0 || v.audio.done < v.audio.total ? ["audio"] : []),
        ];
        if (missing.length) {
          const names: Record<string, string> = { school: "skola", subject: "ämne", date: "provdatum", audio: "färdigt ljud" };
          return json({
            error: { code: "publish_incomplete", message: `Saknas: ${missing.map((m) => names[m]).join(", ")}`, fallback: false },
            missing,
            ...(missing.includes("audio") ? { done: v.audio.done, total: v.audio.total } : {}),
          }, 409);
        }
        // D150: the name only when the user chose to show it; nothing else about the account is ever published
        const name = b?.show_name === true ? clean(b?.display_name, 40).replace(/[^\p{L}\p{N} .'-]/gu, "").trim() : "";
        const prev = await deps.db.publicationOf(d.id);
        const row: PublicationRow = {
          id: prev?.id ?? crypto.randomUUID(), drill_id: d.id, user_id: user.id, school_code: school!.code, subject,
          exam_date: date!, display_name: name || null,
        };
        await deps.db.savePublication(row);
        return json({
          publication: publicView(row, school!, d.title, v.items.length, {
            preview: v.items.slice(0, PREVIEW_QUESTIONS).map(previewItem),
            first_audio_url: ((v.items[0]?.audio.question ?? v.items[0]?.audio.text) as { url?: string | null } | undefined)?.url ?? null,
          }),
        });
      }
      if (action === "unpublish") {
        const d = await owned(user.id, b?.id);
        await deps.db.deletePublication(d.id);
        return json({ unpublished: true });
      }
      if (action === "search") {
        const school = typeof b?.school_code === "string" && /^[0-9]{6,10}$/.test(b.school_code) ? b.school_code : undefined;
        const mine = typeof b?.my_school === "string" ? b.my_school : undefined;
        const from = validDate(b?.from, now()) ?? undefined, to = validDate(b?.to, now()) ?? undefined;
        const rows = (await deps.db.searchPublications({ school, subject: clean(b?.subject, 60) || undefined, from, to }))
          .filter((r) => !r.hidden);
        const drills = new Map<string, DrillRow>();
        for (const r of rows.slice(0, 200)) {
          const d = await deps.db.drill(r.drill_id);
          if (d) drills.set(r.drill_id, d);
        }
        const its = drills.size ? await deps.db.items([...drills.keys()]) : [];
        const schools = new Map<string, SchoolRow>();
        for (const c of new Set(rows.map((r) => r.school_code))) {
          const sc = await deps.db.school(c);
          if (sc) schools.set(c, sc);
        }
        const today = new Date(now()).toISOString().slice(0, 10);
        const old = (r: PublicationRow) => daysBetween(r.exam_date, today) > 30; // more than 30 days back sinks
        const results = rows
          .filter((r) => drills.has(r.drill_id) && schools.has(r.school_code))
          .sort((x, y) =>
            Number(y.school_code === mine) - Number(x.school_code === mine) || Number(old(x)) - Number(old(y)) ||
            y.exam_date.localeCompare(x.exam_date)
          )
          .slice(0, 50);
        // K65: the first questions and a short signed link to the first question's finished audio (no new audio, D180)
        const firsts = new Map(results.map((r) => [r.drill_id, its.filter((i) => i.drill_id === r.drill_id).sort((a, b) => a.position - b.position)]));
        const hs = [...firsts.values()].map((x) => x[0]?.question_hash).filter((h): h is string => !!h);
        const done = new Set((hs.length ? await deps.db.audio(hs) : []).filter((a) => a.status === "done").map((a) => a.hash));
        const urls = done.size ? await deps.storage.sign([...done].map(audioPath)).catch(() => ({} as Record<string, string>)) : {};
        return json({
          results: results.map((r) => {
            const x = firsts.get(r.drill_id) ?? [];
            const h = x[0]?.question_hash;
            return publicView(r, schools.get(r.school_code)!, drills.get(r.drill_id)!.title, x.length, {
              preview: x.slice(0, PREVIEW_QUESTIONS).map(previewItem),
              first_audio_url: h && done.has(h) ? urls[audioPath(h)] ?? null : null,
            });
          }),
        });
      }
      if (action === "report") {
        const pub = await publicationFor(b?.publication_id);
        const reason = ["fel", "krankande", "upphovsratt", "annat"].includes(String(b?.reason)) ? String(b?.reason) : "annat";
        const rl = await enforceLimits(deps.rateLimiter, "drill_report", user.id, { perMinute: 10, perDay: 30, globalPerDay: 20_000 }, 1);
        if (!rl.allowed) throw new HttpError(429, "rate_limited", "För många rapporter på kort tid.", { retryAfterSec: rl.retryAfterSec });
        return json(await deps.db.report(pub.id, user.id, reason));
      }
      if (action === "stats") {
        // K77 (D197): which presses were used (1, 2, 3), in total and per question; logged for Aron's analysis only
        const d = await owned(user.id, b?.id);
        const total = pressStats(b?.presses);
        if (!total) throw new HttpError(400, "invalid_request", 'presses must be {"1": n, "2": n, "3": n}');
        const rl = await enforceLimits(deps.rateLimiter, "drill_stats", user.id, { perMinute: 6, perDay: 100, globalPerDay: 500_000 }, 1);
        if (!rl.allowed) return json({ logged: false });
        const its = (await deps.db.items([d.id])).sort((x, y) => x.position - y.position);
        const per = (Array.isArray(b?.per_question) ? b!.per_question as Record<string, unknown>[] : []).flatMap((q) => {
          const it = its.find((i) => i.position === Number(q?.position));
          const p = pressStats(q?.presses);
          return it && p && !it.part ? [{ question: it.question, presses: p }] : [];
        });
        const m = Number(b?.minutes);
        const row = statsRow(d.kind ?? "questions", d.subject, total, per, Number.isFinite(m) && m >= 0 && m < 10_000 ? Math.round(m) : null);
        const logged = !currentTest()?.test && !!deps.analysis;
        await analyse([row]);
        return json({ logged });
      }
      if (action === "played") {
        const d = await owned(user.id, b?.id);
        const pub = d.shared_from ? await deps.db.publicationOf(d.shared_from) : null;
        if (!pub) return json({ counted: false });
        // at most three plays a day per copy are counted (a number only, never who)
        const rl = await enforceLimits(deps.rateLimiter, `drill_play:${d.id}`, user.id, { perMinute: 1, perDay: 3, globalPerDay: 1_000_000 }, 1);
        if (rl.allowed) await deps.db.bump(pub.id, "plays");
        return json({ counted: rl.allowed });
      }
      if (action === "moderate") {
        const owners = (deps.ownerEmails ?? []).map((e) => e.trim().toLowerCase()).filter(Boolean);
        const byEmail = (user.amr ?? []).some((m) => m === "otp" || m === "magiclink");
        if (user.isAnonymous || !user.email || !byEmail || !owners.includes(user.email.toLowerCase())) {
          throw new HttpError(403, "forbidden", "Owner only");
        }
        const pub = await publicationFor(b?.publication_id, true);
        await deps.db.setHidden(pub.id, b?.hidden === true);
        return json({ hidden: b?.hidden === true });
      }
      if (action === "delete") {
        const d = await owned(user.id, b?.id);
        const its = await deps.db.items([d.id]);
        await deps.db.deleteDrill(d.id); // the shared audio stays (other accounts may use it)
        // K64: files of this drill that are still waiting and that no other question uses leave the queue
        const hs = [...new Set(its.flatMap((i) => [i.question_hash, i.long_hash]))];
        if (hs.length && deps.db.referenced) {
          const still = new Set(await deps.db.referenced(hs).catch(() => hs));
          // K91 (Oscar O76): a file that failed for lack of credits keeps its error, so the K78 check (creditsOut)
          // still knows that ElevenLabs is out; deleting a drill must not lift it
          const waiting = (await deps.db.audio(hs)).filter((a) => (a.status === "pending" || (a.status === "failed" && !(a.error ?? "").startsWith(AUDIO_UNAVAILABLE))) && !still.has(a.hash));
          for (const a of waiting) await deps.db.finish(a.hash, { status: "failed", attempts: 3, error: "unused: the drill was deleted (K64)" }).catch(() => {});
        }
        return json({ deleted: true });
      }
      if (action === "start") {
        // K71 (D190): Starta prov makes the audio: everything still missing is queued and counted now
        const d = await owned(user.id, b?.id);
        const r = await startAudio(user, d);
        // K98: the first play rewards the one who invited this account (once; never blocks the answer)
        if (r.status === 200 && deps.onStarted) await deps.onStarted(user.id).catch((e) => console.warn("invite_reward_failed", String(e).slice(0, 120)));
        return r;
      }
      if (action === "cost") {
        // K92 (D215 punkt 8): what a save of this text would cost, without saving. Limited per account, so it is not
        // a way to ask which texts already have audio (D144: any account's audio is free)
        const rl = await enforceLimits(deps.rateLimiter, "drill_cost", user.id, { perMinute: 20, perDay: 300, globalPerDay: 300_000 }, 1);
        if (!rl.allowed) {
          // Oscar (O77): the day's limit waits until midnight, so it gets its own words
          const day = !!rl.deniedKey?.endsWith(":d") || rl.retryAfterSec > 90;
          throw new HttpError(429, "rate_limited", day ? "Du har förhandsvisat många texter i dag. Försök igen i morgon." : "För många förhandsvisningar just nu. Vänta en stund.", { retryAfterSec: rl.retryAfterSec });
        }
        return await saveDrill(user, b, false, true);
      }
      if (action !== "save") throw new HttpError(400, "invalid_request", "unknown action");
      return await saveDrill(user, b, false);
    } catch (e) {
      return errorResponse(toHttpError(e));
    }
  };
}
