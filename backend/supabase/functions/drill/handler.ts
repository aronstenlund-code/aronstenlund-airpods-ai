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
      if (action === "delete") {
        const d = await owned(user.id, b?.id);
        await deps.db.deleteDrill(d.id); // the shared audio stays (other accounts may use it)
        return json({ deleted: true });
      }
      if (action !== "save") throw new HttpError(400, "invalid_request", "action must be save, get, status, list or delete");

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
      await deps.db.saveDrill(drill, !existing);
      await deps.db.replaceItems(drill.id, rows.map((r) => r.id).filter((x): x is string => !!x), rows);
      if (fresh.length) {
        const at = new Date(now()).toISOString();
        await deps.db.enqueue(fresh.map((f) => ({ ...f, status: "pending", queued_at: at })));
        deps.background ? deps.background(pump()) : await pump();
      }
      const saved = await deps.db.drill(drill.id);
      return json({ ...(await view(saved ?? drill)), new_chars: newChars });
    } catch (e) {
      return errorResponse(toHttpError(e));
    }
  };
}
