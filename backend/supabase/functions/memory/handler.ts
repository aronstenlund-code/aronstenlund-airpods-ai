import { type Authenticator } from "../_shared/auth.ts";
import { CORS_HEADERS, errorResponse, HttpError, toHttpError } from "../_shared/errors.ts";
import { appChecks, enforceLimits, type Limits, type RateLimiter } from "../_shared/ratelimit.ts";
import { networkKey } from "../_shared/demo.ts";
import { readLimitedJson } from "../answer/validate.ts";
import { nowContext } from "../answer/datecalc.ts";
import { sanitizeTagged } from "../answer/prompt.ts";
import type { LLMProvider } from "../answer/llm/types.ts";

/**
 * D80 (owner): `POST /memory` - memory extraction outside the answer path. The app sends one turn (the
 * wearer's own words and, optionally, the answer) plus the memory it already has; the reply lists new or
 * changed facts about the wearer (tests, dates as absolute dates, subjects, wishes, rules). Never sensitive
 * categories. Nothing is stored or logged: the text is processed and dropped (usage keeps metadata only).
 *
 * Request:  {"turn": {"q": "...", "a": "..."?}, "memories": ["..."]?, "language": "sv"|"en"?}
 * Response: {"add": ["..."], "update": [{"old": "...", "new": "..."}], "remove": ["..."], "skipped"?: "no_self_reference"}
 */
export const MEMORY_LIMITS = { bodyBytes: 16_384, q: 1000, a: 2000, memories: 30, memory: 200, items: 5 };

export interface MemoryConfig {
  limits: Limits;
  networkPerDay: number;
  model?: string;
  priceInPerMTok: number;
  priceOutPerMTok: number;
}
export const DEFAULT_MEMORY_CONFIG: MemoryConfig = {
  limits: { perMinute: 10, perDay: 300, globalPerDay: 10000 },
  networkPerDay: 3000,
  priceInPerMTok: 0.10,
  priceOutPerMTok: 0.50,
};

export interface MemoryDeps {
  authenticate: Authenticator;
  rateLimiter: RateLimiter;
  provider: LLMProvider | null;
  config?: MemoryConfig;
  /** Metadata only (no text). */
  recordUsage?: (rec: Record<string, unknown>) => void | Promise<void>;
  now?: () => Date;
}

export interface MemoryResult {
  add: string[];
  update: { old: string; new: string }[];
  remove: string[];
}

/** Words that show the wearer speaks about themselves; without one the model is not called at all. */
const SELF =
  /(?<!\p{L})(jag|mig|min|mitt|mina|vi|oss|vår|vårt|våra|me|my|mine|we|our|alltid|aldrig|i fortsättningen|från och med nu|framöver|kortare|längre)(?!\p{L})/iu;

/** Never kept even if the model returns it (GDPR art. 9 categories and similar). */
const SENSITIVE =
  /allerg|sjuk|diagnos|adhd|autism|diabet|astma|depress|ångest|medicin|gravid|psyk|terapi|religi|kristen|muslim|jude|judisk|ateist|politi|parti|röstar|sexuell|homosex|bisex|transperson|etnisk|ursprung|fackförening|brott|dömd|polisanmäl|biometri|health|religion|sexual|ethnic/iu;

export const SYSTEM_PROMPT_MEMORY =
  `You keep a short memory about the wearer of a study assistant (a student in Sweden). You get <now> (the current date in Sweden), <memories> (what is already remembered) and <turn> (<q> = what the wearer just said, <a> = the assistant's answer, context only).

Return ONLY a JSON object: {"add": [...], "update": [{"old": "...", "new": "..."}], "remove": [...]}.
- add: new, important facts the wearer said about THEMSELVES in <q>: tests and deadlines, subjects and courses, level, goals, standing wishes for how answers should be ("svara kortare", "förklara med exempel"), rules ("fråga mig alltid en kontrollfråga"). One short Swedish sentence each, third person about the wearer, no name needed ("Har prov i kemi fredag 13 november 2026.").
- Dates are always absolute: turn "på fredag", "nästa vecka", "imorgon" into weekday, day, month and year from <now>.
- update: a fact in <memories> that the wearer changed (old = the exact memory text, new = the new sentence). remove: a memory the wearer said is no longer true (exact text).
- Never: facts about other people, small talk, one-off questions ("vad är fotosyntes" is not a fact about the wearer), guesses, anything already in <memories>, and never sensitive categories (health, allergies, diagnoses, religion, politics, sexuality, ethnicity, union membership, crime).
- At most ${MEMORY_LIMITS.items} items in total, each at most 160 characters. Nothing worth keeping: {"add": [], "update": [], "remove": []}.`;

function clean(s: unknown, max: number): string | null {
  if (typeof s !== "string") return null;
  const t = s.replace(/[\u0000-\u001f]/g, " ").replace(/\s+/g, " ").trim();
  return t && t.length <= max ? t : null;
}

