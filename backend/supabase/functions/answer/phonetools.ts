import { wordsToNumber } from "./svnum.ts";

/**
 * K35 (D122): phone tools the app runs (calendar, reminders, timer, alarm, notes), offered to the model through
 * Claude tool use. Protocol (docs/AGENT.md):
 *   1. The app lists what it can run: `tools_available: ["calendar_add", …]` (A48). Without it nothing changes.
 *   2. The model calls a tool -> SSE `tool_call` {id, name, input, confirm, kind} and `done.tool_pending: true`.
 *      `confirm` is the yes/no question the app says first for a write ("Ska jag lägga in …?"), null for reads
 *      and harmless actions (a timer). The app runs the tool only after a yes.
 *   3. The app sends the same request again with `tool_round: {call: {id, name, input}, status, result}`
 *      (status ok | declined | error); the model then says one short sentence ("Klart, …").
 * Inputs are validated here before they are sent to the app (the model's JSON is never trusted).
 */

export type PhoneToolName = "calendar_add" | "calendar_list" | "reminder_add" | "timer_start" | "alarm_set" | "note_add" | "call_contact" | "music_open";
export const PHONE_TOOLS: PhoneToolName[] = ["calendar_add", "calendar_list", "reminder_add", "timer_start", "alarm_set", "note_add", "call_contact", "music_open"];

const LOCAL_DT = "Local date and time in Sweden, ISO 8601 without zone, e.g. 2026-11-12T15:00";
const obj = (properties: Record<string, unknown>, required: string[]) => ({
  type: "object",
  properties,
  required,
  additionalProperties: false,
});

const DEFS: Record<PhoneToolName, { description: string; input_schema: unknown; write: boolean }> = {
  calendar_add: {
    write: true,
    description: "Add an event to the user's calendar on the phone. Use only when the user asks to put something in the calendar or book a time. Absolute dates from <now>.",
    input_schema: obj({
      title: { type: "string", description: "Short title in Swedish, e.g. Tandläkaren" },
      start: { type: "string", description: LOCAL_DT },
      end: { type: "string", description: `${LOCAL_DT}; omit for one hour` },
      all_day: { type: "boolean" },
      location: { type: "string" },
    }, ["title", "start"]),
  },
  calendar_list: {
    write: false,
    description: "Read the user's calendar events between two local times, to answer questions like 'vad har jag i morgon'.",
    input_schema: obj({ from: { type: "string", description: LOCAL_DT }, to: { type: "string", description: LOCAL_DT } }, ["from", "to"]),
  },
  reminder_add: {
    write: true,
    description: "Add a reminder on the phone (Påminnelser). Use when the user asks to be reminded.",
    input_schema: obj({
      title: { type: "string", description: "What to remember, in Swedish" },
      due: { type: "string", description: `${LOCAL_DT}; omit when no time was said` },
    }, ["title"]),
  },
  timer_start: {
    write: false,
    description: "Start a countdown timer on the phone.",
    input_schema: obj({
      seconds: { type: "integer", description: "1 to 86400" },
      label: { type: "string" },
    }, ["seconds"]),
  },
  alarm_set: {
    write: true,
    description: "Set an alarm on the phone at a local time (HH:MM, 24 h).",
    input_schema: obj({
      time: { type: "string", description: "HH:MM, 24 h" },
      label: { type: "string" },
    }, ["time"]),
  },
  note_add: {
    write: false,
    description: "Save a short note in Lumen's own notes (in the app).",
    input_schema: obj({ text: { type: "string" } }, ["text"]),
  },
  // K36 (D125): the app looks the name up in Contacts (only with permission) and opens the call; iOS itself asks
  // the user to confirm the call (one tap), so there is no confirm question from Lumen as well
  call_contact: {
    write: true,
    description: "Start a phone call. Use whenever the user asks you to call someone or something NOW ('ring mamma', 'ring Elin', 'ring tandläkaren', 'ring skolan'): the app looks `name` up in the user's own contacts, so a name is always enough and you never need or look up a number. `name` is exactly as the user said it; `number` only when the user said the digits themself (digits said as words count: 'noll sju tre fyra' = 0734), and always for an emergency or help number the user asks for (112, 1177, 116 111, 90101): call it, never refuse. Not when the user only tells you that someone called or that they will call later ('mamma ringde nyss', 'jag ska ringa sen'). Never make up a number.",
    input_schema: obj({
      name: { type: "string", description: "The contact's name as said, e.g. mamma" },
      number: { type: "string", description: "Only digits the user said, e.g. 0701234567" },
    }, []),
  },
  // K36: opens the music app on the phone with a search (works without a Spotify connection; the user taps play)
  music_open: {
    write: false,
    description: "Open the user's music app (Spotify) on the phone with a search for what they want to hear. Use when the user asks to play music and no Spotify tool is offered.",
    input_schema: obj({ query: { type: "string", description: "What to play, as the user said it" } }, ["query"]),
  },
};

