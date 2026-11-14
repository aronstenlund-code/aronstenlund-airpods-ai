import { AsyncLocalStorage } from "node:async_hooks";

/**
 * K62b (D180, owner): testing never uses ElevenLabs credits. The server recognises test traffic and answers with
 * fake audio and a fake transcript instead of calling ElevenLabs; a guard throws (and logs) if a test request still
 * reaches the ElevenLabs client.
 *
 * A request is a test when ANY of these holds (being marked as a test only takes something away: fake audio):
 *  - header           `x-earmind-test` (any value): the app's UI tests, Toby's and Oscar's tools
 *  - account          the JWT says `app_metadata.test` or `user_metadata.test` is true (set once an account is seen as
 *                     a test, see registerTest, so it stays a test also from another network)
 *  - script           the user agent is a script or a headless browser (python, curl, deno, node, Go, Java,
 *                     HeadlessChrome, Playwright ...) or missing: every account our scripts create
 *  - ci               the caller's IP is in GitHub's published Actions ranges (api.github.com/meta): CI, the nightly
 *                     eval and Toby's simulator runs
 * The owner (Aron, signed in by email) is never a test unless the header says so.
 */
export interface TestInfo {
  test: boolean;
  reason: "header" | "account" | "script" | "ci" | null;
  userId: string | null;
  /**
   * K64 (Oscar O61): `x-earmind-test: unavailable` = the fake audio behaves as if ElevenLabs had no credits
   * (files fail with audio_unavailable, /tts answers 503); `x-earmind-test: slow` = drill files stay pending.
   */
  mode?: "unavailable" | "slow" | null;
}
export function testMode(v: string | null): "unavailable" | "slow" | null {
  const t = (v ?? "").toLowerCase();
  return /\bunavailable\b/.test(t) ? "unavailable" : /\bslow\b/.test(t) ? "slow" : null;
}

const als = new AsyncLocalStorage<TestInfo>();
export const currentTest = (): TestInfo | undefined => als.getStore();
export function runWithTest<T>(info: TestInfo, f: () => T): T {
  return als.run(info, f);
}

export const SCRIPT_UA =
  /^(?:python|curl|wget|deno|node|undici|axios|go-http-client|okhttp|java|apache-httpclient|libwww|httpie|aiohttp|postmanruntime|insomnia|playwright|ruby|php|powershell|dart)|headlesschrome|playwright|puppeteer|\bbot\b|\bspider\b/i;

/** The JWT payload without verifying it: used only to decide fake audio, never for access. */
export function jwtClaims(req: Request): Record<string, unknown> | null {
  const m = /^Bearer\s+([^.\s]+)\.([^.\s]+)\./i.exec(req.headers.get("authorization") ?? "");
  if (!m) return null;
  try {
    const b = m[2].replace(/-/g, "+").replace(/_/g, "/");
    return JSON.parse(new TextDecoder().decode(Uint8Array.from(atob(b + "=".repeat((4 - b.length % 4) % 4)), (c) => c.charCodeAt(0))));
  } catch {
    return null;
  }
}

export function clientIp(req: Request): string {
  return (req.headers.get("cf-connecting-ip") ?? req.headers.get("x-forwarded-for")?.split(",")[0] ?? req.headers.get("x-real-ip") ?? "").trim();
}

// ---------- GitHub Actions ranges ----------
type Range = { v6: boolean; base: bigint; mask: bigint };
let ranges: Range[] = [];
let rangesAt = 0;
let loading: Promise<void> | null = null;

function ipToBig(ip: string): { v6: boolean; n: bigint } | null {
  if (/^\d+\.\d+\.\d+\.\d+$/.test(ip)) {
    const p = ip.split(".").map(Number);
    if (p.some((x) => x > 255)) return null;
    return { v6: false, n: BigInt(((p[0] << 24) >>> 0) + (p[1] << 16) + (p[2] << 8) + p[3]) };
  }
  if (!ip.includes(":")) return null;
  const [head, tail] = ip.split("::");
  const h = head ? head.split(":") : [];
  const t = tail !== undefined ? (tail ? tail.split(":") : []) : [];
  const parts = tail !== undefined ? [...h, ...Array(8 - h.length - t.length).fill("0"), ...t] : h;
  if (parts.length !== 8) return null;
  let n = 0n;
  for (const x of parts) n = (n << 16n) + BigInt(parseInt(x || "0", 16));
  return { v6: true, n };
}

