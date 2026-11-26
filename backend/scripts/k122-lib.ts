/**
 * K122 (D265): test the AI without API credits – the session plays the model.
 *
 * The server's own handlers (answer, provlage-eval, exam, help) run here with the real AnthropicProvider, but its
 * fetch is a scripted one: each call to the Messages API is captured byte for byte (model, max_tokens, system,
 * messages, tools, thinking, output_config – everything except the key header) and answered with a saved reply,
 * as an Anthropic SSE stream. The rest of the chain is the production code: spoken format (K115), crisis marker and
 * its check (D256), source line (D254), length caps, cost records, credits and error codes.
 *
 * Nothing leaves the process. Any other fetch (Anthropic itself, ElevenLabs, a link check) is refused and listed in
 * `blocked`; the eval's Scribe action (`transcribe`) is never run. 0 model calls, 0 ElevenLabs (D180, D258).
 *
 * Files (one stem per model call: <case>.t<turn>.c<call>):
 *   prompt:  <out>/<stem>.json        – what the server would send ({anthropic_request, client_request, ...})
 *   reply:   <replies>/<stem>.txt     – the model's text, exactly as the model would write it (meta line included)
 *            <replies>/<stem>.json    – {"text": "..."} | {"error": {"status": 402, "message": "..."}}
 *                                       | {"events": [ ...raw Messages API stream events... ]} (tool use, web search)
 * A case runs turn by turn and stops at the first call without a reply ("needs_reply"): write that reply and run
 * again, and the next prompt appears (turn 2's prompt holds what the user heard in turn 1).
 */
import { MemoryRateLimiter } from "../supabase/functions/_shared/ratelimit.ts";
import { createHandler, DEFAULT_CONFIG, type UsageRecord } from "../supabase/functions/answer/handler.ts";
import { AnthropicProvider } from "../supabase/functions/answer/llm/anthropic.ts";
import { DEFAULT_MODEL } from "../supabase/functions/answer/llm/factory.ts";
import { createEvalHandler } from "../supabase/functions/provlage-eval/handler.ts";
import { createExamHandler, DEFAULT_EXAM_CONFIG } from "../supabase/functions/exam/handler.ts";
import { drillConfigFromEnv } from "../supabase/functions/exam/drill.ts";
import { createHelpHandler } from "../supabase/functions/help/handler.ts";

export const FAKE_BASE = "https://k122-replay.invalid";
const ROOT = new URL("../../", import.meta.url);

export type Reply =
  | { text: string }
  | { error: { status: number; message?: string; type?: string } }
  | { events: Record<string, unknown>[] };

export interface Case {
  id: string;
  cat?: string;
  /** answer (default), provlage-eval, exam, help */
  endpoint?: string;
  /** one request (provlage-eval, exam, help, a Rizz turn) */
  body?: Record<string, unknown>;
  /** /answer conversations as in scripts/qa/cases.json */
  turns?: { q: string; turn?: string; facit?: string }[];
  mode?: string;
  persona?: string;
  persona_setup?: string;
  goals?: string;
  memories?: string[];
  context_transcript?: unknown;
  /** headers to add, e.g. {"x-earmind-lang": "en"} */
  headers?: Record<string, string>;
  [k: string]: unknown;
}

export interface Prompt {
  stem: string;
  case: string;
  turn: number;
  call: number;
  endpoint: string;
  url: string;
  /** what the client (app/script) sent to the server */
  client_request: Record<string, any>;
  /** exactly what the server sends to the Messages API (the key header is not part of it) */
  anthropic_request: unknown;
  /** how the server reads the reply (so the one playing the model writes the right format) */
  reply_hint: string;
}

/** The answer prompt's own rule (as MockProvider reads it): a <mode> tag means a JSON meta line first. */
export function replyHint(endpoint: string, body: unknown): string {
  const b = body as { messages?: { content?: unknown }[]; system?: unknown; tools?: unknown[] };
  const user = JSON.stringify(b?.messages?.at(-1)?.content ?? "");
  if (endpoint === "answer" || (endpoint === "provlage-eval" && !String(JSON.stringify(b?.system)).startsWith('[{"type":"text","text":"You grade'))) {
    if (String(JSON.stringify(b?.system)).includes("You check ONE utterance")) return "crisis check (D256): one word, 'ja' or 'nej'";
    const tools = b?.tools?.length ? " Web tools are on: plain text is read as an answer given without searching; a search needs {\"events\": [...]} with server_tool_use blocks." : "";
    return (user.includes("<mode>")
      ? "First line: the JSON meta object the system prompt asks for ({\"is_question\":..., \"reconstructed_question\":..., \"confidence\":...}), newline, then the spoken answer."
      : "Direct mode: only the spoken answer text (no JSON line – it would be read aloud).") + tools;
  }
  return "As the system prompt asks (exam, help and the judge read a JSON object from the reply).";
}

