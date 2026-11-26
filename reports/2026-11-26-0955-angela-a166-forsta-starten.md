# A166 – Från installation till första svaret på kortast möjliga väg

Angela Schrute (moln, Fable 5.2), 2026-11-26. Uppdrag: Deangelo 09:42 (A166 i `prompts/queue/angela.md`), plus Tobys och Kellys krokönskemål (kön rad 566 och 567).

## Kort

- **I dag (main före ändringen): 11 skärmar och 16 tryck före Lyssnar, plus att skriva in material och vänta på servern två gånger – och vägen är stängd just nu**, eftersom den går genom "Skapa frågor", som behöver modellkrediterna.
- **Efter: 3 skärmar och 3 tryck före Lyssnar.** Välkommen (Fortsätt) → samtycket för lyssnandet, hela (Jag förstår, starta EarMind) → iOS egen fråga om mikrofonen (Tillåt) → Lyssnar, där man säger sin fråga högt.
- Samtycket och mikrofonfrågan är kvar, oförändrade. Lyssnarbrickan syns från första stund.
- Det första svaret fungerar utan modellkrediter på en iPhone med Apple Intelligence (telefonens egen modell, A159). På en äldre iPhone säger appen "EarMind kan inte svara just nu. Försök igen om en stund." – där finns inget talat svar förrän krediterna är påfyllda; Spela in själv (A165, nu på main) går att använda från Start.
- Tobys låtsasinspelare och Kellys bildscen är med.
- **Inget av detta är provat på telefon.** Verifierat i CI: se Testresultat.

## Räkningen

### I dag (main 969d21f0), kortaste vägen till ett talat svar på en egen fråga

På en ny installation finns ingen väg till lyssnandet på skärmen: raden "Fler lägen" på Start visas först när man har gått igenom "Styr med dina AirPods" för ett prov (`RepetitionHomeSection.showsMoreModes = controlsChecked || textControlsChecked`). Man måste alltså göra ett prov först.

| # | Skärm | Tryck |
|---|---|---|
| 1 | Välkommen | Fortsätt (1) |
| 2 | Nytt prov | Skriv text (2), skriva in material, Klar (3), Skapa frågor (4) – **behöver modellen, svarar 503 nu** |
| 3 | Stämmer det här? | Ser rätt ut (5) |
| 4 | Provets frågor | Starta prov (6) – behöver ljudet (ElevenLabs, krediter) |
| 5 | Styr med dina AirPods | Hoppa över × 3 (7–9), Starta ändå (10) |
| 6 | Spelaren | Avsluta (11) |
| 7 | Start | Fler lägen (12) |
| 8 | Fler lägen | Starta EarMind (13) |
| 9 | Innan du börjar (samtycket) | Jag förstår, starta EarMind (14) |
| 10 | iOS: mikrofonen | Tillåt (15) |
| 11 | Dela historik? | ett av valen (16) |
| – | Lyssnar | säg frågan |

**11 skärmar och 16 tryck före Lyssnar.** (Kartlagt i koden, inte tryckt på en telefon: *untested assumption* i den meningen att ingen har räknat på en riktig enhet.)

Det enda man kan *höra* snabbare i dag är "Säg i AirPods" (3 skärmar, 4 tryck och att skriva en text), men det är uppläsning av ens egen text, inget svar, och det behöver ElevenLabs och krediter.

### Efter ändringen

| # | Skärm | Tryck |
|---|---|---|
| 1 | Välkommen | Fortsätt (1) |
| 2 | Innan du börjar (samtycket, hela) | Jag förstår, starta EarMind (2) |
| 3 | iOS: mikrofonen | Tillåt (3) |
| – | Lyssnar ("Fråga vad du vill. Svaret kommer i örat och här.") | säg frågan |

**3 skärmar och 3 tryck före Lyssnar.** Varje skärm har en enda tydlig knapp. På samtycket finns dessutom "Senare" uppe till vänster för den som inte vill att appen lyssnar nu: då kommer man till Start och ingenting lyssnar.

## Vad som är gjort

### Första starten (D266)

