# A164 – Spela in själv, kärnan (Angela Schrute, moln, 2026-11-26 09:25)

Uppdrag: Deangelo 08:45 (D263, Aron 08:24). iOS-appen på main. Vyerna och bladet är Angela Fables (A165).

Märkning: **[CI]** = verifierat i GitHub Actions · **[kod]** = läst i koden · **[antagande]** = otestat.
Låtsasinspelare och låtsasröst i alla tester: ingen mikrofon, inget tal, inget nät, 0 ElevenLabs. **Mikrofonen (också
AirPods-mikrofonen), telefonens röst och uppspelningen i AirPods är inte provade** – det går bara på en telefon.

## 1. Vad som är gjort

- **En egen samling** (`OwnDeck`): frågor och svar som användaren skriver, och för varje fråga och varje svar en
  **valfri egen inspelning**. Högst 200 kort per samling och 1 000 tecken per text.
- **Allt stannar på telefonen.** Texterna ligger i en fil och inspelningarna i en mapp i appens egen mapp
  (`Application Support/OwnDecks/`). Inspelningarna hålls **utanför iCloud-säkerhetskopian**, så ljudet lämnar inte
  telefonen den vägen heller. Tar man bort ett kort, en samling eller kontot försvinner filerna.
- **Inga nätanrop, inga krediter.** Typerna har ingen väg till servern, och samlingen ligger aldrig i provlagret
  (`DrillStore`), som är det som laddas upp. Testet kör en övning med en låtsasserver bredvid och visar noll anrop.
- **Inspelning** (`OwnRecorder`): en del i taget, AAC i en m4a-fil, högst 5 minuter (stannar då av sig självt och
  sparas). **AirPods-mikrofonen används när AirPods är anslutna**, annars telefonens.
- **Uppspelning genom samma spelare som sparade prov** (`RepetitionModel.start(own:)`): frågan, tänketid, ett tryck för
  svaret, samma spelarskärm. Det finns ett svar, så kort och långt svar är samma ljud.
- **Utan inspelning läser telefonens egen röst texten** (AVSpeechSynthesizer, aldrig ElevenLabs). Rösten skrivs till
  en fil första gången, så spelaren behandlar den som vilket ljud som helst och väntar medan den görs.
- **Lyssna på en del** (▶ i redigeringen) och **allt Angela Fable behöver för vyerna** finns i `OwnDeckModel`;
  gränssnittet skrev jag i hennes kö innan koden, och hon bygger vyerna mot det. Efter hennes önskemål finns två
  DEBUG-hjälpare för skärmbilderna (`stage(recording:)`, `stageRecorded`).
- **Tobys önskemål (T3):** raderna i Inställningar har fasta `accessibilityIdentifier` (`settings.privacy`,
  `settings.notes` … alla fjorton).
- **Tobys fynd (T57):** se §4.

## 2. Två avvikelser från uppdraget, som du bör känna till

1. **Jag bygger inte på `MyAnswerRecording`.** Den sparar inga filer (den transkriberar och raderar) och dess
   ljudsession erbjuder aldrig AirPods-mikrofonen (`.record` utan Bluetooth). Jag har tagit dess mikrofonfråga
   (`AudioSessionPermission`) och i övrigt skrivit en egen inspelare med en session som tillåter Bluetooth-mikrofon.
   **[kod]**; att iOS då verkligen väljer AirPods-mikrofonen är **[antagande]** tills Aron har provat.
2. **Uppdraget och Kellys underlag säger olika om kort utan inspelning.** Uppdraget: utan inspelning läser telefonens
   röst. Kelly (Ke89 §2): Öva går bara när minst en fråga är inspelad, och kort utan inspelad fråga hoppas över.
   Kärnan kan båda: `start(own:onlyRecorded:)` och `deck.playable(onlyRecorded:)`. Förvalet följer uppdraget
   (telefonens röst läser). **Vilket som ska gälla i vyn behöver du eller Kelly bestämma**; Angela Fable har fått veta.

