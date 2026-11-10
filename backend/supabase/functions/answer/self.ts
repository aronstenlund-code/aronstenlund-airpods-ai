/**
 * K20 (Deangelo's reality tests 2026-11-10: "Lyssnar du hela tiden?" was silence; "Sparar du det jag säger?" gave an
 * answer that left out the server and the AI model): questions about Lumen itself always get an honest answer that
 * says exactly what "Om appen" (Lumen/Features/Settings/AboutView.swift) says. Answered in code, never by the model.
 */

const N = (t: string) =>
  t.toLowerCase().replace(/[^\p{L}\s]/gu, " ").replace(/\s+/g, " ").trim()
    .replace(/^(?:(?:hej|okej|ok|men|du|asså) )*(?:lumen )?/u, "").replace(/ (?:lumen|då|eller|egentligen|asså)$/u, "").trim();

const ROBOT = /^(?:är du (?:en )?(?:robot|ai|människa|riktig människa|dator|bot|chattbot|chatbot|levande|på riktigt)|vad är du(?: för något)?|vem är du|är det en människa som svarar|pratar jag med en (?:människa|robot|ai)|är du riktig)$/u;
const LISTEN = /^(?:lyssnar du (?:hela tiden|alltid|nu|på mig|på allt|när jag inte vet om det)|hör du (?:allt|vad jag säger|mig hela tiden)|spelar du in(?: det här| mig| allt)?|är det här inspelat|spelas det här in|tjuvlyssnar du)$/u;
const SAVE = /^(?:sparar du (?:det jag säger|vad jag säger|allt|ljud|ljudet|mina frågor|det här)|vart tar (?:ljudet|det jag säger|mina frågor) vägen|vem kan (?:höra|läsa) (?:det jag säger|det här|mina frågor)|vad händer med (?:det jag säger|ljudet|mina frågor)|skickas det jag säger någonstans|lagrar du (?:det jag säger|ljud|allt))$/u;

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
