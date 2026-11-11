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
import { withDeadline } from "./llm/deadline.ts";
import {
  aboutTopic,
  checkLink,
  domainOf,
  isResourceRequest,
  NO_RESOURCE,
  parseResource,
  RESOURCE_DOMAINS,
  RESOURCE_PROMPT,
  resourceOf,
  resourceTopic,
  spokenFor,
} from "./resource.ts";
import { selfAnswer } from "./self.ts";
import { aboutOther, CRISIS_CHECK_PROMPT, CRISIS_OTHER, CRISIS_SELF, crisisLevel, crisisVerdict } from "./crisis.ts";
import { type ParserEvent, ResponseParser } from "./parser.ts";
import { classifyAnswerType, detectContinuation, isShortFactQuestion } from "./length.ts";
import { buildPersonaUserMessage, personaPlan, personaSystemPrompt } from "./personas.ts";
import { computeFollowUp, computeFragment, spokenComputed } from "./calc.ts";
import { computeMath, isWordProblem } from "./mathcheck.ts";
import { type CommandTask, commandTask, detectRule, funCommand, socialRequest } from "./commands.ts";
import { ACTION_REQUEST, confirmText, isPhoneTool, PHONE_TOOLS_RULE, phoneToolDefs, toolKind, toolRoundMessages, validatePhoneInput } from "./phonetools.ts";
import { APP_COMMAND_SURE, currentMode, detectAppCommand } from "./appcommand.ts";
import { applicable, describe, detectCorrection, profileOf } from "../memory/settings.ts";

/** K9: tasks that ask for one check question (only the question is said, as for "förhör mig"). */
const FREE_INSTRUCTION_NOTE =
  "The fragment is the student's spoken instruction to you (said after \"Lumen\"), not a question: carry it out on the last answer in <recent_qa> or the current topic, in the usual spoken style. Never answer it as a question about its own words and never silence.";