export function parseRanges(cidrs: string[]): Range[] {
  const out: Range[] = [];
  for (const c of cidrs) {
    const [ip, len] = c.split("/");
    const a = ipToBig(ip);
    if (!a) continue;
    const bits = a.v6 ? 128n : 32n;
    const l = BigInt(Number(len));
    const mask = ((1n << bits) - 1n) ^ ((1n << (bits - l)) - 1n);
    out.push({ v6: a.v6, base: a.n & mask, mask });
  }
  return out;
}

export function inRanges(ip: string, rs: Range[]): boolean {
  const a = ipToBig(ip.replace(/^::ffff:/, ""));
  if (!a) return false;
  return rs.some((r) => r.v6 === a.v6 && (a.n & r.mask) === r.base);
}

/** Loads GitHub's Actions ranges (cached 12 h per isolate; a failure keeps the old list and the other rules). */
export function loadCiRanges(fetchFn: typeof fetch = fetch): Promise<void> {
  if (ranges.length && Date.now() - rangesAt < 12 * 3600_000) return Promise.resolve();
  loading ??= (async () => {
    try {
      const r = await fetchFn("https://api.github.com/meta", { headers: { accept: "application/json", "user-agent": "earmind-server" }, signal: AbortSignal.timeout(2500) });
      if (r.ok) {
        const j = await r.json() as Record<string, unknown>;
        const cidrs = Object.entries(j).filter(([k]) => k.startsWith("actions")).flatMap(([, v]) => Array.isArray(v) ? v as string[] : []);
        if (cidrs.length) {
          ranges = parseRanges(cidrs);
          rangesAt = Date.now();
        }
      } else console.warn("ci_ranges_failed", r.status);
    } catch (e) {
      console.warn("ci_ranges_failed", e instanceof Error ? e.message.slice(0, 80) : String(e));
    } finally {
      loading = null;
    }
  })();
  return loading;
}
export function setCiRangesForTest(cidrs: string[]) {
  ranges = parseRanges(cidrs);
  rangesAt = Date.now();
}

export function isOwnerClaims(c: Record<string, unknown> | null, ownerEmails: string[]): boolean {
  const email = typeof c?.email === "string" ? c.email.toLowerCase() : "";
  const amr = Array.isArray(c?.amr) ? (c!.amr as { method?: string }[]).map((a) => a?.method) : [];
  return !!email && amr.some((m) => m === "otp" || m === "magiclink") &&
    ownerEmails.map((e) => e.trim().toLowerCase()).filter(Boolean).includes(email);
}

/** Is this request test traffic? (sync after loadCiRanges) */
export function detectTest(req: Request, ownerEmails: string[] = []): TestInfo {
  const c = jwtClaims(req);
  const userId = typeof c?.sub === "string" ? c.sub : null;
  if (req.headers.has("x-earmind-test")) return { test: true, reason: "header", userId, mode: testMode(req.headers.get("x-earmind-test")) };
  if (isOwnerClaims(c, ownerEmails)) return { test: false, reason: null, userId };
  const meta = (k: string) => (c?.[k] as Record<string, unknown> | undefined)?.test === true;
  if (meta("app_metadata") || meta("user_metadata")) return { test: true, reason: "account", userId };
  const ua = req.headers.get("user-agent") ?? "";
  if (!ua.trim() || SCRIPT_UA.test(ua)) return { test: true, reason: "script", userId };
  const ip = clientIp(req);
  if (ip && inRanges(ip, ranges)) return { test: true, reason: "ci", userId };
  return { test: false, reason: null, userId };
}

// ---------- registering test accounts ----------
const registered = new Set<string>();
/**
 * Records a test account once per isolate: a row in public.test_accounts (who, why, first seen) and
 * app_metadata.test = true, so its next JWT says "test" from any network. Best effort, never blocks the answer.
 */
