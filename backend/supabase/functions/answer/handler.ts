import { type Authenticator } from "../_shared/auth.ts";
import { CORS_HEADERS, errorResponse, HttpError, toHttpError } from "../_shared/errors.ts";
import {
  type AppGuard,
  appChecks,
  enforceLimits,
  type Limits,
  type RateLimiter,
  userWindows,
} from "../_shared/ratelimit.ts";
import { SSE_HEADERS, sseFrame } from "../_shared/sse.ts";
import { type LLMChunk, type LLMProvider, LLMProviderError } from "./llm/types.ts";
import { type ParserEvent, ResponseParser } from "./parser.ts";
import { classifyAnswerType, detectContinuation } from "./length.ts";
import { buildPersonaUserMessage, personaPlan, personaSystemPrompt } from "./personas.ts";
import { computeFollowUp, computeFragment, spokenComputed } from "./calc.ts";
import { computeMath, isWordProblem } from "./mathcheck.ts";
import { commandTask, detectRule } from "./commands.ts";

/** K9: tasks that ask for one check question (only the question is said, as for "förhör mig"). */
const FREE_INSTRUCTION_NOTE =
  "The fragment is the student's spoken instruction to you (said after \"Lumen\"), not a question: carry it out on the last answer in <recent_qa> or the current topic, in the usual spoken style. Never answer it as a question about its own words and never silence.";
const QUIZ_TASKS = new Set(["harder_question", "quick_quiz", "yes_no_quiz", "quiz_topic", "weak_areas"]);
import { missingFact, missingFactNote } from "./interviewfacts.ts";
import { nowContext } from "./datecalc.ts";
import { categorize } from "./category.ts";
import {
  DEFAULT_DEMO_CAPS,
  DEMO_MESSAGES,
  type DemoCaps,
  enforceDemo,
  networkKey,
} from "../_shared/demo.ts";
import { detectReport } from "./report.ts";
import { detectMemoryAdd, MEMORY_ACK, MEMORY_SUMMARY } from "./memory.ts";
import {
  isOrdinalFact,
  needsText,
  needsWeb,
  TEXT_PROMPT,
  textTools,
  ORDINAL_NOTE,
  WEB_PROMPT,
  WEB_SEARCH_USD,
  WEB_UNAVAILABLE_NOTE,
  webTools,
} from "./web.ts";
import { AnswerPost, NumberStream, similarity } from "./speech.ts";

/** K1.4: a short reply grades the check question only within this many seconds of the answer that asked it. */
export const GRADE_REPLY_MAX_AGE_SEC = 120;
/** K1.4: the new check question is (almost) one already asked in this session. */
export function isRepeatedQuestion(text: string, asked: string[]): boolean {
  const q = text.trim();
  if (!q) return false;
  return asked.some((a) => similarity(a, q) >= 0.8);
}
import { stripEcho } from "./echo.ts";
import { numbersToSpeech } from "./svnum.ts";
import {
  detectDecline,
  FALLBACK_DECLINE,
  FALLBACK_SUGGESTIONS,
  pickSuggestions,
  previewSuggestion,
  finalizeCalibration,
  rizzReady,
  suggestionCount,
} from "./rizz.ts";
import {
  buildDirectUserMessage,
  buildUserMessage,
  type PromptExtras,
  RELATION_RULE,
  SUMMARY_RULE,
  SYSTEM_PROMPT,
  systemPromptFor, GRADE_NOTE, isQuizRequest, lastQuestion, QUIZ_NOTE, askedQuestions, looksLikeQuestion
} from "./prompt.ts";
import { type AnswerRequest, LIMITS, readLimitedJson, validateAnswerRequest } from "./validate.ts";

export interface UsageRecord {
  user_id: string;
  endpoint: "answer";
  mode: string;
  language: string;
  provider: string;
  model: string;
  is_question: boolean | null;
  confidence: number | null;
  input_tokens: number | null;
  output_tokens: number | null;
  ttft_ms: number | null;
  total_ms: number;
  est_cost_usd: number | null;
  status: string;
  /** D49: fixed-list category and persona only, never any text. */
  category?: string | null;
  persona?: string | null;
}

export interface HandlerConfig {
  confidenceThreshold: number;
  maxTokens: number;
  /** Token budget / spoken-length cap for developed "study" answers (D35). */
  maxTokensStudy: number;
  maxAnswerChars: number;
  maxAnswerCharsStudy: number;
  limits: Limits;
  /** D46 item 8: caps for requests that use web search/fetch (they cost real money per search). */
  webLimits?: Limits;
  /** D52: model + prices (USD / MTok) for Rizz suggestions (Sonnet 5.5 by default; Haiku for the rest). */
  rizzModel?: string;
  /** D87: model for Provläge (persona tutor in mode tutor); unset = the provider's default (Haiku). */
  tutorModel?: string;
  tutorPriceInPerMTok?: number;
  tutorPriceOutPerMTok?: number;
  rizzPriceInPerMTok?: number;
  rizzPriceOutPerMTok?: number;
  /** push_to_talk/text: headerless prompt, meta synthesised up front (lowest latency). */
  directModes: boolean;
  /** D62 demo caps (defaults in _shared/demo.ts). */
  demo?: DemoCaps;
  /** D79: app traffic per network (answers/day) and the first-hour allowance of a new session. */
  appGuard?: AppGuard;
  /** USD per million tokens, for the cost estimate only (prices as stated in the assignment). */
  priceInPerMTok: number;
  priceOutPerMTok: number;
}

export const DEFAULT_CONFIG: HandlerConfig = {
  confidenceThreshold: 0.45,
  maxTokens: 256,
  maxTokensStudy: 800,
  maxAnswerChars: 600,
  maxAnswerCharsStudy: 1800,
  limits: { perMinute: 20, perDay: 400, globalPerDay: 5000 },
  webLimits: { perMinute: 3, perDay: 20, globalPerDay: 150 },
  // Oscar 2026-11-08: 40 (was 20) and aborted calls are given back here too
  appGuard: { networkPerDay: 1500, newUserAgeSec: 600, newUserPerHour: 40 },
  rizzModel: "claude-sonnet-5-5",
  rizzPriceInPerMTok: 2,
  rizzPriceOutPerMTok: 10,
  // K2 (2026-11-09): Provläge on Sonnet 5.5, the only model over the 90 % target in the D87 bank (DECISIONS D90);
  // TUTOR_MODEL overrides it (e.g. back to Haiku), the demo never uses it
  tutorModel: "claude-sonnet-5-5",
  tutorPriceInPerMTok: 2,
  tutorPriceOutPerMTok: 10,
  directModes: true,
  priceInPerMTok: 0.10,
  priceOutPerMTok: 0.50,
};

