import { type Authenticator } from "../_shared/auth.ts";
import { CORS_HEADERS, errorResponse, HttpError, toHttpError } from "../_shared/errors.ts";
import { appChecks, enforceLimits, type Limits, type RateLimiter } from "../_shared/ratelimit.ts";
import { networkKey } from "../_shared/demo.ts";
import { readLimitedJson } from "../answer/validate.ts";
import { sanitizeTagged } from "../answer/prompt.ts";
import type { LLMProvider } from "../answer/llm/types.ts";

/**
 * D81 (owner): `POST /study-cards` - study cards from a Provläge session. The app sends the session summary
 * (and optionally the Provläge profile); the reply is question cards and a five-question test with answers.
 * Haiku, short JSON. Nothing is stored or logged: only a metadata row in `answer_usage`.
 *
 * Request:  {"summary": "...", "profile"?: "...", "cards"?: 3-12, "language"?: "sv"|"en"}
 * Response: {"cards": [{"q","a"}], "test": [{"q","a"}] (5), "usage": {...}}
 */
export const CARD_LIMITS = { bodyBytes: 32_768, summary: 6000, profile: 2000, q: 200, a: 400 };

export interface CardsConfig {
  limits: Limits;
  networkPerDay: number;
  model?: string;
  priceInPerMTok: number;
  priceOutPerMTok: number;
}
export const DEFAULT_CARDS_CONFIG: CardsConfig = {
  limits: { perMinute: 4, perDay: 40, globalPerDay: 3000 },
  networkPerDay: 600,
  priceInPerMTok: 0.10,
  priceOutPerMTok: 0.50,
};

export interface CardsDeps {
  authenticate: Authenticator;
  rateLimiter: RateLimiter;
  provider: LLMProvider | null;
  config?: CardsConfig;
  recordUsage?: (rec: Record<string, unknown>) => void | Promise<void>;
}

export interface Card {
  q: string;
  a: string;
}

export const SYSTEM_PROMPT_CARDS =
  `You make study material for a student in Sweden from a summary of a study session. You get <summary> (what was studied: questions, answers and explanations), <profile> (optional: exam date, grade, course, subject) and <count> (how many cards).

Return ONLY a JSON object: {"cards": [{"q": "...", "a": "..."}], "test": [{"q": "...", "a": "..."}]}.
- cards: exactly <count> question cards on the most important points of THIS summary, one point per card. "q" is a short question (at most 15 words), "a" the answer the student should be able to say (one or two sentences).
- test: exactly five test questions with answers, like a short exam for the grade in <profile>: a mix of facts, explanations ("förklara varför ...") and one question that uses a concept in a new situation. Different from the cards.
- Only content that is in the summary or follows directly from it; correct facts at the level of the grade. Swedish unless <profile> or the summary is in English. No numbering, no markdown, no extra text.`;

function clean(s: unknown, max: number): string | null {
  if (typeof s !== "string") return null;
  const t = s.replace(/[\u0000-\u001f]/g, " ").replace(/\s+/g, " ").trim();
  return t ? t.slice(0, max) : null;
}

/** Parses the model's JSON; keeps only well-formed cards, trims sizes, drops duplicates. */
export function parseCards(text: string, count: number): { cards: Card[]; test: Card[] } {
  const m = /\{[\s\S]*\}/.exec(text);
  if (!m) return { cards: [], test: [] };
  let j: Record<string, unknown>;
  try {
    j = JSON.parse(m[0]);
  } catch {
    return { cards: [], test: [] };
  }
  const list = (v: unknown, n: number, seen = new Set<string>()) =>
    (Array.isArray(v) ? v : [])
      .map((c) => ({ q: clean((c as Card)?.q, CARD_LIMITS.q), a: clean((c as Card)?.a, CARD_LIMITS.a) }))
      .filter((c): c is Card => !!c.q && !!c.a && !seen.has(c.q.toLowerCase()) && !!seen.add(c.q.toLowerCase()))
      .slice(0, n);
  return { cards: list(j.cards, count), test: list(j.test, 5) };
}

export function createCardsHandler(deps: CardsDeps) {
  const cfg = deps.config ?? DEFAULT_CARDS_CONFIG;
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
      const b = (await readLimitedJson(req, CARD_LIMITS.bodyBytes)) as Record<string, unknown> | null;
      if (typeof b?.summary !== "string" || !b.summary.trim()) {
        throw new HttpError(400, "invalid_request", "summary is required");
      }
      if (b.summary.length > CARD_LIMITS.summary) {
        throw new HttpError(413, "payload_too_large", `summary exceeds ${CARD_LIMITS.summary} characters`);
      }
      const summary = clean(b.summary, CARD_LIMITS.summary)!;
      const profile = clean(b.profile, CARD_LIMITS.profile) ?? "";
      const count = Math.max(3, Math.min(12, Number.isInteger(b.cards) ? Number(b.cards) : 8));
      const extra = appChecks("cards", await networkKey(req), user, {
        networkPerDay: cfg.networkPerDay,
        newUserAgeSec: 0,
        newUserPerHour: 0,
      });
      const rl = await enforceLimits(deps.rateLimiter, "cards", user.id, cfg.limits, 1, extra);
      if (!rl.allowed) {
        throw new HttpError(429, "rate_limited", "Too many requests", { retryAfterSec: rl.retryAfterSec });
      }
      if (!deps.provider) throw new HttpError(503, "provider_unconfigured", "LLM provider not configured");
      const user_ = `<summary>\n${sanitizeTagged(summary)}\n</summary>\n${
        profile ? `<profile>${sanitizeTagged(profile)}</profile>\n` : ""
      }<count>${count}</count>`;
      let text = "";
      let inTok = 0, outTok = 0;
      const ac = new AbortController();
      req.signal?.addEventListener("abort", () => ac.abort());
      for await (
        const c of deps.provider.stream({
          system: SYSTEM_PROMPT_CARDS,
          user: user_,
          maxTokens: 1400,
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
      const result = parseCards(text, count);
      if (!result.cards.length && !result.test.length) {
        throw new HttpError(502, "cards_failed", "No cards could be made from the summary");
      }
      const cost = (inTok * cfg.priceInPerMTok + outTok * cfg.priceOutPerMTok) / 1e6;
      try {
        await deps.recordUsage?.({
          user_id: user.id,
          endpoint: "study-cards",
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
