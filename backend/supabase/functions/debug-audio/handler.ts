/**
 * K43 (D140, owner): test mode. Only for Aron's account (OWNER_EMAIL, email sign-in) and testers who turn it on
 * themselves (signed in by email, never anonymous): the app sends the audio of each turn and what Lumen heard and did,
 * so we can see whether the question was picked out right. Everyone else: no audio is ever stored (CLAUDE.md).
 * Private bucket `debug_audio` + table `debug_turns` (service role only), deleted after 14 days.
 *
 *   GET  /debug-audio                     -> {"debug_audio": bool}            the app's flag (is test mode on for me)
 *   POST /debug-audio?action=opt_in|opt_out -> {"debug_audio": bool}          a tester turns it on or off (email users)
 *   POST /debug-audio {turn}              -> {"id", "audio_path"}             one turn (audio optional), test mode only
 *   GET  /debug-audio?view=owner          -> {"turns": [... signed audio_url (1 h)]}   Aron only
 *   POST /debug-audio?action=purge        -> {"removed": n}                   no login: removes only folders > 14 days
 *
 * turn = {turn_id?, mode?, audio_b64?, audio_mime?, transcript?, words?: [{w, start_ms, end_ms, conf?}], decision?,
 *         answer?, meta?}. Audio at most 1.5 MB, numbers in the text masked as in qa_log.
 */
import type { Authenticator, AuthedUser } from "../_shared/auth.ts";
import { CORS_HEADERS, errorResponse, HttpError, toHttpError } from "../_shared/errors.ts";
import { requireOwner } from "../_shared/owner.ts";
import { enforceLimits, type Limits, type RateLimiter } from "../_shared/ratelimit.ts";
import { maskNumbers } from "../answer/qalog.ts";

export const DEBUG_AUDIO_LIMITS: Limits = { perMinute: 60, perDay: 3000, globalPerDay: 30_000 };
export const MAX_AUDIO_BYTES = 1_500_000;
export const KEEP_DAYS = 14;
const MIMES: Record<string, string> = {
  "audio/mp4": "m4a", "audio/m4a": "m4a", "audio/x-m4a": "m4a", "audio/aac": "aac", "audio/wav": "wav", "audio/x-wav": "wav",
  "audio/mpeg": "mp3", "audio/ogg": "ogg", "audio/webm": "webm", "audio/flac": "flac",
};

export interface DebugTurnRow {
  user_id: string;
  turn_id: string | null;
  mode: string | null;
  audio_path: string | null;
  audio_bytes: number | null;
  transcript: string | null;
  words: { w: string; start_ms: number; end_ms: number; conf?: number }[] | null;
  decision: string | null;
  answer: string | null;
  meta: Record<string, unknown> | null;
}

export interface DebugAudioDeps {
  authenticate: Authenticator;
  rateLimiter: RateLimiter;
  ownerEmails: string[];
  isTester: (userId: string) => Promise<boolean>;
  setTester: (userId: string, on: boolean) => Promise<void>;
  putAudio: (path: string, bytes: Uint8Array<ArrayBuffer>, mime: string) => Promise<void>;
  signUrl: (path: string) => Promise<string | null>;
  /** date folders ("YYYY-MM-DD") in the bucket */
  folders: () => Promise<string[]>;
  removeFolder: (folder: string) => Promise<number>;
  insertTurn: (row: DebugTurnRow) => Promise<number>;
  listTurns: (limit: number) => Promise<(DebugTurnRow & { id: number; created_at: string })[]>;
  now?: () => Date;
  uuid?: () => string;
  limits?: Limits;
}

const isOwner = (u: AuthedUser, owners: string[]) =>
  !u.isAnonymous && !!u.email && (u.amr ?? []).some((m) => m === "otp" || m === "magiclink") &&
  owners.map((e) => e.trim().toLowerCase()).filter(Boolean).includes(u.email.toLowerCase());

const text = (v: unknown, max: number) => typeof v === "string" && v.trim() ? maskNumbers(v.trim()).slice(0, max) : null;

/** String values masked as in qa_log (numbers in the JSON itself stay numbers). */
function maskDeep(v: unknown): unknown {
  if (typeof v === "string") return maskNumbers(v);
  if (Array.isArray(v)) return v.map(maskDeep);
  if (v && typeof v === "object") return Object.fromEntries(Object.entries(v).map(([k, x]) => [k, maskDeep(x)]));
  return v;
}

