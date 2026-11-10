/**
 * K20 (Deangelo's reality tests 2026-11-10: "Lyssnar du hela tiden?" was silence; "Sparar du det jag säger?" gave an
 * answer that left out the server and the AI model): questions about Lumen itself always get an honest answer that
 * says exactly what "Om appen" (Lumen/Features/Settings/AboutView.swift) says. Answered in code, never by the model.
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

/** The answer text when the utterance is a question about Lumen itself, else null. Wording = "Om appen". */
export function selfAnswer(text: string): string | null {
  const t = N(text);
  if (!t || t.split(" ").length > 12) return null;
  if (ROBOT.test(t)) {
    return "Jag är Lumen, en AI-assistent, alltså ingen människa. Frågor och svar går via Lumens server till en AI-modell.";
  }
  if (LISTEN.test(t)) {
    return "Lumen lyssnar bara när du har startat den, du ser alltid när den lyssnar, och ljud sparas inte.";
  }
  if (SAVE.test(t)) {
    return "Ljud sparas inte. Frågor och svar går via Lumens server till en AI-modell. Röstprofilen och dina inställningar ligger bara på den här telefonen.";
  }
  return null;
}
