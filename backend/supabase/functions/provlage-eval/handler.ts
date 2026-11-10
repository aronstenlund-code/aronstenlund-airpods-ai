import { type Authenticator } from "../_shared/auth.ts";
import { CORS_HEADERS, errorResponse, HttpError, toHttpError } from "../_shared/errors.ts";
import { appChecks, enforceLimits, type RateLimiter } from "../_shared/ratelimit.ts";
import { networkKey } from "../_shared/demo.ts";
import { readLimitedJson } from "../answer/validate.ts";
import { sanitizeTagged } from "../answer/prompt.ts";
import { createHandler, DEFAULT_CONFIG, type HandlerConfig } from "../answer/handler.ts";
import type { LLMProvider } from "../answer/llm/types.ts";
import { isLevelMeta } from "../answer/speech.ts";

/**
 * D87 (owner): the Provläge test bank's server side. Two actions, both behind the user JWT and hard daily caps:
 *  {"action":"answer","model":"haiku"|"sonnet","request":{...an /answer body, mode "tutor"...}}
 *     -> the normal /answer SSE stream, produced by the same handler code with Provläge on the given model.
 *  {"action":"grade","judge":"opus"|"sonnet","case":{grade, subject, profile, context, q, expect?},"answer":"..."}
 *     -> {"scores": {correct, a_level, sufficient, natural, length_ok}, "first_answer_suffices", "note", "usage"}
 * Nothing is stored. The judge is a stronger model than the one answering (Opus 5.5 for the model comparison,
 * Sonnet 5.5 for the nightly run of the bank).
 */
export const MODELS: Record<string, { id: string; inPerM: number; outPerM: number }> = {
  haiku: { id: "claude-haiku-5-5", inPerM: 0.10, outPerM: 0.50 },
  sonnet: { id: "claude-sonnet-5-5", inPerM: 2, outPerM: 10 },
  opus: { id: "claude-opus-5-5", inPerM: 4, outPerM: 20 },
};
export const EVAL_LIMITS = {
  answer: { perMinute: 40, perDay: 700, globalPerDay: 2500 },
  grade: { perMinute: 40, perDay: 700, globalPerDay: 1500 },
  /** Opus judgments are the expensive part: a separate global cap per day. */
  opusPerDay: 800,
};

/**
 * K2 (Oscar's D87 review, 2026-11-08): judge v2. Length and the closing question are checked in code (words and
 * sentences, as heard), "sufficient" no longer means "contains every item of the expected list" (that is the
 * separate "covers"), and natural also covers the language (all Swedish apart from target-language examples).
 * "First answer enough" is still correct AND sufficient; "strict" = correct AND sufficient AND covers.
 */
export const SYSTEM_PROMPT_JUDGE =
  `You grade one answer from a spoken study assistant for Swedish school students ("Provläge"). The student is preparing for an exam and asked something out loud; the answer is read aloud to them. You get <case> (grade, subject, profile, earlier turns, what the student said, and optionally what a good answer should contain) and <answer>.
Score each criterion 1 (yes) or 0 (no):
- correct: every fact and every example in the answer is right and it answers what the student most plausibly meant (a misheard or split term read as the right subject term counts as right; a wrong subject is 0; silence when a term was clearly meant is 0).
- a_level: the level fits the top grade A for exactly that grade and course in Sweden (Skolverket): the concepts and reasoning an A answer needs, not far above and not below.
- sufficient: a student of that grade would be helped by this answer alone: it gives the core point and the why or how, so they would NOT need to repeat themselves, ask the question again or ask a follow-up to understand what they asked. A follow-up turn ("och cellandning då?", "varför då?") must be read from the earlier turns. Judge what a student needs to understand the question, not whether every item of "Bör innehålla" is there.
- covers: the answer contains the points listed under "Bör innehålla" (1 when nothing is listed).
- natural: it sounds natural when heard: plain spoken Swedish with correct grammar (gender, word forms), no lists or symbols, no meta talk about the question, the recording, the interpretation or grades, no unanswerable or odd question. For a language subject only the terms and example sentences may be in the target language; an answer in the foreign language or a Swedish word inside a foreign sentence is 0. One short closing sentence that starts with "På provet" and says what to write is natural (it is asked for).
Return ONLY a JSON object: {"correct": 0|1, "a_level": 0|1, "sufficient": 0|1, "covers": 0|1, "natural": 0|1, "note": "<at most 25 words on the main problem, or empty>"}.`;