/** The Anthropic tool definitions for the tools the app offers (strict: inputs follow the schema exactly). */
export function phoneToolDefs(available: string[]): unknown[] {
  return PHONE_TOOLS.filter((n) => available.includes(n)).map((name) => ({
    name,
    description: DEFS[name].description,
    input_schema: DEFS[name].input_schema,
    strict: true,
  }));
}

export const isPhoneTool = (n: string): n is PhoneToolName => (PHONE_TOOLS as string[]).includes(n);

const DT = /^\d{4}-\d{2}-\d{2}(?:T\d{2}:\d{2}(?::\d{2})?)?$/;
const s = (v: unknown, max: number) => typeof v === "string" && v.trim().length > 0 && v.length <= max;

const digits = (v: string) => v.replace(/\D/g, "");
/** O41: the digits the user said, also as words ("noll sju tre, fyra fem sex, sjuttioåtta nittio" = 073456 7890). */
export function spokenDigits(heard: string): string {
  let out = "";
  for (const w of heard.toLowerCase().split(/[^\p{L}\d]+/u)) {
    if (!w) continue;
    if (/^\d+$/.test(w)) {
      out += w;
      continue;
    }
    const n = w === "en" || w === "ett" ? null : wordsToNumber(w); // "en"/"ett" are usually articles
    if (n !== null && n >= 0 && n < 1000) out += String(n);
  }
  return out;
}

/** Checks a model's tool input; returns a clean copy or null (never run, never sent to the app). `heard` (the user's
 *  words) is given for a new call: a phone number is kept only when its digits were said (B6: no invented numbers). */
export function validatePhoneInput(name: string, input: unknown, heard?: string): Record<string, unknown> | null {
  if (!isPhoneTool(name) || !input || typeof input !== "object" || Array.isArray(input)) return null;
  const i = input as Record<string, unknown>;
  const dt = (k: string, req: boolean) => (i[k] === undefined ? !req : typeof i[k] === "string" && DT.test(i[k] as string));
  switch (name) {
    case "calendar_add":
      if (!s(i.title, 120) || !dt("start", true) || !dt("end", false)) return null;
      if (i.location !== undefined && !s(i.location, 120)) return null;
      return { title: String(i.title).trim(), start: i.start, ...(i.end ? { end: i.end } : {}), ...(i.all_day === true ? { all_day: true } : {}), ...(i.location ? { location: String(i.location).trim() } : {}) };
    case "calendar_list":
      return dt("from", true) && dt("to", true) ? { from: i.from, to: i.to } : null;
    case "reminder_add":
      return s(i.title, 160) && dt("due", false) ? { title: String(i.title).trim(), ...(i.due ? { due: i.due } : {}) } : null;
    case "timer_start": {
      const n = Number(i.seconds);
      if (!Number.isInteger(n) || n < 1 || n > 86400) return null;
      if (i.label !== undefined && !s(i.label, 60)) return null;
      return { seconds: n, ...(i.label ? { label: String(i.label).trim() } : {}) };
    }
    case "alarm_set":
      if (typeof i.time !== "string" || !/^(?:[01]\d|2[0-3]):[0-5]\d$/.test(i.time)) return null;
      return { time: i.time, ...(s(i.label, 60) ? { label: String(i.label).trim() } : {}) };
    case "note_add":
      return s(i.text, 1000) ? { text: String(i.text).trim() } : null;
    case "call_contact": {
      const nm = s(i.name, 80) ? String(i.name).trim() : "";
      let num = typeof i.number === "string" && /^\+?[\d\s-]{3,20}$/.test(i.number.trim()) ? i.number.trim() : "";
      if (num && heard !== undefined && !spokenDigits(heard).includes(digits(num))) num = ""; // not said: never dialled
      if (!nm && !num) return null;
      return { ...(nm ? { name: nm } : {}), ...(num ? { number: num } : {}) };
    }
    case "music_open":
      return s(i.query, 120) ? { query: String(i.query).trim() } : null;
  }
  return null;
}

const MONTHS = ["januari", "februari", "mars", "april", "maj", "juni", "juli", "augusti", "september", "oktober", "november", "december"];
const DAYS = ["söndag", "måndag", "tisdag", "onsdag", "torsdag", "fredag", "lördag"];
/** "torsdag tolfte november klockan 15:00" style, spoken numbers are made later by the speech step. */
export function whenSv(dt: string): string {
  const m = /^(\d{4})-(\d{2})-(\d{2})(?:T(\d{2}):(\d{2}))?/.exec(dt);
  if (!m) return dt;
  const d = new Date(Date.UTC(+m[1], +m[2] - 1, +m[3]));
  const day = `${DAYS[d.getUTCDay()]} den ${+m[3]} ${MONTHS[+m[2] - 1]}`;
  return m[4] ? `${day} klockan ${m[4]}:${m[5]}` : day;
}

