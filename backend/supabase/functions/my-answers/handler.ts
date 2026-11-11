import { type Authenticator } from "../_shared/auth.ts";
import { CORS_HEADERS, errorResponse, HttpError, toHttpError } from "../_shared/errors.ts";
import { appChecks, enforceLimits, type Limits, type RateLimiter } from "../_shared/ratelimit.ts";
import { networkKey } from "../_shared/demo.ts";
import { readLimitedJson } from "../answer/validate.ts";
import { sanitizeTagged } from "../answer/prompt.ts";
import type { LLMProvider, LLMRequest } from "../answer/llm/types.ts";

/**
 * K37 (D126, owner): "Mina svar" in Provläget. The app keeps the saved questions and answers on the phone (like the
 * D49 memories); this endpoint only helps write them. Nothing is stored or logged on the server (a metadata row in
 * `answer_usage`, no text). Matching a spoken question to a saved answer happens in /answer (`saved_answers`).
 *
 *  {"action":"suggest","q":"<the question the student typed>","subject"?,"grade"?,"exam"?,"goals"?,"terms"?:[...]}
 *     -> {"q": "<the question, spelling fixed>", "answer": "<how to answer it on the exam, A level, spoken Swedish>"}
 *  {"action":"proofread","q":"...","a":"..."}
 *     -> {"q","a","changed":{"q":bool,"a":bool}}  spelling and small grammar only; a fix that changes more than the
 *        spelling (checked in code: words added, removed or rewritten) is not used, the student's own text stays.
 *  {"action":"compress","transcript":"<a recording, already transcribed by the app with Scribe>","q"?, "subject"?}
 *     -> {"q": "<the question it answers>", "answer": "<the recording compressed to one exam answer>"}
 *        Only what is said in the recording; nothing added. Called once, when the student taps Klar (D120: no
 *        credits are spent on a recording that is not finished, and the audio never reaches this endpoint).
 */
export const MY_ANSWERS_LIMITS = { bodyBytes: 96 * 1024, q: 300, a: 1500, goals: 1500, terms: 50, term: 60, transcript: 60_000 };

export interface MyAnswersConfig {
  limits: Limits;
  networkPerDay: number;
  /** suggest and compress: correctness matters (Sonnet). */
  writeModel: string;
  writePriceInPerMTok: number;
  writePriceOutPerMTok: number;
  /** proofread: the provider's default (Haiku). */
  priceInPerMTok: number;
  priceOutPerMTok: number;
}
export const DEFAULT_MY_ANSWERS_CONFIG: MyAnswersConfig = {
  limits: { perMinute: 10, perDay: 200, globalPerDay: 6000 },
  networkPerDay: 2000,
  writeModel: "claude-sonnet-5-5",
  writePriceInPerMTok: 2,
  writePriceOutPerMTok: 10,
  priceInPerMTok: 0.10,
  priceOutPerMTok: 0.50,
};

export interface MyAnswersDeps {
  authenticate: Authenticator;
  rateLimiter: RateLimiter;
  provider: LLMProvider | null;
  config?: MyAnswersConfig;
  recordUsage?: (rec: Record<string, unknown>) => void | Promise<void>;
}

export const SYSTEM_PROMPT_SUGGEST =
  `A Swedish student is writing their own answers for an upcoming exam ("Mina svar"). You get <context> (subject, grade, exam, course goals and subject terms, all optional) and <question> (typed by the student, may have spelling mistakes). Return ONLY a JSON object {"q": "...", "answer": "..."}:
- "q": the question with spelling and capitals fixed, otherwise word for word (do not rephrase it).
- "answer": exactly how to answer it on the exam to reach A level for that grade, in Swedish: the key facts, the course's own subject terms, how they connect, and one example or reason when it helps. Two to five short sentences that sound natural when read aloud in an earbud. For a calculation: the method in short steps and the final answer with its unit, numbers as digits.
- Be correct above all. When the question cannot be answered without material you do not have (a figure, a text, a teacher's definition), say so in one sentence in "answer".
No markdown, no other text.`;

export const SYSTEM_PROMPT_PROOFREAD =
  `You correct spelling in a Swedish student's saved exam question and answer. You get <q> and <a>. Return ONLY a JSON object {"q": "...", "a": "..."} with spelling, capital letters, missing letters and obvious grammar slips (agreement, a missing word ending) fixed. Never change the content: keep every word, fact, number, term and the order; never add or remove a sentence; never improve the style. When nothing is wrong, return the text unchanged. No other text.`;