/** K2: does the profile ask for check questions ("Kontrollfrågor: …" that is not "inga")? */
export function wantsChecks(profile: string): boolean {
  return /kontrollfrågor\s*:/i.test(profile) && !/inga kontrollfrågor/i.test(profile);
}

/** K2: the length as heard, checked in code. Limits per the profile's explanation length (Oscar's review). */
export function lengthCheck(answer: string, profile: string): { ok: 0 | 1; words: number; sentences: number } {
  let t = answer.trim();
  const sentences = t ? t.split(/(?<=[.!?…])\s+/u).filter((x) => x.trim()) : [];
  // a closing check question that the profile asked for is not counted
  if (wantsChecks(profile) && sentences.length > 1 && sentences.at(-1)!.trim().endsWith("?")) sentences.pop();
  t = sentences.join(" ");
  const words = t ? t.split(/\s+/).filter(Boolean).length : 0;
  const p = profile.toLowerCase();
  const [maxS, maxW] = /korta förklaringar/.test(p) ? [3, 60] : /utförliga förklaringar/.test(p) ? [10, 200] : [6, 115];
  const ok = words > 0 && sentences.length <= maxS && words <= maxW ? 1 : 0;
  return { ok, words, sentences: sentences.length };
}

/** K2: a question at the end only when the profile asks for check questions. */
export function closingCheck(answer: string, profile: string): 0 | 1 {
  if (wantsChecks(profile)) return 1;
  return answer.trim().endsWith("?") ? 0 : 1;
}

/** K7.1: no sentence of the answer (as heard) talks about the level, the grade or what it chooses to explain. */
export function levelCheck(answer: string): 0 | 1 {
  return answer.split(/(?<=[.!?…:])\s+/u).some((x) => isLevelMeta(x)) ? 0 : 1;
}

