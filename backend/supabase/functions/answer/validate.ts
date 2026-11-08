import { HttpError } from "../_shared/errors.ts";

export type Mode = "push_to_talk" | "auto" | "text" | "tutor" | "interview_prep";
export type Persona = "tutor" | "interview" | "social";
export type Turn = "question" | "user_answer";
/** D63: "flirt" (adults only, needs adult_confirmed) or "social" (everyday conversation, all ages). Unknown = "social". */
export type SocialStyle = "flirt" | "social";
export type SocialTrigger = "other_spoke" | "stall" | "opener";
/** D43 Rizzläge input: rolling conversation + style + trigger. Held in memory by the client only. */
export interface SocialInput {
  style: SocialStyle;
  trigger: SocialTrigger;
  /** D81: `label` is the app's speaker label ("Du", "Talare 1" …) when its voice tracking knows the speaker. */
  transcript: { speaker: "user" | "other"; text: string; label?: string }[];
  /** D81: the label of whoever said the fragment ("Talare 2"). */
  fragmentSpeaker?: string;
  interests: string[];
  profile: string;
  /** D69: the stored calibration (the user's own tone wishes / facts), applied to every suggestion. */
  calibration: string;
  /** D69: a spoken calibration instruction; present => merge it, return done.calibration, no suggestions. */
  calibrate: string;
}
const TRIGGERS: SocialTrigger[] = ["other_spoke", "stall", "opener"];
export type Language = "sv" | "en";
export type LengthSetting = "short" | "adaptive" | "long";

export interface AnswerRequest {
  fragment: string;
  mode: Mode;
  language: Language;
  /** Answer length preference; default "adaptive" (fact vs study decided server-side). */
  length: LengthSetting;
  /** The student's course goals (D37), user data, <= 1 500 chars. */
  goals: string;
  /** D42: behaviour of the hands-free loop (default tutor). */
  persona: Persona;
  /** Role / pasted job ad / scenario for interview and social personas and interview_prep (user data). */
  personaSetup: string;
  /** Interview persona: is the fragment the interviewer's question or the user's own answer? */
  turn: Turn;
  /** D43: present => Rizzläge fast path (persona social): returns a `suggestions` event. */
  social: SocialInput | null;
  /** The student's own matched keyword commands (D37), <= 10. */
  commands: { keyword: string; instruction: string }[];
  /** D49: facts the user asked the app to remember (<= 30 x 200 chars), used as user facts. */
  memories: string[];
  /** D62: "demo" = the public demo page (hard caps, Haiku only, no web, no Rizz). */
  source: "app" | "demo";
  context: {
    transcript: string;
    /** D81: `interrupted` = the app stopped this answer mid-way; `a` is what had been said by then. */
    recent_qa: { q: string; a: string; interrupted?: boolean }[];
    prep_terms: string[];
  };
}

