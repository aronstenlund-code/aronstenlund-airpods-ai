// K26/K34: sensitive memories (D113 B5), offline. The O27 Rizz content filter was removed by D113 A1 (K28).
import { assert } from "jsr:@std/assert@1.0.8";
import { isSensitiveMemory } from "../memory/handler.ts";

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
