/**
 * K114 (D251): English by default; Swedish when the device or browser says Swedish. The server's messages to the user
 * are written in Swedish in the code; for everyone else withCors (cors.ts) swaps a known message for its English one
 * here. The iOS app and every browser send Accept-Language; `x-earmind-lang: sv|en` overrides it (the web's own choice).
 * A message not in the table is left as it is (an untranslated Swedish line is better than a wrong English one).
 */
export function userLang(req: Request): "sv" | "en" {
  const forced = (req.headers.get("x-earmind-lang") ?? "").trim().toLowerCase();
  if (forced === "sv" || forced === "en") return forced;
  const first = (req.headers.get("accept-language") ?? "").split(",")[0]?.trim().toLowerCase() ?? "";
  return /^sv\b/.test(first) ? "sv" : "en";
}

const MONTHS: Record<string, string> = {
  januari: "January", februari: "February", mars: "March", april: "April", maj: "May", juni: "June", juli: "July",
  augusti: "August", september: "September", oktober: "October", november: "November", december: "December",
};
const month = (s: string) => s.replace(/(\d{1,2}) (januari|februari|mars|april|maj|juni|juli|augusti|september|oktober|november|december)/g, (_m, d, m) => `${d} ${MONTHS[m]}`);

const EXACT: Record<string, string> = {
  "EarMind är nere en stund. Försök igen senare.": "EarMind is down for a moment. Try again later.",
  "EarMind har mycket att göra just nu. Försök igen om en stund.": "EarMind is busy right now. Try again in a moment.",
  "Bekräfta att kontot ska raderas.": "Confirm that the account should be deleted.",
  "Bilden tillhör inte det här kontot.": "The picture does not belong to this account.",
  "Demon är tillfälligt otillgänglig.": "The demo is temporarily unavailable.",
  "Demon har nått dagens tak. Kom tillbaka i morgon, gå med i väntelistan eller ladda ner appen.": "The demo has reached today's limit. Come back tomorrow, join the waitlist or download the app.",
  "Demon har läst upp många svar till ditt nätverk i dag. Svaren visas som text, och i morgon läses de upp igen.": "The demo has read many answers aloud to your network today. Answers are shown as text, and tomorrow they are read aloud again.",
  "Den rösten går inte att välja än.": "That voice cannot be chosen yet.",
  "Den rösten går inte att välja.": "That voice cannot be chosen.",
  "Det gick inte att läsa Word-filen. Spara den som PDF och försök igen.": "The Word file could not be read. Save it as a PDF and try again.",
  "Det gick inte att läsa materialet.": "The material could not be read.",
  "Det gick inte att läsa materialet. Fotografera rakt ovanifrån i bra ljus, eller klistra in texten.": "The material could not be read. Take the photo straight from above in good light, or paste the text.",
  "Det gick inte.": "That did not work.",
  "Du har förhandsvisat många texter i dag. Försök igen i morgon.": "You have previewed many texts today. Try again tomorrow.",
  "Du har gjort mycket ljud i dag. Spara provet igen i morgon, så görs resten.": "You have made a lot of audio today. Save the exam again tomorrow and the rest is made.",
  "Du behöver logga in igen.": "You need to sign in again.",
  "Du har många prov sparade. Ta bort några gamla först.": "You have many exams saved. Delete some old ones first.",
  "Fotografera rakt ovanifrån i bra ljus, eller klistra in texten.": "Take the photo straight from above in good light, or paste the text.",
  "För många frågor just nu. Vänta en liten stund.": "Too many questions right now. Wait a moment.",
  "För många förhandsvisningar just nu. Vänta en stund.": "Too many previews right now. Wait a moment.",
  "För många försök i dag.": "Too many tries today.",
  "För många försök just nu.": "Too many tries right now.",
  "För många försök just nu. Vänta en liten stund och försök igen.": "Too many tries right now. Wait a moment and try again.",
  "För många försök just nu. Vänta en liten stund.": "Too many tries right now. Wait a moment.",
  "För många försök. Vänta en stund.": "Too many tries. Wait a moment.",
  "För många länkar just nu. Vänta en stund.": "Too many links right now. Wait a moment.",
  "För många nya konton från den här anslutningen i dag. Försök igen i morgon.": "Too many new accounts from this connection today. Try again tomorrow.",
  "För många prov på kort tid. Vänta en stund.": "Too many exams in a short time. Wait a moment.",
  "För många rapporter på kort tid.": "Too many reports in a short time.",
  "För många uppladdningar just nu.": "Too many uploads right now.",
  "Inget förslag just nu. Försök igen.": "No suggestion right now. Try again.",
  "Inloggningen har gått ut. Försök igen.": "The sign-in has expired. Try again.",
  "Inte tillgängligt än.": "Not available yet.",
  "Kontot finns inte längre.": "The account no longer exists.",
  "Kunde inte spara just nu. Försök igen.": "Could not save right now. Try again.",
  "Ljudet går inte att göra just nu. Försök igen om en stund.": "The audio cannot be made right now. Try again in a moment.",
  "Länken fungerar inte längre. Be om en ny.": "The link no longer works. Ask for a new one.",
  "Länken leder inte till en vanlig webbsida. Ladda ner filen och lägg till den som fil i stället.": "The link does not lead to an ordinary web page. Download the file and add it as a file instead.",
  "Något gick fel hos EarMind. Försök igen om en stund.": "Something went wrong at EarMind. Try again in a moment.",
  "Provet finns inte längre.": "This exam is no longer there.",
  "Provet finns inte": "This exam is not there",
  "Provet finns inte.": "This exam is not there.",
  "Provet kan inte byta mellan frågor och text. Gör ett nytt prov.": "An exam cannot switch between questions and text. Make a new exam.",
  "Rösten är redan vald för det här provet. Gör ett nytt prov för att välja hur det ska låta.": "The voice is already chosen for this exam. Make a new exam to choose how it should sound.",
  "Skriv eller klistra in några meningar först.": "Write or paste a few sentences first.",
  "Tjänsten är tillfälligt otillgänglig.": "The service is temporarily unavailable.",
  "Välkomstkrediterna är inte på än.": "The welcome credits are not on yet.",
  "Webbetan har lyssnat mycket i dag. Försök igen i morgon, eller använd appen.": "The web beta has listened a lot today. Try again tomorrow, or use the app.",
  "Webbetan har gjort sitt ljud för i dag. Försök igen i morgon, eller använd appen.": "The web beta has made today's audio. Try again tomorrow, or use the app.",
  "Word-filen är större än 10 MB. Spara den som PDF eller dela upp den.": "The Word file is larger than 10 MB. Save it as a PDF or split it.",
};

