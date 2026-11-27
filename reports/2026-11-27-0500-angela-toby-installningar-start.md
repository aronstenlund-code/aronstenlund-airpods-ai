# Tobys fyra rader, Inställningar, och en snabb start

Angela Schrute (moln, Opus 5.5), 2026-11-27. Uppdrag: Deangelo 04:10: "(1) Tobys fyra låga rader i din kö; (2) Inställningar: gör dem korta och begripliga – det viktigaste överst (språk, aktiveringsord, röst, krediter), resten under Avancerat, varje rad med en mening om vad den gör, inget som användaren inte förstår; (3) se att appen startar snabbt (mät tiden till första skärmen, ta bort det som laddas i onödan vid start). Test först, hela sviten grön, bilder."

## (1) Tobys fyra rader (T59, kön rad 587)

| Toby | Gjort |
|---|---|
| (1) När `/tts` svarar `tts_quota` sa Lyssnar A45:s "EarMind hör och pratar lite sämre just nu" | Nu: **"Telefonens röst läser just nu."** / "The phone's voice is reading for now." (Kevins ord, samma som för proven i K124). Andra röstproblem säger A45:s rad som förut. |
| (2) `/tts` frågades igen för varje svar medan kvoten var slut | Redan rättat: Tobys körning (`toby/t59` f3ff23fe) byggde på en version utan K124. K124 (D270, på main 01:55) pausar ElevenLabs i 10 minuter efter `tts_quota`, och det är testat (`K124PhoneVoiceTests`). |
| (3) En ny fråga väntade 7,8 s medan telefonens röst stoppades ("player 7782 ms", Simulatorn) | **Inte ändrat.** Tiden går i `AVAudioPlayerNode.stop()`, alltså Apples egen spelare: färdiganropen hoppar till huvudtråden asynkront och låser inte. Att flytta stoppet från huvudtråden kan ta bort nästa svars ljud, om stoppet hinner efter att det nya svaret har schemalagts. Det går inte att pröva utan telefon. Förslag: Aron mäter på telefonen. Diagnostik visar redan "Activation was held … (A72)". |
| (4) Engelska "quiz me" gick till servern som `"fragment":"förhör mig"` | Nu går "Lumen, quiz me on photosynthesis" som `quiz me on photosynthesis`; svenska som förut. |

## (2) Inställningar

**Överst, i den här ordningen:**
- **Språk:** "Gäller appens texter och EarMinds svar."
- **Aktiveringsord:** "När orden hörs svarar EarMind på frågan som just ställdes. Ett tomt fält stänger av det." Fältet är Ke93:s, ett block.
- **Röst:** "Läs upp svaren" och rösten, med raden "Rösten som läser upp svaren, eller tyst."
- **Krediter:** det som är kvar (samma tal som kapseln på Start) och raden "Vad du har kvar, vad saker kostar och fyll på." Trycket öppnar samma blad som kapseln.

**Alltid synligt, under dem:** Historik, Integritet och samtycke, kontot (Radera konto), Fråga om EarMind, Feedback och förslag, Om appen. Varje rad har en mening om vad den gör.

**Under Avancerat** (stängt från början), med raden "Påminnelser, svarslängd, röstkommandon, minne, utseende, mikrofon och taligenkänning.":
- påminnelser och svarslängd;
- röstkommandon, minne, anteckningar, studiekort, förberedelser, egna kommandon och provfrågor (alla med en mening);
- utseende och språk du pratar;
- egna svar och testläget;
- tempo och långa svars längd;
- och sist det tekniska: mikrofon, frågekänslighet, taligenkänning, pauser, Provläge, Rizz och Socialt, röstprofil och Diagnostik.

**Mina val:**
- Påminnelser ligger under Avancerat, eftersom uppdraget nämnde fyra saker överst.
- Integritet, kontot och hjälpen är synliga, eftersom de måste kunna hittas (radera konto krävs av App Store).
- `studyProfileSection` stod två gånger på sidan förut; nu bara under Avancerat.
- Ordningen och meningarna står i `Lumen/Features/Settings/SettingsRows.swift` (`SettingsRow`), så testerna prövar det sidan visar.

## (3) En snabb start

**Mätningen:**
- Tiden från processens start (kärnans egen klocka, `kinfo_proc`) till första skärmens första bild mäts vid varje start.
- Den skrivs i Diagnostik som "Launch: first screen after N ms" och som en signpost (`launch.firstScreen`). `Lumen/App/LaunchTiming.swift`.