/** The yes/no question before a write, or null when the action needs no confirmation (D122: confirm changes). */
export function confirmText(name: PhoneToolName, input: Record<string, unknown>): string | null {
  switch (name) {
    case "calendar_add":
      return `Ska jag lägga in ${input.title} ${input.all_day ? whenSv(String(input.start).slice(0, 10)) : whenSv(String(input.start))} i kalendern?`;
    case "reminder_add":
      return input.due ? `Ska jag påminna dig om ${input.title} ${whenSv(String(input.due))}?` : `Ska jag lägga in en påminnelse om ${input.title}?`;
    case "alarm_set":
      return `Ska jag ställa ett larm på ${input.time}?`;
    case "call_contact":
      return null; // iOS asks before the call (one tap)
    default:
      return null;
  }
}

export const toolKind = (name: PhoneToolName): "read" | "write" => (DEFS[name].write || name === "timer_start" || name === "note_add" ? "write" : "read");

/** The system prompt rule when phone tools are offered (cached: one variant). */
export const PHONE_TOOLS_RULE = `
Phone tools (K35): always reply in Swedish. When the user asks you to DO something on their phone (put an event in the calendar, remind them, start a timer, set an alarm, save a note, read what is in the calendar, call someone, open music), call the matching tool and write NOTHING before the call; dates and times are absolute, worked out from <now>, in Swedish local time. Never claim it is done before the tool result says so. When a tool result comes back, say ONE short sentence in Swedish (done, or what the calendar holds, or that it did not work). Never call a tool for an ordinary question.`;

/** K35: an utterance that asks the phone to do something: its text is held until the tool call or the end. */
export const ACTION_REQUEST = /(?<![\p{L}])(?:lägg in|lägga in|boka|påminn|påminna|sätt (?:en |på en )?(?:timer|nedräkning|larm|alarm)|ställ (?:en |ett )?(?:timer|larm|alarm|väckarklocka)|starta (?:en )?(?:timer|nedräkning)|väck mig|spara (?:en )?anteckning|anteckna|skriv upp|kom ihåg att|vad har jag (?:i|på|för)|vad står i (?:min )?kalender|när har jag|timer på|larm (?:på|klockan)|ring|ringa|ringer du|slå en signal|spela|sätt på (?:lite |någon |en |min |mina )?(?:musik|låt|låten|spellista|spellistan|spotify)|kör (?:lite|en låt|spellistan|låten|musik)|lyssna på)(?![\p{L}])/iu;

/** O41 (BLOCKER): the app sends Standardläge as mode "auto", which hears other people too. A phone tool is offered
 *  there only when the utterance is addressed to Lumen (the wake word first, or the app's voice instruction) or
 *  STARTS with the request ("ring mamma", "sätt en timer på fem minuter"); something said in passing is not. */
export function isAddressedAction(fragment: string, voiceInstruction = false): boolean {
  const f = (fragment ?? "").trim();
  const wake = /^(?:(?:hej|okej|ok)\s+)?lumen[,!.]?\s*/iu;
  const addressed = wake.test(f) || voiceInstruction;
  const lead = f.replace(wake, "").replace(/^(?:snälla\s+)?(?:kan du|kunde du|skulle du kunna|vill du|jag vill att du|du får gärna)\s+(?:snälla\s+)?/iu, "")
    .replace(/^snälla\s+/iu, "");
  const m = ACTION_REQUEST.exec(lead);
  return !!m && (addressed || m.index === 0);
}

export interface ToolRound {
  call: { id: string; name: PhoneToolName; input: Record<string, unknown> };
  status: "ok" | "declined" | "error";
  result?: unknown;
}

/** The messages for the second call: the user's turn, the model's tool call and the app's result. */
export function toolRoundMessages(userText: string, r: ToolRound): unknown[] {
  const content = r.status === "declined"
    ? "The user said no; nothing was done."
    : r.status === "error"
    ? `The phone could not do it: ${JSON.stringify(r.result ?? null).slice(0, 300)}`
    : JSON.stringify(r.result ?? { ok: true }).slice(0, 4000);
  return [
    { role: "user", content: userText },
    { role: "assistant", content: [{ type: "tool_use", id: r.call.id, name: r.call.name, input: r.call.input }] },
    { role: "user", content: [{ type: "tool_result", tool_use_id: r.call.id, content, ...(r.status === "ok" ? {} : { is_error: true }) }] },
  ];
}
