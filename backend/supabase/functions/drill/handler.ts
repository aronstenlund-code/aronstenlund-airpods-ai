import type { Authenticator } from "../_shared/auth.ts";
import { CORS_HEADERS, errorResponse, HttpError, toHttpError } from "../_shared/errors.ts";
import { enforceLimits, type Limits, type RateLimiter } from "../_shared/ratelimit.ts";
import { readLimitedJson } from "../answer/validate.ts";
import { toSpeech } from "../answer/speech.ts";
import { pronounce } from "../tts/handler.ts";
import { composeLong, spokenText } from "../exam/drill.ts";

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
 * The material is never stored (B4). Characters for NEW files count against a daily limit per account and globally.
 */
export const DRILL_STORE_LIMITS = {
  bodyBytes: 512 * 1024,
  items: 60,
  question: 300,
  short: 600,
  long: 3000,
  drillsPerUser: 200,
};

export interface DrillRow {
  id: string;
  user_id: string;
  title: string;
  subject: string;
  grade: string;
  covers: string;
  long_words: number;
  shared_from?: string | null;
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
}
export interface AudioRow {
  hash: string;
  kind: "question" | "long";
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
  seq?: number;
  queued_at?: string;
}

export interface DrillDb {
  drill(id: string): Promise<DrillRow | null>;
  drills(userId: string): Promise<DrillRow[]>;
  saveDrill(row: DrillRow, isNew: boolean): Promise<void>;
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
/** K47: the link that opens Earmind (universal link once earmind.ai serves apple-app-site-association; scheme until then). */
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
  speak(text: string, model: string, voiceId: string): Promise<{ audio: Uint8Array; starts: number[]; ends: number[] }>;
}

export interface DrillDeps {
  authenticate: Authenticator;
  rateLimiter: RateLimiter;
  db: DrillDb;
  storage: AudioStorage;
  synth: Synth | null;
  /** D143: a high-quality model (Multilingual v2 or newer, never Turbo/Flash). */
  model: string;
  voiceId: string | null;
  /** USD per 1 000 characters for `model` (verified 2026-11-13: v2/v3/v4 0.08). */
  usdPer1kChars: number;
  /** Characters of NEW audio per account and day, and for everyone (D144). */
  charLimits: Limits;
  /** Runs the generator after the response (EdgeRuntime.waitUntil); tests await it. */
  background?: (p: Promise<unknown>) => void;
  now?: () => number;
  /** K49: Aron (OWNER_EMAIL, signed in by e-mail) shows a hidden publication again. */
  ownerEmails?: string[];
}

// ---------- text and hashes ----------

/** Exactly what the voice reads: no markdown, numbers and symbols in words, measured spellings (K18). */
export function voiceText(s: string): string {
  // a sentence end as the context: each text starts a sentence ("6 koldioxid" -> "Sex koldioxid")
  return pronounce(toSpeech(spokenText(s, 4000), "Start. "), "sv").replace(/\s+/g, " ").trim();
}
/** D145: the long file is the short answer, then the rest; the boundary is known to the character. */
export function longVoice(short: string, long: string): { text: string; shortChars: number } {
  const s = voiceText(short);
  const rest = long.startsWith(short) ? long.slice(short.length) : long;
  const r = voiceText(rest);
  return { text: r ? `${s} ${r}` : s, shortChars: s.length };
}
export async function audioHash(text: string, model: string, voiceId: string): Promise<string> {
  const data = new TextEncoder().encode(JSON.stringify(["drill-audio-v1", text, model, voiceId, "mp3_44100_64"]));
  const d = new Uint8Array(await crypto.subtle.digest("SHA-256", data));
  return Array.from(d, (b) => b.toString(16).padStart(2, "0")).join("");
}
export const audioPath = (hash: string) => `${hash.slice(0, 2)}/${hash}.mp3`;

