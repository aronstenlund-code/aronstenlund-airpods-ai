/**
 * K98 (D224): welcome credits and invitations.
 *  - Welcome: 5 000 credits (drill_settings.welcome_credits) once per account and once per App Attest key: the app
 *    proves with App Attest that it is a genuine copy on a real device; the key may give welcome credits to one account.
 *    (A reinstall makes a new key: "once per phone" across reinstalls needs DeviceCheck, see the K98 report.)
 *  - Invitation: every account has a code. A new account (with an attested key that no other account has) claims a
 *    code once; when it plays its first text or exam, the inviter gets 2 000 (invite_credits), at most 10 a month
 *    (invite_month_max), never for itself and never when the two share a key.
 * Credits go to credit_ledger (kind welcome / invite) with a unique transaction id, so nothing is ever given twice.
 */
export interface RewardStore {
  settings(): Promise<Record<string, number>>;
  /** add a ledger row once (unique transaction_id); false when it was already there */
  credit(row: { user_id: string; kind: "welcome" | "invite"; transaction_id: string; credits: number }): Promise<boolean>;
  /** the account that registered this key first (null = none) */
  keyOwner(keyId: string): Promise<string | null>;
  /** register the key for the account (once; false when another account has it) */
  registerKey(keyId: string, userId: string): Promise<boolean>;
  keysOf(userId: string): Promise<string[]>;
  inviteCode(userId: string): Promise<string | null>;
  createInviteCode(userId: string, code: string): Promise<boolean>;
  codeOwner(code: string): Promise<string | null>;
  /** the claim of this invitee, if any */
  claim(invitee: string): Promise<{ inviter: string; rewarded_at: string | null } | null>;
  addClaim(invitee: string, inviter: string): Promise<boolean>;
  markRewarded(invitee: string): Promise<boolean>;
  /** invite credits the inviter got this month (Stockholm) */
  invitesThisMonth(inviter: string): Promise<number>;
}

export const DEFAULTS = { welcome_credits: 5000, invite_credits: 2000, invite_month_max: 10 };

export class RewardRefusal extends Error {
  constructor(public status: number, public code: string, message: string) {
    super(message);
  }
}

const n = (st: Record<string, number>, k: keyof typeof DEFAULTS) => Number.isFinite(Number(st[k])) && st[k] !== undefined ? Number(st[k]) : DEFAULTS[k];

/** After a verified attestation: register the key and give the welcome credits once. */
export async function welcome(s: RewardStore, userId: string, keyId: string): Promise<{ added: number; reason?: string }> {
  const st = await s.settings().catch(() => ({}));
  const owner = await s.keyOwner(keyId);
  if (owner && owner !== userId) return { added: 0, reason: "key_used" };
  if (!owner && !(await s.registerKey(keyId, userId))) return { added: 0, reason: "key_used" };
  const credits = n(st, "welcome_credits");
  if (credits <= 0) return { added: 0, reason: "off" };
  // once per account AND once per key: both ids are unique transaction ids
  const forKey = await s.credit({ user_id: userId, kind: "welcome", transaction_id: `welcome-key:${keyId}`, credits: 0 });
  if (!forKey) return { added: 0, reason: "key_used" };
  const added = await s.credit({ user_id: userId, kind: "welcome", transaction_id: `welcome:${userId}`, credits });
  return added ? { added: credits } : { added: 0, reason: "already" };
}

const ALPHA = "abcdefghjkmnpqrstuvwxyz23456789";
export function newInviteCode(): string {
  const b = crypto.getRandomValues(new Uint8Array(8));
  return [...b].map((x) => ALPHA[x % ALPHA.length]).join("");
}

export async function inviteCodeFor(s: RewardStore, userId: string): Promise<string> {
  const had = await s.inviteCode(userId);
  if (had) return had;
  for (let i = 0; i < 5; i++) {
    const c = newInviteCode();
    if (await s.createInviteCode(userId, c)) return c;
    const again = await s.inviteCode(userId);
    if (again) return again;
  }
  throw new RewardRefusal(503, "invite_unavailable", "Försök igen om en stund.");
}

/** A new account claims an invitation (needs its own attested key; once). */
export async function claimInvite(s: RewardStore, invitee: string, code: string): Promise<{ ok: true }> {
  const inviter = /^[a-z0-9]{6,12}$/.test(code) ? await s.codeOwner(code) : null;
  if (!inviter) throw new RewardRefusal(404, "invite_not_found", "Inbjudan finns inte.");
  if (inviter === invitee) throw new RewardRefusal(409, "invite_self", "Du kan inte bjuda in dig själv.");
  const mine = await s.keysOf(invitee);
  if (!mine.length) throw new RewardRefusal(409, "invite_needs_device", "Öppna appen på din telefon först.");
  const theirs = new Set(await s.keysOf(inviter));
  if (mine.some((k) => theirs.has(k))) throw new RewardRefusal(409, "invite_same_device", "Inbjudan gäller ett konto på en annan telefon.");
  if (await s.claim(invitee)) throw new RewardRefusal(409, "invite_already", "Du har redan använt en inbjudan.");
  if (!(await s.addClaim(invitee, inviter))) throw new RewardRefusal(409, "invite_already", "Du har redan använt en inbjudan.");
  return { ok: true };
}

/** The invitee played its first text or exam: the inviter gets its credits once (within the month's cap). */
export async function onFirstPlay(s: RewardStore, invitee: string): Promise<{ rewarded: number; reason?: string }> {
  const c = await s.claim(invitee).catch(() => null);
  if (!c || c.rewarded_at) return { rewarded: 0 };
  const st = await s.settings().catch(() => ({}));
  if ((await s.invitesThisMonth(c.inviter)) >= n(st, "invite_month_max")) return { rewarded: 0, reason: "month_cap" };
  if (!(await s.markRewarded(invitee))) return { rewarded: 0 }; // someone else just did it
  const credits = n(st, "invite_credits");
  const ok = await s.credit({ user_id: c.inviter, kind: "invite", transaction_id: `invite:${invitee}`, credits });
  return ok ? { rewarded: credits } : { rewarded: 0 };
}
