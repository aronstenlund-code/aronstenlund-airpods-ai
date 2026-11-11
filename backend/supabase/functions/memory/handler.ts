import { type Authenticator } from "../_shared/auth.ts";
import { CORS_HEADERS, errorResponse, HttpError, toHttpError } from "../_shared/errors.ts";
import { appChecks, enforceLimits, type Limits, type RateLimiter } from "../_shared/ratelimit.ts";
import { networkKey } from "../_shared/demo.ts";
import { readLimitedJson } from "../answer/validate.ts";
import { nowContext } from "../answer/datecalc.ts";
import { sanitizeTagged } from "../answer/prompt.ts";
import { crisisLevel } from "../answer/crisis.ts";
import type { LLMProvider } from "../answer/llm/types.ts";
import { SETTINGS_LIMITS, applyCorrection, applySignal, describe, detectCorrection, profileOf, readContext, readSettings } from "./settings.ts";

/**
 * D80 (owner): `POST /memory` - memory extraction outside the answer path. The app sends one turn (the
 * wearer's own words and, optionally, the answer) plus the memory it already has; the reply lists new or
 * changed facts about the wearer (tests, dates as absolute dates, subjects, wishes, rules). Never sensitive
 * categories. Nothing is stored or logged: the text is processed and dropped (usage keeps metadata only).
 *
 * Request:  {"turn": {"question": "...", "answer": "..."?, "mode"?}, "memories": ["..."]?, "language": "sv"|"en"?}
 * Response: {"add": ["..."], "update": [{"old": "...", "new": "..."}], "remove": ["..."], "skipped"?: "no_self_reference"}
 *
 * K10.2: {"correction": {"text": "kortare", "context": {mode?, subject?, exam?, answer_type?: fact|explanation|math}},
 *         "settings": [{key, value, scope, n?}]} -> {"settings": [...], "setting": {..., text}, "widened", "profile"}
 * (code only, no model call, nothing stored).
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

/** O47: the small model's check of a short utterance the code did not recognise as a correction. */
export const CORRECTION_CHECK_PROMPT =
  `A Swedish student just heard an answer from their study assistant (you) and said <said>. Decide whether <said> is feedback about YOUR LAST ANSWER, the way you answered: its length, how hard it was, examples in it, or whether it was right. Reply with exactly one word:
shorter (your answer was too long, too much talk, wants less or only the answer),
longer (wants more of your answer, more detail, develop it),
simpler (your answer was too hard, wants easier words, did not understand your answer),
examples (wants examples in your answers),
careful (says or doubts that your answer was right: it was wrong, false, made up),
none (anything else).
It is none when <said> is about something other than your answer: a book, a test, a teacher, a friend, history, the student's own problem ("boken är för svår", "läraren pratar för mycket", "det var fel av kungen"); when it is a question or a request for content, also when it contains "exempel", "fel" or "förklara" ("kan du ge exempel på ädelgaser", "jag förstår inte vad X är, kan du förklara", "förenkla bråket"); or when it is a command such as pause or stop.
When unsure, reply none.`;

export function correctionFromCheck(reply: string): { key: "length" | "simplicity" | "examples" | "accuracy"; value: string } | null {
  switch (reply.trim().toLowerCase().replace(/[^a-z]/g, "")) {
    case "shorter": return { key: "length", value: "shorter" };
    case "longer": return { key: "length", value: "longer" };
    case "simpler": return { key: "simplicity", value: "simpler" };
    case "examples": return { key: "examples", value: "more" };
    case "careful": return { key: "accuracy", value: "careful" };
    default: return null;
  }
}