export interface Deps {
  authenticate: Authenticator;
  /** Authoritative (shared, Postgres) limiter. Checked IN PARALLEL with the LLM call. */
  rateLimiter: RateLimiter;
  /**
   * Cheap per-isolate guard checked BEFORE the LLM call starts (0 ms). Bounds how many speculative
   * LLM starts one user can trigger while the shared limiter is still answering.
   */
  localLimiter?: RateLimiter;
  /** Wall clock (tests); default `new Date()`. */
  clock?: () => Date;
  /** null = no provider configured -> 503 provider_unconfigured (fail closed). */
  provider: LLMProvider | null;
  recordUsage: (rec: UsageRecord) => void | Promise<void>;
  config: HandlerConfig;
  now?: () => number;
  /** Called for `GET` + `x-warm: 1` (keep-alive ping): open the upstream connection ahead of time. */
  warm?: () => void;
}

export function providerErrorToHttp(e: unknown): HttpError {
  if (e instanceof LLMProviderError) {
    switch (e.kind) {
      case "quota":
        return new HttpError(503, "provider_quota", "LLM credits exhausted", { fallback: true });
      case "rate_limited":
        return new HttpError(503, "provider_busy", "LLM rate limited", {
          fallback: true,
          retryAfterSec: 5,
        });
      case "unconfigured":
        return new HttpError(503, "provider_unconfigured", "LLM provider not configured", {
          fallback: true,
        });
      case "auth":
        return new HttpError(503, "provider_misconfigured", "LLM provider credentials rejected", {
          fallback: true,
        });
      case "bad_request":
        return new HttpError(502, "provider_error", "LLM rejected the request", { fallback: true });
      default:
        return new HttpError(502, "provider_unavailable", "LLM provider unavailable", {
          fallback: true,
        });
    }
  }
  return new HttpError(502, "provider_unavailable", "LLM provider unavailable", { fallback: true });
}