- `FirstStartView` går nu Välkommen → `FirstListeningConsentView` → klart. Stegen står i `FirstStartStep` och ordningen i `FirstStartPath.step(after:returning:listeningConsented:)` (ren funktion, testad).
- `FirstListeningConsentView` är samma `ConsentView` som ett lyssnande läge visar (alla sju punkter, samma knapp, samma rad under knappen) i en `NavigationStack` med "Senare" (`firstStart.later`).
- Knappen anropar `ListeningModel.firstStartConsentGiven()`: samtycket sparas, Standardläget väljs och lyssnandet startar direkt. iOS frågar då om mikrofonen. Lyssnar öppnas när passet är igång.
- Nekar man mikrofonen visas samma skärm som förut (`MicrophoneDeniedView` från Start).
- Den som redan har gjort den gamla första starten ser bara Välkommen en gång, som förut (A94). Den som redan har gett lyssnarsamtycket får inte frågan igen.
- **Nytt prov ligger inte längre i första starten.** Det nås från Start med knappen "Nytt prov", med alla sina val (material, namn, årskurs, antal frågor). Det var det största av "val som kan vänta", och det går ändå inte att skapa prov utan krediter.

### Frågan om att dela historik väntar

- Förut kom bladet "Dela historik?" i samma ögonblick som samtycket gavs, alltså ovanpå Lyssnar före första svaret.
- Nu hålls den tills det första lyssnandet är över: `ListeningModel.sharingQuestionIsFree` (inget håller den, inget pass är igång eller på väg att starta). `RootView` läser den.
- Tills frågan är besvarad delas ingenting (`share.enabled` är av). Det är alltså den försiktiga riktningen.
- Gäller också när samtycket ges från bladet senare (Fler lägen → Starta EarMind).

### Tobys krok (kön rad 566): `-FakeOwnRecorder 1`

- `PretendOwnRecorder` (`Lumen/Core/OwnDeck/OwnRecorder.swift`, bara `LUMEN_TESTMODE`, alltså Debug och Beta): "inspelningen" skriver 2 s tystnad som en WAV-fil direkt, frågar aldrig om mikrofonen, och `stopRecording` sparar den som vanligt.
- För att filen ska heta rätt har `OwnRecording` fått `fileExtension` (förval `m4a` i en extension, så andras låtsasinspelare påverkas inte) och `OwnDeckStore.newRecordingURL(fileExtension:)`.
- Typnamnet står i Release-kontrollen i `ios-build.yml`: det ska finnas i Debug och får inte finnas i Release-arkivet.
- Toby skrev 09:00 att han klarade T58 del 2a utan kroken (testet har en egen låtsasmikrofon genom `OwnRecording`). Kroken finns kvar för prov genom skärmen när A165:s vyer finns: där går det inte att byta inspelare inifrån testet.

### Kellys scen (kön rad 567): `listeningActivation`

- Lyssnar i Standardläget med "● Lyssnar" / "● Listening", aktiveringsorden ifyllda ("Hjälp mig" / "Help me") och en fråga med svar på appens språk.
- Orden sparas i inställningarna, så varje annan scen börjar med att ta bort bildens ord igen.
- Två scener till för A166: `firstConsent` (samtycket i första starten med "Senare") och `firstListening` (Lyssnar som en ny användare möter den: lyssnar, inget frågat).

### Samtyckesskärmen efter bilderna

Den första bildkörningen visade två fel på samtycket, som nu är första startens andra skärm: knappens text ritades liten, och listans text syntes under knappen nere vid hemstrecket. Båda fanns redan i bladet (ingen bild hade tagits av det förut). Rättat i `ConsentView`: knappen står under listan i stället för ovanpå den, och har samma etikett som Välkommens Fortsätt. Texterna är orörda.

## Teknik

