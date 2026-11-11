/**
 * K20 (Deangelo's reality tests 2026-11-10: "Lyssnar du hela tiden?" was silence; "Sparar du det jag säger?" gave an
 * answer that left out the server and the AI model): questions about Lumen itself always get an honest answer that
 * says what is true (it used to repeat "Om appen" word for word; Angela changes AboutView.swift after Aron's O16 decision).
 * Answered in code, never by the model.
 */

const N = (t: string) =>
  t.toLowerCase().replace(/[^\p{L}\s]/gu, " ").replace(/\s+/g, " ").trim()
    .replace(/^(?:(?:hej|okej|ok|men|du|asså) )*(?:lumen )?/u, "").replace(/ (?:lumen|då|eller|egentligen|asså)$/u, "").trim();

// K27 (Oscar O24: 5/20 new phrasings): matched on content (who is asked + what about), not on whole sentences
const ROBOT = new RegExp([
  String.raw`^(?:är du (?:en )?(?:robot|ai|människa|riktig människa|dator|bot|chattbot|chatbot|levande|på riktigt)|vad är du(?: för något)?|vem är du|är det en människa som svarar|pratar jag med en (?:människa|robot|ai)|är du riktig)$`,
  String.raw`^(?:är|e) (?:du|lumen) (?:en |på )?(?:riktig |riktigt )?(?:ai|robot|människa|bot|chattbot|chatbot|chatgpt|gpt|claude|gemini|dator|program|riktig|levande|på riktigt)(?: eller.*)?$`,
  String.raw`^är det (?:en )?(?:chatgpt|gpt|claude|gemini|ai|robot|bot|människa|riktig människa)(?: som (?:svarar|pratar))?$`,
  String.raw`^(?:vilken|vad för) (?:ai|ai modell|modell|språkmodell)(?: är du| använder (?:du|ni|lumen)| är det| är lumen)$`,
  String.raw`^vem (?:har )?(?:gjort|skapat|byggt|programmerat|tränat|utvecklat|äger) (?:dig|lumen|appen)$`,
  String.raw`^(?:använder|bygger) (?:du|lumen|ni) (?:på )?(?:chatgpt|gpt|claude|gemini|openai|en ai)$`,
].join("|"), "u");
const LISTEN = new RegExp([
  String.raw`(?:^|\s)(?:tjuv|av)?lyssnar (?:du|lumen|appen)(?: (?:hela tiden|alltid|nu|på mig|på oss|på allt|på det|på lektionen|när|även|fast|i bakgrunden|i smyg)(?: .*)?)?$`,
  String.raw`^(?:kan |hör )?(?:du|lumen|appen) (?:höra|hör) (?:mig|oss|allt|vad jag|det jag)(?: .*)?$`,
  String.raw`^hör du (?:allt|mig|oss|vad jag|det jag)(?: .*)?$`,
  String.raw`(?:^|\s)spelar (?:du|lumen|appen) in(?: (?!en |ett |låt|musik|video|podd|film).*)?$`,
  String.raw`^(?:spelas|tas) (?:det|det här|detta|lektionen|allt) (?:in|upp)$`,
  String.raw`^är (?:det här|detta|lektionen|det) inspelat$`,
].join("|"), "u");
const SAVE = new RegExp([
  String.raw`^(?:sparar|lagrar) (?:du|lumen|appen|ni) (?:det|vad|allt|ljud|ljudet|mina|min|det här)(?: .*)?$`,
  String.raw`^(?:sparas|lagras) (?:det|ljudet|mina|vad|allt|det jag)(?: .*)?$`,
  String.raw`^(?:vem|vilka) (?:ser|kan se|kan läsa|läser|kan höra|får se|får läsa) (?:det jag|vad jag|mina)(?: .*)?$`,
  String.raw`^kan (?:läraren|lärarna|mina föräldrar|föräldrarna|mamma|pappa|skolan|någon|ni|andra|rektorn) (?:se|läsa|höra|få se) (?:vad jag|det jag|mina)(?: .*)?$`,
  String.raw`^(?:säljer|delar) (?:ni|du|lumen) (?:min|mina|data|det jag)(?: .*)?$`,
  String.raw`^(?:vart|var|vem) (?:skickas|tar|hamnar|går) (?:ljudet|det jag säger|mina frågor|det)(?: vägen)?$`,
  String.raw`^skickas (?:det|ljudet|mina frågor|det jag säger)(?: .*)?$`,
  String.raw`^vad händer med (?:det jag|ljudet|mina)(?: .*)?$`,
].join("|"), "u");

