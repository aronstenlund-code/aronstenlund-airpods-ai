/**
 * K36 (D122): connection tokens are encrypted with AES-GCM before they are stored, with the key CONNECTIONS_KEY
 * (a Supabase function secret, 32 random bytes as base64; never in the app or the repo). The OAuth `state` is signed
 * with an HMAC derived from the same key, so a callback cannot be forged for another user.
 */
import { secret } from "./secrets.ts";

const te = new TextEncoder(), td = new TextDecoder();

export function b64(bytes: Uint8Array): string {
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s);
}
export function unb64(s: string): Uint8Array<ArrayBuffer> {
  const bin = atob(s);
  const out = new Uint8Array(new ArrayBuffer(bin.length));
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}
const b64url = (bytes: Uint8Array) => b64(bytes).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
const unb64url = (s: string) => unb64(s.replace(/-/g, "+").replace(/_/g, "/") + "===".slice((s.length + 3) % 4));

export class TokenCrypto {
  private constructor(private aes: CryptoKey, private hmac: CryptoKey) {}

  static async fromBase64(key: string | undefined): Promise<TokenCrypto> {
    const raw = key ? unb64(key.trim()) : new Uint8Array(new ArrayBuffer(0));
    if (raw.length !== 32) throw new Error("CONNECTIONS_KEY must be 32 bytes as base64");
    const aes = await crypto.subtle.importKey("raw", raw, "AES-GCM", false, ["encrypt", "decrypt"]);
    const mac = new Uint8Array(await crypto.subtle.digest("SHA-256", new Uint8Array([...raw, ...te.encode("lumen-oauth-state")])));
    const hmac = await crypto.subtle.importKey("raw", mac, { name: "HMAC", hash: "SHA-256" }, false, ["sign", "verify"]);
    return new TokenCrypto(aes, hmac);
  }

  /**
   * CONNECTIONS_KEY when it is set; otherwise a key derived (SHA-256 with a fixed label) from the service role key,
   * which every Edge Function already has. Then no new secret is needed, but rotating the service role key makes the
   * stored tokens unreadable (the users connect again), so a separate CONNECTIONS_KEY is better once there are users.
   */
  static async fromEnv(env: { get(k: string): string | undefined }): Promise<TokenCrypto | null> {
    const own = secret(env, "CONNECTIONS_KEY");
    if (own) return await TokenCrypto.fromBase64(own);
    const svc = secret(env, "SUPABASE_SERVICE_ROLE_KEY");
    if (!svc) return null;
    const d = new Uint8Array(await crypto.subtle.digest("SHA-256", te.encode(`lumen-connections-v1|${svc}`)));
    return await TokenCrypto.fromBase64(b64(d));
  }

  /** "v1.<iv>.<ciphertext>" (base64); a fresh 12-byte IV every time. */
  async seal(plain: string): Promise<string> {
    const iv = crypto.getRandomValues(new Uint8Array(12));
    const ct = new Uint8Array(await crypto.subtle.encrypt({ name: "AES-GCM", iv }, this.aes, te.encode(plain)));
    return `v1.${b64(iv)}.${b64(ct)}`;
  }

  async open(sealed: string): Promise<string> {
    const [v, iv, ct] = sealed.split(".");
    if (v !== "v1" || !iv || !ct) throw new Error("bad sealed token");
    return td.decode(await crypto.subtle.decrypt({ name: "AES-GCM", iv: unb64(iv) }, this.aes, unb64(ct)));
  }

  /** A signed, expiring state for an OAuth round: "<payload>.<mac>" (base64url). */
  async signState(payload: Record<string, unknown>): Promise<string> {
    const p = b64url(te.encode(JSON.stringify(payload)));
    const mac = new Uint8Array(await crypto.subtle.sign("HMAC", this.hmac, te.encode(p)));
    return `${p}.${b64url(mac)}`;
  }

  /** The payload, or null when the signature is wrong or `exp` (ms) has passed. */
  async verifyState(state: string, now = Date.now()): Promise<Record<string, unknown> | null> {
    const [p, mac] = state.split(".");
    if (!p || !mac) return null;
    let ok = false;
    try {
      ok = await crypto.subtle.verify("HMAC", this.hmac, unb64url(mac), te.encode(p));
    } catch {
      return null;
    }
    if (!ok) return null;
    try {
      const j = JSON.parse(td.decode(unb64url(p)));
      return typeof j?.exp === "number" && j.exp > now ? j : null;
    } catch {
      return null;
    }
  }
}
