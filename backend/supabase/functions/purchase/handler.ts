/**
 * K94 (D218, D214): App Store purchases on the server.
 *   POST /purchase {"action":"verify","jws":"<StoreKit 2 signed transaction>"}  (signed in)
 *     -> {ok:true, kind:"credits"|"subscription", added?, until?, wallet}   (the same transaction twice adds once)
 *   POST /purchase {"signedPayload":"<App Store Server Notification v2>"}  (from Apple, no user; the signature is
 *     the authentication) -> 200 {ok:true}: renewals extend the subscription, refunds take bought credits back or
 *     end the subscription, expiry ends it.
 * Products come from the table store_products (product id -> credits or subscription), never from the code. Only
 * Apple's root (pinned) is accepted; a test root only through deps in tests. Errors: 400 invalid_request,
 * 422 purchase_invalid {reason}, 409 purchase_other_account.
 */
import type { Authenticator } from "../_shared/auth.ts";
import { CORS_HEADERS, errorResponse, HttpError, toHttpError } from "../_shared/errors.ts";
import { enforceLimits, type RateLimiter } from "../_shared/ratelimit.ts";
import { InvalidJws, type Transaction, verifyJws } from "./jws.ts";
import { InvalidAttestation, verifyAttestation } from "./attest.ts";
import { claimInvite, inviteCodeFor, inviteStatus, RewardRefusal, type RewardStore, welcome } from "../_shared/rewards.ts";

export interface Product { product_id: string; kind: "credits" | "subscription"; credits: number }
export interface LedgerRow {
  user_id: string; kind: "purchase" | "refund"; product_id: string; transaction_id: string; original_transaction_id: string;
  credits: number; environment: string | null;
}
export interface SubRow { user_id: string; original_transaction_id: string; product_id: string; expires_at: string; status: string; environment: string | null }

export interface PurchaseStore {
  product(id: string): Promise<Product | null>;
  /** the ledger row with this transaction id (purchase) or "refund:<id>", or null */
  ledger(txId: string): Promise<LedgerRow | null>;
  /** insert once (unique transaction_id); false when it was already there */
  addLedger(row: LedgerRow): Promise<boolean>;
  subByOriginal(origTx: string): Promise<SubRow | null>;
  upsertSub(row: SubRow): Promise<void>;
}

export interface PurchaseDeps {
  authenticate: Authenticator;
  rateLimiter: RateLimiter;
  store: PurchaseStore;
  /** accepted roots (SHA-256 hex): production only Apple Root CA - G3 */
  roots: string[];
  bundleId: string;
  /** K98 (D224): welcome credits and invitations (App Attest) */
  rewards?: RewardStore;
  attest?: {
    /** "<TEAMID>.<bundle id>"; null = not configured (Aron sets APPLE_TEAM_ID) */
    appId: string | null;
    allowDevelopment: boolean;
    rootDer: Uint8Array;
    roots: string[];
    /** a one-time challenge for this account (5 minutes) */
    newChallenge(userId: string): Promise<string>;
    /** true once, when this challenge was given to this account and has not expired */
    useChallenge(userId: string, challenge: string): Promise<boolean>;
  };
  /** the account's credits afterwards (the same wallet as /drill quota) */
  wallet?: (userId: string) => Promise<Record<string, unknown>>;
  now?: () => number;
}

/** A refusal with extra fields in the body (HttpError has none). */
class Refusal extends Error {
  constructor(public status: number, public code: string, message: string, public extra: Record<string, unknown> = {}) {
    super(message);
  }
}

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json", "cache-control": "no-store", ...CORS_HEADERS } });

