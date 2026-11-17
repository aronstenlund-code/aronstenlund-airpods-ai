/**
 * K94 tests only: a fake App Store chain (root P-384, intermediate P-384, leaf P-256, Apple's marker OIDs) made at
 * test time with WebCrypto, and JWS signed by its leaf. No key is ever stored; never used outside tests.
 */
import { INTERMEDIATE_OID, LEAF_OID } from "./jws.ts";
import { sha256Hex } from "./x509.ts";

const cat = (...a: Uint8Array[]) => {
  const out = new Uint8Array(a.reduce((n, x) => n + x.length, 0));
  let o = 0;
  for (const x of a) (out.set(x, o), o += x.length);
  return out;
};
const lenBytes = (n: number) => n < 128 ? Uint8Array.of(n) : n < 256 ? Uint8Array.of(0x81, n) : Uint8Array.of(0x82, n >> 8, n & 255);
const tlv = (tag: number, v: Uint8Array) => cat(Uint8Array.of(tag), lenBytes(v.length), v);
const seq = (...a: Uint8Array[]) => tlv(0x30, cat(...a));
const set = (...a: Uint8Array[]) => tlv(0x31, cat(...a));
const int = (v: Uint8Array) => {
  let x = v;
  while (x.length > 1 && x[0] === 0 && !(x[1] & 0x80)) x = x.subarray(1);
  return tlv(0x02, x[0] & 0x80 ? cat(Uint8Array.of(0), x) : x);
};
function oidEnc(dotted: string): Uint8Array {
  const p = dotted.split(".").map(Number);
  const out = [p[0] * 40 + p[1]];
  for (const n of p.slice(2)) {
    const bytes = [n & 0x7f];
    for (let v = Math.floor(n / 128); v > 0; v = Math.floor(v / 128)) bytes.unshift((v & 0x7f) | 0x80);
    out.push(...bytes);
  }
  return tlv(0x06, Uint8Array.from(out));
}
const utc = (ms: number) => {
  const d = new Date(ms), p = (n: number) => String(n).padStart(2, "0");
  return tlv(0x17, new TextEncoder().encode(`${p(d.getUTCFullYear() % 100)}${p(d.getUTCMonth() + 1)}${p(d.getUTCDate())}${p(d.getUTCHours())}${p(d.getUTCMinutes())}${p(d.getUTCSeconds())}Z`));
};
const name = (cn: string) => seq(set(seq(oidEnc("2.5.4.3"), tlv(0x0c, new TextEncoder().encode(cn)))));
const alg = (hash: "SHA-256" | "SHA-384") => seq(oidEnc(hash === "SHA-256" ? "1.2.840.10045.4.3.2" : "1.2.840.10045.4.3.3"));

function derSig(raw: Uint8Array): Uint8Array {
  const h = raw.length / 2;
  return seq(int(raw.subarray(0, h)), int(raw.subarray(h)));
}

interface Made { der: Uint8Array; key: CryptoKeyPair }

async function cert(o: { cn: string; issuer: string; curve: "P-256" | "P-384"; signer?: CryptoKey; hash: "SHA-256" | "SHA-384"; ext?: string; notBefore: number; notAfter: number }): Promise<Made> {
  const key = await crypto.subtle.generateKey({ name: "ECDSA", namedCurve: o.curve }, true, ["sign", "verify"]) as CryptoKeyPair;
  const spki = new Uint8Array(await crypto.subtle.exportKey("spki", key.publicKey));
  const exts = o.ext ? tlv(0xa3, seq(seq(oidEnc(o.ext), tlv(0x04, Uint8Array.of(0x05, 0x00))))) : new Uint8Array();
  const tbs = seq(tlv(0xa0, int(Uint8Array.of(2))), int(crypto.getRandomValues(new Uint8Array(8))), alg(o.hash), name(o.issuer),
    seq(utc(o.notBefore), utc(o.notAfter)), name(o.cn), spki, exts);
  const signer = o.signer ?? key.privateKey;
  const raw = new Uint8Array(await crypto.subtle.sign({ name: "ECDSA", hash: o.hash }, signer, tbs));
  return { der: seq(tbs, alg(o.hash), tlv(0x03, cat(Uint8Array.of(0), derSig(raw)))), key };
}

const b64 = (b: Uint8Array) => btoa(String.fromCharCode(...b));
const b64url = (b: Uint8Array) => b64(b).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");

export interface TestPki { rootSha: string; sign(payload: unknown, o?: { badSig?: boolean; noMarker?: boolean }): Promise<string> }

/** A fake chain valid from a year ago to a year ahead. */
export async function testPki(o: { leafExpired?: boolean } = {}): Promise<TestPki> {
  const t = Date.now(), y = 365 * 864e5;
  const root = await cert({ cn: "Test Root", issuer: "Test Root", curve: "P-384", hash: "SHA-384", notBefore: t - y, notAfter: t + 10 * y });
  const mid = await cert({ cn: "Test WWDR", issuer: "Test Root", curve: "P-384", hash: "SHA-384", signer: root.key.privateKey, ext: INTERMEDIATE_OID, notBefore: t - y, notAfter: t + 5 * y });
  const leaf = await cert({ cn: "Test Store", issuer: "Test WWDR", curve: "P-256", hash: "SHA-384", signer: mid.key.privateKey, ext: LEAF_OID, notBefore: t - y, notAfter: o.leafExpired ? t - 864e5 : t + y });
  const plain = await cert({ cn: "Test Store", issuer: "Test WWDR", curve: "P-256", hash: "SHA-384", signer: mid.key.privateKey, notBefore: t - y, notAfter: t + y });
  return {
    rootSha: await sha256Hex(root.der),
    async sign(payload, s = {}) {
      const l = s.noMarker ? plain : leaf;
      const h = b64url(new TextEncoder().encode(JSON.stringify({ alg: "ES256", x5c: [b64(l.der), b64(mid.der), b64(root.der)] })));
      const p = b64url(new TextEncoder().encode(JSON.stringify(payload)));
      const sig = new Uint8Array(await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, l.key.privateKey, new TextEncoder().encode(`${h}.${p}`)));
      if (s.badSig) sig[5] ^= 1;
      return `${h}.${p}.${b64url(sig)}`;
    },
  };
}