export interface TurnResult {
  turn: number;
  endpoint: string;
  http_status: number;
  /** /answer: the text the user hears (all delta events), after the server's chain */
  said?: string;
  meta?: Record<string, unknown>[];
  done?: Record<string, any>;
  events?: { event: string; data: unknown }[];
  /** JSON endpoints: the body the client gets */
  json?: unknown;
  error?: { code?: string; message?: string; [k: string]: unknown };
  /** the server's cost records (answer_usage rows) */
  usage: Record<string, any>[];
  /** credit/quota calls the handler made (exam/help wallet) */
  credits: { fn: string; n?: number }[];
}

export interface CaseResult {
  id: string;
  status: "done" | "needs_reply" | "refused";
  needs?: string;
  reason?: string;
  prompts: Prompt[];
  turns: TurnResult[];
  /** fetches that were refused (every host but the scripted model) */
  blocked: string[];
}

/** A fetch that refuses everything (and remembers what was tried). */
export function blockedFetch(log: string[]): typeof fetch {
  return (input: string | URL | Request) => {
    const url = input instanceof Request ? input.url : String(input);
    log.push(url);
    return Promise.reject(new TypeError(`K122: network call refused (${url.split("?")[0]})`));
  };
}

const enc = new TextEncoder();
function sse(events: Record<string, unknown>[]): Response {
  const body = events.map((e) => `event: ${e.type}\ndata: ${JSON.stringify(e)}\n\n`).join("");
  return new Response(new ReadableStream({
    start(c) {
      // in pieces, as the network delivers it
      for (let i = 0; i < body.length; i += 120) c.enqueue(enc.encode(body.slice(i, i + 120)));
      c.close();
    },
  }), { status: 200, headers: { "content-type": "text/event-stream" } });
}

/** A text reply as the Messages API streams it. Token counts are estimates (characters / 4 in, / 3.5 out). */
export function textEvents(text: string, inputChars: number): Record<string, unknown>[] {
  const deltas: Record<string, unknown>[] = [];
  for (let i = 0; i < text.length; i += 24) {
    deltas.push({ type: "content_block_delta", index: 0, delta: { type: "text_delta", text: text.slice(i, i + 24) } });
  }
  return [
    { type: "message_start", message: { id: "msg_k122", type: "message", role: "assistant", content: [], usage: { input_tokens: Math.ceil(inputChars / 4), output_tokens: 1 } } },
    { type: "content_block_start", index: 0, content_block: { type: "text", text: "" } },
    ...deltas,
    { type: "content_block_stop", index: 0 },
    { type: "message_delta", delta: { stop_reason: "end_turn", stop_sequence: null }, usage: { output_tokens: Math.max(1, Math.ceil(text.length / 3.5)) } },
    { type: "message_stop" },
  ];
}

export function replyResponse(r: Reply, inputChars: number): Response {
  if ("error" in r) {
    const type = r.error.type ?? (r.error.status === 402 ? "billing_error" : r.error.status === 529 ? "overloaded_error" : "api_error");
    return new Response(JSON.stringify({ type: "error", error: { type, message: r.error.message ?? "" } }), { status: r.error.status, headers: { "content-type": "application/json" } });
  }
  if ("events" in r) return sse(r.events);
  return sse(textEvents(r.text, inputChars));
}

/** Reads a reply file's content: JSON with text/error/events, else the plain text itself. */
export function parseReply(raw: string, name = ""): Reply {
  if (name.endsWith(".json")) {
    const j = JSON.parse(raw);
    if (typeof j === "string") return { text: j };
    if (typeof j?.text === "string" || j?.error || Array.isArray(j?.events)) return j as Reply;
    throw new Error(`${name}: expected {"text"}, {"error"} or {"events"}`);
  }
  return { text: raw.replace(/\r\n/g, "\n").replace(/\n$/, "") };
}

class NeedReply extends Error {
  constructor(readonly stem: string) {
    super(`K122: needs a reply for ${stem}`);
  }
}

const quiet = <T>(fn: () => Promise<T>): Promise<T> => {
  // the handlers log JSON lines (crisis_check, resource, ...); keep the replay's own output readable
  const keep = { log: console.log, warn: console.warn, error: console.error };
  if (Deno.env.get("K122_LOGS") !== "1") console.log = console.warn = console.error = () => {};
  return fn().finally(() => Object.assign(console, keep));
};

function parseSse(text: string) {
  return text.split("\n\n").filter((f) => f.trim()).map((f) => {
    const ev = /^event: (.*)$/m.exec(f)?.[1] ?? "message";
    const raw = f.split("\n").filter((l) => l.startsWith("data: ")).map((l) => l.slice(6)).join("\n");
    let data: unknown = raw;
    try {
      data = JSON.parse(raw);
    } catch { /* not JSON */ }
    return { event: ev, data };
  });
}

