/**
 * K98 (D224): Apple App Attest. An attestation proves that a key was made by a genuine copy of the app on a real
 * Apple device (not a script or a simulator). We check, with WebCrypto only:
 *   - the CBOR object {fmt: "apple-appattest", attStmt: {x5c: [credCert, intermediate], receipt}, authData}
 *   - x5c chains to the pinned Apple App Attestation Root CA (a test root only in tests)
 *   - credCert's extension 1.2.840.113635.100.8.2 holds SHA-256(authData || SHA-256(challenge)) (our one-time challenge)
 *   - keyId = SHA-256 of credCert's public key point, and authData's credential id = keyId
 *   - authData's rpIdHash = SHA-256("<TEAMID>.<bundle id>"), counter 0, aaguid "appattest" (or "appattestdevelop" when
 *     development is allowed)
 * Note (D224): an App Attest key belongs to one install of the app, not to the phone: a reinstall makes a new key.
 * "Once per phone" across reinstalls needs Apple's DeviceCheck two bits (a key Aron makes), see the K98 report.
 */
import { children, der, own, parseCert, sha256Hex, signedBy } from "./x509.ts";

export const ATTEST_NONCE_OID = "1.2.840.113635.100.8.2";

export class InvalidAttestation extends Error {
  constructor(public reason: string) {
    super(reason);
  }
}

// ---------- a minimal CBOR decoder (maps, arrays, byte/text strings, ints) ----------
type Cbor = number | string | Uint8Array | Cbor[] | Map<string, Cbor> | boolean | null;
export function cbor(b: Uint8Array): Cbor {
  let at = 0;
  const len = (info: number): number => {
    if (info < 24) return info;
    const n = info === 24 ? 1 : info === 25 ? 2 : info === 26 ? 4 : info === 27 ? 8 : -1;
    if (n < 0) throw new InvalidAttestation("cbor");
    let v = 0;
    for (let i = 0; i < n; i++) v = v * 256 + b[at++];
    return v;
  };
  const item = (): Cbor => {
    if (at >= b.length) throw new InvalidAttestation("cbor");
    const ib = b[at++], major = ib >> 5, info = ib & 31;
    if (major === 0) return len(info);
    if (major === 1) return -1 - len(info);
    if (major === 2 || major === 3) {
      const n = len(info);
      if (at + n > b.length) throw new InvalidAttestation("cbor");
      const v = b.subarray(at, at + n);
      at += n;
      return major === 2 ? v : new TextDecoder().decode(v);
    }
    if (major === 4) {
      const n = len(info), out: Cbor[] = [];
      for (let i = 0; i < n; i++) out.push(item());
      return out;
    }
    if (major === 5) {
      const n = len(info), m = new Map<string, Cbor>();
      for (let i = 0; i < n; i++) {
        const k = item();
        m.set(String(k), item());
      }
      return m;
    }
    if (major === 7) return info === 20 ? false : info === 21 ? true : null;
    throw new InvalidAttestation("cbor");
  };
  return item();
}

const eq = (a: Uint8Array, b: Uint8Array) => a.length === b.length && a.every((x, i) => x === b[i]);
const sha256 = async (b: Uint8Array) => new Uint8Array(await crypto.subtle.digest("SHA-256", own(b)));
const cat = (a: Uint8Array, b: Uint8Array) => {
  const o = new Uint8Array(a.length + b.length);
  o.set(a);
  o.set(b, a.length);
  return o;
};

/** The EC point (65 bytes, uncompressed) of a SubjectPublicKeyInfo. */
function point(spki: Uint8Array): Uint8Array {
  const [, bits] = children(spki, der(spki, 0));
  return spki.subarray(bits.vstart + 1, bits.end);
}

