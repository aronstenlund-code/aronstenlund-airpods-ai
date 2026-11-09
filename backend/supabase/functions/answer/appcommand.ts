/**
 * K10.1 (owner 2026-11-08 21:26: "man ska inte behöva kunna de exakta kommandona"): a request to control the APP in
 * the user's own words ("kan vi köra vanliga frågor nu", "jag vill öva inför provet", "sluta lyssna en stund") is
 * returned as `meta.app_command` = {action, mode?, confidence}; the app carries it out with an undo (A9). Decided in
 * code before the model call (no extra call). Never when the user only talks ABOUT a mode or uses the words in an
 * ordinary sentence: the whole (short) utterance must be a request, with a request frame ("kan vi", "jag vill",
 * "ska vi", "låt oss", an imperative) and a mode name or a listening verb.
 */

export type AppMode = "fragor" | "prov" | "intervju" | "socialt" | "rizz";
export interface AppCommand {
  action: "switch_mode" | "pause" | "stop" | "resume";
  mode?: AppMode;
  confidence: number;
}

/** The mode the request came from (so "jag vill öva inför provet" inside Provläge is not a switch). */
export function currentMode(req: { mode: string; persona: string; social?: { style?: string } | null }): AppMode | null {
  if (req.persona === "interview") return "intervju";
  if (req.persona === "social") return req.social?.style === "flirt" ? "rizz" : "socialt";
  if (req.mode === "tutor" && req.persona === "tutor") return "prov";
  if (req.mode === "push_to_talk" || req.mode === "auto" || req.mode === "text") return "fragor";
  return null;
}

// a request frame: "kan vi", "ska vi", "jag vill", "låt oss", "nu kör vi", or an imperative verb first
const FRAME =
  String.raw`(?:(?:kan|ska|skulle) vi (?:inte )?|vi kan |låt oss |jag vill (?:att vi |hellre )?|jag skulle vilja |nu (?:kör|tar) vi |dags (?:att|för) |vi (?:kör|tar) |)`;
const GO = String.raw`(?:köra|kör|ta|gå (?:över )?till|gå tillbaka till|byta till|byt till|växla till|starta|börja med|ha|använda|köra med|testa|öppna|sätta på|slå på|tillbaka till|över till)`;
const MODE_WORDS: [AppMode, string][] = [
  // "frågor" alone is too open ("kan vi köra frågor" in Provläge can mean a quiz): "vanliga frågor" or the mode name
  ["fragor", String.raw`(?:vanliga|bara vanliga) frågor|frågor(?:läget|läge)|frågeläget|frågeläge`],
  ["prov", String.raw`provläget|provläge|plugg(?:läget|läge)?|förhörsläget`],
  ["intervju", String.raw`intervjuläget|intervjuläge|intervjuträning|en (?:jobb)?intervju|(?:jobb)?intervjun`],
  ["socialt", String.raw`socialt(?: läge)?|sociala läget`],
  ["rizz", String.raw`rizz(?:läget|läge)?|rizzläget`],
];
const TAIL = String.raw`(?: nu| igen| ett tag| en stund| istället| i stället| lite| då| nu då| tack)*`;

// "jag vill öva inför provet", "nu pluggar vi", "dags att plugga": Provläge without its name
const STUDY_INTENT =
  /^(?:jag vill (?:öva|plugga|plugga lite|förbereda mig) (?:inför|till|för) (?:provet|mitt prov|ett prov|tentan|förhöret)|(?:kan|ska) vi plugga(?: lite)?|nu pluggar vi|dags att plugga|jag ska plugga nu|hjälp mig plugga inför provet|jag vill plugga)(?: nu| lite| tack)*$/u;
// "jag har en intervju snart, kan vi öva", "jag vill öva inför en intervju"
const INTERVIEW_INTENT =
  /^(?:jag vill öva (?:på |inför )?(?:en |min )?(?:jobb)?intervju(?:n)?|kan vi öva (?:på |inför )?(?:en |min )?(?:jobb)?intervju(?:n)?|hjälp mig öva inför (?:en |min )?intervju(?:n)?)(?: nu| tack)*$/u;