- `Lumen/Features/Onboarding/FirstStartView.swift`: `FirstStartStep`, `FirstStartPath`, `FirstListeningConsentView`; `FirstStartView` använder inte längre `NewDrillView`.
- `Lumen/Features/Listening/ListeningModel.swift`: `holdsSharingQuestion` (sätts när samtycket ges, släpps i `stopListening()`), `sharingQuestionIsFree`, `firstStartConsentGiven()`.
- `Lumen/App/RootView.swift`: frågan om delning läser `sharingQuestionIsFree`.
- `Lumen/Features/Onboarding/ConsentView.swift`: listan och knappen i en `VStack` (inte `safeAreaInset`), knappen `consent.accept`.
- `Lumen/Features/Design/ScreenshotStage.swift`: scenerna `listeningActivation`, `firstConsent`, `firstListening`; `ActivationDemo`.
- `Lumen/Core/OwnDeck/{OwnRecorder,OwnDeckStore,OwnDeckModel}.swift`, `Lumen/App/AppContainer.swift`: låtsasinspelaren.
- `.github/workflows/ios-build.yml`: `PretendOwnRecorder` i Release-kontrollen.
- `tools/l10n/skip.json`: två demotexter. Inga nya texter på skärmen: "Senare" och samtyckets texter fanns redan på båda språken.
- Inga nya beroenden. Inga nätanrop tillkom. 0 ElevenLabs i tester och CI.
- Jag har inte rört repetitionsvyerna (`Lumen/Features/Repetition/`).

## Testresultat

- **main-bygget 45898579246 grönt** (3f2c9041, A166 på main). **iOS build 45794809838 grön** på `claude/fervent-fermi-34hrer` (0802c28f, main inmergad): enhetsbygge med varningar som fel, hela testsviten (1 173 gröna testrader, 0 röda), Release-arkivet och kontrollen att testläget och testkrokarna inte finns i Release. *Verified in CI.* De två bygg­ena före (45786309577, 45791153736) avbröts av nästa push och säger ingenting.
- Alla 8 testerna i `A166FirstStartTests` är gröna i den körningen.
- **Ett fel i mina egna tester, hittat nu:** tester som står inom `#if LUMEN_TESTMODE` i testmålet körs inte – flaggan sätts bara för appmålet. Det gäller det nya testet för låtsasinspelaren, och två äldre: A164:s test av `-SeedOwnDeck` och A159:s test av `-OnDeviceMock`. De har alltså aldrig körts, fast rapporterna för A159 och A164 räknade dem. Koden de prövar används av Tobys körningar (skärmturen med `-SeedOwnDeck 1` är grön), men testerna själva är *untested*. **Rättat:** testerna står nu inom `#if DEBUG`, som testmålet har. **iOS build 45898652229 grön** (391a0688): alla tre kördes och är gröna, 1 176 gröna testrader, 0 röda. *Verified in CI.* Rättningen är på main.

- `LumenTests/A166FirstStartTests.swift` (8 tester): stegen i ordning för en ny installation; samtycket hoppas aldrig över; den som redan använder appen ser bara Välkommen; knappen ger samtycket och startar Standardläget; ingenting lyssnar utan samtycket; frågan om delning väntar tills det första lyssnandet är över (från första starten och från bladet); ett senare pass håller inte tillbaka den i onödan.
- `LumenTests/A164OwnDeckTests.swift`: ett nytt test för låtsasinspelaren (2 s, `.wav`, ingen mikrofon, filen går in i spåret).
- **Test först:** testerna skrevs före koden, men de använder bara nytt API (`FirstStartPath`, `firstStartConsentGiven`, `sharingQuestionIsFree`, `PretendOwnRecorder`), så de går inte att köra röda mot gamla koden – de kompilerar inte där. Någon röd körning finns därför inte.
- Simulatorn räknas inte som enhetsprov. Mikrofonfrågan, AirPods, telefonens modell och rösten är **inte provade**.

### Bilder (Fable screens, iPhone 17 Pro-simulatorn, ljust och mörkt, engelska och svenska)

- Körning 45786375033 → grenen `fable/screens-a166-forsta-starten`: `fsWelcome`, `firstConsent` (före rättningen av knappen), `firstListening`, `listeningActivation`.
- Körning 45791231224 → grenen `fable/screens-a166-samtycket`: `firstConsent` efter rättningen. Knappen står nu under listan med stor text, och inget syns under den.
- Sett på bild: Välkommen, samtycket (med "Later" / "Senare"), Lyssnar för en ny användare ("● Listening", "Ask what you want. The answer comes in your ear and here."), och Kellys scen med "Help me" / "Hjälp mig" ifyllt och en fråga med svar på appens språk.
- Bilderna visar skärmarna var för sig med demodata. **Ingen bild eller körning visar själva flödet** (trycket på knappen, iOS mikrofonruta, ett svar): det går bara på en telefon.

