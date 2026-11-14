/**
 * K44 (Aron 21:16, D118): EarMind knows what it is called and what it can do, from ONE list that the app reads too:
 * `Shared/capabilities.json` (repo root). The functions are deployed from backend/, so a copy lives next to this file
 * and `capabilities_test.ts` fails when the two differ.
 *
 *   capabilityAsked("kan du sätta en timer?")   -> the capability, or null
 *   capabilityAnswer(cap, granted)              -> "Ja. Säg till exempel: …" / "Ja, men du behöver tillåta …" / "Det kommer snart."
 *   notYetAsked("kan du skicka sms?")           -> true (an honest no)
 *   helpAnswer("hur stänger jag av dig?")       -> the short help text, or null
 */
import LIST from "./capabilities.json" with { type: "json" };

export interface Capability {
  id: string;
  group: string;
  name: string;
  say: string;
  status: "finns" | "kommer";
  permission?: string;
  tool?: string;
  /** the model carries out a concrete request itself */
  model?: boolean;
  /** offered while the capability is coming */
  instead?: string;
  ask: string[];
}
export const CAPS = LIST.capabilities as Capability[];
export const ASSISTANT_IDENTITY = LIST.identity;
const NOT_YET = new RegExp(String.raw`(?<![\p{L}])(?:${LIST.not_yet.join("|")})(?![\p{L}])`, "iu");
const HELP = LIST.help.map((h) => ({ id: h.id, re: new RegExp(String.raw`(?<![\p{L}])(?:${h.ask.join("|")})`, "iu"), answer: h.answer }));
const CAP_RE = CAPS.map((c) => ({ c, re: new RegExp(String.raw`(?<![\p{L}])(?:${c.ask.join("|")})`, "iu") }));

/** "kan du …", "går det att …", "kan EarMind …", "klarar du att …", "har du (en) …": a question about an ability. */
const ABILITY = /^(?:(?:hej|okej|ok)\s+)?(?:(?:lumen|earmind),?\s+)?(?:kan (?:du|earmind|lumen|appen|man)|går det att|klarar (?:du|earmind)|är det möjligt att|har (?:du|appen|earmind) (?:en |ett |någon |något )?|funkar det att|fungerar det att|vet du hur man|kan jag (?:be dig|få dig att))(?![\p{L}])/iu;
const PERM_NAME: Record<string, string> = { calendar: "kalendern", reminders: "påminnelser", alarms: "larm och timer", contacts: "kontakterna" };

export function isAbilityQuestion(text: string): boolean {
  return ABILITY.test(text.trim());
}

const GENERIC = /(?<![\p{L}])(?:saker|grejer|sånt|sådant|frågor|mig|åt mig|för mig|det|lite|också|med|även|något|nåt|åt|en|ett|i|min|mitt|mina|på|telefonen|mobilen|appen)(?![\p{L}])/giu;

/** The capability a "kan du …?" asks about. A capability without a phone tool (questions, translate, web, training)
 *  counts only when nothing but generic words follow ("kan du förklara saker?"); "kan du förklara fotosyntes" is a
 *  real question for the model. */
export function capabilityAsked(text: string): Capability | null {
  const t = text.trim().replace(/[?.!]+$/u, "");
  if (!ABILITY.test(t)) return null;
  const rest = t.replace(ABILITY, " ");
  for (const { c, re } of CAP_RE) {
    const m = re.exec(rest);
    if (!m) continue;
    if ((c.tool && c.tool !== "switch_mode") || !c.model) return c; // only what the model can do needs a bare question
    // "kan du ge mig ett träningspass", "kan du göra ett förhör": a request the model carries out
    // (only where the model can: not "kan du ge mig en morgonrapport om min sömn", Oscar O52)
    if (c.model && /(?<![\p{L}])(?:ge mig|gör|göra|skriv|skriva|skapa|hitta på|föreslå|ta fram)(?![\p{L}])/iu.test(rest)) return null;
    const after = rest.slice(m.index + m[0].length).replace(/^\p{L}*/u, "").replace(GENERIC, " ").replace(/[,]/g, " ").trim();
    return after ? null : c;
  }
  return null;
}

export function notYetAsked(text: string): boolean {
  return ABILITY.test(text.trim()) && NOT_YET.test(text);
}

export function capabilityAnswer(c: Capability, granted?: string[]): string {
  const say = c.say.replace(/\.$/, "");
  const end = /[?!]$/.test(say) ? "" : "."; // Oscar O52: never "i morgon?."
  if (c.status === "kommer") return `Det kommer snart. ${c.name} går inte än.${c.instead ? ` ${c.instead}` : ""}`;
  if (c.permission && granted && !granted.includes(c.permission)) {
    return `Ja, men du behöver tillåta ${PERM_NAME[c.permission] ?? c.permission} i appen först. Sedan säger du till exempel: ${say}${end}`;
  }
  return /^Lumen,/.test(say) ? `Ja. Säg till exempel: ${say}${end}` : `Ja. ${say}${end}`;
}

export const NOT_YET_ANSWER = "Nej, det kan jag inte än. Jag kan svara på frågor, förhöra dig, sätta timer och larm, påminna dig, lägga in i kalendern, ringa och öppna musik.";

/** "Vad kan du göra?": a short spoken overview from the list (only what exists). */
export function overview(): string {
  const have = CAPS.filter((c) => c.status === "finns");
  const pick = (g: string) => have.filter((c) => c.group === g).map((c) => c.name.toLowerCase());
  return `Jag är en AI-agent i dina AirPods för vardag, skola och jobb. I skolan: ${pick("skola").join(", ")}. I vardagen: ${pick("vardag").join(", ")}. Jag kan också ringa, öppna musik, översätta, söka på webben och hjälpa dig i intervjuer och samtal. Säg Lumen och vad du vill.`;
}

export function helpAnswer(text: string): string | null {
  const t = text.trim();
  if (!/^(?:(?:hej|okej|ok)\s+)?(?:(?:lumen|earmind),?\s+)?(?:hur|var|vad ska jag göra för att|kan jag|går det att)(?![\p{L}])/iu.test(t)) return null;
  return HELP.find((h) => h.re.test(t))?.answer ?? null;
}

/** For the system prompt: the list in one paragraph (K44: never "jag kan inte" about something that exists). */
export function capabilitiesRule(name: string, granted?: string[]): string {
  const have = CAPS.filter((c) => c.status === "finns").map((c) => `${c.name}${c.permission && granted && !granted.includes(c.permission) ? " (needs permission in the app)" : ""}`);
  const soon = CAPS.filter((c) => c.status === "kommer").map((c) => c.name);
  return `\n- You are ${name}, an AI agent in AirPods for everyday life, school and work (never call yourself a study assistant or studieassistent). What the app can do (the user starts it with "Lumen, …"): ${have.join(", ")}. Coming soon: ${soon.join(", ")}. Asked whether you can do one of these, say yes and how to ask for it (for example "Ja, säg: Lumen, sätt en timer på tio minuter"); never say that you cannot do something on this list. Asked about something not on it, say honestly that you cannot do it yet.`;
}
