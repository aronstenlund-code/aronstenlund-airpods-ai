/**
 * K101 (Apple's rule, Ke78): POST /account/delete — the signed-in user deletes their own account and everything that
 * belongs to it. Only the caller's own account, only with {"confirm": true}; never several accounts.
 *  - Their drills, texts and items, shares, publications, credits (free, bought, given), App Attest keys, invitations,
 *    feedback, history, usage rows, Spotify connection and debug turns (with their audio) are deleted.
 *  - Audio files only their drills use are deleted (rows and storage). A file another account's drill also uses, or a
 *    cue every drill plays ("Tryck en gång för svaret."), stays: it is shared and holds nothing that points to them.
 *  - The account in auth is deleted last (its foreign keys cascade the rest).
 *  - An active weekly subscription is not cancelled by us: Apple does that; the answer says so.
 */
import { type Authenticator } from "../_shared/auth.ts";
import { CORS_HEADERS, errorResponse, HttpError, toHttpError } from "../_shared/errors.ts";
import { enforceLimits, type RateLimiter } from "../_shared/ratelimit.ts";

export interface AccountFile { hash: string; model: string; voice_id: string }

export interface AccountStore {
  /** the audio files this account's drill items point at */
  drillFiles(userId: string): Promise<AccountFile[]>;
  /** of these hashes, those another account's drill items also point at */
  usedByOthers(hashes: string[], userId: string): Promise<Set<string>>;
  deleteAudioRows(hashes: string[]): Promise<void>;
  /** the storage paths of this account's debug audio (debug_turns.audio_path) */
  debugAudioPaths(userId: string): Promise<string[]>;
  subscription(userId: string): Promise<{ active: boolean; until: string | null }>;
  /** rows in tables whose user column does not cascade from auth.users */
  deleteOwnRows(userId: string): Promise<void>;
  /** the auth account (cascades drills, items, shares, publications, quota, ledger, subscriptions, keys, invites) */
  deleteAuthUser(userId: string): Promise<void>;
}

export interface AccountDeps {
  authenticate: Authenticator;
  rateLimiter: RateLimiter;
  store: AccountStore;
  /** removes objects from a storage bucket (at most 100 paths a call) */
  removeObjects(bucket: string, paths: string[]): Promise<void>;
  /** the hashes of the shared cue files for these (model, voice) pairs (never deleted) */
  cueHashes(pairs: { model: string; voice_id: string }[]): Promise<Set<string>>;
  audioPath(hash: string): string;
}

export const SUBSCRIPTION_NOTICE = "Veckokortet avslutas inte när kontot raderas. Säg upp det i Inställningar > ditt namn > Prenumerationer.";

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json", "cache-control": "no-store", ...CORS_HEADERS } });

async function inChunks<T>(xs: T[], n: number, f: (part: T[]) => Promise<unknown>) {
  for (let i = 0; i < xs.length; i += n) await f(xs.slice(i, i + n));
}

export function createAccountHandler(deps: AccountDeps): (req: Request) => Promise<Response> {
  return async (req) => {
    if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: { ...CORS_HEADERS, "access-control-allow-methods": "POST, OPTIONS" } });
    try {
      if (req.method !== "POST") throw new HttpError(405, "method_not_allowed", "Use POST");
      const user = await deps.authenticate(req);
      const b = await req.json().catch(() => null) as Record<string, unknown> | null;
      const action = new URL(req.url).pathname.endsWith("/delete") ? "delete" : String(b?.action ?? "");
      if (action !== "delete") throw new HttpError(400, "invalid_request", "unknown action");
      if (b?.confirm !== true) throw new HttpError(400, "confirm_required", "Bekräfta att kontot ska raderas.");
      const rl = await enforceLimits(deps.rateLimiter, "account_delete", user.id, { perMinute: 3, perDay: 10, globalPerDay: 5_000 }, 1);
      if (!rl.allowed) throw new HttpError(429, "rate_limited", "Försök igen om en stund.", { retryAfterSec: rl.retryAfterSec });

      const sub = await deps.store.subscription(user.id).catch(() => ({ active: false, until: null }));
      // the audio only this account's drills use
      const files = await deps.store.drillFiles(user.id);
      const hashes = [...new Set(files.map((f) => f.hash))];
      const others = hashes.length ? await deps.store.usedByOthers(hashes, user.id) : new Set<string>();
      const pairs = [...new Map(files.map((f) => [`${f.model}|${f.voice_id}`, { model: f.model, voice_id: f.voice_id }])).values()];
      const cues = pairs.length ? await deps.cueHashes(pairs) : new Set<string>();
      const mine = hashes.filter((h) => !others.has(h) && !cues.has(h));
      await inChunks(mine, 100, (p) => deps.removeObjects("drill_audio", p.map(deps.audioPath)));
      await inChunks(mine, 100, (p) => deps.store.deleteAudioRows(p));
      const debug = await deps.store.debugAudioPaths(user.id).catch(() => []);
      await inChunks(debug, 100, (p) => deps.removeObjects("debug_audio", p));
      await deps.store.deleteOwnRows(user.id);
      await deps.store.deleteAuthUser(user.id);
      console.log("account_deleted", JSON.stringify({ files: mine.length, shared_kept: hashes.length - mine.length, debug: debug.length }));
      return json({
        deleted: true,
        removed: { audio_files: mine.length, shared_audio_kept: hashes.length - mine.length },
        subscription: { active: sub.active, until: sub.until },
        ...(sub.active ? { notice: SUBSCRIPTION_NOTICE } : {}),
      });
    } catch (e) {
      return errorResponse(toHttpError(e));
    }
  };
}
