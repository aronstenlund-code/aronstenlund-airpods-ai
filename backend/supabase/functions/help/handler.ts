import type { Authenticator } from "../_shared/auth.ts";
import { CORS_HEADERS, errorResponse, HttpError, toHttpError } from "../_shared/errors.ts";
import { enforceLimits, type RateLimiter } from "../_shared/ratelimit.ts";
import { readLimitedJson } from "../answer/validate.ts";
import { sanitizeTagged } from "../answer/prompt.ts";
import type { LLMProvider } from "../answer/llm/types.ts";
import { CAPS } from "../_shared/capabilities.ts";
import { HJALP } from "../_shared/hjalp.ts";
import { DEFAULT_DRILL_CONFIG, type DrillConfig, handleDrill } from "../exam/drill.ts";

/**
 * K57 (D166): `POST /help`, the help AI inside the app ("Fråga om Earmind").
 *  {"question": "Hur delar jag ett prov?"} -> {"answer", "in_scope": true}
 *     Only questions about Earmind, answered from docs/HJALP.md and Shared/capabilities.json (never an invented
 *     feature). Anything else: {"answer": "Det kan jag inte svara på.", "in_scope": false, "hint": "Jag svarar bara …"}.
 *  {"action": "try", "text": "<a short text>"} -> {"items": [3 × {id, question, short, long}], "summary", "notes", "quota"}
 *     Three questions with answers from a short text; counts as 3 of the month's questions (D155); 402 when they are
 *     not left. "Spara som prov" in the app saves them through /drill like any drill.
 */
export const OUT_OF_SCOPE = "Det kan jag inte svara på.";
export const OUT_OF_SCOPE_HINT = "Jag svarar bara på hur Earmind fungerar, till exempel hur du gör ett nytt prov.";
/** K60 (Deangelo 12:15, Oscar O58 fynd 1) word for word, and D165 for the pause: questions on the presses and on how to
 * hear the long or short answer always get this. */
export const PRESS_LINE = "1 tryck = det långa A-svaret. 2 tryck = det korta A-svaret, en till två meningar. 3 tryck = paus.";
export const PRESSES = `Medan frågan spelas: ${PRESS_LINE} Tryck igen för att fortsätta. Under paus fortsätter vilket tryck som helst från början av meningen där du slutade.`;
const PRESS_Q = /(?:hur fungerar|vad gör|vad betyder|förklara|hur styr|vilka)[^?]{0,25}(?:tryck|knapp|airpods)|tryck(?:er|a)?\s+(?:jag\s+)?(?:en|1|två|2|tre|3)\s+gång|hur\s+(?:pausar|fortsätter)(?!\p{L})|hela\s+(?:förklaringen|svaret|a-svaret)|(?:hur|när)\s+(?:får|hör|spelar|lyssnar)\s+(?:jag\s+)?(?:höra\s+|på\s+|fram\s+)?(?:det\s+|ett\s+)?(?:långa\s+|korta\s+)?(?:a-)?svar/iu;
// troubleshooting ("kommer inte fram", "fungerar inte") is answered by the model from the help text instead
const PRESS_TROUBLE = /inte (?:kommer|kom|fungerar|funkar|hörs)|kommer (?:inte )?fram|gamla|äldre/iu;
/** K60 (Oscar O58b prio 3:1): what the short and the long answer are, fixed (it once said "the first answer"). */
export const ANSWERS_DEF = "Det korta A-svaret är första meningen, eller de två första, i det långa A-svaret, och det är ett fullgott svar i sig. Det långa A-svaret förklarar mer. Du får det korta med 2 tryck och det långa med 1 tryck.";
const DEF_Q = /^\s*(?:vad|vilket)\s+(?:är|betyder)\s+(?:det\s+)?(?:korta|långa)\s+(?:a-)?svaret\s*\??\s*$|skillnaden\s+(?:mellan|på)\s+(?:det\s+)?(?:kort|lång)/iu;
export const isAnswersQuestion = (q: string) => DEF_Q.test(q);
export const isPressQuestion = (q: string) => PRESS_Q.test(q) && !PRESS_TROUBLE.test(q);
export const UNKNOWN = "Det vet jag inte. Skriv till oss under Inställningar › Om Earmind.";

