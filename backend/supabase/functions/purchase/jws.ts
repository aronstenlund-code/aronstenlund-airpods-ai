/**
 * K94 (D218): verify an App Store signed object (StoreKit 2 transaction, renewal info, or App Store Server
 * Notification v2): ES256 JWS with the chain in `x5c` = [leaf, intermediate, root]. The root must be the pinned
 * Apple Root CA - G3 (by SHA-256 of its DER; a test root only in tests), the leaf and intermediate must carry Apple's
 * marker OIDs, every certificate must be valid at the signing time, and the JWS must be signed by the leaf.
 */
import { importKey, own, parseCert, sha256Hex, signedBy } from "./x509.ts";

/** Apple Root CA - G3, SHA-256 of the DER (https://www.apple.com/certificateauthority/). */
export const APPLE_ROOT_G3_SHA256 = "63343abfb89a6a03ebb57e9b3f5fa7be7c4f5c756f3017b3a8c488c3653e9179";
/** App Store receipt signing (leaf) and Apple Worldwide Developer Relations G6 (intermediate). */
export const LEAF_OID = "1.2.840.113635.100.6.11.1";
export const INTERMEDIATE_OID = "1.2.840.113635.100.6.2.1";

export class InvalidJws extends Error {
  constructor(public reason: string) {
    super(reason);
  }
}

export const b64url = (s: string) => Uint8Array.from(atob(s.replace(/-/g, "+").replace(/_/g, "/") + "=".repeat((4 - (s.length % 4)) % 4)), (c) => c.charCodeAt(0));
const b64 = (s: string) => Uint8Array.from(atob(s), (c) => c.charCodeAt(0));

export interface VerifyOptions {
  /** SHA-256 hex of the accepted root DER (production: APPLE_ROOT_G3_SHA256 only). */
  roots: string[];
  /** when the chain must be valid (ms); default: the payload's signedDate, else now */
  at?: number;
}

/** The payload of a verified JWS, or throws InvalidJws. */
export async function verifyJws<T = Record<string, unknown>>(jws: string, o: VerifyOptions): Promise<T> {
  const parts = typeof jws === "string" ? jws.split(".") : [];
  if (parts.length !== 3) throw new InvalidJws("format");
  let header: { alg?: string; x5c?: string[] }, payload: Record<string, unknown>;
  try {
    header = JSON.parse(new TextDecoder().decode(b64url(parts[0])));
    payload = JSON.parse(new TextDecoder().decode(b64url(parts[1])));
  } catch {
    throw new InvalidJws("format");
  }
  if (header.alg !== "ES256") throw new InvalidJws("alg");
  if (!Array.isArray(header.x5c) || header.x5c.length !== 3) throw new InvalidJws("chain");
  let leaf, mid, root;
  try {
    [leaf, mid, root] = header.x5c.map((c) => parseCert(b64(c)));
  } catch {
    throw new InvalidJws("chain");
  }
  if (!o.roots.includes(await sha256Hex(root.raw))) throw new InvalidJws("root");
  if (!leaf.extensions.has(LEAF_OID) || !mid.extensions.has(INTERMEDIATE_OID)) throw new InvalidJws("marker");
  const at = o.at ?? (typeof payload.signedDate === "number" ? payload.signedDate : Date.now());
  for (const c of [leaf, mid, root]) if (at < c.notBefore || at > c.notAfter) throw new InvalidJws("expired");
  if (!(await signedBy(leaf, mid)) || !(await signedBy(mid, root)) || !(await signedBy(root, root))) throw new InvalidJws("chain");
  if (leaf.curve !== "P-256") throw new InvalidJws("alg");
  const ok = await crypto.subtle.verify({ name: "ECDSA", hash: "SHA-256" }, await importKey(leaf), own(b64url(parts[2])), new TextEncoder().encode(`${parts[0]}.${parts[1]}`));
  if (!ok) throw new InvalidJws("signature");
  return payload as T;
}

/** StoreKit 2 JWSTransactionDecodedPayload (the fields we use). */
export interface Transaction {
  transactionId: string;
  originalTransactionId: string;
  bundleId: string;
  productId: string;
  purchaseDate: number;
  expiresDate?: number;
  revocationDate?: number;
  type: string;
  environment?: string;
  appAccountToken?: string;
  quantity?: number;
  signedDate?: number;
}
