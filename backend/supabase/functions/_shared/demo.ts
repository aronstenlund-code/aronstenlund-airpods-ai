import { HttpError } from "./errors.ts";
import type { RateLimiter } from "./ratelimit.ts";

/**
 * D62: the public demo page calls the real backend with `source: "demo"` (/answer and /tts in the body,
 * /stt-token as `?source=demo`). Demo requests are capped hard because anybody on the internet can send them:
 * per visitor and day, per network and day, and a global daily kill-switch. A visitor is the anonymous
 * Supabase user of the page (the page keeps its session in the browser); the network is a hash of the client
 * IP, so clearing the browser does not reset the allowance. Caps are fixed windows (UTC day).
 */
export interface DemoCaps {
  questionsPerVisitor: number;
  questionsPerIp: number;
  questionsGlobal: number;
  ttsCharsPerVisitor: number;
  ttsCharsPerIp: number;
  ttsCharsGlobal: number;
  sttPerVisitor: number;
  sttPerIp: number;
  sttGlobal: number;
  /** Max characters of one TTS request in the demo ("max 400 tecken röst"). */
  ttsCharsPerRequest: number;
  /** Spoken answer is cut at this many characters; the model gets a small token budget. */
  answerMaxChars: number;
  answerMaxTokens: number;
}

export const DEFAULT_DEMO_CAPS: DemoCaps = {
  questionsPerVisitor: 5,
  questionsPerIp: 20,
  questionsGlobal: 600,
  ttsCharsPerVisitor: 2000,
  ttsCharsPerIp: 8000,
  ttsCharsGlobal: 60000,
  sttPerVisitor: 8,
  sttPerIp: 30,
  sttGlobal: 400,
  ttsCharsPerRequest: 400,
  answerMaxChars: 400,
  answerMaxTokens: 160,
};

export function demoCapsFromEnv(env: { get(k: string): string | undefined }): DemoCaps {
  const n = (k: string, d: number) => {
    const v = Number(env.get(k));
    return Number.isFinite(v) && v > 0 ? Math.floor(v) : d;
  };
  const d = DEFAULT_DEMO_CAPS;
  return {
    ...d,
    questionsPerVisitor: n("DEMO_QUESTIONS_PER_VISITOR", d.questionsPerVisitor),
    questionsGlobal: n("DEMO_GLOBAL_QUESTIONS_PER_DAY", d.questionsGlobal),
    ttsCharsGlobal: n("DEMO_GLOBAL_TTS_CHARS_PER_DAY", d.ttsCharsGlobal),
    sttGlobal: n("DEMO_GLOBAL_STT_PER_DAY", d.sttGlobal),
  };
}

export const DEMO_MESSAGES = {
  visitor: (n: number) =>
    `Du har använt dagens ${n} demofrågor. Ladda ner appen eller kom tillbaka i morgon.`,
  ip:
    "Det har ställts många demofrågor från ditt nätverk i dag. Kom tillbaka i morgon eller ladda ner appen.",
  global:
    "Demon har nått dagens tak. Kom tillbaka i morgon, gå med i väntelistan eller ladda ner appen.",
  unavailable: "Det här läget finns bara i appen.",
  // D77: the speech (STT) and read-aloud (TTS) caps have their own wording; only the question cap counts questions.
  sttVisitor: (n: number) =>
    `Du har använt dagens ${n} röstfrågor i demon. Skriv frågan i stället, eller kom tillbaka i morgon.`,
  sttIp:
    "Det har talats in många frågor i demon från ditt nätverk i dag. Skriv frågan i stället, eller kom tillbaka i morgon.",
  sttGlobal:
    "Röstinmatningen i demon har nått dagens tak. Skriv frågan i stället, eller kom tillbaka i morgon.",
  ttsVisitor:
    "Du har använt dagens uppläsning i demon. Svaren visas som text, och i morgon läses de upp igen.",
  ttsIp:
    "Demon har läst upp många svar till ditt nätverk i dag. Svaren visas som text, och i morgon läses de upp igen.",
  ttsGlobal: "Uppläsningen i demon har nått dagens tak. Svaren visas som text, och i morgon läses de upp igen.",
};

/** SHA-256 of the client IP (first 16 hex chars): rate-limit keys never hold a raw address. */
export async function networkKey(req: Request): Promise<string> {
  const ip = (req.headers.get("cf-connecting-ip") ??
    req.headers.get("x-forwarded-for")?.split(",")[0] ?? req.headers.get("x-real-ip") ?? "unknown")
    .trim();
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(`lumen-demo:${ip}`));
  return [...new Uint8Array(buf)].slice(0, 8).map((b) => b.toString(16).padStart(2, "0")).join("");
}

export type DemoKind = "answer" | "tts" | "stt";

/** Throws HttpError(429, demo_limit_*) when the visitor, the network or the whole demo is out of allowance. */
export async function enforceDemo(
  rl: RateLimiter,
  kind: DemoKind,
  userId: string,
  net: string,
  caps: DemoCaps,
  cost = 1,
): Promise<void> {
  const lim = kind === "answer"
    ? [caps.questionsPerVisitor, caps.questionsPerIp, caps.questionsGlobal]
    : kind === "tts"
    ? [caps.ttsCharsPerVisitor, caps.ttsCharsPerIp, caps.ttsCharsGlobal]
    : [caps.sttPerVisitor, caps.sttPerIp, caps.sttGlobal];
  const M = DEMO_MESSAGES;
  const msg = kind === "answer"
    ? [M.visitor(caps.questionsPerVisitor), M.ip, M.global]
    : kind === "tts"
    ? [M.ttsVisitor, M.ttsIp, M.ttsGlobal]
    : [M.sttVisitor(caps.sttPerVisitor), M.sttIp, M.sttGlobal];
  const steps: [string, number, HttpError][] = [
    [`demo:${kind}:u:${userId}:d`, lim[0], new HttpError(429, "demo_limit_visitor", msg[0])],
    [`demo:${kind}:ip:${net}:d`, lim[1], new HttpError(429, "demo_limit_ip", msg[1])],
    [`demo:${kind}:global:d`, lim[2], new HttpError(429, "demo_limit_global", msg[2])],
  ];
  for (const [key, limit, err] of steps) {
    let r;
    try {
      r = await rl.check(key, limit, 86400, cost);
    } catch (e) {
      console.error("demo_limiter_error", e instanceof Error ? e.message : String(e));
      throw new HttpError(503, "demo_unavailable", "Demon är tillfälligt otillgänglig.");
    }
    if (!r.allowed) {
      throw new HttpError(err.status, err.code, err.message, { retryAfterSec: r.retryAfterSec });
    }
  }
}
