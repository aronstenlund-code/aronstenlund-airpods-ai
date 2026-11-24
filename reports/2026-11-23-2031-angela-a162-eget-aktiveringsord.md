# A162 – eget aktiveringsord (Angela Schrute, moln, 2026-11-23 20:31)

Uppdrag: Deangelo 19:49 (D259, Aron 19:36). iOS-appen på main.

Märkning: **[CI]** = verifierat i GitHub Actions · **[kod]** = läst i koden · **[antagande]** = otestat.
Låtsastranskript och låtsasleverantör i alla tester, 0 ElevenLabs. **Inget är provat på telefon**, och jag har inte sett
fältet på bild.

## 1. Vad som är gjort

- **Meningen står exakt som Aron skrev den**, med ett fält i: "Fråga du inte är beredd på? Säg [ … ] så aktiveras vår
  AI." – på engelska "Question you're not prepared for? Say [ … ] so our AI activates." Den finns överst i lyssnarvyn
  (där svaren kommer; inte i Socialt och Rizz) och i Inställningar under Questions.
- **Fältet tar ett eller flera ord** (högst 40 tecken, radbrytningar och dubbla mellanslag städas bort) och **sparas**
  mellan starter. **Tomt fält = av.**
- **När orden hörs i en avslutad tur svarar appen på frågan som just ställdes:** det som sades före orden i samma tur
  ("Vad är fotosyntes? Banan."); annars det som följer orden ("Banan. Vad är fotosyntes?"); annars det senaste som
  hördes före turen (någon annan ställde frågan, och användaren säger bara orden). Svaret är ett vanligt A-svar
  (samma väg som "svara på det senaste", `push_to_talk`), så servern svarar även om frågegrinden inte hade tagit det.
- **Orden själva skickas aldrig** som fråga, och en tur med orden i blir aldrig en vanlig tur.
- Orden hörs som **hela ord i samma ordning intill varandra**, oavsett versaler och skiljetecken ("LÅT MIG, TÄNKA!");
  "banan" hörs inte i "bananer". Står orden flera gånger gäller sista stället.
- Orden skickas också som nyckelord till taligenkänningen (Scribe), så att ovanliga ord hörs rätt.

## 2. Teknik (DECISIONS: A162)

- `Lumen/Core/Understanding/ActivationPhrase.swift` (ren logik): `cleaned`, `match(_:in:)` → före/efter,
  `question(for:earlier:)`.
- `ActivationSettings.phrase` + `setPhrase(_:)` (UserDefaults `activation.phrase`).
- `ActivationController.answer(heard:language:)`: frågan går som `.answerLast`; en fråga som väntade i grinden släpps,
  så den inte besvaras en gång till.
- `ListeningModel`: vid turens slut, efter ekokontrollen och före "Lumen, …"; `discardAhead` kastar ett svar som hade
  börjat förberedas på turen.
- `ActivationWordsField` (SwiftUI): meningen i tre delar med fältet i mitten i den befintliga radbrytande layouten;
  uppläst namn "Aktiveringsord" / "Activation words", `accessibilityIdentifier` `activation.words`.

## 3. Test

- **Test först:** tre tester som kör hela turen genom lyssnarmodellen och bara använder det appen redan hade (orden
  läggs rakt i inställningslagret) gick ensamma till `angela/a162-test-rod`: **iOS build 45241787494 röd på
  påståendena** (4 fel: frågan gick som vanlig tur, `tutor`, med "Banan." i; det tredje testet, tomt fält, gick).
- Med funktionen: **iOS build 45241781178 grön** (hela sviten; grenen innehöll också A159). 8 tester på logiken
  (`A162ActivationPhraseTests`: ett ord, flera ord, versaler/skiljetecken, hela ord, tomt fält, sista stället,
  städning, vilken fråga som besvaras, sparandet) och 3 på hela turen (`A162ActivationWordsHeardTests`). **[CI]**
- **Inte testat i hel tur:** orden ensamma efter en tidigare tur (bara logiken `question(for:earlier:)` är testad);
  att fältet ser rätt ut och går att skriva i med största textstorleken; på telefon.

## 4. Concerns

Meningen "Fråga du inte är beredd på?" tillsammans med ett helt valfritt ord gör det lätt att använda appen utan att
andra märker det, till exempel i ett muntligt förhör eller en intervju: ordet kan vara något som låter som vanligt tal
("låt mig tänka"). Funktionen i sig döljer inte appen – samtycket, lyssnarindikatorn och "använd den inte där
inspelning inte är tillåten, till exempel på prov" är som förut, och inget ljud sparas – så jag har byggt den inom
skyddsräckena. Men jag vill att Deangelo och Aron tar ställning till formuleringen, och till om samtyckets rad om prov
räcker när appen nu uppmanar till just den situationen. Kelly har fått en rad om orden och utseendet.

## 5. Kvar

- Kellys granskning (placering överst i lyssnarvyn, utseendet på fältet).
- Arons prov på telefon: skriv ett ord i fältet, starta lyssningen, ställ en fråga och säg ordet.
- Grenarna `angela/a162-aktiveringsord`, `angela/a162-test-rod`, `angela/a159-test-rod` och `angela/o97-test-rod` behövs
  inte mer; jag tar bort dem om du säger till.