const N = "([\\d\\u00a0 ]+)";
const PATTERNS: [RegExp, (m: RegExpMatchArray) => string][] = [
  [new RegExp(`^Det här kostar ${N} krediter\\. Du har ${N} kvar\\. Nya krediter den (.+)\\.$`), (m) => `This costs ${m[1]} credits. You have ${m[2]} left. New credits on ${month(m[3])}.`],
  [/^Du har inga krediter kvar den här månaden\. Nya krediter den (.+)\. Andras prov är gratis\.$/, (m) => `You have no credits left this month. New credits on ${month(m[1])}. Other people's exams are free.`],
  [new RegExp(`^(Ett prov med|Svaren på) ${N} frågor kostar cirka ${N} krediter\\. Du har ${N} kvar, (det räcker till ${N} frågor|det räcker inte till ett prov \\(minst ${N} frågor\\))\\. Nya krediter den (.+)\\.$`), (m) =>
    `${m[1] === "Ett prov med" ? `An exam with ${m[2]} questions costs` : `The answers to ${m[2]} questions cost`} about ${m[3]} credits. You have ${m[4]} left, ${
      m[6] ? `enough for ${m[6]} questions` : `not enough for an exam (at least ${m[7]} questions)`}. New credits on ${month(m[8])}.`],
  [/^Dela när ljudet är klart \((\d+) av (\d+)\)$/, (m) => `Share when the audio is ready (${m[1]} of ${m[2]})`],
  [/^Bild (\d+) har ett format som inte stöds \(till exempel HEIC\)\. Skicka JPEG, PNG eller WebP\.$/, (m) => `Picture ${m[1]} has a format that is not supported (for example HEIC). Send JPEG, PNG or WebP.`],
  [/^Bild (\d+) är för stor \(högst 3 MB\)\. Förminska bilderna innan de skickas\.$/, (m) => `Picture ${m[1]} is too large (at most 3 MB). Make the pictures smaller before sending them.`],
];

/** The English message for a Swedish one the user can meet, or null when it is not in the table. */
export function english(sv: string): string | null {
  const s = sv.trim();
  if (EXACT[s]) return EXACT[s];
  for (const [re, f] of PATTERNS) {
    const m = re.exec(s);
    if (m) return f(m);
  }
  return null;
}