export function registerTest(info: TestInfo, fn: string, env = Deno.env, fetchFn: typeof fetch = fetch): Promise<void> {
  if (!info.test || !info.userId || registered.has(info.userId)) return Promise.resolve();
  registered.add(info.userId);
  const base = (env.get("SUPABASE_URL") ?? "").replace(/\/+$/, "");
  const key = env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!base || !key) return Promise.resolve();
  const h = { apikey: key, authorization: `Bearer ${key}`, "content-type": "application/json" };
  return Promise.all([
    fetchFn(`${base}/rest/v1/test_accounts?on_conflict=user_id`, {
      method: "POST",
      headers: { ...h, prefer: "resolution=ignore-duplicates,return=minimal" },
      body: JSON.stringify({ user_id: info.userId, reason: info.reason, first_fn: fn }),
    }).then((r) => r.body?.cancel()),
    info.reason === "account" ? Promise.resolve() : fetchFn(`${base}/auth/v1/admin/users/${encodeURIComponent(info.userId)}`, {
      method: "PUT",
      headers: h,
      body: JSON.stringify({ app_metadata: { test: true } }),
    }).then((r) => r.body?.cancel()),
  ]).then(() => {}).catch((e) => console.warn("test_register_failed", e instanceof Error ? e.message.slice(0, 80) : String(e)));
}

// ---------- the guard ----------
export class TestCreditsError extends Error {
  constructor(where: string) {
    super(`D180: a test request reached ElevenLabs (${where})`);
  }
}
/** Throws (and logs) when the current request is a test and the call goes to ElevenLabs. */
export function assertNotTest(where: string, url = "") {
  const t = currentTest();
  if (t?.test && (!url || /elevenlabs/i.test(url))) {
    console.error("elevenlabs_blocked_test", JSON.stringify({ where, reason: t.reason, user: t.userId }));
    throw new TestCreditsError(where);
  }
}
/** A fetch that refuses ElevenLabs for test requests (the K62b guard). */
export function guardedFetch(fetchFn: typeof fetch = fetch, where = "fetch"): typeof fetch {
  return (async (input: Request | URL | string, init?: RequestInit) => {
    const url = typeof input === "string" ? input : input instanceof URL ? input.href : input.url;
    assertNotTest(where, url);
    return await fetchFn(input, init);
  }) as typeof fetch;
}

// ---------- fake media ----------
/** A silent MPEG-1 Layer III file (44.1 kHz, 128 kbit/s, mono-compatible), `seconds` long (max 10 s). */
export function silentMp3(seconds = 1): Uint8Array<ArrayBuffer> {
  const frames = Math.max(1, Math.min(390, Math.round(seconds / 0.026122)));
  const frame = new Uint8Array(417);
  frame.set([0xff, 0xfb, 0x90, 0x64]);
  const out = new Uint8Array(new ArrayBuffer(frames * frame.length));
  for (let i = 0; i < frames; i++) out.set(frame, i * frame.length);
  return out;
}
export const FAKE_TRANSCRIPT = "Det här är en testtranskription.";
export const TEST_VOICE_ID = "earmind-test-silent";

/**
 * Wraps a handler: decides test or not, registers a test account, runs the handler inside the test context (so the
 * guard sees it), and lets `fake` answer test requests directly (no ElevenLabs).
 */
export function withTestMode(
  fn: string,
  handler: (req: Request) => Promise<Response>,
  opts: { fake?: (req: Request, info: TestInfo) => Promise<Response | null> | Response | null; ownerEmails?: string[] } = {},
): (req: Request) => Promise<Response> {
  return async (req) => {
    if (req.method === "OPTIONS") return handler(req);
    await loadCiRanges();
    const info = detectTest(req, opts.ownerEmails ?? (Deno.env.get("OWNER_EMAIL") ?? "").split(","));
    if (info.test) {
      console.log("test_request", JSON.stringify({ fn, reason: info.reason, user: info.userId }));
      const rt = (globalThis as { EdgeRuntime?: { waitUntil?: (p: Promise<unknown>) => void } }).EdgeRuntime;
      const p = registerTest(info, fn);
      rt?.waitUntil ? rt.waitUntil(p) : void p;
      const f = opts.fake ? await opts.fake(req, info) : null;
      if (f) return f;
    }
    return runWithTest(info, () => handler(req));
  };
}