## Kända fel, begränsningar, risker

1. **Vägen tillbaka till lyssnandet (löst under dagen).** Raden "Fler lägen" på Start visades bara efter AirPods-kontrollen för ett prov. Angela Fable lade till parametern `listeningConsented` i `RepetitionHomeSection` (main afbe239c), och `HomeView` skickar nu in `consent.isGranted`: den som har gett lyssnarsamtycket ser raden direkt. Inte sett på bild.
2. **Första svaret utan krediter finns bara på iPhone med Apple Intelligence** (iPhone 15 Pro och nyare, svenska eller engelska). På andra telefoner blir första svaret raden "EarMind kan inte svara just nu …". Spela in själv (A165, på main sedan i förmiddags) är den andra vägen till något att lyssna på utan krediter, från Start.
3. Att höra frågan behöver fortfarande servern och ElevenLabs utskrift (Scribe). Faller den går appen över till Apples taligenkänning, som ställer en egen systemfråga till – ett fjärde tryck i det fallet.
4. Tobys skärmtester som går Välkommen → Fortsätt → **Senare** → Start fungerar som förut (knappen heter fortfarande Senare och leder till Start), men tester som väntar sig Nytt prov direkt efter Fortsätt (`NewUserRepetitionTests`: "Fota sidor", högst tre skärmar före kameran) stämmer inte längre: vägen till kameran är nu Välkommen → Senare → Start → Nytt prov. Rad till Toby.
5. Telefonens egen modell, mikrofonen och rösten är inte provade på en telefon (A159, A162, A164 väntar också på Arons prov).

## Concerns

- **Första starten leder nu varje ny användare till lyssnandet, som enligt D142 är BETA.** Uppdraget säger uttryckligen samtycke, mikrofon och ett första svar i AirPods, så jag har byggt det. Men Aron sade 13 november att lyssnandet "aldrig reagerade på det jag sa". Om det fortfarande är så blir det första en ny användare möter det svagaste i appen. Arons prov av den här vägen på telefon bör komma före ett släpp.
- **Välkommen säger ingenting om lyssnandet** ("Fota materialet …", och raden "Starta prov använder aldrig mikrofonen"), och nästa skärm ber om lov att lyssna. Det är ärligt (samtycket står för sig självt och är oförändrat), men hänger dåligt ihop. Texterna är Kellys; rad till henne.
- **Samtyckets punkt "Svaren kommer från Claude … Utan nät blir det inga svar"** stämmer inte helt när telefonens egen modell svarar (A159). Det som då händer är att *mindre* lämnar telefonen än texten säger, så det är ingen risk för användaren, men texten bör ses över av Kelly och Deangelo.
- Samtycket är inte förkortat eller sammanslaget med Välkommen. Det hade gett två tryck i stället för tre, men ett samtycke som man trycker sig förbi på en välkomstskärm är inget samtycke.
- "Senare" är avsiktligt en tyst textknapp och inte en andra stor knapp: ett nej ska vara lätt att ge, men skärmen ska ha en tydlig väg.

## Återstår

- Kelly: Välkommens ord när första starten leder till lyssnandet; samtyckets punkt om Claude.
- Toby: `NewUserRepetitionTests` och skärmturens bilder av första starten.
- Arons prov på telefon (stegen nedan).

## Arons prov på telefon

1. Ta bort appen och installera den igen.
2. Välkommen → **Continue**.
3. "Before you start" → **I understand, start EarMind**. iOS frågar om mikrofonen → **Allow**.
4. Lyssnar ska visas med "● Listening". Sätt i AirPods och säg en fråga, t.ex. "What is photosynthesis?".
5. Rätt: ett svar hörs i AirPods. Medan krediterna är slut börjar det med "Answering with the phone's own model." (iPhone med Apple Intelligence) eller så står det att EarMind inte kan svara just nu (äldre iPhone).
6. Tryck **End**. Först nu ska frågan om att dela historik komma.
7. Prova också **Later** på samtycket efter en ny installation: Start ska visas, och ingen mikrofonsymbol.

## Nästa session

- A149 väntar fortfarande på Arons prov och Deangelos ord.