/** One run of a case: every model call gets the reply `lookup(stem)` gives, or the case stops there. */
export async function runCase(c: Case, lookup: (stem: string) => Reply | null): Promise<CaseResult> {
  const endpoint = c.endpoint ?? "answer";
  const res: CaseResult = { id: c.id, status: "done", prompts: [], turns: [], blocked: [] };
  if (endpoint === "provlage-eval" && c.body?.action === "transcribe") {
    return { ...res, status: "refused", reason: "transcribe calls ElevenLabs Scribe (D180); not replayed" };
  }
  const usage: Record<string, any>[] = [];
  const credits: { fn: string; n?: number }[] = [];
  let turn = 0, call = 0;
  let clientBody: Record<string, any> = {};

  const scripted: typeof fetch = async (input: string | URL | Request, init?: RequestInit) => {
    const url = input instanceof Request ? input.url : String(input);
    if (!url.startsWith(FAKE_BASE)) return blockedFetch(res.blocked)(url);
    call++;
    const stem = `${c.id}.t${turn}.c${call}`;
    const raw = String(init?.body ?? "");
    let body: unknown = raw;
    try {
      body = JSON.parse(raw);
    } catch { /* keep the text */ }
    res.prompts.push({ stem, case: c.id, turn, call, endpoint, url, client_request: structuredClone(clientBody), anthropic_request: body, reply_hint: replyHint(endpoint, body) });
    const reply = lookup(stem);
    if (!reply) throw new NeedReply(stem);
    return replyResponse(reply, raw.length);
  };
  const provider = new AnthropicProvider({
    apiKey: "k122-no-key",
    model: Deno.env.get("LLM_MODEL") ?? DEFAULT_MODEL,
    baseUrl: FAKE_BASE,
    effort: (Deno.env.get("LLM_EFFORT") ?? "low") as "low",
    disableThinking: (Deno.env.get("LLM_DISABLE_THINKING") ?? "1") !== "0",
  }, scripted);
  const user = { id: `k122-${c.id}`, isAnonymous: false };
  const authenticate = () => Promise.resolve(user);
  const rateLimiter = new MemoryRateLimiter();
  const recordUsage = (r: UsageRecord | Record<string, unknown>) => void usage.push(r as Record<string, any>);
  const noEnv = { get: (k: string) => Deno.env.get(k) };
  const wallet = (fn: string) => (_u: string, n = 0) => {
    credits.push({ fn, n });
    return Promise.resolve({ ok: true, used: 0, lim: 100_000 });
  };
  const handler = endpoint === "answer"
    ? createHandler({ authenticate, rateLimiter, provider, recordUsage, fetchImpl: blockedFetch(res.blocked), config: DEFAULT_CONFIG })
    : endpoint === "provlage-eval"
    ? createEvalHandler({ authenticate, rateLimiter, provider, recordUsage, answerConfig: DEFAULT_CONFIG, elevenLabsKey: null, fetchImpl: blockedFetch(res.blocked), access: () => true })
    : endpoint === "exam"
    ? createExamHandler({
      authenticate, rateLimiter, provider, recordUsage,
      config: { ...DEFAULT_EXAM_CONFIG, model: Deno.env.get("EXAM_MODEL") || undefined, drill: drillConfigFromEnv(noEnv) },
      quota: (u) => wallet("exam.quota")(u, 0),
      qaMeasure: () => Promise.resolve(false),
    })
    : endpoint === "help"
    ? createHelpHandler({ authenticate, rateLimiter, provider, recordUsage, useQuota: wallet("help.useQuota"), addTryCredits: (_u, keys) => (credits.push({ fn: "help.addTryCredits", n: keys.length }), Promise.resolve()) })
    : null;
  if (!handler) return { ...res, status: "refused", reason: `unknown endpoint ${endpoint}` };

  // the bodies, turn by turn (an /answer conversation as scripts/qa/run.py builds it)
  const bodies: (() => Record<string, any>)[] = [];
  const hist: { q: string; a: string }[] = [];
  const memories = [...(c.memories ?? [])];
  if (c.body) bodies.push(() => structuredClone(c.body!));
  else {
    for (const t of c.turns ?? []) {
      bodies.push(() => {
        const mode = c.mode ?? "push_to_talk";
        const b: Record<string, any> = { fragment: t.q, mode, language: "sv", context: {} };
        if (hist.length) {
          const n = mode === "tutor" || c.persona ? 6 : 3;
          b.context.recent_qa = hist.slice(-n).map((h) => ({ q: h.q.slice(0, 400), a: h.a.slice(0, 1500) }));
        }
        for (const k of ["persona", "persona_setup", "goals"] as const) if (c[k] !== undefined) b[k] = c[k];
        if (c.context_transcript !== undefined) b.context.transcript = c.context_transcript;
        if (memories.length) b.memories = [...memories];
        if (t.turn) b.turn = t.turn;
        return b;
      });
    }
  }

  const guard = globalThis.fetch;
  globalThis.fetch = blockedFetch(res.blocked);
  try {
    for (let i = 0; i < bodies.length; i++) {
      turn = i + 1;
      call = 0;
      clientBody = bodies[i]();
      usage.length = 0;
      credits.length = 0;
      const req = new Request(`http://k122.local/${endpoint}`, {
        method: "POST",
        headers: { "content-type": "application/json", "x-forwarded-for": "203.0.113.7", ...(c.headers ?? {}) },
        body: JSON.stringify(clientBody),
      });
      let missing: string | null = null;
      const r = await quiet(async () => {
        const resp = await handler(req);
        const text = await resp.text();
        return { resp, text };
      }).catch((e) => {
        if (e instanceof NeedReply) missing = e.stem;
        else throw e;
        return null;
      });
      // a handler that catches the missing reply still answers; the case stops at the first call without one
      const asked = res.prompts.filter((p) => p.turn === turn).length;
      const replied = res.prompts.filter((p) => p.turn === turn && lookup(p.stem)).length;
      if (missing || asked > replied) {
        res.status = "needs_reply";
        res.needs = missing ?? res.prompts.filter((p) => p.turn === turn).find((p) => !lookup(p.stem))!.stem;
        return res;
      }
      const t: TurnResult = { turn, endpoint, http_status: r!.resp.status, usage: [...usage], credits: [...credits] };
      if ((r!.resp.headers.get("content-type") ?? "").includes("event-stream")) {
        const ev = parseSse(r!.text);
        t.events = ev;
        t.said = ev.filter((e) => e.event === "delta").map((e) => String((e.data as { text?: string }).text ?? "")).join("");
        t.meta = ev.filter((e) => e.event === "meta").map((e) => e.data as Record<string, unknown>);
        t.done = ev.find((e) => e.event === "done")?.data as Record<string, any> | undefined;
        const err = ev.find((e) => e.event === "error")?.data as { code?: string } | undefined;
        if (err) t.error = ((err as { error?: TurnResult["error"] }).error ?? err) as TurnResult["error"];
        if (t.done?.memory_add) memories.push(String(t.done.memory_add));
      } else {
        let j: any = r!.text;
        try {
          j = JSON.parse(r!.text);
        } catch { /* not JSON */ }
        t.json = j;
        // the answer inside the eval is the /answer stream itself
        if (typeof j === "string" && j.includes("event: ")) {
          const ev = parseSse(j);
          t.events = ev;
          t.said = ev.filter((e) => e.event === "delta").map((e) => String((e.data as { text?: string }).text ?? "")).join("");
          t.done = ev.find((e) => e.event === "done")?.data as Record<string, any> | undefined;
          delete t.json;
        }
        if (j && typeof j === "object" && j.error) t.error = j.error;
      }
      res.turns.push(t);
      const q = c.turns?.[i]?.q;
      if (q !== undefined) hist.push({ q, a: t.said ?? "" });
    }
    return res;
  } finally {
    globalThis.fetch = guard;
  }
}

