import { HttpError } from "../_shared/errors.ts";

export type Mode = "push_to_talk" | "auto" | "text";
export type Language = "sv" | "en";

export interface AnswerRequest {
  fragment: string;
  mode: Mode;
  language: Language;
  context: {
    transcript: string;
    recent_qa: { q: string; a: string }[];
    prep_terms: string[];
  };
}

export const LIMITS = {
  bodyBytes: 16 * 1024,
  fragment: 1000,
  transcript: 6000,
  recentQa: 6,
  qaText: 400,
  prepTerms: 30,
  prepTerm: 60,
} as const;

const bad = (msg: string) => new HttpError(400, "invalid_request", msg);

function str(v: unknown, name: string, max: number, required = false): string {
  if (v === undefined || v === null) {
    if (required) throw bad(`${name} is required`);
    return "";
  }
  if (typeof v !== "string") throw bad(`${name} must be a string`);
  const t = v.trim();
  if (required && !t) throw bad(`${name} must not be empty`);
  if (t.length > max) {
    throw new HttpError(413, "payload_too_large", `${name} exceeds ${max} characters`);
  }
  return t;
}

/** Validates the JSON body of POST /answer. Throws HttpError(400|413). */
export function validateAnswerRequest(raw: unknown): AnswerRequest {
  if (typeof raw !== "object" || raw === null || Array.isArray(raw)) {
    throw bad("body must be a JSON object");
  }
  const o = raw as Record<string, unknown>;
  const mode = o.mode;
  if (mode !== "push_to_talk" && mode !== "auto" && mode !== "text") {
    throw bad('mode must be "push_to_talk", "auto" or "text"');
  }
  const language = o.language;
  if (language !== "sv" && language !== "en") throw bad('language must be "sv" or "en"');
  const fragment = str(o.fragment, "fragment", LIMITS.fragment, true);

  const c = (o.context ?? {}) as Record<string, unknown>;
  if (typeof c !== "object" || c === null || Array.isArray(c)) {
    throw bad("context must be an object");
  }
  const transcript = str(c.transcript, "context.transcript", LIMITS.transcript);

  const qaRaw = c.recent_qa ?? [];
  if (!Array.isArray(qaRaw)) throw bad("context.recent_qa must be an array");
  if (qaRaw.length > LIMITS.recentQa) {
    throw new HttpError(
      413,
      "payload_too_large",
      `context.recent_qa exceeds ${LIMITS.recentQa} items`,
    );
  }
  const recent_qa = qaRaw.map((x, i) => {
    const e = (x ?? {}) as Record<string, unknown>;
    return {
      q: str(e.q, `recent_qa[${i}].q`, LIMITS.qaText),
      a: str(e.a, `recent_qa[${i}].a`, LIMITS.qaText),
    };
  });

  const termsRaw = c.prep_terms ?? [];
  if (!Array.isArray(termsRaw)) throw bad("context.prep_terms must be an array");
  if (termsRaw.length > LIMITS.prepTerms) {
    throw new HttpError(
      413,
      "payload_too_large",
      `context.prep_terms exceeds ${LIMITS.prepTerms} items`,
    );
  }
  const prep_terms = termsRaw.map((t, i) => str(t, `prep_terms[${i}]`, LIMITS.prepTerm));

  return { fragment, mode, language, context: { transcript, recent_qa, prep_terms } };
}

/** Reads the request body with a hard byte cap (does not trust Content-Length alone). */
export async function readLimitedJson(req: Request, maxBytes: number): Promise<unknown> {
  const declared = Number(req.headers.get("content-length") ?? "0");
  if (declared > maxBytes) {
    throw new HttpError(413, "payload_too_large", `Body exceeds ${maxBytes} bytes`);
  }
  if (!req.body) throw bad("Missing body");
  const reader = req.body.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    total += value.byteLength;
    if (total > maxBytes) {
      await reader.cancel();
      throw new HttpError(413, "payload_too_large", `Body exceeds ${maxBytes} bytes`);
    }
    chunks.push(value);
  }
  const buf = new Uint8Array(total);
  let off = 0;
  for (const c of chunks) {
    buf.set(c, off);
    off += c.byteLength;
  }
  try {
    return JSON.parse(new TextDecoder().decode(buf));
  } catch {
    throw bad("Body is not valid JSON");
  }
}