export const SYSTEM_PROMPT_COMPRESS =
  `A Swedish student recorded a perfect answer (a teacher explaining, a video, a classmate) and wants it as one saved exam answer. You get <transcript> (from speech recognition: may have misheard words, repetitions and talk that is not part of the answer), <question> (optional, typed by the student) and <subject> (optional). Return ONLY a JSON object {"q": "...", "answer": "..."}:
- "q": the question the recording answers: the student's <question> with spelling fixed when given, otherwise the main question as a short Swedish question.
- "answer": the recording compressed to one exam answer in Swedish: the key facts, terms, steps and examples that are said, in two to six short sentences that sound natural when read aloud. Fix obvious misheard words from the context. Use ONLY what is said in the transcript: never add a fact, number, name or example that is not there, and leave out greetings, repetitions and side talk.
- When the transcript contains no answer to anything (silence, noise, only side talk), "answer" is "" and "q" is "".
No markdown, no other text.`;

function clean(s: unknown, max: number): string {
  if (typeof s !== "string") return "";
  return s.replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f]/g, " ").trim().slice(0, max);
}

/** Words of a text for the proofread guard (letters and digits, lower case). */
function words(s: string): string[] {
  return s.toLowerCase().split(/[^\p{L}\p{N}]+/u).filter(Boolean);
}
function editDistance(a: string, b: string): number {
  const d = Array.from({ length: a.length + 1 }, (_, i) => [i, ...Array(b.length).fill(0)]);
  for (let j = 1; j <= b.length; j++) d[0][j] = j;
  for (let i = 1; i <= a.length; i++) {
    for (let j = 1; j <= b.length; j++) {
      d[i][j] = Math.min(d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1));
    }
  }
  return d[a.length][b.length];
}

/**
 * The fix is only spelling: the same number of words (± 1 for a split or joined compound), every number the same,
 * and every changed word close to the original (at most a third of its letters, at least one letter kept).
 */
export function onlySpelling(before: string, after: string): boolean {
  if (!after.trim()) return false;
  const a = words(before), b = words(after);
  if (Math.abs(a.length - b.length) > 1) return false;
  const nums = (x: string[]) => x.filter((w) => /\d/.test(w)).join(" ");
  if (nums(a) !== nums(b)) return false;
  if (a.length !== b.length) {
    return editDistance(a.join(""), b.join("")) <= Math.max(2, Math.ceil(a.join("").length * 0.08));
  }
  let changed = 0;
  for (let i = 0; i < a.length; i++) {
    if (a[i] === b[i]) continue;
    changed++;
    if (editDistance(a[i], b[i]) > Math.max(1, Math.floor(Math.max(a[i].length, b[i].length) / 3))) return false;
  }
  return changed <= Math.max(3, Math.ceil(a.length * 0.3));
}

function parseJson(text: string): Record<string, unknown> {
  try {
    const j = JSON.parse(/\{[\s\S]*\}/.exec(text)?.[0] ?? "{}");
    return j && typeof j === "object" ? j as Record<string, unknown> : {};
  } catch {
    return {};
  }
}