const capsText = () =>
  CAPS.map((c) => `- ${c.name}: ${c.status === "finns" ? "finns" : "kommer snart"}${c.permission ? " (kräver att du tillåter det)" : ""}`).join("\n");

export const SYSTEM_PROMPT_HELP = `You are the help inside the Swedish app Earmind. You answer ONLY questions about how Earmind works, using ONLY <hjalp> and <funktioner> below. Return ONLY a JSON object {"in_scope": true|false, "answer": "..."}.
- in_scope is false for anything that is not about using Earmind (school subjects, homework, general knowledge, other apps, chat, jokes, personal questions, requests to do something outside the app). Then answer is "".
- When it is about Earmind but <hjalp> and <funktioner> do not say, answer exactly: "${UNKNOWN}" Never invent a feature, a setting, a price, a number of seconds or a place in the app.
- The answer: Swedish du-form, short sentences, at most 4 sentences or 5 numbered steps ("1. ..."), the answer first (no "Bra fråga", "Självklart", "Som en AI"). Button names exactly as in <hjalp> (Nytt prov, Fota sidor, Skapa frågor, Ser rätt ut, Starta prov, Avsluta, Fler lägen, Dela, Publicera prov). Never the words "övningsprov", "A+-svar", "drill", "TTS" or model or company names.
- Questions about the presses: give the sentence in <hjalp> word for word. Never swap them: ${PRESS_LINE} "A-svaret" alone means the long answer.
- Use only the button names, gestures and steps that are in <hjalp>; never add one (no "Spara", no swiping, no setting that is not named).
- A question about doing something IN Earmind (language, question types, skipping or going back, exporting, accounts, reminders) is always in_scope true, also when Earmind cannot do it: then say plainly that it is not in Earmind (see "Det här finns inte i Earmind"), or answer exactly the "Det vet jag inte" sentence.
- The short answer is the first sentence (or two) of the long answer, never "the first answer". Premium, subscriptions and prices: say what <hjalp> says (coming later, no prices yet), never "Det vet jag inte".
- Answer only what was asked: no extra sentence about another topic, and never the same instruction twice.
- Say only what <hjalp> says about calls and reminders: a call pauses the drill and it goes on when you press again; Earmind has no study reminders of its own.
- Something "kommer snart" is said to be coming; beta modes are said to be in beta.
- Never ask for personal information. No emoji.

<hjalp>
${sanitizeTagged(HJALP)}
</hjalp>

<funktioner>
${capsText()}
</funktioner>`;

export interface HelpDeps {
  authenticate: Authenticator;
  rateLimiter: RateLimiter;
  provider: LLMProvider | null;
  /** D155: the month's generated questions (n = 0 only reads). */
  useQuota: (userId: string, n: number) => Promise<{ ok: boolean; used: number; lim: number }>;
  drill?: DrillConfig;
  recordUsage?: (rec: Record<string, unknown>) => void | Promise<void>;
}

const PRICE_IN = 0.10, PRICE_OUT = 0.50; // Haiku 5.5, verified 2026-11-13

export function parseHelp(text: string): { in_scope: boolean; answer: string } {
  const m = /\{[\s\S]*\}/.exec(text);
  try {
    const j = JSON.parse(m?.[0] ?? "{}");
    // K60 (Oscar O58): no intro line ("Så här börjar du:") before numbered steps, so 5 steps stay 5 sentences
    const answer = typeof j.answer === "string"
      ? j.answer.replace(/\*\*/g, "").trim().replace(/^[^\n.!?]{0,60}:\s*(?=1\.\s)/u, "").slice(0, 1200)
      : "";
    if (j.in_scope === false) return { in_scope: false, answer: OUT_OF_SCOPE };
    if (answer) return { in_scope: true, answer };
  } catch { /* falls through */ }
  return { in_scope: true, answer: UNKNOWN };
}