/** The octet string inside the nonce extension: SEQUENCE { [1] { OCTET STRING nonce } }. */
function nonceOf(raw: Uint8Array): Uint8Array | null {
  const c = parseCert(raw);
  if (!c.extensions.has(ATTEST_NONCE_OID)) return null;
  // find the extension's value again (parseCert keeps only the OIDs)
  const top = der(raw, 0);
  const tbs = children(raw, top)[0];
  for (const f of children(raw, tbs)) {
    if (f.tag !== 0xa3) continue;
    for (const ext of children(raw, children(raw, f)[0])) {
      const parts = children(raw, ext);
      const id = raw.subarray(parts[0].vstart, parts[0].end);
      const want = Uint8Array.of(0x2a, 0x86, 0x48, 0x86, 0xf7, 0x63, 0x64, 0x08, 0x02);
      if (!eq(id, want)) continue;
      const octet = parts[parts.length - 1];
      const inner = raw.subarray(octet.vstart, octet.end); // SEQUENCE
      const seq = der(inner, 0);
      const tagged = children(inner, seq)[0]; // [1]
      const os = children(inner, tagged)[0];
      return inner.subarray(os.vstart, os.end);
    }
  }
  return null;
}

export interface AttestOptions {
  roots: string[]; // SHA-256 hex of the accepted root DER
  appId: string; // "<TEAMID>.<bundle id>"
  allowDevelopment?: boolean;
  /** the root's DER (x5c holds only the leaf and the intermediate) */
  rootDer: Uint8Array;
  at?: number;
}

/** Verifies an attestation; returns the key's public key (SPKI) for later assertions, or throws InvalidAttestation. */
export async function verifyAttestation(keyIdB64: string, attestation: Uint8Array, challenge: Uint8Array, o: AttestOptions): Promise<{ spki: Uint8Array; keyId: string }> {
  const obj = cbor(attestation);
  if (!(obj instanceof Map) || obj.get("fmt") !== "apple-appattest") throw new InvalidAttestation("format");
  const st = obj.get("attStmt"), authData = obj.get("authData");
  if (!(st instanceof Map) || !(authData instanceof Uint8Array)) throw new InvalidAttestation("format");
  const x5c = st.get("x5c");
  if (!Array.isArray(x5c) || x5c.length < 2 || !x5c.every((c) => c instanceof Uint8Array)) throw new InvalidAttestation("chain");
  if (!o.roots.includes(await sha256Hex(o.rootDer))) throw new InvalidAttestation("root");
  let leaf, mid, root;
  try {
    [leaf, mid, root] = [parseCert(x5c[0] as Uint8Array), parseCert(x5c[1] as Uint8Array), parseCert(o.rootDer)];
  } catch {
    throw new InvalidAttestation("chain");
  }
  const at = o.at ?? Date.now();
  for (const c of [leaf, mid, root]) if (at < c.notBefore || at > c.notAfter) throw new InvalidAttestation("expired");
  if (!(await signedBy(leaf, mid)) || !(await signedBy(mid, root))) throw new InvalidAttestation("chain");
  // the nonce binds our challenge to this key
  const nonce = await sha256(cat(authData, await sha256(challenge)));
  const got = nonceOf(x5c[0] as Uint8Array);
  if (!got || !eq(got, nonce)) throw new InvalidAttestation("nonce");
  // the key id is the hash of the key
  const keyId = await sha256(point(leaf.spki));
  const asked = Uint8Array.from(atob(keyIdB64), (c) => c.charCodeAt(0));
  if (!eq(keyId, asked)) throw new InvalidAttestation("key");
  // authData: rpIdHash(32) flags(1) counter(4) aaguid(16) credIdLen(2) credId
  if (authData.length < 55) throw new InvalidAttestation("auth_data");
  if (!eq(authData.subarray(0, 32), await sha256(new TextEncoder().encode(o.appId)))) throw new InvalidAttestation("app");
  const counter = new DataView(authData.buffer, authData.byteOffset + 33, 4).getUint32(0);
  if (counter !== 0) throw new InvalidAttestation("counter");
  const aaguid = new TextDecoder().decode(authData.subarray(37, 53)).replace(/\0+$/, "");
  if (aaguid !== "appattest" && !(o.allowDevelopment && aaguid === "appattestdevelop")) throw new InvalidAttestation("environment");
  const n = (authData[53] << 8) | authData[54];
  if (!eq(authData.subarray(55, 55 + n), keyId)) throw new InvalidAttestation("key");
  return { spki: leaf.spki, keyId: keyIdB64 };
}