export function createMyAnswersHandler(deps: MyAnswersDeps) {
  const cfg = deps.config ?? DEFAULT_MY_ANSWERS_CONFIG;
  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json", ...CORS_HEADERS } });
  return async (req: Request): Promise<Response> => {
    const t0 = Date.now();
    if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS_HEADERS });
    try {
      if (req.method !== "POST") throw new HttpError(405, "method_not_allowed", "Use POST");
      const user = await deps.authenticate(req);
      const b = (await readLimitedJson(req, MY_ANSWERS_LIMITS.bodyBytes)) as Record<string, unknown> | null;
      const action = String(b?.action ?? "");
      if (!["suggest", "proofread", "compress"].includes(action)) {
        throw new HttpError(400, "invalid_request", "action must be suggest, proofread or compress");
      }
      const L = MY_ANSWERS_LIMITS;
      const q = clean(b?.q, L.q);
      const a = clean(b?.a, L.a);
      const transcript = clean(b?.transcript, L.transcript);
      if (action !== "compress" && !q) throw new HttpError(400, "invalid_request", "q is required");
      if (action === "proofread" && !a) throw new HttpError(400, "invalid_request", "a is required");
      if (action === "compress" && transcript.length < 20) {
        throw new HttpError(400, "invalid_request", "transcript is required (the recording, transcribed by the app)");
      }
      const extra = appChecks("my-answers", await networkKey(req), user, { networkPerDay: cfg.networkPerDay, newUserAgeSec: 0, newUserPerHour: 0 });
      const rl = await enforceLimits(deps.rateLimiter, "my-answers", user.id, cfg.limits, 1, extra);
      if (!rl.allowed) {
        throw new HttpError(429, "rate_limited", "För många försök just nu. Vänta en liten stund och försök igen.", { retryAfterSec: rl.retryAfterSec });
      }
      if (!deps.provider) throw new HttpError(503, "provider_unconfigured", "LLM provider not configured");

      const ctx = [
        clean(b?.subject, 60) && `Ämne: ${clean(b?.subject, 60)}`,
        clean(b?.grade, 60) && `Årskurs: ${clean(b?.grade, 60)}`,
        clean(b?.exam, 120) && `Prov: ${clean(b?.exam, 120)}`,
        clean(b?.goals, L.goals) && `Mål: ${clean(b?.goals, L.goals)}`,
        Array.isArray(b?.terms) && b!.terms.length
          ? `Ämnesord: ${(b!.terms as unknown[]).slice(0, L.terms).map((x) => clean(x, L.term)).filter(Boolean).join(", ")}`
          : "",
      ].filter(Boolean).join("\n");
      const write = action !== "proofread";
      const llm: LLMRequest = action === "suggest"
        ? {
          system: SYSTEM_PROMPT_SUGGEST,
          user: `<context>${sanitizeTagged(ctx || "okänt")}</context>\n<question>${sanitizeTagged(q)}</question>`,
          maxTokens: 700,
          cacheSystem: true,
          model: cfg.writeModel,
          noThinking: true,
          timeoutMs: 30_000,
          signal: req.signal,
        }
        : action === "proofread"
        ? {
          system: SYSTEM_PROMPT_PROOFREAD,
          user: `<q>${sanitizeTagged(q)}</q>\n<a>${sanitizeTagged(a)}</a>`,
          maxTokens: 1200,
          cacheSystem: true,
          noThinking: true,
          signal: req.signal,
        }
        : {
          system: SYSTEM_PROMPT_COMPRESS,
          user: `<subject>${sanitizeTagged(clean(b?.subject, 60))}</subject>\n<question>${sanitizeTagged(q)}</question>\n<transcript>\n${
            sanitizeTagged(transcript)
          }\n</transcript>`,
          maxTokens: 900,
          cacheSystem: true,
          model: cfg.writeModel,
          noThinking: true,
          timeoutMs: 45_000,
          signal: req.signal,
        };
      let text = "";
      let inTok = 0, outTok = 0;
      for await (const c of deps.provider.stream(llm)) {
        if (c.type === "text") text += c.text;
        else if (c.type === "usage") {
          inTok = c.inputTokens ?? inTok;
          outTok = c.outputTokens ?? outTok;
        }
      }
      const cost = write
        ? (inTok * cfg.writePriceInPerMTok + outTok * cfg.writePriceOutPerMTok) / 1e6
        : (inTok * cfg.priceInPerMTok + outTok * cfg.priceOutPerMTok) / 1e6;
      try {
        await deps.recordUsage?.({
          user_id: user.id,
          endpoint: `my-answers-${action}`,
          provider: deps.provider.name,
          model: llm.model ?? deps.provider.model,
          input_tokens: inTok,
          output_tokens: outTok,
          total_ms: Date.now() - t0,
          est_cost_usd: cost,
          status: "ok",
        });
      } catch (e) {
        console.error("usage_log_failed", e instanceof Error ? e.message : String(e));
      }
      const usage = { input_tokens: inTok, output_tokens: outTok, est_cost_usd: cost };
      const j = parseJson(text);
      if (action === "proofread") {
        const q2 = clean(j.q, L.q), a2 = clean(j.a, L.a);
        const okQ = onlySpelling(q, q2), okA = onlySpelling(a, a2);
        return json({ q: okQ ? q2 : q, a: okA ? a2 : a, changed: { q: okQ && q2 !== q, a: okA && a2 !== a }, usage });
      }
      const outQ = clean(j.q, L.q), outA = clean(j.answer, L.a);
      if (action === "suggest") {
        if (!outA) throw new HttpError(502, "no_answer", "Inget förslag just nu. Försök igen.");
        // the question stays the student's own unless the fix is only spelling
        return json({ q: onlySpelling(q, outQ) ? outQ : q, answer: outA, usage });
      }
      return json({ q: q && !onlySpelling(q, outQ) ? q : outQ, answer: outA, usage });
    } catch (e) {
      return errorResponse(toHttpError(e));
    }
  };
}