export const LIMITS = {
  bodyBytes: 64 * 1024,
  fragment: 1000,
  transcript: 6000,
  recentQa: 6,
  qaText: 400,
  qaAnswer: 1500,
  prepTerms: 50, // D84: the subject term list from /study-profile (30-50 terms)
  prepTerm: 60,
  goals: 1500,
  personaSetup: 2000, // D81: job ad + compressed CV
  socialLines: 40,
  socialLine: 300,
  socialInterests: 10,
  socialInterest: 60,
  socialProfile: 1000,
  socialCalibration: 300,
  socialCalibrate: 300,
  commands: 10,
  memories: 30,
  memory: 200,
  commandKeyword: 60,
  commandInstruction: 300,
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
  if (
    mode !== "push_to_talk" && mode !== "auto" && mode !== "text" && mode !== "tutor" &&
    mode !== "interview_prep"
  ) {
    throw bad('mode must be "push_to_talk", "auto", "text", "tutor" or "interview_prep"');
  }
  const language = o.language;
  if (language !== "sv" && language !== "en") throw bad('language must be "sv" or "en"');
  // Rizzläge (D43) may be triggered by silence or an opener: then there is no fragment.
  const hasSocial = o.social !== undefined && o.social !== null;
  const fragment = str(o.fragment, "fragment", LIMITS.fragment, !hasSocial);

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
      a: str(e.a, `recent_qa[${i}].a`, LIMITS.qaAnswer),
      ...(e.interrupted === true ? { interrupted: true } : {}),
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

  const goals = str(o.goals, "goals", LIMITS.goals);

  const memRaw = o.memories ?? [];
  if (!Array.isArray(memRaw)) throw bad("memories must be an array");
  if (memRaw.length > LIMITS.memories) {
    throw new HttpError(413, "payload_too_large", `memories exceeds ${LIMITS.memories} items`);
  }
  const memories = memRaw.map((x, i) => str(x, `memories[${i}]`, LIMITS.memory)).filter(Boolean);
  const cmdRaw = o.commands ?? [];
  if (!Array.isArray(cmdRaw)) throw bad("commands must be an array");
  if (cmdRaw.length > LIMITS.commands) {
    throw new HttpError(413, "payload_too_large", `commands exceeds ${LIMITS.commands} items`);
  }
  const commands = cmdRaw.map((x, i) => {
    const e = (x ?? {}) as Record<string, unknown>;
    return {
      keyword: str(e.keyword, `commands[${i}].keyword`, LIMITS.commandKeyword, true),
      instruction: str(
        e.instruction,
        `commands[${i}].instruction`,
        LIMITS.commandInstruction,
        true,
      ),
    };
  });

  const persona = o.persona === undefined || o.persona === null ? "tutor" : o.persona;
  if (persona !== "tutor" && persona !== "interview" && persona !== "social") {
    throw bad('persona must be "tutor", "interview" or "social"');
  }
  const personaSetup = str(o.persona_setup, "persona_setup", LIMITS.personaSetup);
  if (mode === "interview_prep" && !personaSetup) {
    throw bad("persona_setup (the role or job ad) is required for interview_prep");
  }
  const turn = o.turn === undefined || o.turn === null ? "question" : o.turn;
  if (turn !== "question" && turn !== "user_answer") {
    throw bad('turn must be "question" or "user_answer"');
  }

  let social: SocialInput | null = null;
  if (hasSocial) {
    const x = o.social as Record<string, unknown>;
    if (typeof x !== "object" || Array.isArray(x)) throw bad("social must be an object");
    if (persona !== "social") throw bad('social requires persona "social"');
    const style: SocialStyle = x.style === "flirt" ? "flirt" : "social"; // missing / unknown / old styles -> social
    if (style === "flirt" && o.adult_confirmed !== true && x.adult_confirmed !== true) {
      throw new HttpError(
        403,
        "adult_confirmation_required",
        "Flirt kräver att användaren bekräftat att hen är 18 år eller äldre (adult_confirmed: true).",
      );
    }
    const trigger = x.trigger === undefined || x.trigger === null ? "other_spoke" : x.trigger;
    if (!TRIGGERS.includes(trigger as SocialTrigger)) {
      throw bad(`social.trigger must be one of ${TRIGGERS.join(", ")}`);
    }
    const trRaw = x.transcript ?? [];
    if (!Array.isArray(trRaw)) throw bad("social.transcript must be an array");
    if (trRaw.length > LIMITS.socialLines) {
      throw new HttpError(
        413,
        "payload_too_large",
        `social.transcript exceeds ${LIMITS.socialLines} lines`,
      );
    }
    const transcript = trRaw.map((l, i) => {
      const e = (l ?? {}) as Record<string, unknown>;
      // D81: besides "user"/"other" the speaker may be the app's label itself ("Du", "Talare 1"); "Du" is the user
      const raw = typeof e.speaker === "string" ? e.speaker.trim() : "";
      const labelOf = (v: unknown) =>
        typeof v === "string" && /^[\p{L}\p{N} .'-]{1,24}$/u.test(v.trim()) ? v.trim() : undefined;
      let speaker: "user" | "other";
      let label = labelOf(e.label);
      if (raw === "user" || raw === "other") speaker = raw;
      else if (/^(du|jag|you)$/i.test(raw)) {
        speaker = "user";
        label = undefined;
      } else if (labelOf(raw)) {
        speaker = "other";
        label = labelOf(raw);
      } else throw bad(`social.transcript[${i}].speaker must be "user", "other" or a speaker label`);
      return {
        speaker,
        text: str(e.text, `social.transcript[${i}].text`, LIMITS.socialLine),
        ...(speaker === "other" && label ? { label } : {}),
      };
    }).filter((l) => l.text);
    const inRaw = x.interests ?? [];
    if (!Array.isArray(inRaw)) throw bad("social.interests must be an array");
    if (inRaw.length > LIMITS.socialInterests) {
      throw new HttpError(
        413,
        "payload_too_large",
        `social.interests exceeds ${LIMITS.socialInterests} items`,
      );
    }
    const interests = inRaw.map((t, i) => str(t, `social.interests[${i}]`, LIMITS.socialInterest))
      .filter(Boolean);
    social = {
      style,
      trigger: trigger as SocialTrigger,
      transcript,
      interests,
      profile: str(x.profile, "social.profile", LIMITS.socialProfile),
      // A stored calibration longer than the cap is cut, not rejected (it would block every request).
      calibration: typeof x.calibration === "string"
        ? x.calibration.trim().slice(0, LIMITS.socialCalibration)
        : str(x.calibration, "social.calibration", LIMITS.socialCalibration),
      calibrate: str(x.calibrate, "social.calibrate", LIMITS.socialCalibrate),
      ...(typeof x.speaker === "string" && /^[\p{L}\p{N} .'-]{1,24}$/u.test(x.speaker.trim()) &&
          !/^(du|jag|you)$/i.test(x.speaker.trim())
        ? { fragmentSpeaker: x.speaker.trim() }
        : {}),
    };
  }

  const length = o.length === undefined || o.length === null ? "adaptive" : o.length;
  if (length !== "short" && length !== "adaptive" && length !== "long") {
    throw bad('length must be "short", "adaptive" or "long"');
  }
  const source = o.source === undefined || o.source === null ? "app" : o.source;
  if (source !== "app" && source !== "demo") throw bad('source must be "app" or "demo"');
  return {
    fragment,
    mode,
    language,
    length,
    source,
    goals,
    persona,
    personaSetup,
    turn,
    social,
    commands,
    memories,
    context: { transcript, recent_qa, prep_terms },
  };
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
