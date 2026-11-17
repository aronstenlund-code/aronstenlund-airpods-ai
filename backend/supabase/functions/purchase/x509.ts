/**
 * K94 (D218): just enough DER and X.509 to verify an App Store signed transaction (JWS with an x5c chain), with
 * WebCrypto only (no third-party code, CLAUDE.md). Reads a certificate's to-be-signed part, signature algorithm,
 * signature, public key, validity and whether an extension OID is present.
 */
export interface Der { tag: number; start: number; vstart: number; end: number }

/** One DER element at `at`: tag, where its value starts and where it ends. */
export function der(b: Uint8Array, at: number): Der {
  const tag = b[at];
  let len = b[at + 1];
  let v = at + 2;
  if (len & 0x80) {
    const n = len & 0x7f;
    if (n < 1 || n > 4) throw new Error("der: bad length");
    len = 0;
    for (let i = 0; i < n; i++) len = (len << 8) | b[v + i];
    v += n;
  }
  if (v + len > b.length) throw new Error("der: truncated");
  return { tag, start: at, vstart: v, end: v + len };
}

/** The children of a constructed element. */
export function children(b: Uint8Array, e: Der): Der[] {
  const out: Der[] = [];
  for (let at = e.vstart; at < e.end;) {
    const c = der(b, at);
    out.push(c);
    at = c.end;
  }
  return out;
}

/** A dotted OID from its DER value. */
export function oid(b: Uint8Array, e: Der): string {
  const v = b.subarray(e.vstart, e.end);
  const parts = [Math.floor(v[0] / 40), v[0] % 40];
  let n = 0;
  for (let i = 1; i < v.length; i++) {
    n = n * 128 + (v[i] & 0x7f);
    if (!(v[i] & 0x80)) (parts.push(n), n = 0);
  }
  return parts.join(".");
}

export interface Cert {
  raw: Uint8Array;
  tbs: Uint8Array;
  sigAlg: string;
  sig: Uint8Array;
  spki: Uint8Array;
  curve: "P-256" | "P-384";
  notBefore: number;
  notAfter: number;
  extensions: Set<string>;
}

const CURVES: Record<string, "P-256" | "P-384"> = { "1.2.840.10045.3.1.7": "P-256", "1.3.132.0.34": "P-384" };

function time(b: Uint8Array, e: Der): number {
  const s = new TextDecoder().decode(b.subarray(e.vstart, e.end));
  const m = e.tag === 0x17
    ? /^(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})Z$/.exec(s) // UTCTime
    : /^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})Z$/.exec(s); // GeneralizedTime
  if (!m) throw new Error("x509: bad time");
  let y = Number(m[1]);
  if (e.tag === 0x17) y += y < 50 ? 2000 : 1900;
  return Date.UTC(y, Number(m[2]) - 1, Number(m[3]), Number(m[4]), Number(m[5]), Number(m[6]));
}

export function parseCert(raw: Uint8Array): Cert {
  const top = der(raw, 0);
  const [tbsE, algE, sigE] = children(raw, top);
  const f = children(raw, tbsE);
  let i = f[0].tag === 0xa0 ? 1 : 0; // version
  i += 2; // serial, signature
  i += 1; // issuer
  const validity = children(raw, f[i++]);
  i += 1; // subject
  const spkiE = f[i++];
  const spkiAlg = children(raw, children(raw, spkiE)[0]);
  const curve = CURVES[oid(raw, spkiAlg[1])];
  if (!curve) throw new Error("x509: unsupported key");
  const extensions = new Set<string>();
  for (const x of f.slice(i)) {
    if (x.tag !== 0xa3) continue;
    for (const ext of children(raw, children(raw, x)[0])) extensions.add(oid(raw, children(raw, ext)[0]));
  }
  const bits = raw.subarray(sigE.vstart + 1, sigE.end); // BIT STRING: skip the unused-bits byte
  return {
    raw, tbs: raw.subarray(tbsE.start, tbsE.end), sigAlg: oid(raw, children(raw, algE)[0]), sig: bits,
    spki: raw.subarray(spkiE.start, spkiE.end), curve, notBefore: time(raw, validity[0]), notAfter: time(raw, validity[1]), extensions,
  };
}

/** DER ECDSA-Sig-Value (SEQUENCE {r, s}) to the raw r||s WebCrypto wants. */
export function rawSig(sig: Uint8Array, size: number): Uint8Array {
  const [r, s] = children(sig, der(sig, 0));
  const out = new Uint8Array(size * 2);
  const put = (e: Der, off: number) => {
    let v = sig.subarray(e.vstart, e.end);
    while (v.length > size && v[0] === 0) v = v.subarray(1);
    if (v.length > size) throw new Error("x509: bad signature");
    out.set(v, off + size - v.length);
  };
  put(r, 0);
  put(s, size);
  return out;
}

const HASH: Record<string, string> = { "1.2.840.10045.4.3.2": "SHA-256", "1.2.840.10045.4.3.3": "SHA-384" };

/** A copy on its own ArrayBuffer (what WebCrypto's types want). */
export const own = (u: Uint8Array) => new Uint8Array(u);

export function importKey(c: Cert): Promise<CryptoKey> {
  return crypto.subtle.importKey("spki", own(c.spki), { name: "ECDSA", namedCurve: c.curve }, false, ["verify"]);
}

/** Is `child` signed by `issuer`? */
export async function signedBy(child: Cert, issuer: Cert): Promise<boolean> {
  const hash = HASH[child.sigAlg];
  if (!hash) return false;
  const size = issuer.curve === "P-384" ? 48 : 32;
  return await crypto.subtle.verify({ name: "ECDSA", hash }, await importKey(issuer), own(rawSig(child.sig, size)), own(child.tbs));
}

export async function sha256Hex(b: Uint8Array): Promise<string> {
  return [...new Uint8Array(await crypto.subtle.digest("SHA-256", own(b)))].map((x) => x.toString(16).padStart(2, "0")).join("");
}
