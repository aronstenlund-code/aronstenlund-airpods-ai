/**
 * K42.4 (Aron's phone test 18:58: "varför upprepar du", "varför svarar du inte" got empty promises, "jag ska inte
 * upprepa det"): a complaint about Lumen itself gets an honest short answer in code and never a promise of a change;
 * the turn is marked `complaint` in qa_log (only with consent v5) so it shows on Aron's page.
 */
const N = (t: string) =>
  t.toLowerCase().replace(/[^\p{L}\s]/gu, " ").replace(/\s+/g, " ").trim()
    .replace(/^(?:(?:hej|okej|ok|men|asså|alltså|eh|öh) )*(?:lumen |earmind )?/u, "").trim();

const COMPLAINT = new RegExp([
  // repeating
  String.raw`^varför (?:upprepar|repeterar) du(?: (?:dig|det|allt|samma|svaret|svaren|hela tiden|igen|dig själv)\b.*)?$`,
  String.raw`^varför säger du (?:samma (?:sak|svar)|det igen|allt två gånger|det två gånger)(?: .*)?$`,
  String.raw`^(?:du|nu) (?:upprepar|repeterar) (?:du )?(?:dig|det|allt|samma|svaret)(?: .*)?$`,
  String.raw`^sluta (?:upprepa|repetera|säga samma)(?: .*)?$`,
  String.raw`^du sa (?:ju )?(?:det|samma sak) (?:redan|två gånger|igen)$`,
  // not answering, not hearing
  String.raw`^varför (?:svarar|lyssnar|hör) du inte(?: .*)?$`,
  String.raw`^du (?:svarar|lyssnar|hör) (?:ju )?inte(?: (?:på|när|vad) .*)?$`,
  String.raw`^varför (?:blev det|är det) tyst$`,
  String.raw`^varför (?:avbryter|pratar) du (?:mig|i mun|hela tiden|när jag pratar)(?: .*)?$`,
  String.raw`^varför (?:tar det|är du) så (?:lång tid|långsam)(?: .*)?$`,
  String.raw`^du (?:har|hörde) (?:hört )?fel(?: igen)?$`,
  String.raw`^varför (?:hör|uppfattar) du fel(?: .*)?$`,
].join("|"), "u");

export function isComplaint(text: string): boolean {
  const t = N(text);
  return !!t && t.split(" ").length <= 14 && COMPLAINT.test(t);
}

/** Honest and short; never "jag ska inte göra om det" (the model cannot change itself). */
export function complaintAnswer(logged: boolean): string {
  return logged
    ? "Det låter som ett fel. Jag har sparat det så att det kan rättas."
    : "Det låter som ett fel. Skriv gärna det i appens feedback, så kan det rättas.";
}
