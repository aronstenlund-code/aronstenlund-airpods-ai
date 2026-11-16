/**
 * K81 (D204): which addresses fetch-url may ever connect to (SSRF). Only http/https on the default ports, no user
 * info, no internal names, and every address the name resolves to must be public, checked again after each redirect.
 */
export const FETCH_LIMITS = { maxBytes: 2 * 1024 * 1024, timeoutMs: 10_000, maxRedirects: 3, textChars: 40_000, urlChars: 2000 };

export class BlockedUrl extends Error {
  constructor(public reason: string) {
    super(reason);
  }
}

/** IPv4 as four numbers, or null. Only the plain dotted form (other spellings are refused before this). */
function v4(ip: string): number[] | null {
  const m = /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/.exec(ip);
  if (!m) return null;
  const n = m.slice(1).map(Number);
  return n.every((x) => x >= 0 && x <= 255) ? n : null;
}

/** A private, loopback, link-local, multicast, reserved or otherwise not public IPv4 address. */
export function privateV4(n: number[]): boolean {
  const [a, b, c] = n;
  return a === 0 || a === 10 || a === 127 || a >= 224 ||
    (a === 100 && b >= 64 && b <= 127) || // carrier-grade NAT
    (a === 169 && b === 254) || // link-local, cloud metadata (169.254.169.254)
    (a === 172 && b >= 16 && b <= 31) ||
    (a === 192 && b === 168) ||
    (a === 192 && b === 0 && (c === 0 || c === 2)) ||
    (a === 198 && (b === 18 || b === 19)) ||
    (a === 198 && b === 51 && c === 100) ||
    (a === 203 && b === 0 && c === 113);
}

/** Expands an IPv6 address to eight 16-bit groups (an embedded IPv4 tail included), or null. */
function v6groups(ip: string): number[] | null {
  let s = ip.toLowerCase().replace(/^\[|\]$/g, "").split("%")[0];
  const tail = /(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})$/.exec(s);
  if (tail) {
    const n = v4(tail[1]);
    if (!n) return null;
    s = s.slice(0, -tail[1].length) + `${((n[0] << 8) | n[1]).toString(16)}:${((n[2] << 8) | n[3]).toString(16)}`;
  }
  if (!/^[0-9a-f:]+$/.test(s) || (s.match(/::/g) ?? []).length > 1) return null;
  const [head, rest] = s.split("::");
  const h = head ? head.split(":") : [];
  const r = rest !== undefined && rest !== "" ? rest.split(":") : [];
  const fill = s.includes("::") ? 8 - h.length - r.length : 0;
  const all = [...h, ...Array(fill).fill("0"), ...r];
  if (all.length !== 8 || all.some((g) => g.length === 0 || g.length > 4)) return null;
  return all.map((g) => parseInt(g, 16));
}

export function privateV6(g: number[]): boolean {
  const zero = g.slice(0, 7).every((x) => x === 0);
  if (zero && (g[7] === 0 || g[7] === 1)) return true; // :: and ::1
  if (g.slice(0, 5).every((x) => x === 0) && (g[5] === 0xffff || g[5] === 0)) {
    // IPv4-mapped / -compatible: judge the IPv4 address
    return privateV4([g[6] >> 8, g[6] & 255, g[7] >> 8, g[7] & 255]);
  }
  if (g[0] === 0x64 && g[1] === 0xff9b) return privateV4([g[6] >> 8, g[6] & 255, g[7] >> 8, g[7] & 255]); // NAT64
  return (g[0] & 0xfe00) === 0xfc00 || // unique local fc00::/7
    (g[0] & 0xffc0) === 0xfe80 || // link-local
    (g[0] & 0xff00) === 0xff00 || // multicast
    g[0] === 0x2001 && g[1] === 0x0db8; // documentation
}

/** Is this literal address (IPv4 or IPv6) public? null when it is not an IP literal. */
export function publicIp(ip: string): boolean | null {
  const n = v4(ip);
  if (n) return !privateV4(n);
  if (ip.includes(":")) {
    const g = v6groups(ip);
    return g ? !privateV6(g) : false;
  }
  return null;
}

const INTERNAL_NAME = /(?:^|\.)(?:localhost|local|internal|intranet|lan|home|corp|localdomain|home\.arpa)$|^metadata(?:\.google\.internal)?$/i;

/** Checks the URL itself (no DNS): scheme, port, user info, host shape. Returns the parsed URL. */
export function checkUrl(raw: string, ownHosts: string[] = []): URL {
  if (raw.length > FETCH_LIMITS.urlChars) throw new BlockedUrl("url_too_long");
  let u: URL;
  try {
    u = new URL(raw.trim());
  } catch {
    throw new BlockedUrl("invalid_url");
  }
  if (u.protocol !== "http:" && u.protocol !== "https:") throw new BlockedUrl("scheme");
  if (u.username || u.password) throw new BlockedUrl("userinfo");
  if (u.port && !((u.protocol === "http:" && u.port === "80") || (u.protocol === "https:" && u.port === "443"))) throw new BlockedUrl("port");
  const host = u.hostname.replace(/^\[|\]$/g, "").replace(/\.$/, "").toLowerCase();
  if (!host || INTERNAL_NAME.test(host) || !host.includes(".") && !host.includes(":")) throw new BlockedUrl("internal_name");
  if (ownHosts.some((h) => host === h || host.endsWith(`.${h}`))) throw new BlockedUrl("own_host");
  // a numeric host that is not a plain IPv4 (2130706433, 0x7f.1, 0177.0.0.1) is refused: never guess its meaning
  if (/^[\d.x]+$/i.test(host) && !v4(host)) throw new BlockedUrl("odd_ip");
  if (v4(host) && /(^|\.)0\d/.test(host)) throw new BlockedUrl("odd_ip");
  const lit = publicIp(host);
  if (lit === false) throw new BlockedUrl("private_address");
  return u;
}

export type Resolver = (host: string) => Promise<string[]>;

/** Every address the host resolves to must be public (a literal IP was checked in checkUrl). */
export async function checkResolved(u: URL, resolve: Resolver): Promise<void> {
  const host = u.hostname.replace(/^\[|\]$/g, "");
  if (publicIp(host) !== null) return;
  let ips: string[];
  try {
    ips = await resolve(host);
  } catch {
    throw new BlockedUrl("dns_failed");
  }
  if (!ips.length) throw new BlockedUrl("dns_failed");
  for (const ip of ips) if (publicIp(ip) !== true) throw new BlockedUrl("private_address");
}

/** DNS over HTTPS (Cloudflare's JSON API): A and AAAA records. Deno.resolveDns is not in every runtime. */
export function dohResolver(fetchFn: typeof fetch = fetch): Resolver {
  return async (host) => {
    const out: string[] = [];
    for (const type of ["A", "AAAA"]) {
      const r = await fetchFn(`https://cloudflare-dns.com/dns-query?name=${encodeURIComponent(host)}&type=${type}`, {
        headers: { accept: "application/dns-json" },
        signal: AbortSignal.timeout(3000),
      });
      if (!r.ok) throw new Error(`doh ${r.status}`);
      const j = await r.json() as { Answer?: { type: number; data: string }[] };
      for (const a of j.Answer ?? []) if (a.type === 1 || a.type === 28) out.push(a.data);
    }
    return out;
  };
}