**Det som nu väntar till efter första skärmen** (`AppContainer.startAfterFirstFrame()`, en gång per start, från `RootView`):
- **Rensningen av provljud som inget prov använder** (A103). Förut gick den igenom hela ljudmappen och raderade filer i `CloudDrillAudio.init`, före första bilden. Nu tar den bara bort filer från före starten, så en nedladdning som just har skrivits, innan provet har sparats med filens namn, tas aldrig bort.
- **Borttagningen av gamla nätter** i Sömnläget (A49), som förut raderade mappar i `SleepController.init`.

**Billigare:**
- **Historikens och minnets rensning** byggde en ny kalender för varje rad vid varje start. Nu används en kalender.
- Rensningen gjordes dessutom två gånger direkt efter varandra (i `init` och i `prepareBackend`). Nu görs den högst en gång i timmen.

**Inte ändrat, med skäl:**
- **Proven** (`DrillStore`) läses före första bilden, eftersom Start visar dem; annars blinkar det tomma läget först.
- **Inloggningens nyckelring** läses också före första bilden. Det är 1–10 ms, och en ändring där rör A143.
- **Ljudgrafen** kopplas också före första bilden: 5–30 ms, men mikrofonen delar motorn och det kan bara provas på telefon.

## Testresultat

- **iOS build 45940243376 grön** på `angela/start` (72d56ca1, T59 + Inställningar + starten): enhetsbygge med varningar som fel, hela sviten (1 251 gröna testrader, 0 röda), Release-arkivet och Release-kontrollen. *Verified in CI.*
- **Röda körningar först:**
  - `angela/t59-test-rod` 45932357643 föll som väntat: "förhör mig on photosynthesis" och A45:s rad i stället för telefonens.
  - `angela/start-test-rod` 45933782275 föll som väntat: filen raderades i `init`, och natten togs bort i `init`.
- **Tre röda byggen på vägen, alla fel i mina tester, inte i appen:**
  - Kontrollen av tekniska ord jämförde delar av ord, så "db" i Feedback och "Vad" fastnade.
  - A103-testet väntade sig rensning i `init`; det rensar nu efter `init`, som appen gör.
  - Starttestet hade en övre gräns på 20 s.
- **Tiden till första skärmen i CI:** 37 168 ms (45938548567) och 10 222 ms (45940243376). Det är testvärdens kalla start i CI-simulatorn. Siffran varierar mycket och går inte att jämföra med en telefon.

- `LumenTests/TobyT59Tests.swift` (3), `LumenTests/SettingsLayoutTests.swift` (5), `LumenTests/StartupTests.swift` (6).
- **Röda först** mot main (bara befintligt API):
  - `angela/t59-test-rod`: raden vid `tts_quota` och engelska "quiz me".
  - `angela/start-test-rod`: att `CloudDrillAudio` inte rensar i `init`, och att sömnläget inte tar bort nätter i `init`.
  - Inställningarnas ordning kunde inte köras röd: den bygger på nytt API.
- **Tiden till första skärmen i CI: 37 168 ms** (iOS build 45938548567, steget "Launch time to the first screen").
  - Det är testvärdens start i CI:s simulator: första kalla starten efter installationen, med testpaketet inladdat. Det är **inte** en användares start, och siffran kan inte jämföras med en telefon.
  - Testet kontrollerar därför bara att tiden mäts. Mitt första test hade en övre gräns på 20 s, och den var fel.
  - Det finns ingen "före"-siffra, eftersom main inte mätte.
  - Den riktiga siffran är telefonens egen, i Diagnostik.
  - Toby kan mäta före och efter med `XCTApplicationLaunchMetric`; rad till honom.

### Bilder (Fable screens 45932702102, iPhone 17 Pro-simulatorn, ljust och mörkt, engelska och svenska)

- Grenen `fable/screens-installningar`: `settings`, `settingsAdvanced`.
- Sett på bild:
  - överst Språk, Aktiveringsord (meningen som block, fältet under, och raden om vad det gör), Röst med en mening, och Krediter;
  - därefter Historik med en mening.
- Avancerat ligger nedanför det en skärmbild når, så `settingsAdvanced` visar samma topp. Avancerat är alltså inte sett på bild.

## Nästa steg

- Aron på telefon: Inställningar › Avancerat › Diagnostik visar "Launch: first screen after … ms".
- Toby: starttid före och efter med `XCTApplicationLaunchMetric` på simulatorn.
