# T55: Starta prov sa ingenting när krediterna inte räckte, och loggen visar nu vilket konto appen startar som

Angela Schrute (moln, Fable 5.2), 2026-11-19 18:55–19:58. Main, sammanslagning 2bdedec5 (grenen
`angela/t55-krediter-prov`, 9b9667d7). Efter Tobys T55 (`reports/apptest/2026-11-19-1800-toby-moln-t55-granskarens-vag.md`).
0 ElevenLabs. **Verifierat i CI, inte på enhet och inte i Tobys flöde än.**

## 1. Fyndet
Nytt konto med 1 500 krediter. Ett prov på 5 frågor från en text på 39 ord står som "Det här kostar 1 909 krediter".
Starta prov gav ingen spelare och ingen förklaring.

## 2. Orsaken
- Ett nytt prov som krediterna inte räcker till **nekas redan när det sparas** (D212 punkt 3), så provet finns bara på
  telefonen och har ingen kostnad i appen.
- Kortets förkontroll jämför provets kostnad med saldot. Utan kostnad blev den falsk, så appen gick vidare, försökte
  spara igen, fick samma nej och visade ingenting.
- Raden på kortet var redan serverns nej, men bara första meningen: "Det här kostar 1 909 krediter". Den ser ut som
  ett pris, inte som ett nej.
- **Slutsatsen är dragen ur koden och Tobys logg** (kortet visade serverns mening före trycket, och övningen av
  AirPods-trycken kom upp, alltså hade förkontrollen släppt igenom). Appens egna loggrader fanns inte i körningen.

## 3. Rättningen
| Var | Vad |
|---|---|
| Kortet på Start | säger också vad som finns kvar: "5 frågor · Det här kostar 1 909 krediter. Du har 1 500 kvar" |
| Starta prov på kortet | öppnar provets egen skärm när servern redan har sagt nej, i stället för att försöka igen |
| Ett nekat startförsök | öppnar provets skärm (gäller också om förkontrollen missar av annat skäl) |
| Provets skärm | serverns ord (kostnad, saldo, när nya krediter kommer) och **Fyll på**, som öppnar krediterna. Förut stod "Du har inga frågor kvar den här månaden", från tiden före krediterna |
| Efter påfyllning | ett startförsök som går igenom glömmer nejet, så kortet startar som vanligt igen |

Filer: `RepetitionModel.start`, `DrillCloud.swift` (`quotaExceeded.remove`), `DrillText.cardProblem`,
`RepetitionHomeSection.swift` (två små ändringar), `DrillView.swift` (texten och knappen). De två sista är Angela
Fables vyer; hon vet vilka rader. Knappens utseende är Kellys och hennes att ändra.

## 4. Loggraden Toby bad om
Kapseln visade 1 406 efter en Säg-text och 1 500 efter en omstart, som om appen blivit ett nytt konto.
- **Debug och Beta:** "Auth: at start the account on this phone is ab12cd34" vid start och "Auth: signup gave the
  account …" efter varje inloggning. De första åtta tecknen av kontots id, aldrig hela id:t eller token. Nivån är
  notice, så raden syns i en vanlig log stream.
- **Alla byggen:** när nyckelringen inte kan läsas eller inte sparar kontot loggas statusen som fel. Förut svaldes
  det tyst, och appen blev ett nytt konto vid nästa start utan att något syntes.
- **Gissning, inte belagd:** i ett osignerat Simulator-bygge nekar nyckelringen, så varje start blir ett nytt konto.
  På en signerad telefon ska kontot stå kvar. Tobys nästa körning visar det.

## 5. Testresultat
- **CI: iOS build 44587888248 grön** på 9b9667d7. Nya tester:
  - `aStartTheCreditsDoNotCoverOpensTheExamsScreen`: nekat startförsök öppnar provets skärm och spelar inget; när
    krediterna räcker startar samma tryck och nejet är glömt.
  - `theCardSaysWhatIsLeftWhenTheCreditsAreShort`: kortets ord.
  - `theUserIDIsTheTokensSubject` (utökat): loggens märke.
- **Inte sett på bild.** Kortets rad och provets skärm med Fyll på är inte körda i Simulatorn; Tobys T55 gör det.

## 6. Till Deangelo (D238 punkt 4)
- **Första provet kostar mer än ett nytt konto har:** 5 frågor från 39 ord kostar 1 909 krediter, kontot har 1 500.
  Utan välkomstkrediterna (5 000) kan en granskare inte starta ett enda prov utan att köpa.
- Välkomstkrediterna kräver App Attest. Det finns inte i Simulatorn och inte i en Sideloadly-installation, och
  rättigheten väntar på Arons ja och `APPLE_TEAM_ID` (A141). Om en riktig App Store-installation får dem är oprövat.
- Kostnaden och de fria krediterna är Kevins och ert beslut; appen säger nu i alla fall vad som saknas.

## 7. Kvar
- Tobys T55 på main: kortets rad, provets skärm, och Auth-raderna före och efter en omstart.
- Om nyckelringen visar sig vara orsaken: inget att rätta i appen för telefoner, men Tobys bygge behöver signeras
  för att kontot ska stå kvar mellan starter.

## Tillägg 2026-11-20 07:52: main är grönt
Sammanslagningens eget bygge (44593311942) fick ingen byggmaskin och avbröts av GitHub. Nästa bygge på main,
44598313619 (a5f4a2c8), innehåller rättningen och är grönt. **Verifierat i CI.** Tobys T55 på main har jag inte sett
resultatet av än.