export function createHelpHandler(deps: HelpDeps) {
  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json", "cache-control": "no-store", ...CORS_HEADERS } });
  return async (req: Request): Promise<Response> => {
    if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS_HEADERS });
    try {
      if (req.method !== "POST") throw new HttpError(405, "method_not_allowed", "Use POST");
      const user = await deps.authenticate(req);
      const b = (await readLimitedJson(req, 64 * 1024)) as Record<string, unknown> | null;
      if (!deps.provider) throw new HttpError(503, "provider_unconfigured", "LLM provider not configured");
      if (b?.action === "try") {
        const text = typeof b.text === "string" ? b.text.trim().slice(0, 6000) : "";
        if (text.length < 40) throw new HttpError(400, "invalid_request", "Skriv eller klistra in några meningar först.");
        const rl = await enforceLimits(deps.rateLimiter, "help_try", user.id, { perMinute: 3, perDay: 20, globalPerDay: 20_000 }, 1);
        if (!rl.allowed) throw new HttpError(429, "rate_limited", "För många försök just nu. Vänta en liten stund.", { retryAfterSec: rl.retryAfterSec });
        // D166: counts as 3 of the month's questions; checked first, counted only when the questions were made
        const q0 = await deps.useQuota(user.id, 0);
        if (q0.used + 3 > q0.lim) {
          return json({
            error: { code: "quota_exceeded", message: "Du har inga frågor kvar den här månaden.", fallback: false },
            used: q0.used,
            limit: q0.lim,
            needed: 3,
          }, 402);
        }
        const { body, steps } = await handleDrill("drill", { text, questions: 3, long_words: 90 }, deps.provider, deps.drill ?? DEFAULT_DRILL_CONFIG, req.signal);
        const q = await deps.useQuota(user.id, 3);
        for (const st of steps) {
          await Promise.resolve(deps.recordUsage?.({ user_id: user.id, endpoint: "help-try", provider: deps.provider.name, model: st.model, input_tokens: st.input_tokens, output_tokens: st.output_tokens, est_cost_usd: st.est_cost_usd, status: "ok" })).catch(() => {});
        }
        return json({ ...body, quota: { used: q.used, limit: q.lim } });
      }
      const question = typeof b?.question === "string" ? b.question.replace(/\s+/g, " ").trim().slice(0, 500) : "";
      if (!question) throw new HttpError(400, "invalid_request", "question is required");
      const rl = await enforceLimits(deps.rateLimiter, "help", user.id, { perMinute: 10, perDay: 200, globalPerDay: 200_000 }, 1);
      if (!rl.allowed) throw new HttpError(429, "rate_limited", "För många frågor just nu. Vänta en liten stund.", { retryAfterSec: rl.retryAfterSec });
      let text = "", inTok = 0, outTok = 0;
      for await (const c of deps.provider.stream({ system: SYSTEM_PROMPT_HELP, user: `<fråga>${sanitizeTagged(question)}</fråga>`, maxTokens: 500, cacheSystem: true, timeoutMs: 30_000, signal: req.signal })) {
        if (c.type === "text") text += c.text;
        else if (c.type === "usage") {
          inTok = c.inputTokens ?? inTok;
          outTok = c.outputTokens ?? outTok;
        }
      }
      let r = parseHelp(text);
      // Kelly Ke57 rule 3: the presses are always explained with Aron's text, word for word (not left to the model)
      if (r.in_scope && isPressQuestion(question)) r = { in_scope: true, answer: PRESSES };
      else if (r.in_scope && isAnswersQuestion(question)) r = { in_scope: true, answer: ANSWERS_DEF };
      const cost = (inTok * PRICE_IN + outTok * PRICE_OUT) / 1e6;
      await Promise.resolve(deps.recordUsage?.({ user_id: user.id, endpoint: "help", provider: deps.provider.name, model: deps.provider.model, input_tokens: inTok, output_tokens: outTok, est_cost_usd: cost, status: "ok" })).catch(() => {});
      return json({ ...r, ...(r.in_scope ? {} : { hint: OUT_OF_SCOPE_HINT }), usage: { input_tokens: inTok, output_tokens: outTok, est_cost_usd: cost } });
    } catch (e) {
      return errorResponse(toHttpError(e));
    }
  };
}