/** K7.3 (Oscar O1 finding B): Danish or Norwegian words in Swedish speech ("Ja, det har jeg."). */
const NORDIC = /(?<![\p{L}])(?:jeg|ikke|ikkje|hvad|hvordan|hvorfor|hvilken|hvilket|hvem|hvis|også|meget|nogle|nogen|kanskje|efter at|desværre|dejlig|selvfølgelig)(?![\p{L}])/iu;
export function languageCheck(answer: string): 0 | 1 {
  // target-language examples in quotes are not Swedish speech
  return NORDIC.test(answer.replace(/["”“„»«][^"”“„»«]*["”“„»«]/gu, "")) ? 0 : 1;
}

export interface EvalDeps {
  authenticate: Authenticator;
  rateLimiter: RateLimiter;
  provider: LLMProvider | null;
  recordUsage?: (rec: Record<string, unknown>) => void | Promise<void>;
  /** Base answer config (the production one); the model is set per call. */
  answerConfig?: HandlerConfig;
  /** D88: ElevenLabs key for the batch Scribe comparison (the realtime path uses /stt-token like the app). */
  elevenLabsKey?: string | null;
  fetchImpl?: typeof fetch;
}

/** D88: batch transcription of one test clip (WAV, base64, at most 2 MB), for comparison with the realtime path. */
export const TRANSCRIBE_LIMITS = { perMinute: 30, perDay: 400, globalPerDay: 1500, maxBase64: 2_800_000 };

function scores(text: string) {
  const m = /\{[\s\S]*\}/.exec(text);
  let j: Record<string, unknown> = {};
  try {
    j = m ? JSON.parse(m[0]) : {};
  } catch { /* malformed: all zero */ }
  const b = (k: string) => (Number(j[k]) === 1 ? 1 : 0);
  const s = { correct: b("correct"), a_level: b("a_level"), sufficient: b("sufficient"), covers: b("covers"), natural: b("natural") };
  return { scores: s, note: typeof j.note === "string" ? j.note.slice(0, 300) : "", parsed: !!m };
}

export function createEvalHandler(deps: EvalDeps) {
  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), {
      status,
      headers: { "content-type": "application/json", "cache-control": "no-store", ...CORS_HEADERS },
    });
  return async (req: Request): Promise<Response> => {
    if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS_HEADERS });
    try {
      if (req.method !== "POST") throw new HttpError(405, "method_not_allowed", "Use POST");
      const user = await deps.authenticate(req);
      // Oscar O13 del 3: a transcribe body is up to ~2 MB of base64 (it was cut at 64 KB = 1.4 s of audio, 413)
      const b = (await readLimitedJson(req, TRANSCRIBE_LIMITS.maxBase64 + 64 * 1024)) as Record<string, unknown> | null;
      const action = String(b?.action ?? "");
      if (!deps.provider) throw new HttpError(503, "provider_unconfigured", "LLM provider not configured");
      const net = await networkKey(req);
      if (action === "answer") {
        const m = MODELS[String(b?.model ?? "haiku")];
        if (!m || m.id === MODELS.opus.id) throw new HttpError(400, "invalid_request", "model must be haiku or sonnet");
        const r = (b?.request ?? {}) as Record<string, unknown>;
        if (r.mode !== "tutor" || (r.persona ?? "tutor") !== "tutor") {
          throw new HttpError(400, "invalid_request", "only Provläge requests (mode tutor, persona tutor)");
        }
        const rl = await enforceLimits(deps.rateLimiter, "eval-answer", user.id, EVAL_LIMITS.answer, 1,
          appChecks("eval-answer", net, user, { networkPerDay: 1500, newUserAgeSec: 0, newUserPerHour: 0 }));
        if (!rl.allowed) throw new HttpError(429, "rate_limited", "Too many requests", { retryAfterSec: rl.retryAfterSec });
        const base = deps.answerConfig ?? DEFAULT_CONFIG;
        const handler = createHandler({
          authenticate: () => Promise.resolve(user),
          rateLimiter: deps.rateLimiter,
          provider: deps.provider,
          recordUsage: (rec) => deps.recordUsage?.(rec as unknown as Record<string, unknown>),
          config: {
            ...base,
            // the eval has its own caps above; the answer windows are not the user's real ones
            limits: { perMinute: 60, perDay: 2000, globalPerDay: 20000 },
            appGuard: { networkPerDay: 0, newUserAgeSec: 0, newUserPerHour: 0 },
            tutorModel: m.id,
            tutorFactRoute: false, // K29: the chosen model answers every case
            tutorPriceInPerMTok: m.inPerM,
            tutorPriceOutPerMTok: m.outPerM,
          },
        });
        return await handler(new Request(req.url, {
          method: "POST",
          headers: { "content-type": "application/json", "x-forwarded-for": req.headers.get("x-forwarded-for") ?? "" },
          body: JSON.stringify(r),
        }));
      }
      if (action === "grade") {
        const judgeKey = String(b?.judge ?? "sonnet");
        const judge = MODELS[judgeKey];
        if (!judge || judgeKey === "haiku") throw new HttpError(400, "invalid_request", "judge must be opus or sonnet");
        const c = (b?.case ?? {}) as Record<string, unknown>;
        const answer = typeof b?.answer === "string" ? b.answer.slice(0, 4000) : "";
        const extra = appChecks("eval-grade", net, user, { networkPerDay: 1500, newUserAgeSec: 0, newUserPerHour: 0 });
        if (judgeKey === "opus") extra.push({ key: "eval-grade:opus:global:d", limit: EVAL_LIMITS.opusPerDay, windowSec: 86400 });
        const rl = await enforceLimits(deps.rateLimiter, "eval-grade", user.id, EVAL_LIMITS.grade, 1, extra);
        if (!rl.allowed) throw new HttpError(429, "rate_limited", "Too many requests", { retryAfterSec: rl.retryAfterSec });
        const ctx = Array.isArray(c.context)
          ? (c.context as { q?: string; a?: string }[]).slice(-3).map((t) => `Q: ${sanitizeTagged(String(t.q ?? ""))}\nA: ${sanitizeTagged(String(t.a ?? ""))}`).join("\n")
          : "";
        const user_ = `<case>\nÅrskurs: ${sanitizeTagged(String(c.grade ?? ""))}\nÄmne: ${sanitizeTagged(String(c.subject ?? ""))}\nProfil: ${
          sanitizeTagged(String(c.profile ?? ""))
        }\nTidigare turer:\n${ctx || "(inga)"}\nEleven sa: ${sanitizeTagged(String(c.q ?? ""))}\nBör innehålla: ${
          sanitizeTagged(String(c.expect ?? ""))
        }\n</case>\n<answer>${sanitizeTagged(answer) || "(tyst, inget svar)"}</answer>`;
        let text = "";
        let inTok = 0, outTok = 0;
        for await (
          const ch of deps.provider.stream({ system: SYSTEM_PROMPT_JUDGE, user: user_, maxTokens: 1200, cacheSystem: true, model: judge.id, signal: req.signal })
        ) {
          if (ch.type === "text") text += ch.text;
          else if (ch.type === "usage") {
            inTok = ch.inputTokens ?? inTok;
            outTok = ch.outputTokens ?? outTok;
          }
        }
        const s = scores(text);
        const profile = String(c.profile ?? "");
        const len = lengthCheck(answer, profile);
        const empty = answer.trim() ? 0 : 1;
        const all = {
          ...s.scores, length_ok: len.ok, closing_ok: closingCheck(answer, profile),
          // K7: in code, as heard
          level_ok: empty ? 1 : levelCheck(answer), lang_ok: empty ? 1 : languageCheck(answer),
        };
        if (empty) all.correct = all.sufficient = all.covers = all.natural = 0;
        const cost = (inTok * judge.inPerM + outTok * judge.outPerM) / 1e6;
        // K7.1: an answer that says the level aloud is not enough in the leveltalk cases; K7.3: never another language
        const first = all.correct && all.sufficient && all.lang_ok && (c.kind !== "leveltalk" || all.level_ok) ? 1 : 0;
        return json({
          ...s, scores: all, rubric: 2, words: len.words, sentences: len.sentences, empty,
          first_answer_suffices: first, strict: first && all.covers ? 1 : 0,
          judge: judge.id, usage: { input_tokens: inTok, output_tokens: outTok, est_cost_usd: cost },
        });
      }
      if (action === "transcribe") {
        const xiKey = deps.elevenLabsKey;
        if (!xiKey) throw new HttpError(503, "stt_unconfigured", "ElevenLabs key not configured");
        const wav = typeof b?.audio_base64 === "string" ? b.audio_base64 : "";
        if (!wav || wav.length > TRANSCRIBE_LIMITS.maxBase64) {
          throw new HttpError(400, "invalid_request", "audio_base64: a WAV file, at most about 2 MB");
        }
        const rl = await enforceLimits(deps.rateLimiter, "eval-stt", user.id, TRANSCRIBE_LIMITS, 1,
          appChecks("eval-stt", net, user, { networkPerDay: 1500, newUserAgeSec: 0, newUserPerHour: 0 }));
        if (!rl.allowed) throw new HttpError(429, "rate_limited", "Too many requests", { retryAfterSec: rl.retryAfterSec });
        const bytes = Uint8Array.from(atob(wav), (ch) => ch.charCodeAt(0));
        const doFetch = deps.fetchImpl ?? fetch;
        let last = "";
        for (const model of ["scribe_v2", "scribe_v1"]) {
          const form = new FormData();
          form.append("model_id", model);
          form.append("language_code", "swe");
          form.append("tag_audio_events", "false");
          form.append("file", new Blob([bytes], { type: "audio/wav" }), "clip.wav");
          const r = await doFetch("https://api.elevenlabs.io/v1/speech-to-text?enable_logging=false", {
            method: "POST",
            headers: { "xi-api-key": xiKey },
            body: form,
          });
          if (r.ok) {
            const j = await r.json();
            return json({ text: String(j.text ?? "").trim(), model });
          }
          // the provider's reason (never the key), so a 403 can be told apart (permission, plan, logging)
          const why = (await r.text().catch(() => "")).replace(/\s+/g, " ").slice(0, 200);
          last = `${model}: HTTP ${r.status} ${why}`.trim();
          if (r.status !== 400 && r.status !== 422) break; // only an unknown model is retried
        }
        throw new HttpError(502, "stt_failed", `batch transcription failed (${last})`);
      }
      throw new HttpError(400, "invalid_request", "action must be answer, grade or transcribe");
    } catch (e) {
      return errorResponse(toHttpError(e));
    }
  };
}