// K-stående omgång 2 (Oscar O34 grupp 13: one fixed text per group answered the wrong question in 6/11, and "ljud
// sparas inte" is not true for ElevenLabs on our plan, O16 verified live): the answer is chosen by WHAT is asked
const WHO_MADE = /^vem (?:har )?(?:gjort|skapat|byggt|programmerat|programmerade|tränat|utvecklat|utvecklade|äger|gjorde|skapade|byggde) (?:dig|lumen|appen)$/u;
const WHICH_AI = /(?:chatgpt|gpt|openai|claude|gemini|anthropic|vilken (?:ai|ai modell|modell|språkmodell)|vad för (?:ai|modell))/u;
const WHO_SEES = /^(?:(?:vem|vilka) (?:ser|kan se|kan läsa|läser|kan höra|får se|får läsa)|kan (?:läraren|lärarna|mina föräldrar|föräldrarna|mamma|pappa|skolan|någon(?: annan)?|ni|andra|rektorn) (?:se|läsa|höra|få se))(?: .*)?$/u;
const SELL = /^(?:säljer|delar) (?:ni|du|lumen) /u;
const AUDIO = /(?:ljud|ljudet|det jag säger|tar du upp|spelar (?:du|lumen|appen) in|spelas|inspelat|bakgrunden)/u;
const LISTEN_EXTRA = /^(?:hör du vad (?:min |mina )?lärare(?:n|na)? säger|tar du upp (?:ljud|det jag säger|allt)(?: .*)?)$/u;
const BOT_EXTRA = /^är du (?:typ |liksom |alltså )?(?:en )?(?:bot|robot|ai|människa)$/u;
const SEE_EXTRA = /^kan (?:någon|andra|någon annan) (?:läsa|se|höra) (?:det här|detta|det)$/u;

export type SelfTopic = "robot" | "who_made" | "which_ai" | "listen" | "who_sees" | "sell" | "audio" | "save";

/** Spoken answers. True today: Lumen stores no audio, but ElevenLabs (speech to text) may keep it under its terms
 *  (zero retention needs their enterprise tier, O16); questions and answers go through Lumen's server to Anthropic's
 *  model; with consent v5 (K30) the developer reads questions and answers to improve the app, deleted within 14 days. */
export const SELF_TEXT: Record<SelfTopic, string> = {
  robot: "Jag är Lumen, en AI-assistent, alltså ingen människa. Frågor och svar går via Lumens server till en AI-modell.",
  who_made: "Lumen är en svensk app från ett litet team. Svaren skrivs av en AI-modell, Claude från Anthropic.",
  which_ai: "Nej, Lumen är inte ChatGPT. Svaren skrivs av en AI-modell från Anthropic som heter Claude.",
  listen: "Lumen lyssnar bara när du har startat den, och du ser alltid när den lyssnar. Lumen sparar inget ljud, men ElevenLabs, som skriver ut talet, kan spara det enligt sina villkor.",
  who_sees: "Din lärare och dina föräldrar kan inte se dina frågor. Om du har godkänt det i samtycket läser utvecklaren av Lumen frågor och svar för att göra appen bättre, och de raderas inom 14 dagar.",
  sell: "Nej, vi säljer ingen data. Frågor och svar används bara för att svara dig, och om du har godkänt det, för att göra appen bättre.",
  audio: "Lumen sparar inget ljud. Talet skickas till ElevenLabs, som skriver ut det och kan spara det en tid enligt sina villkor. Frågan går sedan via Lumens server till AI-modellen.",
  save: "Lumen sparar inget ljud, men ElevenLabs, som skriver ut talet, kan spara det enligt sina villkor. Frågor och svar går via Lumens server till en AI-modell, och om du har godkänt det läser utvecklaren dem och raderar dem inom 14 dagar. Röstprofilen och dina inställningar ligger bara på den här telefonen.",
};

/** What a question about Lumen itself asks, or null when it is not one. */
export function selfTopic(text: string): SelfTopic | null {
  const t = N(text);
  if (!t || t.split(" ").length > 12) return null;
  if (WHO_MADE.test(t)) return "who_made";
  if (ROBOT.test(t) || BOT_EXTRA.test(t)) return WHICH_AI.test(t) ? "which_ai" : "robot";
  if (LISTEN.test(t) || LISTEN_EXTRA.test(t)) return /bakgrunden|tar du upp/u.test(t) ? "audio" : "listen";
  if (SEE_EXTRA.test(t)) return "who_sees";
  if (SAVE.test(t)) {
    if (WHO_SEES.test(t)) return "who_sees";
    if (SELL.test(t)) return "sell";
    if (AUDIO.test(t)) return "audio";
    return "save";
  }
  return null;
}

/** The answer text when the utterance is a question about Lumen itself, else null. */
export function selfAnswer(text: string): string | null {
  const k = selfTopic(text);
  return k ? SELF_TEXT[k] : null;
}