export function validateMemoryRequest(raw: unknown): { q: string; a: string; memories: string[]; language: string } {
  const b = raw as Record<string, unknown> | null;
  const turn = b?.turn as Record<string, unknown> | undefined;
  const q = clean(turn?.q, MEMORY_LIMITS.q);
  if (!q) throw new HttpError(400, "invalid_request", `turn.q is required (max ${MEMORY_LIMITS.q} characters)`);
  const a = turn?.a === undefined || turn?.a === null ? "" : clean(turn.a, MEMORY_LIMITS.a);
  if (a === null) throw new HttpError(400, "invalid_request", `turn.a is at most ${MEMORY_LIMITS.a} characters`);
  const mem = b?.memories ?? [];
  if (!Array.isArray(mem) || mem.length > MEMORY_LIMITS.memories) {
    throw new HttpError(400, "invalid_request", `memories: at most ${MEMORY_LIMITS.memories} strings`);
  }
  const memories = mem.map((m) => clean(m, MEMORY_LIMITS.memory));
  if (memories.some((m) => m === null)) {
    throw new HttpError(400, "invalid_request", `each memory is 1-${MEMORY_LIMITS.memory} characters`);
  }
  return { q, a, memories: memories as string[], language: b?.language === "en" ? "en" : "sv" };
}

/** Parses the model's JSON; drops anything malformed, too long, sensitive, duplicate or not in memory. */
export function parseMemoryReply(text: string, memories: string[]): MemoryResult {
  const out: MemoryResult = { add: [], update: [], remove: [] };
  const m = /\{[\s\S]*\}/.exec(text);
  if (!m) return out;
  let j: Record<string, unknown>;
  try {
    j = JSON.parse(m[0]);
  } catch {
    return out;
  }
  const known = new Set(memories.map((x) => x.toLowerCase()));
  const ok = (s: unknown) => {
    const t = clean(s, 160);
    return t && !SENSITIVE.test(t) ? t : null;
  };
  let n = 0;
  for (const s of Array.isArray(j.add) ? j.add : []) {
    const t = ok(s);
    if (t && !known.has(t.toLowerCase()) && n < MEMORY_LIMITS.items) {
      out.add.push(t);
      known.add(t.toLowerCase());
      n++;
    }
  }
  for (const u of Array.isArray(j.update) ? j.update : []) {
    const old = clean((u as Record<string, unknown>)?.old, MEMORY_LIMITS.memory);
    const nw = ok((u as Record<string, unknown>)?.new);
    if (old && nw && memories.includes(old) && n < MEMORY_LIMITS.items) {
      out.update.push({ old, new: nw });
      n++;
    }
  }
  for (const s of Array.isArray(j.remove) ? j.remove : []) {
    const t = clean(s, MEMORY_LIMITS.memory);
    if (t && memories.includes(t) && n < MEMORY_LIMITS.items) {
      out.remove.push(t);
      n++;
    }
  }
  return out;
}

export function createMemoryHandler(deps: MemoryDeps) {
  const cfg = deps.config ?? DEFAULT_MEMORY_CONFIG;
  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), {
      status,
      headers: { "content-type": "application/json", "cache-control": "no-store", ...CORS_HEADERS },
    });
  return async (req: Request): Promise<Response> => {
    if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS_HEADERS });
    const t0 = Date.now();
    try {
      if (req.method !== "POST") throw new HttpError(405, "method_not_allowed", "Use POST");
      const user = await deps.authenticate(req);
      const body = validateMemoryRequest(await readLimitedJson(req, MEMORY_LIMITS.bodyBytes));
      if (!SELF.test(body.q)) {
        // nothing about the wearer: no model call, no cost
        return json({ add: [], update: [], remove: [], skipped: "no_self_reference" });
      }
      const extra = appChecks("memory", await networkKey(req), user, {
        networkPerDay: cfg.networkPerDay,
        newUserAgeSec: 0,
        newUserPerHour: 0,
      });
      const rl = await enforceLimits(deps.rateLimiter, "memory", user.id, cfg.limits, 1, extra);
      if (!rl.allowed) {
        throw new HttpError(429, "rate_limited", "Too many requests", { retryAfterSec: rl.retryAfterSec });
      }
      if (!deps.provider) throw new HttpError(503, "provider_unconfigured", "LLM provider not configured");
      const now = (deps.now ?? (() => new Date()))();
      const mem = body.memories.length
        ? body.memories.map((m) => `- ${sanitizeTagged(m)}`).join("\n")
        : "(tomt)";
      const user_ = `<now>${nowContext(now)}</now>\n<memories>\n${mem}\n</memories>\n<turn>\n<q>${
        sanitizeTagged(body.q)
      }</q>\n<a>${sanitizeTagged(body.a)}</a>\n</turn>`;
      let text = "";
      let inTok = 0, outTok = 0;
      const ac = new AbortController();
      req.signal?.addEventListener("abort", () => ac.abort());
      for await (
        const c of deps.provider.stream({
          system: SYSTEM_PROMPT_MEMORY,
          user: user_,
          maxTokens: 220,
          cacheSystem: true,
          model: cfg.model,
          signal: ac.signal,
        })
      ) {
        if (c.type === "text") text += c.text;
        else {
          inTok = c.inputTokens ?? inTok;
          outTok = c.outputTokens ?? outTok;
        }
      }
      const result = parseMemoryReply(text, body.memories);
      const cost = (inTok * cfg.priceInPerMTok + outTok * cfg.priceOutPerMTok) / 1e6;
      try {
        await deps.recordUsage?.({
          user_id: user.id,
          endpoint: "memory",
          language: body.language,
          provider: deps.provider.name,
          model: cfg.model ?? deps.provider.model,
          input_tokens: inTok,
          output_tokens: outTok,
          total_ms: Date.now() - t0,
          est_cost_usd: cost,
          status: "ok",
        });
      } catch (e) {
        console.error("usage_log_failed", e instanceof Error ? e.message : String(e));
      }
      return json({ ...result, usage: { input_tokens: inTok, output_tokens: outTok, est_cost_usd: cost } });
    } catch (e) {
      return errorResponse(toHttpError(e));
    }
  };
}