/** Word timings from character timings: [[start_ms, end_ms], ...], and where the short answer ends. */
export function timings(text: string, starts: number[], ends: number[], shortChars?: number | null) {
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
export function publicView(r: PublicationRow, school: SchoolRow, title: string, items: number) {
  return {
    id: r.id,
    title,
    subject: r.subject,
    school: { code: school.code, name: school.name, locality: school.locality ?? null },
    exam_date: r.exam_date,
    items,
    ...(r.display_name ? { display_name: r.display_name } : {}),
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

  /** Makes queued files until the queue is empty or the time is up. Never throws. */
  async function pump(budgetMs = 110_000): Promise<number> {
    if (!deps.synth) return 0;
    const t0 = now();
    let made = 0;
    try {
      while (now() - t0 < budgetMs) {
        const jobs = await deps.db.claim(3);
        if (!jobs.length) break;
        await Promise.all(jobs.map(async (j) => {
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
              error: null,
              done_at: new Date(now()).toISOString(),
            });
            made++;
          } catch (e) {
            const msg = e instanceof Error ? e.message.slice(0, 300) : String(e).slice(0, 300);
            console.error("drill_audio_failed", j.hash.slice(0, 12), msg);
            await deps.db.finish(j.hash, { status: (j.attempts ?? 1) >= 3 ? "failed" : "pending", error: msg }).catch(() => {});
            if (/quota|credit|401|402/i.test(msg)) throw e; // out of credits: stop, the queue waits
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
        ...(a.status === "done"
          ? { url: urls[audioPath(h)] ?? null, duration_ms: a.duration_ms, ...(a.kind === "long" ? { short_end_ms: a.short_end_ms } : {}) }
          : {}),
      };
    };
    const chars = hashes.reduce((n, h) => n + (audio.get(h)?.text.length ?? 0), 0);
    return {
      drill: {
        id: drill.id, title: drill.title, subject: drill.subject, grade: drill.grade, covers: drill.covers,
        long_words: drill.long_words, shared_from: drill.shared_from ?? null, created_at: drill.created_at, updated_at: drill.updated_at,
      },
      items: items.map((i) => ({
        id: i.id, position: i.position, question: i.question, short: i.short, long: i.long,
        audio: { question: file(i.question_hash), long: file(i.long_hash) },
      })),
      audio: {
        done: done.length,
        total: hashes.length,
        failed: hashes.filter((h) => audio.get(h)?.status === "failed").length,
        // R10: what this drill's audio costs (whoever generated it first), and its size
        chars,
        est_usd: Math.round(chars * deps.usdPer1kChars / 10) / 100,
        bytes: done.reduce((n, h) => n + (audio.get(h)?.bytes ?? 0), 0),
        model: deps.model,
      },
    };
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
      covers: src.covers, long_words: src.long_words, shared_from: src.id,
    };
    const its = (await deps.db.items([src.id])).sort((a, b) => a.position - b.position);
    await deps.db.saveDrill(copy, true);
    await deps.db.replaceItems(copy.id, [], its.map((i) => ({
      drill_id: copy.id, user_id: userId, position: i.position, question: i.question, short: i.short, long: i.long,
      question_hash: i.question_hash, long_hash: i.long_hash,
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

  return async (req: Request): Promise<Response> => {
    if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS_HEADERS });
    try {
      if (req.method !== "POST") throw new HttpError(405, "method_not_allowed", "Use POST");
      const user = await deps.authenticate(req);
      const b = (await readLimitedJson(req, DRILL_STORE_LIMITS.bodyBytes)) as Record<string, unknown> | null;
      const action = String(b?.action ?? "");
      if (action === "list") {
        const drills = await deps.db.drills(user.id);
        const items = drills.length ? await deps.db.items(drills.map((d) => d.id)) : [];
        const hashes = [...new Set(items.flatMap((i) => [i.question_hash, i.long_hash]).filter(Boolean))];
        const doneSet = new Set((hashes.length ? await deps.db.audio(hashes) : []).filter((a) => a.status === "done").map((a) => a.hash));
        return json({
          drills: drills.map((d) => {
            const its = items.filter((i) => i.drill_id === d.id);
            const hs = [...new Set(its.flatMap((i) => [i.question_hash, i.long_hash]))];
            return {
              id: d.id, title: d.title, subject: d.subject, grade: d.grade, items: its.length, updated_at: d.updated_at,
              shared_from: d.shared_from ?? null, audio: { done: hs.filter((h) => doneSet.has(h)).length, total: hs.length },
            };
          }),
        });
      }
      if (action === "get" || action === "status") {
        const d = await owned(user.id, b?.id);
        const v = await view(d);
        if (action === "status" && v.audio.done + v.audio.failed < v.audio.total) {
          deps.background ? deps.background(pump()) : await pump();
        }
        return json(v);
      }
      if (action === "share") {
        const d = await owned(user.id, b?.id);
        const v = await view(d);
        if (v.audio.total === 0 || v.audio.done < v.audio.total) {
          // D143: sharing before the audio is done would make the recipient pay for the same audio again
          return json({
            error: { code: "audio_not_ready", message: `Delas när ljudet är klart (${v.audio.done} av ${v.audio.total})`, fallback: false },
            done: v.audio.done,
            total: v.audio.total,
          }, 409);
        }
        let sh = await deps.db.shareOf(d.id);
        if (!sh || sh.revoked_at) {
          sh = { code: newShareCode(), drill_id: d.id, user_id: user.id };
          await deps.db.createShare(sh);
        }
        return json({ code: sh.code, url: SHARE_URL(sh.code), app_url: SHARE_APP_URL(sh.code) });
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
        const v = await view(d);
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
        return json({ publication: publicView(row, school!, d.title, v.items.length) });
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
          .slice(0, 50)
          .map((r) => publicView(r, schools.get(r.school_code)!, drills.get(r.drill_id)!.title, its.filter((i) => i.drill_id === r.drill_id).length));
        return json({ results });
      }
      if (action === "report") {
        const pub = await publicationFor(b?.publication_id);
        const reason = ["fel", "krankande", "upphovsratt", "annat"].includes(String(b?.reason)) ? String(b?.reason) : "annat";
        const rl = await enforceLimits(deps.rateLimiter, "drill_report", user.id, { perMinute: 10, perDay: 30, globalPerDay: 20_000 }, 1);
        if (!rl.allowed) throw new HttpError(429, "rate_limited", "För många rapporter på kort tid.", { retryAfterSec: rl.retryAfterSec });
        return json(await deps.db.report(pub.id, user.id, reason));
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
        await deps.db.deleteDrill(d.id); // the shared audio stays (other accounts may use it)
        return json({ deleted: true });
      }
      if (action !== "save") throw new HttpError(400, "invalid_request", "unknown action");

      // ---------- save ----------
      const di = (b?.drill ?? {}) as Record<string, unknown>;
      const rawItems = Array.isArray(b?.items) ? b!.items as Record<string, unknown>[] : [];
      if (!rawItems.length) throw new HttpError(400, "invalid_request", "items: at least one question");
      if (rawItems.length > DRILL_STORE_LIMITS.items) throw new HttpError(400, "invalid_request", `items: at most ${DRILL_STORE_LIMITS.items}`);
      if (!deps.voiceId) throw new HttpError(503, "provider_unconfigured", "No voice configured");
      let existing: DrillRow | null = null;
      if (di.id !== undefined && di.id !== null) existing = await owned(user.id, di.id);
      else if ((await deps.db.drills(user.id)).length >= DRILL_STORE_LIMITS.drillsPerUser) {
        throw new HttpError(409, "too_many_drills", "Du har många prov sparade. Ta bort några gamla först.");
      }
      const lw = Math.round(Number(di.long_words));
      const drill: DrillRow = {
        id: existing?.id ?? crypto.randomUUID(),
        user_id: user.id,
        title: clean(di.title, 120) || existing?.title || "",
        subject: clean(di.subject, 60) || existing?.subject || "",
        grade: clean(di.grade, 60) || existing?.grade || "",
        covers: clean(di.covers, 400) || existing?.covers || "",
        long_words: Number.isFinite(lw) && lw >= 40 && lw <= 200 ? lw : existing?.long_words ?? 90,
        shared_from: existing?.shared_from ?? null,
      };
      const oldItems = existing ? await deps.db.items([existing.id]) : [];
      const oldIds = new Set(oldItems.map((i) => i.id));
      const rows: (ItemRow & { keep?: string })[] = [];
      const files = new Map<string, AudioRow>();
      for (const [pos, it] of rawItems.entries()) {
        const question = clean(it?.question, DRILL_STORE_LIMITS.question);
        if (!question) throw new HttpError(400, "invalid_request", `items[${pos}].question is required`);
        const short = clean(it?.short, DRILL_STORE_LIMITS.short);
        if (!short) throw new HttpError(400, "invalid_request", `items[${pos}].short is required`);
        // D145: the long answer starts with the short one; an edited short answer is put in front again
        let long = clean(it?.long, DRILL_STORE_LIMITS.long) || short;
        if (!long.startsWith(short)) long = composeLong(short, long).slice(0, DRILL_STORE_LIMITS.long);
        const q = voiceText(question);
        const l = longVoice(short, long);
        const qh = await audioHash(q, deps.model, deps.voiceId);
        const lh = await audioHash(l.text, deps.model, deps.voiceId);
        files.set(qh, files.get(qh) ?? { hash: qh, kind: "question", text: q, model: deps.model, voice_id: deps.voiceId, seq: pos * 2 });
        files.set(lh, files.get(lh) ?? { hash: lh, kind: "long", text: l.text, short_chars: l.shortChars, model: deps.model, voice_id: deps.voiceId, seq: pos * 2 + 1 });
        const id = typeof it?.id === "string" && oldIds.has(it.id) ? it.id : undefined;
        rows.push({ ...(id ? { id } : {}), drill_id: drill.id, user_id: user.id, position: pos, question, short, long, question_hash: qh, long_hash: lh });
      }
      // D144: only files no account has yet are generated and counted
      const have = new Set((await deps.db.audio([...files.keys()])).map((a) => a.hash));
      const fresh = [...files.values()].filter((f) => !have.has(f.hash));
      const newChars = fresh.reduce((n, f) => n + f.text.length, 0);
      if (newChars > 0) {
        const rl = await enforceLimits(deps.rateLimiter, "drill_tts", user.id, deps.charLimits, newChars);
        if (!rl.allowed) {
          throw new HttpError(429, "rate_limited", "Du har gjort mycket ljud i dag. Spara provet igen i morgon, så görs resten.", {
            retryAfterSec: rl.retryAfterSec,
          });
        }
      }
      // the audio is queued first: a failure leaves no half-saved drill (a queued file nobody uses costs nothing)
      if (fresh.length) {
        const at = new Date(now()).toISOString();
        // every row with the same keys (PostgREST bulk insert, live 2026-11-13: HTTP 400 otherwise)
        await deps.db.enqueue(fresh.map((f) => ({
          hash: f.hash, kind: f.kind, text: f.text, short_chars: f.short_chars ?? null, model: f.model,
          voice_id: f.voice_id, status: "pending", seq: f.seq ?? 0, queued_at: at,
        })));
      }
      await deps.db.saveDrill(drill, !existing);
      await deps.db.replaceItems(drill.id, rows.map((r) => r.id).filter((x): x is string => !!x), rows);
      if (fresh.length) deps.background ? deps.background(pump()) : await pump();
      const saved = await deps.db.drill(drill.id);
      return json({ ...(await view(saved ?? drill)), new_chars: newChars });
    } catch (e) {
      return errorResponse(toHttpError(e));
    }
  };
}