/** scripts/qa/cases.json (the /answer bank, Rizz as run.py sends it) + backend/scripts/k122-cases.json. */
export async function loadCases(): Promise<Case[]> {
  const qa = JSON.parse(await Deno.readTextFile(new URL("scripts/qa/cases.json", ROOT))) as Case[];
  const out: Case[] = [];
  for (const c of qa) {
    if (c.rizz && c.social) {
      for (const [style, adult, id] of [["flirt", true, c.id], ["social", false, `${c.id}s`]] as const) {
        out.push({ id, cat: style === "flirt" ? "rizz" : "socialt-läge", body: { fragment: "", mode: "tutor", language: "sv", persona: "social", social: { ...(c.social as object), style }, context: {}, ...(adult ? { adult_confirmed: true } : {}) } });
      }
    } else out.push(c);
  }
  const extra = JSON.parse(await Deno.readTextFile(new URL("backend/scripts/k122-cases.json", ROOT))) as Case[];
  return [...out, ...extra];
}

/** Replies from a directory: <stem>.txt or <stem>.json. */
export function dirLookup(dir: string | null): (stem: string) => Reply | null {
  return (stem) => {
    if (!dir) return null;
    for (const ext of [".json", ".txt"]) {
      try {
        return parseReply(Deno.readTextFileSync(`${dir}/${stem}${ext}`), ext);
      } catch (e) {
        if (!(e instanceof Deno.errors.NotFound)) throw e;
      }
    }
    return null;
  };
}

export const repoPath = (p: string) => new URL(p, ROOT).pathname;