## 3. Teknik (DECISIONS: A164)

- `Lumen/Core/OwnDeck/`: `OwnDeck.swift` (typerna och provet som spelaren får), `OwnDeckStore.swift`,
  `OwnRecorder.swift`, `PhoneVoice.swift`, `OwnDeckAudio.swift`, `OwnDeckModel.swift`, `OwnDeckSeed.swift`.
- Spelaren får ett tillfälligt `Drill` med samlingens id; det sparas aldrig.
- Textfilen skrivs så att den går att läsa när telefonen är låst efter första upplåsningen: övningen går med skärmen av.
- **Testkrok (T58 och skärmbilder):** `-SeedOwnDeck 1` i testbyggen lägger en samling med tre kort och ger tyst
  ljud i stället för telefonens röst. Aldrig i Release (Release-kontrollen letar efter typerna i arkivet).

## 4. Tobys fynd: `/answer` frågades två gånger per fråga när modellen är nere

Orsak **[kod]**: frågan i förväg (på orden hittills) fick 503, och när pausen kom frågades hela turen en gång till,
eftersom nejet inte kom ihåg. Rättat: ett nej för att serverns modell är nere minns i tio sekunder, och den färdiga
turen får samma nej genom svarsmotorns vanliga felväg utan att servern frågas igen. Andra fel i förväg (till exempel
ett långsamt nät) frågas om som förut. Gäller bara telefoner utan egen modell; med modell svarar den (A159).

## 5. Test

- **A164:** 22 tester i `LumenTests/A164OwnDeckTests.swift`: samlingen sparas mellan starter; nyast först; texter
  kortas; full samling; flytta kort; ljudet utanför säkerhetskopian; inspelning sparas för sin del; ny inspelning
  ersätter den gamla; avbryt behåller den gamla; gränsen sparar; för kort inspelning sparas inte; nekad mikrofon
  säger det; en i taget; borttagning tar filerna; inspelningen spelas och telefonens röst läser resten; röst som
  inte ger ljud lämnar ingen fil; vad spelaren får; lyssna på en del; **övning genom provspelaren utan anrop till
  servern och utan att provlagret rörs**; tom samling startar inget; bildhjälparna (DEBUG); Tobys krok. Testerna skrevs före koden, men
  de kunde inte köras röda i CI: allt de använder är nytt, så det hade bara blivit ett kompileringsfel.
- **T57-fyndet:** testet gick ensamt till `angela/t57-test-rod` (iOS build 45777210628, **rött som väntat, på påståendet**: `requests.count → 2`, alltså två anrop för samma fråga; det andra testet, att andra fel frågas om, gick).
- **Bygget som gäller:** kärnan + T57-rättningen + bildhjälparna, **iOS build 45777575993 grön** (hela sviten och Release-kontrollen, som också visar att `SilentPhoneVoice` och `OwnDeckSeed` inte finns i Release-arkivet). Det är samma appkod som ligger på main. **[CI]**

## 6. Arons prov (när Angela Fables vyer finns; tills dess går kärnan inte att nå i appen)

1. Gör en samling, skriv en fråga och ett svar, spela in båda med AirPods i. Hörs din röst vid ▶, och lät den som
   AirPods-mikrofonen eller telefonens?
2. Tryck Öva: kommer frågan med din röst, och svaret efter ett tryck på AirPods?
3. Ett kort utan inspelning: läser telefonens röst texten?
4. Flygplansläge: fungerar allt fortfarande, och är krediterna oförändrade efteråt?

## 7. Kvar

- Angela Fables A165 (vyerna, bladet vid slut på krediter), Kellys ord, Tobys T58.
- Beslutet i §2.2.
- Grenarna `angela/a164-t57`, `angela/t57-test-rod` och de fyra äldre testgrenarna tar jag bort om du säger till.