function decodeB64(s: string): Uint8Array<ArrayBuffer> {
  const bin = atob(s.replace(/\s+/g, ""));
  const out = new Uint8Array(new ArrayBuffer(bin.length));
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

async function readJson(req: Request, maxBytes: number): Promise<Record<string, unknown>> {
  const len = Number(req.headers.get("content-length") ?? "0");
  if (len > maxBytes) throw new HttpError(413, "too_large", "At most 1.5 MB of audio per turn");
  const raw = await req.text();
  if (raw.length > maxBytes) throw new HttpError(413, "too_large", "At most 1.5 MB of audio per turn");
  try {
    const o = JSON.parse(raw || "{}");
    if (!o || typeof o !== "object" || Array.isArray(o)) throw new Error("not an object");
    return o as Record<string, unknown>;
  } catch {
    throw new HttpError(400, "invalid_request", "Send JSON");
  }
}

export function createDebugAudioHandler(deps: DebugAudioDeps) {
  const now = deps.now ?? (() => new Date());
  const uuid = deps.uuid ?? (() => crypto.randomUUID());
  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json", "cache-control": "no-store", ...CORS_HEADERS } });
  const enabled = async (u: AuthedUser) => isOwner(u, deps.ownerEmails) || (!u.isAnonymous && await deps.isTester(u.id));

  return async (req: Request): Promise<Response> => {
    if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS_HEADERS });
    try {
      const url = new URL(req.url);
      const action = url.searchParams.get("action");
      if (req.method === "POST" && action === "purge") {
        // no login: only date folders older than KEEP_DAYS go, so calling it early does nothing
        const cutoff = new Date(now().getTime() - KEEP_DAYS * 86_400_000).toISOString().slice(0, 10);
        let removed = 0;
        for (const f of await deps.folders()) if (/^\d{4}-\d{2}-\d{2}$/.test(f) && f < cutoff) removed += await deps.removeFolder(f);
        return json({ removed });
      }
      if (req.method === "GET" && url.searchParams.get("view") === "owner") {
        await requireOwner(req, deps.authenticate, deps.ownerEmails);
        const rows = await deps.listTurns(200);
        const turns = await Promise.all(rows.map(async (r) => ({ ...r, audio_url: r.audio_path ? await deps.signUrl(r.audio_path) : null })));
        return json({ turns });
      }
      const user = await deps.authenticate(req);
      if (req.method === "GET") return json({ debug_audio: await enabled(user) });
      if (req.method !== "POST") throw new HttpError(405, "method_not_allowed", "Use GET or POST");
      if (action === "opt_in" || action === "opt_out") {
        if (user.isAnonymous || !user.email) throw new HttpError(403, "forbidden", "Testläget kräver inloggning med e-post.");
        await deps.setTester(user.id, action === "opt_in");
        return json({ debug_audio: await enabled(user) });
      }
      if (!(await enabled(user))) throw new HttpError(403, "forbidden", "Testläget är inte på för det här kontot.");
      const rl = await enforceLimits(deps.rateLimiter, "debug-audio", user.id, deps.limits ?? DEBUG_AUDIO_LIMITS, 1, []);
      if (!rl.allowed) throw new HttpError(429, "rate_limited", "För många uppladdningar just nu.", { retryAfterSec: rl.retryAfterSec });
      const b = await readJson(req, Math.ceil(MAX_AUDIO_BYTES * 4 / 3) + 64_000);
      let audioPath: string | null = null;
      let audioBytes: number | null = null;
      if (typeof b.audio_b64 === "string" && b.audio_b64) {
        const mime = typeof b.audio_mime === "string" ? b.audio_mime.toLowerCase() : "audio/mp4";
        const ext = MIMES[mime];
        if (!ext) throw new HttpError(400, "invalid_request", "audio_mime must be an audio type (m4a, aac, wav, mp3, ogg, webm, flac)");
        let bytes: Uint8Array<ArrayBuffer>;
        try {
          bytes = decodeB64(b.audio_b64);
        } catch {
          throw new HttpError(400, "invalid_request", "audio_b64 is not base64");
        }
        if (bytes.length > MAX_AUDIO_BYTES) throw new HttpError(413, "too_large", "At most 1.5 MB of audio per turn");
        audioPath = `${now().toISOString().slice(0, 10)}/${user.id}/${uuid()}.${ext}`;
        await deps.putAudio(audioPath, bytes, mime);
        audioBytes = bytes.length;
      }
      const words = Array.isArray(b.words)
        ? b.words.slice(0, 400).flatMap((x) => {
          const o = x as Record<string, unknown>;
          if (!o || typeof o.w !== "string" || typeof o.start_ms !== "number" || typeof o.end_ms !== "number") return [];
          return [{ w: maskNumbers(o.w).slice(0, 60), start_ms: Math.round(o.start_ms), end_ms: Math.round(o.end_ms), ...(typeof o.conf === "number" ? { conf: o.conf } : {}) }];
        })
        : null;
      const metaRaw = b.meta && typeof b.meta === "object" && !Array.isArray(b.meta) ? JSON.stringify(b.meta) : "";
      const row: DebugTurnRow = {
        user_id: user.id,
        turn_id: typeof b.turn_id === "string" ? b.turn_id.slice(0, 64) : null,
        mode: typeof b.mode === "string" ? b.mode.slice(0, 32) : null,
        audio_path: audioPath,
        audio_bytes: audioBytes,
        transcript: text(b.transcript, 4000),
        words: words && words.length ? words : null,
        decision: typeof b.decision === "string" ? b.decision.slice(0, 64) : null,
        answer: text(b.answer, 6000),
        meta: metaRaw && metaRaw.length <= 4000 ? maskDeep(b.meta) as Record<string, unknown> : null,
      };
      if (!row.audio_path && !row.transcript && !row.answer) throw new HttpError(400, "invalid_request", "Send audio_b64, transcript or answer");
      const id = await deps.insertTurn(row);
      return json({ id, audio_path: audioPath });
    } catch (e) {
      return errorResponse(toHttpError(e));
    }
  };
}