/** Words that show the wearer speaks about themselves; without one the model is not called at all. */
const SELF =
  /(?<!\p{L})(jag|mig|min|mitt|mina|vi|oss|vår|vårt|våra|me|my|mine|we|our|i am|i'm|i've|i have|i will|i'll|i need|i want|i study|i go|i like|i prefer|always|never|from now on|alltid|aldrig|i fortsättningen|från och med nu|framöver|kortare|längre)(?!\p{L})/iu;

/**
 * Never kept even if the model returns it. D113 B5 (K34/K28): only health, crisis and ID numbers (personnummer,
 * samordningsnummer, card and account numbers, passwords and PIN codes); everything else (faith, politics, origin,
 * interests, friends) is no longer stopped in code (D113 A5). Oscar O36: illnesses as stems, crisis in the third
 * person as the model writes memories ("Brukar rispa sig"), and the crisis layer of /answer on top (isCrisisMemory).
 * Kept on one line: Oscar's O28/O36 tests read the literal from this file.
 */
const SENSITIVE_RAW =
  /allerg|(?<![\p{L}])sjuk(?:dom\p{L}*|skriv\p{L}*|hus\p{L}*|a|domar)?(?![\p{L}])|diagnos|adhd|(?<![\p{L}])add(?![\p{L}])|autism|asperger|diabet|astma|epilep|celiaki|gluten|laktos|intolerans|dyslexi|dyskalkyli|depress|ångest|ätstörning|anorexi|bulimi|migrän|insulin|psoriasis|eksem|reuma|crohn|(?<![\p{L}])ibs(?![\p{L}])|cancer|tumör|leukemi|hjärtfel|hjärtsjuk|hjärtproblem|hjärtsvikt|blodtryck|hörapparat|cochlea|(?<![\p{L}])döv\p{L}*|hörselskad|nedsatt (?:hörsel|syn)|synskad|(?<![\p{L}])blind(?![\p{L}])|rullstol|funktionsnedsätt|funktionsvariation|(?<![\p{L}])npf(?![\p{L}])|tourette|(?<![\p{L}])ocd(?![\p{L}])|tvångssyndrom|bipolär|schizofren|psykos|(?<![\p{L}])ptsd(?![\p{L}])|(?<![\p{L}])hiv(?![\p{L}])|kronisk|tinnitus|narkolepsi|sömnstörning|sömnproblem|insomni|pacemaker|opererad|opererats|opereras|operation|(?<![\p{L}])gips(?![\p{L}])|hjärnskakning|vårdcentral|läkarbesök|läkartid|hos läkaren|går (?:till|hos) (?:en )?läkare|(?<![\p{L}])ont i |värk|(?<![\p{L}])väger(?![\p{L}])|\d+ ?kilo(?![\p{L}])|gå ner i vikt|(?<![\p{L}])mens(?![\p{L}])|medicin(?:er|en|erar)?(?![\p{L}])|tabletter|concerta|elvanse|ritalin|medikinet|sertralin|gravid|psyk|terapi|kurator|(?<![\p{L}])bup(?![\p{L}])|habilitering|logoped|health|medication|diagnosed|självmord|självskad|(?<![\p{L}])skär (?:sig|mig)|skurit (?:sig|mig)|(?<![\p{L}])rispa\p{L}*|(?<![\p{L}])rist(?:ar|a|ade) sig|river upp (?:sår|såren)|ta livet|ta sitt (?:eget )?liv|tagit sitt liv|vill dö|vill inte leva|orkar inte leva|dödstankar|överdos|skada(?:r)? sig själv|svälter sig|suicid|self.?harm|personnummer|samordningsnummer|(?<!\d)(?:19|20)?\d{6}[- +]?\d{4}(?!\d)|kontonummer|kortnummer|clearingnummer|(?<!\d)\d{4}[ -]?\d{4}[ -]?\d{4}[ -]?\d{4}(?!\d)|lösenord|password|pinkod|pin-kod|(?<![\p{L}])pin(?![\p{L}])|passnummer|bank ?id-?kod|biometri/iu;

/**
 * K8 (Oscar O7 item 8): the categories are about the user's own faith, health, politics …, not the subjects
 * studied: "prov i religionskunskap", "partiklar", "företagsekonomi", "långa förklaringar" are kept. School subject
 * and study words are taken out before the check.
 */
const STUDY_WORDS =
  /\b(?:religionskunskap\p{L}*|religionsprov\p{L}*|religion(?:en)? (?:som ämne|prov\p{L}*)|samhällskunskap\p{L}*|partikl\p{L}*|partikel\p{L}*|företagsekonomi\p{L}*|privatekonomi(?:kurs\p{L}*)?|nationalekonomi\p{L}*|ekonomiprov\p{L}*|långa? förklaring\p{L}*|lång\p{L}* svar|psykologiprov\p{L}*|psykologi(?:kurs\p{L}*)?|medicinsk\p{L}* ämne|politikprov\p{L}*|statsvetenskap\p{L}*|(?:prov|läxa|test|uppsats|kurs|lektion)(?:en)? (?:i|på|om) (?:religion|psykologi|politik|ekonomi|medicin|sexualkunskap|sex och samlevnad)\p{L}*|(?:uppsats|arbete|redovisning|fördjupning|prov|läxa)(?:en)? (?:i \p{L}+ )?om \p{L}+|läser om \p{L}+|(?:i|om) religion(?:en)?(?![\p{L}])|skriv\p{L}* om \p{L}+(?= (?:som|i|till|för) \p{L}*(?:uppsats|ämne|arbete|redovisning|kurs|lektion|prov))|\p{L}+ som (?:uppsats|redovisnings|arbets|fördjupnings)?ämne|(?:plugga|läsa|studera|bli) (?:till )?(?:medicin|läkare|psykolog|sjuksköterska)\p{L}*)/giu;
/** K34: a memory is written in the third person ("Har tänkt på att ta sitt liv"); in the first person the /answer
 * crisis layer (crisis.ts) recognises it, so the two lists cannot drift apart. */
export function isCrisisMemory(t: string): boolean {
  const first = t.replace(/(?<![\p{L}])sig(?![\p{L}])/giu, "mig").replace(/(?<![\p{L}])sitt(?![\p{L}])/giu, "mitt")
    .replace(/(?<![\p{L}])sin(?![\p{L}])/giu, "min").replace(/(?<![\p{L}])sina(?![\p{L}])/giu, "mina");
  return crisisLevel("jag " + first) === "strong";
}
const SENSITIVE = { test: (t: string) => SENSITIVE_RAW.test(t.replace(STUDY_WORDS, " ")) || isCrisisMemory(t) };
/** K26: for the tests (Oscar O28). */
export const isSensitiveMemory = (t: string): boolean => SENSITIVE.test(t);

export const SYSTEM_PROMPT_MEMORY =
  `You keep a short memory about the wearer of a study assistant (a student in Sweden). You get <now> (the current date in Sweden), <memories> (what is already remembered) and <turn> (<q> = what the wearer just said, <a> = the assistant's answer, context only).

Return ONLY a JSON object: {"add": [...], "update": [{"old": "...", "new": "..."}], "remove": [...]}.
- add: new, important facts the wearer said about THEMSELVES in <q>: tests and deadlines, subjects and courses, level, goals, standing wishes for how answers should be ("svara kortare", "förklara med exempel"), rules ("fråga mig alltid en kontrollfråga"). One short Swedish sentence each, third person about the wearer, no name needed ("Har prov i kemi fredag 13 november 2026.").
- Dates are always absolute: turn "på fredag", "nästa vecka", "imorgon" into weekday, day, month and year from <now>.
- Several exams can be in <memories> (D86): a change to an exam (date, topics) updates only the exam with the same subject; a new exam in another subject is a new item, never an update of another exam.
- update: a fact in <memories> that the wearer changed (old = the exact memory text, new = the new sentence). remove: a memory the wearer said is no longer true (exact text).
- Write every item in Swedish, whatever language the turn is in. Never: facts about other people, small talk, one-off questions ("vad är fotosyntes" is not a fact about the wearer), guesses, anything already in <memories>. NEVER anything about health (illnesses, diagnoses, allergies, medicines, injuries, aids such as a hearing aid, care visits), about crisis (suicide, self-harm, not wanting to live), or ID numbers, card or account numbers, passwords and PIN codes: a list of illnesses is never complete, so leave out every fact about the body or mental health even when it is not named here.
- At most ${MEMORY_LIMITS.items} items in total, each at most 160 characters. Nothing worth keeping: {"add": [], "update": [], "remove": []}.`;

function clean(s: unknown, max: number): string | null {
  if (typeof s !== "string") return null;
  const t = s.replace(/[\u0000-\u001f]/g, " ").replace(/\s+/g, " ").trim();
  return t && t.length <= max ? t : null;
}

export function validateMemoryRequest(raw: unknown): { q: string; a: string; memories: string[]; language: string } {
  const b = raw as Record<string, unknown> | null;
  const turn = b?.turn as Record<string, unknown> | undefined;
  // The app (Lumen/Core/History/MemoryExtraction.swift) sends turn.question / turn.answer; q / a also work.
  // Its today / weekday / timezone fields are ignored: the date comes from the server's Swedish clock.
  const q = clean(turn?.question ?? turn?.q, MEMORY_LIMITS.q);
  if (!q) throw new HttpError(400, "invalid_request", `turn.question is required (max ${MEMORY_LIMITS.q} characters)`);
  const rawA = turn?.answer ?? turn?.a;
  const a = rawA === undefined || rawA === null || rawA === "" ? "" : clean(rawA, MEMORY_LIMITS.a);
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
      const raw = await readLimitedJson(req, MEMORY_LIMITS.bodyBytes);
      // K10.2: a correction right after an answer -> a structured setting with a scope (code only, no model call)
      // K13.2: the answer to "mer?" after a short answer (yes / no or silence) -> the learned default length
      const sig = (raw as Record<string, unknown> | null)?.length_signal as Record<string, unknown> | undefined;
      if (sig && typeof sig === "object" && (sig.signal === "yes" || sig.signal === "no")) {
        const settings = readSettings((raw as Record<string, unknown>).settings);
        const r = applySignal(settings, sig.signal, readContext(sig.context));
        console.log(JSON.stringify({ event: "length_signal", signal: sig.signal, history: r.history, long_first: r.longFirst }));
        return json({
          add: [], update: [], remove: [],
          settings: r.settings,
          ...(r.changed ? { setting: { ...r.changed, text: describe(r.changed) } } : {}),
          long_first: r.longFirst,
          profile: profileOf(r.settings),
        });
      }
      const corr = (raw as Record<string, unknown> | null)?.correction as Record<string, unknown> | undefined;
      if (corr && typeof corr === "object") {
        const text = typeof corr.text === "string" ? corr.text.slice(0, SETTINGS_LIMITS.text) : "";
        const settings = readSettings((raw as Record<string, unknown>).settings);
        let c = detectCorrection(text);
        let by: "code" | "model" = "code";
        // Oscar O47 (new phrasings 5/20 in code, 0 false): a short utterance the code does not know goes to one tiny
        // Haiku check ("shorter | longer | simpler | examples | careful | none"); anything else = not a correction
        if (!c && deps.provider && text.trim() && text.trim().split(/\s+/).length <= 15) {
          const rl = await enforceLimits(deps.rateLimiter, "memory", user.id, cfg.limits, 1, []);
          if (rl.allowed) {
            let reply = "";
            let inT = 0, outT = 0;
            try {
              for await (const ch of deps.provider.stream({
                system: CORRECTION_CHECK_PROMPT,
                user: `<said>${sanitizeTagged(text)}</said>`,
                maxTokens: 4,
                cacheSystem: true,
                noThinking: true,
                signal: AbortSignal.timeout(3000),
              })) {
                if (ch.type === "text") reply += ch.text;
                else if (ch.type === "usage") {
                  inT = ch.inputTokens ?? inT;
                  outT = ch.outputTokens ?? outT;
                }
              }
            } catch (e) {
              console.warn("correction_check_failed", e instanceof Error ? e.message.slice(0, 120) : String(e));
            }
            c = correctionFromCheck(reply);
            if (c) by = "model";
            try {
              await deps.recordUsage?.({
                user_id: user.id, endpoint: "memory-correction", provider: deps.provider.name, model: deps.provider.model,
                input_tokens: inT, output_tokens: outT, total_ms: Date.now() - t0,
                est_cost_usd: (inT * cfg.priceInPerMTok + outT * cfg.priceOutPerMTok) / 1e6, status: "ok",
              });
            } catch { /* metadata only */ }
          }
        }
        if (!c) return json({ add: [], update: [], remove: [], settings, profile: profileOf(settings), skipped: "not_a_correction" });
        const r = applyCorrection(settings, c, readContext(corr.context));
        return json({
          add: [], update: [], remove: [],
          settings: r.settings,
          setting: { ...r.changed, text: describe(r.changed) },
          widened: r.widened,
          profile: profileOf(r.settings),
          by,
        });
      }
      const body = validateMemoryRequest(raw);
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
        else if (c.type === "usage") {
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