export function createHandler(deps: Deps): (req: Request) => Promise<Response> {
  const now = deps.now ?? (() => performance.now());
  const cfg = deps.config;
  let served = 0; // requests served by this isolate (0 => the first one is "cold")

  return async (req: Request): Promise<Response> => {
    if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS_HEADERS });
    if (req.method === "GET" && req.headers.get("x-warm") === "1") {
      deps.warm?.();
      return new Response(null, { status: 204 });
    }
    const t0 = now();
    const cold = served++ === 0;
    try {
      if (req.method !== "POST") throw new HttpError(405, "method_not_allowed", "Use POST");
      const declared = Number(req.headers.get("content-length") ?? "0");
      if (declared > LIMITS.bodyBytes) {
        throw new HttpError(413, "payload_too_large", "Body too large");
      }

      const user = await deps.authenticate(req);
      const tAuth = now() - t0;

      if (deps.localLimiter) {
        const lr = await deps.localLimiter.check(`answer:u:${user.id}:m`, cfg.limits.perMinute, 60);
        if (!lr.allowed) {
          throw new HttpError(429, "rate_limited", "Too many requests", {
            fallback: true,
            retryAfterSec: lr.retryAfterSec,
          });
        }
      }

      const parsed = validateAnswerRequest(await readLimitedJson(req, LIMITS.bodyBytes));
      // D62: the public demo gets a restricted request: no Rizz / interview / auto / tutor mode, no memories,
      // no commands; web search and the report/memory shortcuts are off further down.
      const demo = parsed.source === "demo";
      const demoCaps = cfg.demo ?? DEFAULT_DEMO_CAPS;
      if (
        demo &&
        (parsed.persona !== "tutor" || parsed.social ||
          !["text", "push_to_talk"].includes(parsed.mode))
      ) {
        throw new HttpError(403, "demo_unavailable", DEMO_MESSAGES.unavailable);
      }
      const body0 = demo ? { ...parsed, memories: [], commands: [], goals: "" } : parsed;
      // D82: in Provläge / Auto the words that repeat the last answer (picked up again by the microphone) are
      // removed before anything else looks at the fragment; nothing left = silence, without a model call.
      const echo = !demo && !body0.social && (body0.persona ?? "tutor") === "tutor" &&
          (body0.mode === "tutor" || body0.mode === "auto")
        ? stripEcho(body0.fragment, body0.context.recent_qa.at(-1)?.a)
        : { rest: body0.fragment, echoed: 0 };
      const body = echo.echoed ? { ...body0, fragment: echo.rest } : body0;
      if (echo.echoed && echo.rest.split(/\s+/).filter((w) => /\p{L}{2,}/u.test(w)).length < 2) {
        const totalMs = Math.round(now() - t0);
        try {
          await deps.recordUsage({
            user_id: user.id,
            endpoint: "answer",
            mode: body0.mode,
            language: body0.language,
            provider: "local",
            model: "echo",
            is_question: false,
            confidence: 1,
            input_tokens: null,
            output_tokens: null,
            ttft_ms: null,
            total_ms: totalMs,
            est_cost_usd: 0,
            status: "not_question",
            category: "övrigt",
            persona: body0.persona,
          });
        } catch (e) {
          console.error("usage_log_failed", e instanceof Error ? e.message : String(e));
        }
        const frames = [
          sseFrame("meta", {
            reconstructed_question: body0.fragment,
            confidence: 1,
            is_question: false,
            needs_confirmation: false,
            answer_type: "fact",
            relation: null,
          }),
          sseFrame("done", {
            answered: false,
            timing: { meta_ms: totalMs, ttft_ms: null, llm_first_token_ms: null, total_ms: totalMs },
            breakdown: { direct: true, cold, answer_type: "fact", continuation: null },
            usage: { input_tokens: 0, output_tokens: 0, cache_read_tokens: 0, web_searches: 0, model: "echo" },
            summary: null,
            relation: null,
            source: null,
            memory_add: null,
          }),
        ];
        return new Response(
          new ReadableStream<Uint8Array>({
            start(c) {
              for (const f of frames) c.enqueue(f);
              c.close();
            },
          }),
          { status: 200, headers: { ...SSE_HEADERS, ...CORS_HEADERS } },
        );
      }
      if (demo) {
        await enforceDemo(deps.rateLimiter, "answer", user.id, await networkKey(req), demoCaps);
      }
      // D79: the app's own traffic is also capped per network and for brand-new sessions (demo has its caps).
      const appExtra = demo ? [] : appChecks(
        "answer",
        await networkKey(req),
        user,
        cfg.appGuard ?? DEFAULT_CONFIG.appGuard!,
      );
      const tBody = now() - t0;
      const provider = deps.provider;
      if (!provider) {
        throw new HttpError(503, "provider_unconfigured", "LLM provider not configured", {
          fallback: true,
        });
      }

      // D57: the spoken report command is recognised here (no model call, nothing spoken): the app sends
      // the previous turn to POST /feedback and plays its own confirmation.
      if (
        !demo && (body.mode === "auto" || body.mode === "push_to_talk" || body.mode === "tutor") &&
        detectReport(body.fragment)
      ) {
        const rl = await enforceLimits(deps.rateLimiter, "answer", user.id, cfg.limits, 1, appExtra);
        if (!rl.allowed) {
          throw new HttpError(429, "rate_limited", "Too many requests", {
            fallback: true,
            retryAfterSec: rl.retryAfterSec,
          });
        }
        const totalMs = Math.round(now() - t0);
        try {
          await deps.recordUsage({
            user_id: user.id,
            endpoint: "answer",
            mode: body.mode,
            language: body.language,
            provider: "local",
            model: "report",
            is_question: false,
            confidence: 1,
            input_tokens: null,
            output_tokens: null,
            ttft_ms: 0,
            total_ms: totalMs,
            est_cost_usd: 0,
            status: "report",
            category: "övrigt",
            persona: body.persona,
          });
        } catch (e) {
          console.error("usage_log_failed", e instanceof Error ? e.message : String(e));
        }
        const frames = [
          sseFrame("meta", {
            reconstructed_question: body.fragment,
            confidence: 1,
            is_question: false,
            needs_confirmation: false,
            answer_type: "fact",
          }),
          sseFrame("done", {
            answered: false,
            report: true,
            timing: { meta_ms: 0, ttft_ms: null, llm_first_token_ms: null, total_ms: totalMs },
            breakdown: { direct: true, cold, answer_type: "fact", continuation: null },
            usage: {
              input_tokens: 0,
              output_tokens: 0,
              cache_read_tokens: 0,
              web_searches: 0,
              model: "report",
            },
            summary: null,
            memory_add: null,
          }),
        ];
        return new Response(
          new ReadableStream<Uint8Array>({
            start(c) {
              for (const f of frames) c.enqueue(f);
              c.close();
            },
          }),
          { status: 200, headers: { ...SSE_HEADERS, ...CORS_HEADERS } },
        );
      }

      // D49: an explicit "kom ihåg ..." is answered locally (no model call) and returned as `memory_add`.
      const memoryOnly = !demo && body.mode !== "auto" && body.mode !== "interview_prep"
        ? detectMemoryAdd(body.fragment)
        : null;
      // K9: "i framtiden ska du …" / "svara alltid …" / "… det är minnet" in Provläge and Frågor is a standing rule,
      // answered locally like "kom ihåg" (memory_add "Regel: …", which the app sends back among the memories)
      const ruleHit = !memoryOnly && !demo && (body.mode === "tutor" || body.mode === "push_to_talk" || body.mode === "text") && !personaPlan(body)
        ? detectRule(body.fragment)
        : null;
      const memoryFact = memoryOnly ?? (ruleHit ? `Regel: ${ruleHit.rule}` : null);
      if (memoryFact) {
        const rl = await enforceLimits(deps.rateLimiter, "answer", user.id, cfg.limits, 1, appExtra);
        if (!rl.allowed) {
          throw new HttpError(429, "rate_limited", "Too many requests", {
            fallback: true,
            retryAfterSec: rl.retryAfterSec,
          });
        }
        const totalMs = Math.round(now() - t0);
        try {
          await deps.recordUsage({
            user_id: user.id,
            endpoint: "answer",
            mode: body.mode,
            language: body.language,
            provider: "local",
            model: "memory",
            is_question: true,
            confidence: 1,
            input_tokens: null,
            output_tokens: null,
            ttft_ms: 0,
            total_ms: totalMs,
            est_cost_usd: 0,
            status: "ok",
            category: "övrigt",
            persona: body.persona,
          });
        } catch (e) {
          console.error("usage_log_failed", e instanceof Error ? e.message : String(e));
        }
        const ack = ruleHit ? ruleHit.ack : body.language === "en" ? MEMORY_ACK.en : MEMORY_ACK.sv;
        const frames = [
          sseFrame("meta", {
            reconstructed_question: body.fragment,
            confidence: 1,
            is_question: true,
            needs_confirmation: false,
            answer_type: "fact",
          }),
          sseFrame("delta", { text: ack }),
          sseFrame("done", {
            answered: true,
            timing: { meta_ms: 0, ttft_ms: 0, llm_first_token_ms: null, total_ms: totalMs },
            breakdown: { direct: true, cold, answer_type: "fact", continuation: null },
            usage: {
              input_tokens: 0,
              output_tokens: 0,
              cache_read_tokens: 0,
              web_searches: 0,
              model: "memory",
            },
            summary: ruleHit ? "Användaren gav en stående regel för hur svaren ska vara." : MEMORY_SUMMARY,
            memory_add: memoryFact,
            ...(ruleHit ? { rule_add: ruleHit.rule } : {}),
          }),
        ];
        return new Response(
          new ReadableStream<Uint8Array>({
            start(c) {
              for (const f of frames) c.enqueue(f);
              c.close();
            },
          }),
          { status: 200, headers: { ...SSE_HEADERS, ...CORS_HEADERS } },
        );
      }

      const direct = (cfg.directModes && body.mode !== "auto") || !!personaPlan(body);
      // 'mer' / 'fortsätt' / 'förklara enklare' continue the last answer (needs history).
      const plan = personaPlan(body); // D42 persona / interview prep (null = ordinary flows)
      const continuation = !plan && body.context.recent_qa.length
        ? detectContinuation(body.fragment)
        : null;
      const tutor = body.mode === "tutor";
      // K9: a spoken instruction from the command table ("ge ett exempel", "sammanfatta", "var säker" …)
      const command = demo || continuation
        ? null
        : !plan && body.mode !== "auto" && body.mode !== "interview_prep"
        ? commandTask(body.fragment, "study")
        : plan?.kind === "interview" && plan.task === "interview_question"
        ? commandTask(body.fragment, "interview")
        : null;
      const quizTask = !!command && QUIZ_TASKS.has(command.task);
      // K9: an instruction the table does not know goes to the model as one (A7 sends voice_instruction: true)
      const freeInstruction = body.voiceInstruction === true && !command && !continuation && !plan;
      const careful = command?.task === "careful";
      const answerTypeBase = plan?.answerType ?? (command ? (command.task === "brief_style" ? "fact" : "study") : undefined) ??
        classifyAnswerType(body.fragment, body.length, continuation, {
          tutor,
          commands: body.commands.length > 0,
        });
      // D46: arithmetic / percentages / unit conversions are computed in code, not by the model.
      const computed = plan || body.mode === "interview_prep"
        ? null
        : computeFragment(body.fragment, (deps.clock ?? (() => new Date()))()) ??
          computeFollowUp(body.fragment, body.context.recent_qa.at(-1)?.a) ??
          computeMath(body.fragment); // K1.3: derivatives and linear equations checked in code
      // History fix 2026-11-08 ("270 gånger 270" was spoken as "sjutusen niohundra" although <computed> was
      // right): arithmetic, percentages and a bare clock time are answered entirely by code, no model call.
      const localCalc = computed && !plan ? spokenComputed(computed, tutor) : null;
      if (localCalc) {
        const rl = await enforceLimits(deps.rateLimiter, "answer", user.id, cfg.limits, 1, appExtra);
        if (!rl.allowed) {
          throw new HttpError(429, "rate_limited", "Too many requests", {
            fallback: true,
            retryAfterSec: rl.retryAfterSec,
          });
        }
        const ns = new NumberStream();
        const spoken = (ns.push(localCalc) + ns.finish()).replace(/^\s*\p{Ll}/u, (c) => c.toUpperCase());
        const totalMs = Math.round(now() - t0);
        try {
          await deps.recordUsage({
            user_id: user.id,
            endpoint: "answer",
            mode: body.mode,
            language: body.language,
            provider: "local",
            model: "calc",
            is_question: true,
            confidence: 1,
            input_tokens: null,
            output_tokens: null,
            ttft_ms: totalMs,
            total_ms: totalMs,
            est_cost_usd: 0,
            status: "ok",
            category: "matte",
            persona: body.persona,
          });
        } catch (e) {
          console.error("usage_log_failed", e instanceof Error ? e.message : String(e));
        }
        const frames = [
          sseFrame("meta", {
            reconstructed_question: body.fragment,
            confidence: 1,
            is_question: true,
            needs_confirmation: false,
            answer_type: "fact",
            relation: null,
          }),
          sseFrame("delta", { text: spoken }),
          sseFrame("done", {
            answered: true,
            timing: { meta_ms: totalMs, ttft_ms: totalMs, llm_first_token_ms: null, total_ms: totalMs },
            breakdown: { direct: true, cold, answer_type: "fact", continuation: null },
            usage: {
              input_tokens: 0,
              output_tokens: 0,
              cache_read_tokens: 0,
              web_searches: 0,
              model: "calc",
              est_cost_usd: 0,
            },
            summary: demo ? null : `Räknade ut: ${computed!.text}.`,
            relation: null,
            source: null,
            memory_add: null,
          }),
        ];
        return new Response(
          new ReadableStream<Uint8Array>({
            start(c) {
              for (const f of frames) c.enqueue(f);
              c.close();
            },
          }),
          { status: 200, headers: { ...SSE_HEADERS, ...CORS_HEADERS } },
        );
      }
      // D46 item 8: web search/fetch only when the question needs it, and only within the caps.
      // D84: a song, a poem or a quote gets its own search and rules (traditional texts in full).
      const textReq = !demo && !plan && !computed && body.mode !== "interview_prep" && needsText(body.fragment);
      const need =
        !textReq && !demo && !plan && !computed && body.mode !== "auto" && body.mode !== "interview_prep"
          ? needsWeb(body.fragment)
          : null;
      let webOn = false;
      let webNote: string | undefined;
      let textOn = false;
      if (textReq) {
        const wl = await enforceLimits(
          deps.rateLimiter,
          "answer-web",
          user.id,
          cfg.webLimits ?? DEFAULT_CONFIG.webLimits!,
        );
        textOn = wl.allowed; // without search the rules still apply, from the model's own knowledge
      }
      if (need) {
        const wl = await enforceLimits(
          deps.rateLimiter,
          "answer-web",
          user.id,
          cfg.webLimits ?? DEFAULT_CONFIG.webLimits!,
        );
        webOn = wl.allowed;
        if (!webOn) webNote = WEB_UNAVAILABLE_NOTE;
      }
      const answerType = (computed || webOn || demo) && !tutor ? "fact" : answerTypeBase;
      const maxChars = (demo ? demoCaps.answerMaxChars : undefined) ?? plan?.maxChars ??
        (textReq ? 2400 : undefined) ?? (webOn ? 800 : undefined) ??
        (answerType === "study" ? cfg.maxAnswerCharsStudy : cfg.maxAnswerChars);
      const parser = new ResponseParser(
        body.mode,
        body.fragment,
        cfg.confidenceThreshold,
        direct,
        answerType,
      );
      let inputTokens: number | null = null;
      let outputTokens: number | null = null;
      let cacheRead = 0;
      let cacheWrite = 0;
      let llmFirstTokenMs: number | null = null;
      let metaMs: number | null = null;
      let ttftMs: number | null = null;
      let limitsMs: number | null = null;
      let answerChars = 0;
      let closed = false;
      let doneSent = false; // D80: the client got the whole answer (else a client abort is not counted)
      let retries = 0;
      let webSearches = 0;
      let status = "ok";
      const carry = { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 }; // tokens of discarded attempts
      // D75: Provläge and Auto say nothing to a fragment that is not a question (or is too broken):
      // the meta event is held until the first spoken text so the app can still be told to stay silent.
      // D86: "förhör mig" is an explicit request: never silence
      const silenceOn = !demo && !plan && (body.mode === "tutor" || body.mode === "auto") &&
        !(body.mode === "tutor" && isQuizRequest(body.fragment)) && !command && body.voiceInstruction !== true;
      // D86: "förhör mig" asks for exactly one check question (also when the profile has "inga kontrollfrågor")
      const quiz = !plan && ((tutor && isQuizRequest(body.fragment)) || quizTask);
      const lastQ = body.context.recent_qa.at(-1);
      // K1.4: a short reply is an answer only when it is not a new question and comes shortly after the check
      // question (the app sends last_answer_age_sec; without it the old rule holds)
      const replyAge = body.context.last_answer_age_sec;
      const gradeReply = tutor && !plan && !quiz && !command && !!lastQ && !!lastQuestion(lastQ.a) &&
        lastQ.a.trim().endsWith("?") && body.fragment.trim().split(/\s+/).length <= 12 &&
        !looksLikeQuestion(body.fragment) && (replyAge === undefined || replyAge <= GRADE_REPLY_MAX_AGE_SEC);
      // K2: with a profile, a check question only when the profile asks for one (a "Kontrollfrågor" line that is not "inga")
      const noChecks = !quiz && tutor && body.persona === "tutor" && !!body.personaSetup &&
        (!/kontrollfrågor\s*:/i.test(body.personaSetup) || /inga kontrollfrågor/i.test(body.personaSetup)) &&
        !gradeReply;
      let silenced = false;

      // D84: texts and quotes need the exact words: they use the stronger model (Rizz's), like Rizz
      const isRizz = plan?.kind === "rizz" || textReq || careful; // K9: "var säker" = the stronger model, one answer
      // D87: Provläge can run on its own model (TUTOR_MODEL); the measured choice is in DECISIONS D87
      const tutorModel = !isRizz && tutor && !plan && !demo && cfg.tutorModel ? cfg.tutorModel : undefined;
      // K7.6: a word or logic problem in Provläge gets the model's thinking (it said "Tom är nio" before working
      // out eight); everything else keeps thinking off for the first word
      const wordProblem = !!tutorModel && isWordProblem(body.fragment);
      const modelUsed = isRizz ? (cfg.rizzModel ?? provider.model) : tutorModel ?? provider.model;
      const priceIn = isRizz
        ? (cfg.rizzPriceInPerMTok ?? cfg.priceInPerMTok)
        : tutorModel
        ? (cfg.tutorPriceInPerMTok ?? cfg.priceInPerMTok)
        : cfg.priceInPerMTok;
      const priceOut = isRizz
        ? (cfg.rizzPriceOutPerMTok ?? cfg.priceOutPerMTok)
        : tutorModel
        ? (cfg.tutorPriceOutPerMTok ?? cfg.priceOutPerMTok)
        : cfg.priceOutPerMTok;
      const cacheReadMult = 0.1; // cache hits cost 0.1x of the input price (Sonnet 5.5 and Haiku 5.5; claude-api skill 2026-10-06)

      function usage(s: string): UsageRecord {
        const m = parser.meta;
        const inTok = inputTokens === null ? (carry.input || null) : inputTokens + carry.input;
        const outTok = outputTokens === null ? (carry.output || null) : outputTokens + carry.output;
        const cr = cacheRead + carry.cacheRead, cw = cacheWrite + carry.cacheWrite;
        const total = inTok ?? 0;
        const plain = Math.max(0, total - cr - cw);
        const cost = inTok !== null || outTok !== null
          ? ((plain + cr * cacheReadMult + cw * 1.25) * priceIn +
                (outTok ?? 0) * priceOut) / 1e6 + webSearches * WEB_SEARCH_USD
          : null;
        return {
          user_id: user.id,
          endpoint: "answer",
          mode: body.mode,
          language: body.language,
          provider: provider!.name,
          model: modelUsed,
          is_question: silenced ? false : m?.is_question ?? null,
          confidence: m?.confidence ?? null,
          input_tokens: inTok,
          output_tokens: outTok,
          ttft_ms: ttftMs === null ? null : Math.round(ttftMs),
          total_ms: Math.round(now() - t0),
          est_cost_usd: cost,
          status: s,
          category,
          persona: body.persona,
        };
      }

      // Start the shared-limit check and the LLM call at the same time. No byte is sent to the client
      // before BOTH have succeeded, so a denied request never leaks an answer; it only costs the
      // aborted LLM start (bounded by the local guard above).
      const ac = new AbortController();
      const acs = [ac]; // one controller per LLM attempt (a retry starts a new one)
      const abortAll = () => acs.forEach((a) => a.abort());
      req.signal.addEventListener("abort", abortAll);
      const countedAt = Date.now(); // D80: an aborted answer is given back in this window
      const limitsP = enforceLimits(deps.rateLimiter, "answer", user.id, cfg.limits, 1, appExtra).then((r) => {
        limitsMs = now() - t0;
        return r;
      });
      const category = demo ? "demo" : categorize({
        mode: body.mode,
        persona: body.persona,
        fragment: body.fragment,
        planKind: plan?.kind ?? null,
        web: webOn,
        computed: !!computed,
      });
      const noSummary = plan?.kind === "rizz" || plan?.kind === "calibrate" || demo;
      const relationTag = direct && !plan && body.context.recent_qa.length > 0;
      const systemPrompt = (plan
        ? personaSystemPrompt(plan.kind, body)
        : direct
        ? systemPromptFor(answerType, tutor)
        : SYSTEM_PROMPT) +
        (relationTag ? RELATION_RULE : "") + (noSummary ? "" : SUMMARY_RULE) +
        (webOn ? WEB_PROMPT : "") + (textReq ? TEXT_PROMPT : "");
      const baseTokens = plan?.maxTokens ?? (textReq ? 1100 : undefined) ?? (webOn ? 600 : undefined) ??
        (answerType === "study" ? cfg.maxTokensStudy : cfg.maxTokens);
      const maxTokens = demo
        ? demoCaps.answerMaxTokens + (relationTag ? 12 : 0)
        : baseTokens + (noSummary ? 0 : 80) + (relationTag ? 12 : 0);
      const tools = textOn ? textTools() : webOn && need ? webTools(need) : undefined;
      // D82: after the echo of the last answer was removed, only a complete new question gets an answer.
      const echoNote = echo.echoed
        ? "The start of <fragment> repeated your own last answer (picked up again by the microphone) and was removed. Answer only if what is left is by itself a complete new question or request; a cut-off half sentence, a remark or noise gets the silence reply."
        : undefined;
      // K1.5: the interviewer asks about a fact the CV does not give (körkort, ålder, alkohol, pendling)
      const missing = plan?.kind === "interview" && plan.task === "interview_question"
        ? missingFact(body.fragment, body.personaSetup, body.memories)
        : null;
      const userFor = (b: AnswerRequest, extras: PromptExtras = {}) =>
        plan
          ? buildPersonaUserMessage(b, plan.task) +
            (command ? `
<task>${command.task}</task>
<task_rule>${command.rule}</task_rule>` : "") +
            (extras.note ? `
<note>${extras.note}</note>` : "") + (missing ? `
<note>${missingFactNote(missing)}</note>` : "")
          : direct
          ? buildDirectUserMessage(b, continuation, {
            ...extras,
            ...(command ? { command } : {}),
            note: extras.note ?? echoNote ?? (quiz ? QUIZ_NOTE : gradeReply ? GRADE_NOTE : freeInstruction ? FREE_INSTRUCTION_NOTE : undefined),
          })
          : buildUserMessage(b, cfg.confidenceThreshold, answerType, continuation, {
            ...extras,
            ...(command ? { command } : {}),
            note: extras.note ?? echoNote,
          });
      // D72 live test: "the Nth king" was answered wrong without listing first; ask for the list in code.
      const ordinal = !plan && isOrdinalFact(body.fragment);
      const baseExtras: PromptExtras = {
        now: nowContext((deps.clock ?? (() =>
          new Date()))()),
        ...(computed ? { computed: computed.text } : {}),
        ...(webNote || ordinal
          ? { note: [webNote, ordinal ? ORDINAL_NOTE : ""].filter(Boolean).join(" ") }
          : {}),
      };
      const iterator = provider
        .stream({
          system: systemPrompt,
          user: userFor(body, baseExtras),
          maxTokens,
          cacheSystem: true,
          tools,
          // D72 live test: "den andra statsministern" was answered wrong from memory: ordinal facts search.
          ...(tools && ordinal ? { toolChoice: { type: "any" } } : {}),
          ...(isRizz && cfg.rizzModel ? { model: cfg.rizzModel } : {}),
          ...(tutorModel ? { model: tutorModel, noThinking: !wordProblem, think: wordProblem } : {}),
          ...(careful ? { think: true } : {}),
          signal: ac.signal,
        })[Symbol.asyncIterator]();
      const firstP = iterator.next().then((r) => {
        llmFirstTokenMs = now() - t0;
        return r;
      });
      firstP.catch(() => {}); // handled below, or deliberately dropped when the limiter denies

      const rl = await limitsP;
      if (!rl.allowed) {
        ac.abort();
        iterator.return?.()?.catch?.(() => {});
        throw new HttpError(429, "rate_limited", "Too many requests", {
          fallback: true,
          retryAfterSec: rl.retryAfterSec,
        });
      }

      // Wait for the first chunk before committing to a 200: quota/auth errors become real HTTP errors.
      let first: IteratorResult<LLMChunk>;
      try {
        first = await firstP;
      } catch (e) {
        ac.abort();
        try {
          await deps.recordUsage(usage("provider_error"));
        } catch (le) {
          console.error("usage_log_failed", le instanceof Error ? le.message : String(le));
        }
        throw providerErrorToHttp(e);
      }

      const stream = new ReadableStream<Uint8Array>({
        async start(controller) {
          const send = (event: string, data: unknown) => {
            if (closed) {
              return;
            }
            try {
              controller.enqueue(sseFrame(event, data));
            } catch {
              closed = true;
              abortAll();
            }
          };
          let stop = false;
          let it = iterator;
          // D46 post-processing: digits -> words, drop a closing question, stop a repeated answer.
          const qnorm = (x: string) => x.toLowerCase().replace(/[^\p{L}\p{N}]+/gu, "");
          const guardOn = direct && !plan && !continuation && body.context.recent_qa.length > 0 &&
            body.fragment.trim().split(/\s+/).length >= 2;
          const prevAnswers = guardOn
            ? body.context.recent_qa.filter((x) => qnorm(x.q) !== qnorm(body.fragment)).map((x) =>
              x.a
            )
            : [];
          let post = new AnswerPost({
            previousAnswers: prevAnswers,
            // D83: profile "Inga kontrollfrågor" = no check question, also in Provläge (enforced in code)
            trimQuestion: direct && !plan && (!tutor || noChecks),
            firstLineOnly: plan?.kind === "socialline",
            relationTag,
            web: webOn || !!need,
            source: textReq, // D84: texts and quotes split off their källa line
            tutor,
            silence: silenceOn,
            inputMeta: silenceOn, // 2026-11-08: never about the fragment, sound or microphone (sentence-buffered modes only)
            heard: body.fragment,
            quizOnly: quiz, // D86: only the check question is said
            subjectKnown: tutor && body.persona === "tutor" && !!body.personaSetup,
            interview: plan?.kind === "interview", // D77
            missingFact: missing ?? undefined,
          });
          let pendingMeta: Record<string, unknown> | null = null;
          const flushMeta = () => {
            if (!pendingMeta) return;
            metaMs = now() - t0;
            send("meta", pendingMeta);
            pendingMeta = null;
          };
          const deliver = (t: string) => {
            if (!t || closed) return;
            flushMeta();
            if (ttftMs === null) ttftMs = now() - t0;
            answerChars += t.length;
            send("delta", { text: t });
            if (answerChars >= maxChars) {
              status = "truncated";
              stop = true;
            }
          };
          const rizz = plan?.kind === "rizz";
          const calib = plan?.kind === "calibrate"; // D69: collect the merged calibration, send nothing else
          let calibBuf = "";
          let calibration: string | null = null;
          let rizzBuf = "";
          const rizzCount = rizz ? suggestionCount(body) : 0; // D72: 1 by default, max 5 when asked
          let previewSent = false;
          let previewText: string | null = null;
          const emit = (ev: ParserEvent) => {
            if (ev.type === "meta") {
              const m = {
                reconstructed_question: ev.meta.reconstructed_question,
                confidence: ev.meta.confidence,
                is_question: ev.meta.is_question,
                needs_confirmation: ev.meta.needs_confirmation,
                answer_type: ev.meta.answer_type,
                relation: ev.meta.relation ?? null,
              };
              if (silenceOn && ev.meta.is_question) {
                pendingMeta = m; // D75: sent with the first spoken text
              } else {
                metaMs = now() - t0;
                send("meta", m);
              }
              if (!ev.meta.is_question) {
                status = "not_question";
                stop = true;
              }
            } else {
              if (!stop) deliver(post.push(ev.text));
              if (silenceOn && post.silenceMarked) stop = true; // D75: nothing more will be said
              if (post.silencedLate) stop = true; // 2026-11-08: marker after text: say nothing more
            }
          };
          const handle = (chunk: LLMChunk) => {
            if (chunk.type === "usage") {
              if (chunk.inputTokens !== undefined) inputTokens = chunk.inputTokens;
              if (chunk.outputTokens !== undefined) outputTokens = chunk.outputTokens;
              if (chunk.cacheReadTokens !== undefined) cacheRead = chunk.cacheReadTokens;
              if (chunk.cacheWriteTokens !== undefined) cacheWrite = chunk.cacheWriteTokens;
              if (chunk.webSearches !== undefined) webSearches = chunk.webSearches;
              return;
            }
            if (calib) {
              calibBuf += chunk.text;
              return;
            }
            if (rizz) {
              rizzBuf += chunk.text;
              // The model finished its pick (complete TOP line): answer now instead of waiting for the stream to end.
              const done = rizzBuf.slice(0, rizzBuf.lastIndexOf("\n") + 1);
              if (done && rizzReady(done, rizzCount)) stop = true;
              // D63: the first line is the model's strongest: show it at once, the full list follows.
              if (!previewSent) {
                const first = previewSuggestion(done);
                if (first) {
                  previewSent = true;
                  previewText = first;
                  if (ttftMs === null) ttftMs = now() - t0;
                  send("suggestion_preview", { text: numbersToSpeech(first) });
                }
              }
            } else for (const ev of parser.push(chunk.text)) emit(ev);
          };

          try {
            if (parser.presetMeta && !rizz && !calib) emit({ type: "meta", meta: parser.presetMeta });
            let r = first;
            for (let attempt = 0;; attempt++) {
              while (!r.done && !stop && !closed) {
                handle(r.value);
                if (stop || closed || post.duplicate) break;
                r = await it.next();
              }
              if (rizz || calib || closed) break;
              let note: string | null = null;
              let history = body.context.recent_qa;
              if (post.duplicate) {
                note =
                  "Your previous reply repeated an earlier answer. The fragment is a new request: answer only the fragment.";
                const m = post.dup.matched;
                if (m) history = history.filter((x) => x.a !== m);
              } else {
                if (!stop) { for (const ev of parser.finish()) emit(ev); }
                const fin = post.finish();
                // K1.4: "förhör mig" never repeats a question of this session (held until here, nothing was sent)
                const repeated = quiz && attempt === 0 && !stop && isRepeatedQuestion(fin, askedQuestions(body));
                if (!repeated) deliver(fin);
                if (repeated) {
                  note =
                    "Your previous check question was already asked in this session (see <already_asked>). Ask ONE different check question about another part of the topic.";
                } else if (post.questionOnly && !stop) {
                  note =
                    "Your previous reply only asked the user a question. Answer directly with the most likely interpretation and do not ask anything back.";
                } else if (plan?.kind === "interview" && post.interviewMetaOnly && ttftMs === null && !stop) {
                  // Oscar 2026-11-08: an interview answer is never empty
                  note =
                    "Your previous reply only talked about facts that are not given. Answer the interviewer's question directly in first person with what you bring to the role, and never mention what is missing.";
                }
              }
              if (!note || attempt > 0) break;
              // regenerate once (nothing of the first attempt was sent to the client)
              status = "ok";
              carry.input += inputTokens ?? 0;
              carry.output += outputTokens ?? 0;
              carry.cacheRead += cacheRead;
              carry.cacheWrite += cacheWrite;
              inputTokens = outputTokens = null;
              cacheRead = cacheWrite = 0;
              acs[attempt].abort();
              try {
                await it.return?.();
              } catch { /* already finished */ }
              const ac2 = new AbortController();
              acs.push(ac2);
              retries++;
              it = provider.stream({
                system: systemPrompt,
                user: userFor({ ...body, context: { ...body.context, recent_qa: history } }, {
                  ...baseExtras,
                  note,
                }),
                maxTokens,
                cacheSystem: true,
                tools,
                ...(isRizz && cfg.rizzModel ? { model: cfg.rizzModel } : {}),
                ...(tutorModel ? { model: tutorModel, noThinking: !wordProblem, think: wordProblem } : {}),
          ...(careful ? { think: true } : {}),
                signal: ac2.signal,
              })[Symbol.asyncIterator]();
              post = new AnswerPost({
                previousAnswers: [],
                trimQuestion: false,
                firstLineOnly: plan?.kind === "socialline",
                relationTag,
                web: webOn || !!need,
                source: textReq,
                tutor,
                silence: silenceOn,
                inputMeta: silenceOn,
                heard: body.fragment,
                quizOnly: quiz,
                subjectKnown: tutor && body.persona === "tutor" && !!body.personaSetup,
                interview: plan?.kind === "interview",
                missingFact: missing ?? undefined,
              });
              r = await it.next();
            }
            if (rizz) {
              // D43: one `suggestions` event (2-3 options, best first), nothing else.
              // After an early stop the last line may be cut mid-sentence: only complete lines count.
              let options = pickSuggestions(
                stop ? rizzBuf.slice(0, rizzBuf.lastIndexOf("\n") + 1) : rizzBuf,
                true,
                undefined,
                rizzCount,
              );
              // the preview was shown first: the final list keeps it first
              if (previewText && options.length) {
                options = [previewText, ...options.filter((o) => o !== previewText)].slice(
                  0,
                  rizzCount,
                );
              }
              if (!options.length) {
                options = (detectDecline(body) ? FALLBACK_DECLINE : FALLBACK_SUGGESTIONS).slice(
                  0,
                  rizzCount,
                );
                status = "filtered";
              }
              if (ttftMs === null) ttftMs = now() - t0;
              metaMs = ttftMs;
              send("suggestions", options.map(numbersToSpeech));
            } else if (calib) {
              calibration = finalizeCalibration(calibBuf, body.social?.calibration ?? "");
              if (ttftMs === null) ttftMs = now() - t0;
              metaMs = ttftMs;
            } else if (stop && !closed && status !== "ok") {
              deliver(post.finish()); // truncated: speak the tail that was held back
            }
            if (stop) abortAll();
            if (parser.headerFailed) {
              console.warn(JSON.stringify({ evt: "header_parse_failed", mode: body.mode }));
            }
            // D75: the model chose silence, or only meta comments were written: tell the app to stay quiet.
            if (silenceOn && status === "ok" && ttftMs === null && post.silent) {
              silenced = true;
              status = "not_question";
              pendingMeta = null;
              metaMs = now() - t0;
              send("meta", {
                reconstructed_question: parser.meta?.reconstructed_question ?? body.fragment,
                confidence: parser.meta?.confidence ?? 1,
                is_question: false,
                needs_confirmation: false,
                answer_type: parser.meta?.answer_type ?? answerType,
                relation: null,
              });
            }
            flushMeta();
            if (status === "ok" && parser.meta?.is_question && ttftMs === null) {
              status = "empty_answer";
              send("error", {
                code: "empty_answer",
                message: "Model returned no answer",
                fallback: true,
              });
            }
            const r2 = (n: number | null) => (n === null ? null : Math.round(n));
            send("done", {
              answered: !post.silencedLate &&
                (status === "ok" || status === "truncated" || status === "filtered"),
              // 2026-11-08: the model put [[TYST]] after text it had already streamed: the app drops the answer
              ...(post.silencedLate ? { retract: true } : {}),
              timing: {
                meta_ms: r2(metaMs),
                ttft_ms: r2(ttftMs),
                llm_first_token_ms: r2(llmFirstTokenMs),
                total_ms: Math.round(now() - t0),
              },
              breakdown: {
                auth_ms: r2(tAuth),
                body_ms: r2(tBody),
                limits_ms: r2(limitsMs),
                llm_first_chunk_ms: r2(llmFirstTokenMs),
                direct,
                cold,
                answer_type: answerType,
                continuation,
              },
              usage: {
                input_tokens: inputTokens,
                output_tokens: outputTokens,
                cache_read_tokens: cacheRead,
                cache_write_tokens: cacheWrite,
                web_searches: webSearches,
                model: modelUsed,
                est_cost_usd: usage("ok").est_cost_usd,
              },
              summary: noSummary ? null : post.summary,
              relation: post.relation ?? parser.meta?.relation ?? null,
              source: post.source,
              memory_add: null,
              calibration,
            });
            doneSent = !closed;
          } catch (e) {
            if (!closed) {
              const he = providerErrorToHttp(e);
              status = he.code;
              send("error", { code: he.code, message: he.message, fallback: true });
            }
          } finally {
            abortAll(); // no-op if already finished; releases the upstream connection otherwise
            try {
              await it.return?.();
            } catch { /* provider already failed */ }
            // D80: the client aborted (the app redoes its preliminary answer when the user keeps talking):
            // the request does not count against the user's own minute/day allowance. Network, global and
            // new-user windows stay counted, so aborting cannot buy free answers.
            const aborted = closed && !doneSent;
            if (aborted) {
              status = "aborted";
              try {
                // Oscar 2026-11-08: the new-session window is given back as well (network and global stay counted)
                const newWin = appExtra.filter((c) => c.key.includes(":new:u:"))
                  .map((c) => ({ key: c.key, windowSec: c.windowSec }));
                await deps.rateLimiter.release?.([...userWindows("answer", user.id), ...newWin], 1, countedAt);
              } catch (e) {
                console.error("rate_release_failed", e instanceof Error ? e.message : String(e));
              }
            }
            const rec = usage(status);
            console.log(JSON.stringify({
              evt: "answer",
              ...rec,
              user_id: undefined,
              auth_ms: Math.round(tAuth),
              limits_ms: limitsMs === null ? null : Math.round(limitsMs),
              llm_first_chunk_ms: llmFirstTokenMs === null ? null : Math.round(llmFirstTokenMs),
              cache_read: cacheRead,
              direct,
              cold,
              answer_type: answerType,
              continuation,
            }));
            try {
              await deps.recordUsage(rec);
            } catch (e) {
              console.error("usage_log_failed", e instanceof Error ? e.message : String(e));
            }
            if (!closed) {
              closed = true;
              try {
                controller.close();
              } catch { /* already closed */ }
            }
          }
        },
        cancel() {
          closed = true;
          abortAll();
        },
      });

      return new Response(stream, { status: 200, headers: { ...SSE_HEADERS, ...CORS_HEADERS } });
    } catch (e) {
      return errorResponse(toHttpError(e));
    }
  };
}