// "jag vill bara ställa frågor", "nu vill jag fråga saker"
const QUESTIONS_INTENT =
  /^(?:jag vill (?:bara )?ställa (?:lite )?(?:vanliga )?frågor|nu vill jag (?:bara )?fråga (?:saker|lite)|jag vill fråga om (?:allt möjligt|lite av varje)|sluta förhöra mig|inget mer plugg)(?: nu| tack)*$/u;

const PAUSE =
  /^(?:sluta lyssna|lyssna inte|pausa|pausa lyssnandet|ta en paus|vänta med att lyssna|sluta lyssna på mig|du kan sluta lyssna|inte lyssna|tyst en stund|var tyst en stund|håll tyst en stund)(?: nu| ett tag| en stund| lite| tack| en liten stund)*$/u;
const STOP =
  /^(?:avsluta(?: sessionen| lyssnandet| lyssningen| passet)?|stäng av(?: dig)?|vi är klara(?: för idag| nu)?|det var allt för idag|nu slutar vi|sluta helt|stäng av lumen|vi slutar för idag)(?: nu| tack)*$/u;
const RESUME = /^(?:(?:börja |fortsätt )?lyssna igen|du kan lyssna igen|fortsätt lyssna|lyssna nu)(?: nu| tack)*$/u;

const SWITCH = MODE_WORDS.map(([m, w]) => [m, new RegExp(`^${FRAME}${GO} (?:till )?(?:${w})${TAIL}$`, "u")] as const);
// "nu kör vi provläget", "vi tar intervjuläget": the verb is in the frame
const SWITCH_VI = MODE_WORDS.map(([m, w]) => [m, new RegExp(`^(?:nu |då )?(?:kör|tar|testar) vi (?:${w})${TAIL}$|^vi (?:kör|tar) (?:${w})${TAIL}$`, "u")] as const);
const BARE = MODE_WORDS.map(([m, w]) => [m, new RegExp(`^(?:${w})(?: nu| tack| igen)*$`, "u")] as const);

/** Lower case, no punctuation, no leading "Lumen" (the request frame words are kept: they carry the meaning). */
function norm(text: string): string {
  return text.toLowerCase().replace(/[^\p{L}\p{N}\s-]/gu, " ").replace(/\s+/g, " ").trim()
    .replace(/^(?:(?:hej|okej|ok) )?lumen /u, "").replace(/ (?:tack|snälla)$/u, "").trim();
}

export function detectAppCommand(text: string, current: AppMode | null): AppCommand | null {
  const t = norm(text);
  if (!t || t.split(" ").length > 12) return null;
  // where other people talk (Intervju, Socialt, Rizz) a command needs "Lumen" first (A7/A9)
  if ((current === "intervju" || current === "socialt" || current === "rizz") && !/^\s*(?:hej\s+|okej\s+)?lumen\b/iu.test(text)) {
    return null;
  }
  if (/^(?:vad|hur|varför|vilket|vilken|när|vem|finns|är|kan man|går det)\s/u.test(t) && !/^(?:kan|ska) vi /u.test(t)) {
    return null; // a question about the app, not a request
  }
  if (PAUSE.test(t)) return { action: "pause", confidence: 0.9 };
  if (STOP.test(t)) return { action: "stop", confidence: 0.85 };
  if (RESUME.test(t)) return { action: "resume", confidence: 0.85 };
  const sw = (mode: AppMode, confidence: number): AppCommand | null =>
    mode === current ? null : { action: "switch_mode", mode, confidence };
  for (const [m, re] of SWITCH) if (re.test(t)) return sw(m, 0.9);
  for (const [m, re] of SWITCH_VI) if (re.test(t)) return sw(m, 0.9);
  if (STUDY_INTENT.test(t)) return sw("prov", 0.8);
  if (INTERVIEW_INTENT.test(t)) return sw("intervju", 0.8);
  if (QUESTIONS_INTENT.test(t)) return sw("fragor", 0.8);
  for (const [m, re] of BARE) if (re.test(t)) return sw(m, 0.7);
  return null;
}

/** At or above this the backend answers nothing itself: the app switches and confirms (A9). */
export const APP_COMMAND_SURE = 0.8;
