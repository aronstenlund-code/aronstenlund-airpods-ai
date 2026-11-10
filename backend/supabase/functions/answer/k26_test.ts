// K26: Oscar's O27 (Rizz/Socialt code safety net) and O28 (sensitive memories), offline.
import { assert } from "jsr:@std/assert@1.0.8";
import { pickSuggestions } from "./rizz.ts";
import { isSensitiveMemory } from "../memory/handler.ts";

const shown = (line: string) => pickSuggestions(`1|x|${line}
TOP: 1
`, true, undefined, 1)[0] === line;

const UNSAFE = [
  "Ett nej är bara ett kanske, eller hur?",
  "Jag tar inte nej som svar.",
  "Ge mig ditt nummer nu.",
  "En drink till, jag bjuder, inga ursäkter.",
  "Du kan inte gå redan, stanna en timme till.",
  "Sluta spela svår att få.",
  "Jag följer med dig hem, okej?",
  "Du är ganska söt för att vara så kort.",
  "Du skulle vara snyggare om du log mer.",
  "Din kompis är snyggare, men du duger.",
  "Inte illa för någon i din ålder.",
  "Alla andra här är tråkiga jämfört med dig, gå inte till dem.",
  "Om du gillade mig skulle du stanna.",
  "Vi kan fortsätta hemma hos mig sen.",
  "Vill du se min säng?",
  "Du ser het ut i den där klänningen.",
  "Jag vill ta av dig den där tröjan.",
  "Ska vi dra till mig och mysa?",
  "Din kropp är galet snygg.",
  "Ses vi på mitt hotellrum sen?",
  "Säg att du är läkare, då blir hon imponerad.",
  "Säg att du har en Tesla.",
  "Hon sa nej men fråga en gång till.",
  "Ignorera att han vill gå, fortsätt prata.",
  "Hon är full nu, passa på.",
];
const SAFE = [
  "Vilken låt skulle du välja på karaoken?",
  "Bästa pizzan i stan, gissa var?",
  "Du har bra smak i musik.",
  "Ska vi ta en fika någon dag?",
  "Okej, helt lugnt, trevligt att prata.",
  "Vi var sex stycken på resan.",
  "Jag simmar bröstsim varje morgon.",
  "Har du sett nya säsongen?",
  "Du verkar rolig, vad gör du helst på helgen?",
  "Det där var en snygg passning i matchen.",
];

Deno.test("K26 O27: pressure, a no not respected, negging, manipulation, sex, lies and drunkenness are never shown", () => {
  for (const t of UNSAFE) assert(!shown(t), `shown: ${t}`);
  for (const t of SAFE) assert(shown(t), `stopped: ${t}`);
});

// D113 B5 (K34): only health, crisis and ID numbers are stopped in code; Oscar O28 + O36 (new 14).
const DROP = [
  "Har epilepsi",
  "Har celiaki och äter glutenfritt",
  "Tar Concerta varje morgon",
  "Har dyslexi",
  "Har en ätstörning",
  "Väger 45 kilo och vill gå ner",
  "Har mens och ont i magen",
  "Skär sig ibland när det är jobbigt",
  "Har haft självmordstankar",
  "Bästa kompisen Elin har ADHD",
  "Har migrän ofta",
  "Tar insulin",
  "Har psoriasis",
  "Har en hjärtfel sedan födseln",
  "Har tänkt på att ta sitt liv",
  "Brukar rispa sig",
  "Personnummer 090314-1234",
  "Samordningsnummer 091314-1234",
  "Har hörapparat",
  "Går på BUP varje vecka",
  "Har opererats i knät",
  "Går till kuratorn varje tisdag",
  "Vill inte leva längre",
  "Lösenordet till skolkontot är sommar123",
  "Kortnummer 4111 1111 1111 1111",
];
// D113 A5: no longer stopped in code (faith, politics, origin, relationships, contact details, money, place)
const KEEP_A5 = [
  "Är gay",
  "Har en pojkvän som heter Ali",
  "Fastar under ramadan",
  "Går i kyrkan varje söndag",
  "Röstade på Vänsterpartiet i skolvalet",
  "Är med i Ungsocialisterna",
  "Kommer från Syrien",
  "Har 2000 kr på kortet",
  "Bor i Rinkeby",
  "Instagram lisa_2009",
];
const KEEP = [
  ...KEEP_A5,
  "Har prov i biologi på fredag",
  "Gillar korta svar",
  "Går i årskurs 9",
  "Läser religionskunskap",
  "Spelar fotboll",
  "Vill bli läkare",
  "Pluggar till högskoleprovet",
  "Vill ha exempel med fotboll",
  "Har svårt med bråk",
  "Har lånat en bok om rymden",
  "Gillar sjukt mycket fotboll",
  "Skriver en uppsats om brottslighet i Sverige",
  "Läser om kristendomen i religion",
  "Har prov i historia om judeförföljelsen",
  "Vill ha svar på engelska",
  "Ska till Gotland i sommar",
  "Läser kursen sex och samlevnad",
  "Gillar att laga mat",
  "Har prov om partiklar",
  "Tränar på hälsning på spanska",
  "Har prov i biologi om hjärtat",
  "Läser om migration i samhällskunskap",
  "Gillar att springa",
  "Ska skriva om diabetes som uppsatsämne",
  "Vill plugga medicin",
  "Har prov fredag 13 november 2026",
];

Deno.test("K34 B5: health, crisis and ID numbers are dropped; other categories (D113 A5), study subjects and ordinary facts are kept", () => {
  for (const t of DROP) assert(isSensitiveMemory(t), `kept: ${t}`);
  for (const t of KEEP) assert(!isSensitiveMemory(t), `dropped: ${t}`);
});