/** K10.2: what each learned setting means for this answer (shown with its readable line). */
const PREF_RULE: Record<string, string> = {
  "length:shorter": "at most three short sentences, the core only",
  "length:longer": "a developed answer, clearly longer than usual, with the why and the details",
  "simplicity:simpler": "everyday words and short sentences of at most twelve words each; explain every subject term in plain words; no extra terms",
  "examples:more": "always at least TWO different concrete everyday examples (more than you would give otherwise), each introduced with \"Till exempel\" or \"Ett annat exempel är\"",
  "accuracy:careful": "double-check every fact and leave out anything you are not sure of",
};
/** K13.1: short answer first, then the developed answer after a marker (the app keeps it for "ja"/"mer"/a nod). */
export const TWO_LEVEL_RULE = `

TWO LEVELS (K13, this request; it replaces the length rules above): first the SHORT answer: one or two sentences, at most 30 words, correct, with the single most important point, no check question. Then a line with only [[MER]]. Then the DEVELOPED answer at A level for the student: the concepts, how they connect, one concrete example and the nuance that matters, in four to seven sentences. The developed answer continues from the short one and never repeats or rephrases it; it may end with one check question when the style rules allow one. Nothing is said about the two parts.`;
const MORE_MARK = "[[MER]]";
/** K17.2: the end-of-session summary (the app keeps it as study cards, D81, and in Anteckningar). */
const SESSION_END_RULE =
  "The student just ended the study session. Say, in four short spoken sentences and nothing else: the three most important points of what was studied in <recent_qa> (one sentence each, with the key terms), then one sentence that starts with \"Det du var osäker på var\" and names the concepts the student got wrong or was unsure of (from <concept_stats> and the graded replies in <recent_qa>; when there were none, say \"Du hade allt rätt i dag\"). Nothing new, no question.";
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
  cleanDomain,
  isFollowUp,
  isOrdinalFact,
  isPersonQuote,
  NO_GUESS_NOTE,
  SAME_SOURCE_NOTE,
  SEARCH_MARK_RULE,
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
import { parseSavedCheck, rankSaved, SAVED_CHECK_PROMPT, type SavedAnswer, savedCheckUser } from "./savedanswers.ts";
import { numbersToSpeech } from "./svnum.ts";
import {
  filterReasons,
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
  systemPromptFor, GRADE_NOTE, isQuizRequest, lastQuestion, QUIZ_NOTE, askedQuestions, looksLikeQuestion, sanitizeTagged,
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
  /** K12: spoken instructions (commands, calibrations, free instructions) are counted apart from questions. */
  commandLimits?: Limits;
  /** D52: model + prices (USD / MTok) for Rizz suggestions (Sonnet 5.5 by default; Haiku for the rest). */
  rizzModel?: string;
  /** D87: model for Provläge (persona tutor in mode tutor); unset = the provider's default (Haiku). */
  tutorModel?: string;
  /** K29: short fact questions in Provläge on the provider's default model (Haiku); off by default (TUTOR_FACT_ROUTE=1). */
  tutorFactRoute?: boolean;
  /** K5: the public demo's model (first impression; DEMO_MODEL overrides, "" = the default model). */
  demoModel?: string;
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
  webLimits: { perMinute: 5, perDay: 20, globalPerDay: 150 }, // Oscar O20: a recipe and two follow-ups in a minute
  // K12 (Toby T6 #7: 429 on quick instructions in Socialt/Rizz): instructions have their own budget
  commandLimits: { perMinute: 15, perDay: 300, globalPerDay: 3000 },
  // Oscar 2026-11-08: 40 (was 20) and aborted calls are given back here too
  appGuard: { networkPerDay: 1500, newUserAgeSec: 600, newUserPerHour: 40 },
  rizzModel: "claude-sonnet-5-5",
  rizzPriceInPerMTok: 2,
  rizzPriceOutPerMTok: 10,
  // K2 (2026-11-09): Provläge on Sonnet 5.5, the only model over the 90 % target in the D87 bank (DECISIONS D90);
  // TUTOR_MODEL overrides it (e.g. back to Haiku), the demo never uses it
  tutorModel: "claude-sonnet-5-5",
  // K29 measured (2026-11-10, 20 short fact questions, Sonnet judge): Haiku correct 75 % vs Sonnet 100 %, so off
  tutorFactRoute: false,
  // K5 (2026-11-10): the demo on Sonnet too (Haiku's demo answers had Swedish slips); within the demo caps
  // (600 questions a day, 160 tokens each) at most about 3 USD a day
  demoModel: "claude-sonnet-5-5",
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
  /** K19: fetch used to check a resource link (tests). */
  fetchImpl?: typeof fetch;
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
      // K27: a quote inside a follow-up (echo.quoted) keeps the whole fragment
      const body = echo.echoed && !echo.quoted ? { ...body0, fragment: echo.rest } : body0;
      // K21 (BLOCKER, safety): words about not wanting to live, suicide or self-harm always get a warm answer with a
      // way to help, in every mode (also the demo), before anything else and whatever the model would call it
      const provider0 = deps.provider;
      const othersSaid = (body0.social?.transcript ?? []).slice(-2).filter((x) => x.speaker !== "user").map((x) => x.text);
      // Oscar O17: a strong hit answers at once; a weak one (first person + a word about living, dying or harm, or an
      // everyday reading of a strong pattern) gets a one-word check by the small model first; a failed check = answer
      const otherPersona = body0.persona === "social" || body0.persona === "interview" || aboutOther(body0.fragment);
      const fragLevel = crisisLevel(body0.fragment);
      const otherLevels = othersSaid.map(crisisLevel);
      let crisisWho: "self" | "other" | null = fragLevel === "strong"
        ? (otherPersona ? "other" : "self")
        : otherLevels.includes("strong")
        ? "other"
        : null;
      if (!crisisWho) {
        const weak = [...(fragLevel === "weak" ? [body0.fragment] : []), ...othersSaid.filter((_, i) => otherLevels[i] === "weak")];
        if (weak.length) {
          let yes = true;
          let reply = "";
          try {
            if (!provider0) throw new Error("no provider");
            for await (const c of provider0.stream({
              system: CRISIS_CHECK_PROMPT,
              user: `<utterance>${sanitizeTagged(weak.join(" / ").slice(0, 600))}</utterance>`,
              maxTokens: 5,
              cacheSystem: true,
              noThinking: true,
              signal: AbortSignal.timeout(4000),
            })) if (c.type === "text") reply += c.text;
            yes = crisisVerdict(reply);
          } catch (e) {
            console.warn("crisis_check_failed", e instanceof Error ? e.message.slice(0, 120) : String(e)); // fail safe: answer
          }
          console.log(JSON.stringify({ event: "crisis_check", verdict: yes, reply: reply.trim().slice(0, 10) }));
          if (yes) crisisWho = fragLevel === "weak" && !otherPersona ? "self" : "other";
        }
      }
      const crisisSelf = crisisWho === "self";
      const crisisOther = crisisWho === "other";
      if (crisisSelf || crisisOther) {
        const text = crisisSelf ? CRISIS_SELF : CRISIS_OTHER;
        const totalMs = Math.round(now() - t0);
        console.warn(JSON.stringify({ event: "crisis_answer", mode: body0.mode, persona: body0.persona, who: crisisSelf ? "self" : "other" }));
        try {
          await deps.recordUsage({
            user_id: user.id,
            endpoint: "answer",
            mode: body0.mode,
            language: body0.language,
            provider: "local",
            model: "crisis",
            is_question: true,
            confidence: 1,
            input_tokens: null,
            output_tokens: null,
            ttft_ms: totalMs,
            total_ms: totalMs,
            est_cost_usd: 0,
            status: "ok",
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
            is_question: true,
            needs_confirmation: false,
            answer_type: "fact",
            relation: null,
            safety: "crisis",
          }),
          ...(body0.persona === "social" && body0.social
            ? [sseFrame("suggestions", [text])]
            : [sseFrame("delta", { text })]),
          sseFrame("done", {
            answered: true,
            safety: "crisis",
            timing: { meta_ms: totalMs, ttft_ms: totalMs, llm_first_token_ms: null, total_ms: totalMs },
            breakdown: { direct: true, cold, answer_type: "fact", continuation: null },
            usage: { input_tokens: 0, output_tokens: 0, cache_read_tokens: 0, web_searches: 0, model: "crisis" },
            summary: null, // never stored
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

      // K20: a question about Lumen itself ("är du en robot", "lyssnar du hela tiden", "sparar du det jag säger") gets
      // the honest answer of "Om appen", in code (where others talk only with "Lumen" first)
      const selfText = !demo && (!(body.persona === "social" || body.persona === "interview") || /^\s*(?:hej\s+|okej\s+)?lumen\b/iu.test(body.fragment))
        ? selfAnswer(body.fragment)
        : null;
      if (selfText) {
        const totalMs = Math.round(now() - t0);
        const frames = [
          sseFrame("meta", { reconstructed_question: body.fragment, confidence: 1, is_question: true, needs_confirmation: false, answer_type: "fact", relation: null }),
          sseFrame("delta", { text: selfText }),
          sseFrame("done", {
            answered: true,
            timing: { meta_ms: totalMs, ttft_ms: totalMs, llm_first_token_ms: null, total_ms: totalMs },
            breakdown: { direct: true, cold, answer_type: "fact", continuation: null },
            usage: { input_tokens: 0, output_tokens: 0, cache_read_tokens: 0, web_searches: 0, model: "self" },
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

      // K10.1: a request to control the app in the user's own words. Sure (>= 0.8): no answer, the app does it.
      const appCmd = demo || body.sessionEnd ? null : detectAppCommand(body.fragment, currentMode(body)); // K17.2: the summary is asked for
      if (appCmd && appCmd.confidence >= APP_COMMAND_SURE) {
        const totalMs = Math.round(now() - t0);
        const frames = [
          sseFrame("meta", {
            reconstructed_question: body.fragment,
            confidence: 1,
            is_question: false,
            needs_confirmation: false,
            answer_type: "fact",
            app_command: appCmd,
          }),
          sseFrame("done", {
            answered: false,
            timing: { meta_ms: 0, ttft_ms: null, llm_first_token_ms: null, total_ms: totalMs },
            breakdown: { direct: true, cold, answer_type: "fact", continuation: null },
            usage: { input_tokens: 0, output_tokens: 0, cache_read_tokens: 0, web_searches: 0, model: "app_command" },
            summary: null,
            memory_add: null,
            app_command: appCmd,
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

      // K19: "har du en film om fotosyntes?": one checked link from Swedish learning resources, and one sentence
      if (!demo && !personaPlan(body) && body.mode !== "auto" && body.mode !== "interview_prep" && isResourceRequest(body.fragment)) {
        const wl = await enforceLimits(deps.rateLimiter, "answer-web", user.id, cfg.webLimits ?? DEFAULT_CONFIG.webLimits!);
        const rl = await enforceLimits(deps.rateLimiter, "answer", user.id, cfg.limits, 1, appExtra);
        if (!rl.allowed) {
          throw new HttpError(429, "rate_limited", "Too many requests", { fallback: true, retryAfterSec: rl.retryAfterSec });
        }
        const topic = resourceTopic(body.fragment, body.context.recent_qa.at(-1)?.q);
        const grade = /Årskurs:\s*([^.]+)/u.exec(body.personaSetup)?.[1]?.trim();
        let text = "";
        let inTok = 0, outTok = 0, searches = 0;
        if (wl.allowed) {
          try {
            for await (const c of provider.stream({
              system: "You find learning resources for a Swedish school student." + RESOURCE_PROMPT,
              user: `<topic>${sanitizeTagged(topic)}</topic>${grade ? `\n<grade>${sanitizeTagged(grade)}</grade>` : ""}\n<request>${sanitizeTagged(body.fragment)}</request>`,
              maxTokens: 400,
              cacheSystem: true,
              tools: [{ type: "web_search_20250305", name: "web_search", max_uses: 2, allowed_domains: RESOURCE_DOMAINS }],
              timeoutMs: 25_000,
              signal: req.signal,
            })) {
              if (c.type === "text") text += c.text;
              else if (c.type === "usage") {
                inTok = c.inputTokens ?? inTok;
                outTok = c.outputTokens ?? outTok;
                searches = c.webSearches ?? searches;
              }
            }
          } catch (e) {
            console.warn("resource_search_failed", e instanceof Error ? e.message.slice(0, 150) : String(e));
          }
        }
        // the link is checked in code: on the list, answers 200, about the topic; otherwise no link is passed on
        const found = parseResource(text);
        let resource = found && domainOf(found.url) ? resourceOf(found.url, found.title) : null;
        let check: { ok: boolean; status: number; pageTitle: string } | null = null;
        if (resource) {
          check = await checkLink(resource.url, deps.fetchImpl ?? fetch);
          if (!check.ok || !aboutTopic(topic, resource.title, check.pageTitle, resource.url)) resource = null;
        }
        const said = text.replace(/LÄNK:[^\n]*\n?/iu, "").trim();
        const spoken = numbersToSpeech(resource ? spokenFor(resource, topic, said) : NO_RESOURCE);
        console.log(JSON.stringify({ event: "resource", found: !!found, ok: !!resource, status: check?.status ?? null }));
        const totalMs = Math.round(now() - t0);
        const cost = ((inTok * cfg.priceInPerMTok) + outTok * cfg.priceOutPerMTok) / 1e6 + searches * WEB_SEARCH_USD;
        try {
          await deps.recordUsage({
            user_id: user.id, endpoint: "answer", mode: body.mode, language: body.language, provider: provider.name,
            model: "resource", is_question: true, confidence: 1, input_tokens: inTok, output_tokens: outTok,
            ttft_ms: totalMs, total_ms: totalMs, est_cost_usd: cost, status: "ok", category: "övrigt", persona: body.persona,
          });
        } catch (e) {
          console.error("usage_log_failed", e instanceof Error ? e.message : String(e));
        }
        const frames = [
          sseFrame("meta", { reconstructed_question: body.fragment, confidence: 1, is_question: true, needs_confirmation: false, answer_type: "fact", relation: null }),
          sseFrame("delta", { text: spoken }),
          sseFrame("done", {
            answered: true,
            timing: { meta_ms: totalMs, ttft_ms: totalMs, llm_first_token_ms: null, total_ms: totalMs },
            breakdown: { direct: true, cold, answer_type: "fact", continuation: null },
            usage: { input_tokens: inTok, output_tokens: outTok, cache_read_tokens: 0, web_searches: searches, model: "resource", est_cost_usd: cost },
            summary: null,
            relation: null,
            source: resource ? domainOf(resource.url) : null,
            memory_add: null,
            resource,
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

      // K37 (D126): "Mina svar". A question that asks the same thing as one of the student's saved questions gets the
      // saved answer word for word (spoken form in the delta, the exact text in done.saved_answer). Sure in code = no
      // model call; a maybe = one short check by the small model of the best three; a failed check = the normal answer.
      const savedList = !demo && body.savedAnswers?.length && !body.social && (body.persona ?? "tutor") === "tutor" &&
          body.turn !== "user_answer" && !body.sessionEnd && !body.toolRound && !body.voiceInstruction
        ? body.savedAnswers
        : null;
      if (savedList) {
        const ranked = rankSaved(body.fragment, savedList, body.mode === "tutor" || body.mode === "auto");
        let pick: { item: SavedAnswer; via: "code" | "check" } | null = ranked[0]?.sure ? { item: ranked[0].item, via: "code" } : null;
        let checkIn = 0, checkOut = 0;
        if (!pick && ranked.length) {
          const cands = ranked.slice(0, 3);
          let reply = "";
          try {
            for await (const c of provider.stream({
              system: SAVED_CHECK_PROMPT,
              user: savedCheckUser(body.fragment, cands, sanitizeTagged),
              maxTokens: 4,
              cacheSystem: true,
              noThinking: true,
              signal: AbortSignal.timeout(2500),
            })) {
              if (c.type === "text") reply += c.text;
              else if (c.type === "usage") {
                checkIn = c.inputTokens ?? checkIn;
                checkOut = c.outputTokens ?? checkOut;
              }
            }
          } catch (e) {
            console.warn("saved_check_failed", e instanceof Error ? e.message.slice(0, 120) : String(e)); // no hit
            reply = "";
          }
          const k = parseSavedCheck(reply, cands.length);
          if (k !== null) pick = { item: cands[k].item, via: "check" };
          console.log(JSON.stringify({ event: "saved_check", n: cands.length, top: Number(cands[0].score.toFixed(2)), hit: k !== null }));
        }
        if (pick) {
          const rl = await enforceLimits(deps.rateLimiter, "answer", user.id, cfg.limits, 1, appExtra);
          if (!rl.allowed) {
            throw new HttpError(429, "rate_limited", "Too many requests", { fallback: true, retryAfterSec: rl.retryAfterSec });
          }
          const ns = new NumberStream();
          const spoken = ns.push(pick.item.a) + ns.finish();
          const totalMs = Math.round(now() - t0);
          const cost = (checkIn * cfg.priceInPerMTok + checkOut * cfg.priceOutPerMTok) / 1e6;
          try {
            await deps.recordUsage({
              user_id: user.id,
              endpoint: "answer",
              mode: body.mode,
              language: body.language,
              provider: pick.via === "check" ? provider.name : "local",
              model: "saved_answer",
              is_question: true,
              confidence: 1,
              input_tokens: checkIn || null,
              output_tokens: checkOut || null,
              ttft_ms: totalMs,
              total_ms: totalMs,
              est_cost_usd: cost,
              status: "ok",
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
              is_question: true,
              needs_confirmation: false,
              answer_type: "fact",
            }),
            sseFrame("delta", { text: spoken }),
            sseFrame("done", {
              answered: true,
              timing: { meta_ms: totalMs, ttft_ms: totalMs, llm_first_token_ms: null, total_ms: totalMs },
              breakdown: { direct: true, cold, answer_type: "fact", continuation: null },
              usage: { input_tokens: checkIn, output_tokens: checkOut, cache_read_tokens: 0, web_searches: 0, model: "saved_answer" },
              summary: null,
              relation: null,
              source: null,
              memory_add: null,
              saved_answer: { id: pick.item.id, text: pick.item.a, via: pick.via },
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
      }

      // K10.2 (measured: "kortare" was ignored 0/6 when only a line in the prompt said it): a learned length setting
      // drives the real length controls, the Provläge profile's explanation length or `length`
      const earlySubject = body.prefContext?.subject ?? /(?:^|\.\s*)Ämne:\s*([^.]+)/u.exec(body.personaSetup)?.[1]?.trim();
      const earlyPrefs = body.preferences?.length && !demo
        ? applicable(body.preferences, {
          mode: currentMode(body) ?? undefined,
          subject: earlySubject,
          exam: body.prefContext?.exam,
          answer_type: /^matem/iu.test(earlySubject ?? "") ? "math" : undefined,
        })
        : [];
      const lengthPref = earlyPrefs.find((x) => x.key === "length")?.value;
      if (lengthPref === "shorter" || lengthPref === "longer") {
        const want = lengthPref === "shorter" ? "korta förklaringar" : "utförliga förklaringar";
        if (body.mode === "tutor" && body.persona === "tutor" && body.personaSetup) {
          body.personaSetup = /Förklaringar:\s*[^.]*\./u.test(body.personaSetup)
            ? body.personaSetup.replace(/Förklaringar:\s*[^.]*\./u, `Förklaringar: ${want}.`)
            : `${body.personaSetup} Förklaringar: ${want}.`;
        } else if (!personaPlan(body)) {
          body.length = lengthPref === "shorter" ? "short" : "long";
        }
      }
      // K32 (D115): "sjung", "rappa", "berätta ett skämt", "säg det som en pirat" in every mode, answered to the user
      const funCmd = demo || body.sessionEnd ? null : funCommand(body.social?.calibrate || body.fragment,
        body.mode === "auto" || !!personaPlan(body));
      const direct = !!funCmd || (cfg.directModes && body.mode !== "auto") || !!personaPlan(body);
      // 'mer' / 'fortsätt' / 'förklara enklare' continue the last answer (needs history).
      const plan = funCmd ? null : personaPlan(body); // D42 persona / interview prep (null = ordinary flows)
      const continuation = !plan && body.context.recent_qa.length
        ? detectContinuation(body.fragment)
        : null;
      const tutor = body.mode === "tutor" && !funCmd;
      // K9: a spoken instruction from the command table ("ge ett exempel", "sammanfatta", "var säker" …)
      const command: CommandTask | null = funCmd ? funCmd : body.sessionEnd && !demo && !personaPlan(body)
        ? { task: "session_summary", rule: SESSION_END_RULE }
        : demo || continuation
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
      const counterQ = command?.task === "interview_help:counter_question"; // the answer is a question to ask
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
      const quoteCheck = textReq && isPersonQuote(body.fragment); // K11
      // K8 (Oscar O7 W1): prices search shops; not in Auto: there the web tools made the meta step call the price
      // question "not a question" (empty answer live), worse than the answer without a price
      let need =
        !textReq && !demo && !plan && !computed && body.mode !== "auto" && body.mode !== "interview_prep"
          ? needsWeb(body.fragment)
          : null;
      // K16.2: a short follow-up to an answer that came from a source searches that source again
      const lastSource = cleanDomain(body.context.recent_qa.at(-1)?.source);
      const followSource = lastSource && !textReq && !demo && !plan && !computed &&
          body.mode !== "auto" && body.mode !== "interview_prep" && body.mode !== "tutor" && isFollowUp(body.fragment)
        ? lastSource
        : null;
      if (followSource) need = { ...(need ?? { search: true, fetch: false }), search: true, extraDomains: [followSource] };
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
        else if (followSource) webNote = SAME_SOURCE_NOTE(followSource);
      }
      const answerType = (computed || webOn || demo) && !tutor ? "fact" : answerTypeBase;
      // K10.2: only the learned settings that apply to this context (mode, subject, exam, kind of answer)
      const prefSubject = body.prefContext?.subject ?? /(?:^|\.\s*)Ämne:\s*([^.]+)/u.exec(body.personaSetup)?.[1]?.trim();
      const applicableHere = body.preferences?.length && !demo
        ? applicable(body.preferences, {
          mode: currentMode(body) ?? undefined,
          subject: prefSubject,
          exam: body.prefContext?.exam,
          answer_type: computed || /^matem/iu.test(prefSubject ?? "") ? "math" : answerType === "study" ? "explanation" : "fact",
        })
        : [];
      // K13.3: the situation as one line (mode, subject, exam, time of day, others talking)
      const examDays = /\(om (\d{1,2}) dag(?:ar)?\)|\bom (\d{1,2}) dag(?:ar)?\b/u.exec(body.personaSetup);
      const days = examDays ? Number(examDays[1] ?? examDays[2]) : /\b(?:imorgon|i morgon)\b/iu.test(body.personaSetup) ? 1 : null;
      const hour = Number(new Intl.DateTimeFormat("sv-SE", { hour: "numeric", timeZone: "Europe/Stockholm" }).format((deps.clock ?? (() => new Date()))()));
      const situation = demo ? "" : [
        `läge: ${currentMode(body) ?? body.mode}`,
        prefSubject ? `ämne: ${prefSubject}` : "",
        days !== null ? `provet om ${days} ${days === 1 ? "dag" : "dagar"}` : "",
        Number.isFinite(hour) ? (hour < 6 ? "natt" : hour < 10 ? "morgon" : hour < 17 ? "dag" : hour < 22 ? "kväll" : "sen kväll") : "",
        body.situation?.othersTalking ? "andra pratar runt användaren" : "",
      ].filter(Boolean).join("; ");
      const prefLines = applicableHere.map((x) => `${describe(x)}: ${PREF_RULE[`${x.key}:${x.value}`] ?? ""}`.replace(/: $/, ""));
      // K13.3 (live: 3/5 shorter with only the situation line): others talking near the user = a short, discreet answer
      if (body.situation?.othersTalking && !demo) {
        prefLines.push("Andra pratar runt användaren: at most three short sentences, the core only, nothing the others need to hear");
      }
      // K10.3: the profile goes in its own cached system block after the shared prompt
      // K13 (Oscar O10 #4: "längre svar i kemi" followed into Frågor): with the settings at hand the profile is built
      // from those that apply here; the app's own profile line only when no settings are sent
      const profileText = demo ? "" : body.preferences?.length ? profileOf(applicableHere) : body.prefProfile ?? "";
      const systemTail = profileText
        ? `<user_profile>${sanitizeTagged(profileText)}</user_profile> How this user wants answers in this context, learned from their corrections: follow it unless the request asks otherwise.`
        : undefined;
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
      // K13.1: short first unless the learned default here is the long answer (2 of the last 3 "ja", K13.2)
      const longFirst = applicableHere.some((x) => x.key === "length" && x.value === "longer");
      const twoLevel = body.twoLevel === true && !demo && !plan && !command && !continuation && !computed &&
        !textReq && !need && !quiz && !gradeReply && (tutor || answerTypeBase === "study") && !longFirst;

      // D84: texts and quotes need the exact words: they use the stronger model (Rizz's), like Rizz
      const isRizz = plan?.kind === "rizz" || textReq || careful; // K9: "var säker" = the stronger model, one answer
      // D87: Provläge can run on its own model (TUTOR_MODEL); the measured choice is in DECISIONS D87
      // K29 (D115 T1): a short fact question in Provläge can go to the cheaper default model (TUTOR_FACT_ROUTE=1)
      const factRoute = !isRizz && tutor && !plan && !demo && !!cfg.tutorModel && cfg.tutorFactRoute === true &&
        !continuation && !computed && isShortFactQuestion(body.fragment);
      const tutorModel = !isRizz && tutor && !plan && !demo && cfg.tutorModel && !factRoute
        ? cfg.tutorModel
        : demo && cfg.demoModel // K5: the demo runs on the stronger model (priced like Provläge)
        ? cfg.demoModel
        : undefined;
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
      // K12: an instruction ("roligare", "ge mig tre", "förhör mig på …") never uses up the question budget
      const instruction = !demo && (!!command || !!continuation || plan?.kind === "calibrate" ||
        body.voiceInstruction === true || !!body.social?.calibrate || detectCorrection(body.fragment) !== null ||
        (!!body.social && socialRequest(body.fragment) !== null));
      const limitsP = (instruction
        ? enforceLimits(deps.rateLimiter, "answer-cmd", user.id, cfg.commandLimits ?? DEFAULT_CONFIG.commandLimits!, 1,
          appChecks("answer-cmd", await networkKey(req), user, cfg.appGuard ?? DEFAULT_CONFIG.appGuard!))
        : enforceLimits(deps.rateLimiter, "answer", user.id, cfg.limits, 1, appExtra)).then((r) => {
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
      // K35 (D122): phone tools the app can run, in the direct modes (Standardläge, Provläge), never in the demo
      const phoneOffer = [...(body.toolsAvailable ?? []), ...(body.toolRound ? [body.toolRound.call.name] : [])];
      const phoneTools = !demo && !plan && direct && body.mode !== "auto" && phoneOffer.length ? phoneToolDefs(phoneOffer) : undefined;
      const noSummary = plan?.kind === "rizz" || plan?.kind === "calibrate" || demo;
      const relationTag = direct && !plan && body.context.recent_qa.length > 0;
      // K16.1: in Frågor (push to talk, text) the model may answer only [[SÖK]] when it is not sure of a specific fact
      const askSearch = direct && !tutor && !plan && !demo && !need && !textReq && !computed &&
        body.mode !== "auto" && body.mode !== "interview_prep";
      const systemPrompt = (plan
        ? personaSystemPrompt(plan.kind, body)
        : direct
        ? systemPromptFor(answerType, tutor)
        : SYSTEM_PROMPT) +
        (relationTag ? RELATION_RULE : "") + (noSummary ? "" : SUMMARY_RULE) +
        (webOn ? WEB_PROMPT : "") + (textReq ? TEXT_PROMPT : "") + (askSearch ? SEARCH_MARK_RULE : "") +
        (twoLevel ? TWO_LEVEL_RULE : "") + (phoneTools ? PHONE_TOOLS_RULE : "");
      const baseTokens = plan?.maxTokens ?? (textReq ? 1100 : undefined) ?? (webOn ? 600 : undefined) ??
        (answerType === "study" ? cfg.maxTokensStudy : cfg.maxTokens);
      const maxTokens = demo
        ? demoCaps.answerMaxTokens + (relationTag ? 12 : 0)
        : baseTokens + (noSummary ? 0 : 80) + (relationTag ? 12 : 0);
      const tools = textOn ? textTools() : webOn && need ? webTools(need) : undefined;
      const allTools = tools && phoneTools ? [...tools, ...phoneTools] : tools ?? phoneTools;
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
        ...(prefLines.length ? { preferences: prefLines } : {}),
        ...(situation ? { situation } : {}),
        now: nowContext((deps.clock ?? (() =>
          new Date()))()),
        ...(computed ? { computed: computed.text } : {}),
        ...(webNote || ordinal
          ? { note: [webNote, ordinal ? ORDINAL_NOTE : ""].filter(Boolean).join(" ") }
          : {}),
      };
      // K11 (Oscar O5: a Sonnet call hung for 90 s): first text within 5 s (7.5 s with thinking), else the same
      // request once more on the default model without thinking; a web turn gets 12 s and no second try
      const thinking = wordProblem || careful;
      const llm = withDeadline(provider, {
        firstTextMs: tools ? 12_000 : thinking ? 7_500 : 5_000,
        idleMs: tools ? 12_000 : 4_000,
        fallbackModel: tools ? undefined : provider.model,
        log: (event, data) => console.warn(event, JSON.stringify(data)),
      });
      const iterator = llm
        .stream({
          system: systemPrompt,
          user: userFor(body, baseExtras),
          maxTokens,
          cacheSystem: true,
          ...(systemTail ? { systemTail } : {}),
          tools: allTools,
          // K35: the second call of a tool round: the user's turn, the tool call and the app's result
          ...(body.toolRound && phoneTools ? { messages: toolRoundMessages(userFor(body, baseExtras), body.toolRound) } : {}),
          ...(phoneTools && !body.toolRound && ACTION_REQUEST.test(body.fragment) ? { holdTextBeforeTool: true } : {}),
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
            quizOnly: quiz || counterQ, // D86: only the check question is said; K9: the interview counter question too
            subjectKnown: tutor && body.persona === "tutor" && !!body.personaSetup,
            interview: plan?.kind === "interview", // D77
            missingFact: missing ?? undefined,
            quoteCheck,
          });
          let pendingMeta: Record<string, unknown> | null = null;
          const flushMeta = () => {
            if (!pendingMeta) return;
            metaMs = now() - t0;
            send("meta", pendingMeta);
            pendingMeta = null;
          };
          // K13 (Oscar O10 #7: Frågor cut answers mid-word at the cap, "… kontakta vården direkt. ["): close to the cap
          // only whole sentences are said; what does not fit is dropped, and nothing is said after the cut
          let nearBuf = "";
          const emitText = (raw: string) => {
            // K16: a late search marker ("… femtusen invånare. [[SÖK]]", live 3/10) is never read aloud
            if (/\[\[S[ÖO]K\]\]/iu.test(raw)) console.warn("search_marker_late", JSON.stringify({ mode: body.mode }));
            if (/\[\[KRIS\]\]/iu.test(raw)) crisisLate = true; // K23: the crisis answer follows what was said
            let t = raw.replace(/\s*\[\[(?:S[ÖO]K|VET|KRIS)\]\]\s*/giu, " ").replace(/\s*\[+\s*$/u, "");
            // Oscar O13: raw search text was read aloud ("| Arjeplog |", "Nickname: …"): table bars and English
            // field labels never reach the voice
            if (webOn || searched || textOn) {
              t = t.replace(/\s*\|\s*/gu, ", ").replace(/,\s*,/gu, ",")
                .replace(/(?<![\p{L}])(?:Nickname|Population|Area|Elevation|Founded|Website|Coordinates|Type|Country|Region)\s*:\s*/gu, "");
            }
            if (!t.trim()) return;
            flushMeta();
            if (ttftMs === null) ttftMs = now() - t0;
            answerChars += t.length;
            send("delta", { text: t });
          };
          const deliver = (t: string) => {
            if (!t || closed || status === "truncated") return;
            if (answerChars + nearBuf.length + t.length <= maxChars - 200) {
              emitText(t);
              return;
            }
            nearBuf += t;
            const fits = maxChars - answerChars;
            let end = -1;
            for (const m of nearBuf.matchAll(/[.!?](?=\s|$)/gu)) if (m.index! + 1 <= fits) end = m.index! + 1;
            if (nearBuf.length > fits) {
              // no sentence end fits: when nothing was said yet, stop at the last whole word instead of saying nothing
              const out = end > 0
                ? nearBuf.slice(0, end)
                : answerChars === 0
                ? nearBuf.slice(0, fits).replace(/\s+\S*$/u, "")
                : "";
              nearBuf = "";
              emitText(out);
              status = "truncated";
              stop = true;
              return;
            }
            if (end > 0) {
              emitText(nearBuf.slice(0, end));
              nearBuf = nearBuf.slice(end);
            }
          };
          const flushNear = () => {
            const rest = nearBuf;
            nearBuf = "";
            if (rest && status !== "truncated") emitText(rest);
          };
          const rizz = plan?.kind === "rizz";
          const calib = plan?.kind === "calibrate"; // D69: collect the merged calibration, send nothing else
          let calibBuf = "";
          let calibration: string | null = null;
          let rizzBuf = "";
          // K23: the head is held in every direct answer until it is clear it is not a marker ([[KRIS]], [[SÖK]], [[VET]]);
          // an answer that does not start with "[" passes at once
          let headBuf: string | null = askSearch || (direct && !plan) ? "" : null;
          let crisisMarked = false;
          let crisisLate = false;
          let toolPending = false; // K35: a phone tool call was sent; the app runs it and sends a tool_round
          // K13.1: the developed answer after [[MER]]: its own post-processing, sent as more_delta, kept for done
          let inMore = false;
          let markBuf = "";
          let moreText = "";
          const morePost = new AnswerPost({ previousAnswers: [], trimQuestion: false, tutor, heard: body.fragment });
          const sendMore = (t: string) => {
            if (!t || closed || moreText.length >= 2000) return;
            const cut = t.slice(0, 2000 - moreText.length);
            moreText += cut;
            send("more_delta", { text: cut });
          };
          const pushMore = (t: string) => sendMore(morePost.push(t));
          // K13 (live: the short part was 103 words p50): the spoken part ends after two sentences or ~35 words at a
          // sentence end; what the model wrote beyond that is the start of the developed answer
          let shortDone = false;
          let shortFinished = false;
          let shortSentences = 0;
          let shortWords = 0;
          const sayShort = (t: string) => {
            if (!t) return;
            if (shortDone) {
              sendMore(t);
              return;
            }
            const wordsIn = (x: string) => (x.match(/[\p{L}\p{N}]+/gu) ?? []).length;
            let cut = -1;
            for (const m of t.matchAll(/[.!?](?=\s|$)/gu)) {
              shortSentences++;
              if (shortSentences >= 2 || shortWords + wordsIn(t.slice(0, m.index! + 1)) >= 35) {
                cut = m.index! + 1;
                break;
              }
            }
            if (cut < 0) {
              shortWords += wordsIn(t);
              deliver(t);
              return;
            }
            deliver(t.slice(0, cut));
            shortDone = true;
            const rest = t.slice(cut).replace(/^\s+/u, "");
            if (rest) sendMore(rest);
          };
          let searchMarked = false;
          let retrySystem = systemPrompt;
          let retryTools = tools;
          let searched = false;
          const rizzCount = rizz ? suggestionCount(body) : 0; // D72: 1 by default, max 5 when asked
          let previewSent = false;
          let previewText: string | null = null;
          const emit = (ev: ParserEvent) => {
            if (ev.type === "meta" && ev.meta.self_harm_risk) {
              crisisMarked = true; // K23: the model's own flag (Auto): the crisis answer, whatever is_question says
              stop = true;
              return;
            }
            if (ev.type === "meta") {
              const m = {
                reconstructed_question: ev.meta.reconstructed_question,
                confidence: ev.meta.confidence,
                is_question: ev.meta.is_question,
                needs_confirmation: ev.meta.needs_confirmation,
                answer_type: ev.meta.answer_type,
                relation: ev.meta.relation ?? null,
                ...(appCmd ? { app_command: appCmd } : {}), // K10.1: unsure (< 0.8): the app may offer it
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
            } else if (twoLevel && !stop) {
              // K13.1: text before [[MER]] is the short answer (spoken), after it the developed one (more_delta)
              if (inMore) {
                pushMore(ev.text);
              } else {
                markBuf += ev.text;
                const i = markBuf.indexOf(MORE_MARK);
                if (i >= 0) {
                  // the short answer is complete: flush every held sentence now (a held last sentence came only at the end)
                  sayShort(post.push(markBuf.slice(0, i) + "\n"));
                  sayShort(post.finish());
                  shortFinished = true;
                  inMore = true;
                  const rest = markBuf.slice(i + MORE_MARK.length);
                  markBuf = "";
                  if (rest) pushMore(rest);
                } else {
                  // keep a possible start of the marker ("[", "[[M" …) for the next chunk
                  const keep = /\[(?:\[(?:M(?:E(?:R(?:\])?)?)?)?)?$/u.exec(markBuf)?.[0] ?? "";
                  const say = markBuf.slice(0, markBuf.length - keep.length);
                  markBuf = keep;
                  if (say) sayShort(post.push(say));
                }
              }
              if (silenceOn && post.silenceMarked) stop = true;
              if (post.silencedLate) stop = true;
            } else {
              if (!stop) deliver(post.push(ev.text));
              if (silenceOn && post.silenceMarked) stop = true; // D75: nothing more will be said
              if (post.silencedLate) stop = true; // 2026-11-08: marker after text: say nothing more
            }
          };
          const feed = (text: string) => {
            for (const ev of parser.push(text)) emit(ev);
          };
          const flushHead = () => {
            if (headBuf === null) return;
            const h = headBuf.replace(/\[\[VET\]\]\s*/iu, "");
            headBuf = null;
            if (h) feed(h);
          };
          const handle = (chunk: LLMChunk) => {
            if (chunk.type === "cite") {
              post.addCited(chunk.cited);
              return;
            }
            if (chunk.type === "tool_use") {
              // K35: validated before anything reaches the app; an unknown tool or bad input is dropped (logged)
              const input = isPhoneTool(chunk.name) ? validatePhoneInput(chunk.name, chunk.input) : null;
              if (!input || !isPhoneTool(chunk.name) || toolPending) {
                console.warn(JSON.stringify({ event: "tool_call_dropped", name: chunk.name.slice(0, 40), valid: !!input }));
                return;
              }
              toolPending = true;
              flushMeta();
              if (ttftMs === null) ttftMs = now() - t0;
              send("tool_call", { id: chunk.id, name: chunk.name, input, confirm: confirmText(chunk.name, input), kind: toolKind(chunk.name) });
              console.log(JSON.stringify({ event: "tool_call", name: chunk.name, mode: body.mode }));
              return;
            }
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
            } else if (headBuf !== null) {
              // K16.1: the first characters decide whether the model asked for a search ([[SÖK]])
              headBuf += chunk.text;
              const head0 = headBuf.replace(/^\s*\[\[REL [^\]]*\]\]\s*/u, "");
              if (/^\s*\[\[REL/u.test(headBuf) && !headBuf.includes("]]")) return; // the relation tag is not complete yet
              if (/^\s*\[\[(?:V(?:E(?:T(?:\])?)?)?)?$/iu.test(head0)) return; // the [[VET]] marker is not complete yet
              if (/^\s*\[\[KRIS\]\]/iu.test(head0)) {
                crisisMarked = true; // K23: the model's own safety layer (direct modes)
                headBuf = null;
                stop = true;
              } else if (/^\s*\[\[S[ÖO]K\]\]/iu.test(head0) && askSearch) {
                searchMarked = true;
                headBuf = null;
                stop = true;
              } else if (head0.replace(/\s+/g, "").length >= 8 || (!/^\s*\[/.test(head0) && head0.trim().length > 0)) {
                flushHead();
              }
            } else feed(chunk.text);
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
              if (crisisMarked) break;
              if (rizz || calib || closed) break;
              let note: string | null = null;
              let history = body.context.recent_qa;
              if (post.duplicate) {
                note =
                  "Your previous reply repeated an earlier answer. The fragment is a new request: answer only the fragment.";
                const m = post.dup.matched;
                if (m) history = history.filter((x) => x.a !== m);
              } else if (searchMarked && attempt === 0) {
                // K16.1: the model is not sure: search once (within the web caps), or say it does not know
                const wl = await enforceLimits(deps.rateLimiter, "answer-web", user.id, cfg.webLimits ?? DEFAULT_CONFIG.webLimits!);
                if (wl.allowed) {
                  retrySystem = systemPrompt.replace(SEARCH_MARK_RULE, "") + WEB_PROMPT;
                  retryTools = webTools({ search: true, fetch: false });
                  searched = true;
                  note = "Search the web for this question and answer from the sources.";
                } else {
                  retrySystem = systemPrompt.replace(SEARCH_MARK_RULE, "");
                  note = NO_GUESS_NOTE;
                }
                stop = false;
                console.warn("search_marked", JSON.stringify({ allowed: wl.allowed }));
              } else {
                flushHead();
                if (!stop) { for (const ev of parser.finish()) emit(ev); }
                const fin = shortFinished ? "" : post.finish();
                // K1.4: "förhör mig" never repeats a question of this session (held until here, nothing was sent)
                const repeated = quiz && attempt === 0 && !stop && isRepeatedQuestion(fin, askedQuestions(body));
                if (!repeated) (twoLevel ? sayShort : deliver)(fin);
                if (repeated) {
                  note =
                    "Your previous check question was already asked in this session (see <already_asked>). Ask ONE different check question about another part of the topic.";
                } else if (post.unverifiedQuote && ttftMs === null && !stop) {
                  // K11: the quote was not in what the search gave: nothing was said yet, ask for own words
                  note =
                    "The quote you gave was not found word for word in the search results. Do not quote anything: start with \"Jag kan inte citera det ordagrant, men\" and say in your own words what the person writes or says about it, without quotation marks, and name a work only when you are sure the person wrote it.";
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
              it = llm.stream({
                system: retrySystem,
                user: userFor({ ...body, context: { ...body.context, recent_qa: history } }, {
                  ...baseExtras,
                  note,
                }),
                maxTokens: searched ? Math.max(maxTokens, 600 + 80) : maxTokens,
                cacheSystem: true,
                ...(systemTail ? { systemTail } : {}),
                tools: retryTools,
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
                web: webOn || !!need || searched,
                source: textReq,
                tutor,
                silence: silenceOn,
                inputMeta: silenceOn,
                heard: body.fragment,
                quizOnly: quiz || counterQ,
                subjectKnown: tutor && body.persona === "tutor" && !!body.personaSetup,
                interview: plan?.kind === "interview",
                missingFact: missing ?? undefined,
                quoteCheck,
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
                options = FALLBACK_SUGGESTIONS.slice(
                  0,
                  rizzCount,
                );
                status = "filtered";
                console.log(JSON.stringify({ event: "suggestions_filtered", ...filterReasons(rizzBuf) }));
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
            if (twoLevel) {
              if (!inMore && markBuf && status !== "truncated") sayShort(post.push(markBuf)); // no marker came
              markBuf = "";
              if (inMore) sendMore(morePost.finish());
            }
            flushNear();
            // K23: the model flagged a crisis (Auto meta or [[KRIS]]): the fixed caring answer, never silence
            if (crisisMarked || crisisLate) {
              const crisisText = aboutOther(body.fragment) || plan ? CRISIS_OTHER : CRISIS_SELF;
              if (crisisMarked && ttftMs === null) {
                pendingMeta = null;
                metaMs = now() - t0;
                send("meta", {
                  reconstructed_question: body.fragment, confidence: 1, is_question: true, needs_confirmation: false,
                  answer_type: "fact", relation: null, safety: "crisis",
                });
              }
              status = "ok";
              emitText((crisisLate ? " " : "") + crisisText);
              console.warn(JSON.stringify({ event: "crisis_answer", mode: body.mode, who: "model", late: crisisLate && !crisisMarked }));
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
              summary: noSummary || crisisMarked || crisisLate ? null : post.summary ?? (twoLevel ? morePost.summary : null),
              ...(crisisMarked || crisisLate ? { safety: "crisis" } : {}),
              ...(twoLevel ? { more: moreText.trim() || null } : {}),
              relation: post.relation ?? parser.meta?.relation ?? null,
              source: post.source,
              memory_add: null,
              calibration,
              ...(toolPending ? { tool_pending: true } : {}),
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