export function createPurchaseHandler(deps: PurchaseDeps) {
  const now = deps.now ?? (() => Date.now());

  async function transaction(jws: unknown): Promise<Transaction> {
    if (typeof jws !== "string" || jws.length > 20_000) throw new HttpError(400, "invalid_request", "jws is required");
    let t: Transaction;
    try {
      t = await verifyJws<Transaction>(jws, { roots: deps.roots });
    } catch (e) {
      if (e instanceof InvalidJws) throw new Refusal(422, "purchase_invalid", "Köpet gick inte att kontrollera.", { reason: e.reason });
      throw e;
    }
    if (t.bundleId !== deps.bundleId) throw new Refusal(422, "purchase_invalid", "Köpet gick inte att kontrollera.", { reason: "bundle" });
    if (!t.transactionId || !t.productId) throw new Refusal(422, "purchase_invalid", "Köpet gick inte att kontrollera.", { reason: "fields" });
    return t;
  }

  /** Credits or the subscription for this account; the same transaction never counts twice. */
  async function apply(userId: string, t: Transaction) {
    const p = await deps.store.product(t.productId);
    if (!p) throw new Refusal(422, "purchase_invalid", "Okänd produkt.", { reason: "product" });
    // a transaction belongs to the account that bought it (StoreKit's appAccountToken is the user id when the app sets it)
    if (t.appAccountToken && t.appAccountToken.toLowerCase() !== userId.toLowerCase()) {
      throw new Refusal(409, "purchase_other_account", "Köpet hör till ett annat konto.");
    }
    if (p.kind === "credits") {
      const had = await deps.store.ledger(t.transactionId);
      if (had && had.user_id !== userId) throw new Refusal(409, "purchase_other_account", "Köpet hör till ett annat konto.");
      if (t.revocationDate) return { kind: "credits", added: 0, revoked: true };
      const credits = p.credits * Math.max(1, t.quantity ?? 1);
      const added = await deps.store.addLedger({
        user_id: userId, kind: "purchase", product_id: p.product_id, transaction_id: t.transactionId,
        original_transaction_id: t.originalTransactionId ?? t.transactionId, credits, environment: t.environment ?? null,
      });
      return { kind: "credits", added: added ? credits : 0 };
    }
    const orig = t.originalTransactionId ?? t.transactionId;
    const sub = await deps.store.subByOriginal(orig);
    if (sub && sub.user_id !== userId) throw new Refusal(409, "purchase_other_account", "Prenumerationen hör till ett annat konto.");
    // O78 F1: a refunded (or ended) subscription comes back only with a transaction bought after it ended, never
    // with the old one StoreKit keeps on the phone
    if (sub && sub.status !== "active" && !t.revocationDate && !(t.purchaseDate > Date.parse(sub.expires_at))) {
      return { kind: "subscription", until: sub.expires_at, active: false, ...(sub.status === "revoked" ? { revoked: true } : {}) };
    }
    const until = new Date(t.revocationDate ?? t.expiresDate ?? now()).toISOString();
    // never move an end date backwards because an older transaction came in late
    const keep = sub && !t.revocationDate && Date.parse(sub.expires_at) > Date.parse(until);
    const row: SubRow = {
      user_id: userId, original_transaction_id: orig, product_id: p.product_id, expires_at: keep ? sub!.expires_at : until,
      status: t.revocationDate ? "revoked" : "active", environment: t.environment ?? null,
    };
    await deps.store.upsertSub(row);
    return { kind: "subscription", until: row.expires_at, active: row.status === "active" && Date.parse(row.expires_at) > now() };
  }

  /** App Store Server Notifications v2: who it belongs to comes from what we stored at verify. */
  async function notify(signedPayload: unknown): Promise<Response> {
    let n: { notificationType?: string; subtype?: string; data?: { signedTransactionInfo?: string; bundleId?: string } };
    try {
      n = await verifyJws(String(signedPayload ?? ""), { roots: deps.roots });
    } catch (e) {
      if (e instanceof InvalidJws) return json({ error: { code: "purchase_invalid", message: "invalid", fallback: false }, reason: e.reason }, 422);
      throw e;
    }
    if (n.data?.bundleId && n.data.bundleId !== deps.bundleId) return json({ ok: true, ignored: "bundle" });
    if (!n.data?.signedTransactionInfo) return json({ ok: true, ignored: "no_transaction" });
    const t = await transaction(n.data.signedTransactionInfo);
    const type = n.notificationType ?? "";
    const p = await deps.store.product(t.productId);
    if (!p) return json({ ok: true, ignored: "product" });
    const orig = t.originalTransactionId ?? t.transactionId;
    if (p.kind === "credits") {
      const bought = await deps.store.ledger(t.transactionId);
      if (!bought) return json({ ok: true, ignored: "unknown_transaction" });
      if (type === "REFUND" || t.revocationDate) {
        // the bought credits are taken back once (a balance can go below 0: the next purchase pays it back)
        const taken = await deps.store.addLedger({ ...bought, kind: "refund", transaction_id: `refund:${t.transactionId}`, credits: -bought.credits });
        // O78 F2: the same refund again takes nothing and says so
        return json(taken ? { ok: true, refunded: bought.credits } : { ok: true, refunded: 0, already: true });
      }
      return json({ ok: true });
    }
    const sub = await deps.store.subByOriginal(orig);
    if (!sub) return json({ ok: true, ignored: "unknown_subscription" });
    if (type === "REFUND" || type === "REVOKE" || t.revocationDate) {
      await deps.store.upsertSub({ ...sub, status: "revoked", expires_at: new Date(t.revocationDate ?? now()).toISOString() });
      return json({ ok: true, status: "revoked" });
    }
    if (type === "EXPIRED") {
      await deps.store.upsertSub({ ...sub, status: "expired" });
      return json({ ok: true, status: "expired" });
    }
    if (sub.status !== "active" && !(t.purchaseDate > Date.parse(sub.expires_at))) return json({ ok: true, status: sub.status, ignored: "older_than_end" });
    if (t.expiresDate && Date.parse(sub.expires_at) < t.expiresDate) {
      await deps.store.upsertSub({ ...sub, status: "active", expires_at: new Date(t.expiresDate).toISOString(), product_id: p.product_id });
    }
    return json({ ok: true, status: "active" });
  }

  return async (req: Request): Promise<Response> => {
    if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS_HEADERS });
    try {
      if (req.method !== "POST") throw new HttpError(405, "method_not_allowed", "Use POST");
      const raw = await req.text();
      if (raw.length > 64 * 1024) throw new HttpError(413, "payload_too_large", "too large");
      const b = (raw ? JSON.parse(raw) : null) as Record<string, unknown> | null;
      if (b && "signedPayload" in b) return await notify(b.signedPayload);
      const user = await deps.authenticate(req);
      // ---------- K98 (D224): welcome credits and invitations ----------
      if (b?.action === "attest_challenge") {
        // K109 (Oscar O90): no App ID (Team ID) yet = 503 here too, so the app keeps its three welcome tries
        if (!deps.attest || !deps.attest.appId) throw new HttpError(503, "attest_unconfigured", "Inte tillgängligt än.");
        return json({ challenge: await deps.attest.newChallenge(user.id) });
      }
      if (b?.action === "welcome") {
        if (!deps.attest || !deps.rewards || !deps.attest.appId) throw new HttpError(503, "attest_unconfigured", "Välkomstkrediterna är inte på än.");
        const rl = await enforceLimits(deps.rateLimiter, "welcome", user.id, { perMinute: 5, perDay: 20, globalPerDay: 50_000 }, 1);
        if (!rl.allowed) throw new HttpError(429, "rate_limited", "För många försök just nu.", { retryAfterSec: rl.retryAfterSec });
        const keyId = typeof b.key_id === "string" ? b.key_id : "", ch = typeof b.challenge === "string" ? b.challenge : "";
        const att = typeof b.attestation === "string" ? b.attestation : "";
        if (!keyId || !ch || !att || att.length > 20_000) throw new HttpError(400, "invalid_request", "key_id, challenge and attestation are required");
        if (!(await deps.attest.useChallenge(user.id, ch))) throw new Refusal(422, "attest_invalid", "Försök igen.", { reason: "challenge" });
        try {
          await verifyAttestation(keyId, Uint8Array.from(atob(att), (c) => c.charCodeAt(0)), new TextEncoder().encode(ch), {
            roots: deps.attest.roots, rootDer: deps.attest.rootDer, appId: deps.attest.appId, allowDevelopment: deps.attest.allowDevelopment,
          });
        } catch (e) {
          if (e instanceof InvalidAttestation) throw new Refusal(422, "attest_invalid", "Telefonen gick inte att kontrollera.", { reason: e.reason });
          throw new Refusal(422, "attest_invalid", "Telefonen gick inte att kontrollera.", { reason: "format" });
        }
        const r = await welcome(deps.rewards, user.id, keyId);
        return json({ ok: true, added: r.added, ...(r.reason ? { reason: r.reason } : {}), ...(deps.wallet ? { wallet: await deps.wallet(user.id) } : {}) });
      }
      if (b?.action === "invite_code") {
        if (!deps.rewards) throw new HttpError(503, "invite_unavailable", "Inte tillgängligt än.");
        const code = await inviteCodeFor(deps.rewards, user.id);
        return json({ code, url: `https://earmind.vercel.app/i/${code}`, app_url: `earmind://invite/${code}`, ...(await inviteStatus(deps.rewards, user.id)) });
      }
      if (b?.action === "invite_claim") {
        if (!deps.rewards) throw new HttpError(503, "invite_unavailable", "Inte tillgängligt än.");
        const rl = await enforceLimits(deps.rateLimiter, "invite_claim", user.id, { perMinute: 5, perDay: 20, globalPerDay: 50_000 }, 1);
        if (!rl.allowed) throw new HttpError(429, "rate_limited", "För många försök just nu.", { retryAfterSec: rl.retryAfterSec });
        await claimInvite(deps.rewards, user.id, String(b.code ?? "").trim().toLowerCase());
        return json({ ok: true });
      }
      if (b?.action !== "verify") throw new HttpError(400, "invalid_request", "unknown action");
      const rl = await enforceLimits(deps.rateLimiter, "purchase_verify", user.id, { perMinute: 20, perDay: 200, globalPerDay: 100_000 }, 1);
      if (!rl.allowed) throw new HttpError(429, "rate_limited", "För många försök just nu.", { retryAfterSec: rl.retryAfterSec });
      const t = await transaction(b.jws);
      const r = await apply(user.id, t);
      return json({ ok: true, ...r, transaction_id: t.transactionId, product_id: t.productId, ...(deps.wallet ? { wallet: await deps.wallet(user.id) } : {}) });
    } catch (e) {
      if (e instanceof Refusal) return json({ error: { code: e.code, message: e.message, fallback: false }, ...e.extra }, e.status);
      if (e instanceof RewardRefusal) return json({ error: { code: e.code, message: e.message, fallback: false } }, e.status);
      if (e instanceof SyntaxError) return errorResponse(new HttpError(400, "invalid_request", "invalid JSON"));
      return errorResponse(toHttpError(e));
    }
  };
}
