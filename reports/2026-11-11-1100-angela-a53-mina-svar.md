# A53 – "Mina svar" i Provläget (D126, K37)

Angela, 2026-11-11. Kö: `prompts/queue/angela.md` A53. Underlag:
- Kevins K37 (`reports/2026-11-11-1041-kevin-k37-mina-svar.md`, D130);
- Kellys Ke30 (`docs/design/mina-svar.md`);
- Oscars O39 (K37 godkänd).

## Vad som är gjort
Eleven bestämmer själv vad Lumen säger på en provfråga.

- **Vägarna in:**
  - På Start, under Förhör mig, finns raden "Mina svar" med "N sparade ›" eller "Lägg till ›". Den syns alltid.
  - I Inställningar › Mina svar.
  - "Ändra svaret" på Lyssnar.
- **Första gången** står rubriken "Bestäm själv vad Lumen säger" med en mening under. Där finns **Skriv en fråga** (blå
  knapp) och **Spela in ett svar** (sekundär knapp).
- **Listan per prov:**
  - Med flera prov väljs provet med runda chips. Ett prov visas i taget.
  - Varje rad visar frågan och svarets början. Inspelade svar har brickan "Inspelat".
  - Svep åt vänster raderar svaret.
- **Skriv en fråga:**
  - Eleven skriver frågan och trycker Nästa. Då hämtar appen `suggest` (K37) och lägger förslaget i DITT SVAR.
  - Medan förslaget hämtas står "Lumen skriver ett förslag …" i fältet.
  - Har eleven börjat skriva själv används inte förslaget.
  - LUMENS FÖRSLAG står kvar ovanför fältet, med "Använd förslaget igen".
- **Spara:**
  - Appen skickar `proofread` (K37). Bara stavningen rättas, och servern vägrar större ändringar.
  - Ändrades något visas "Rättat: kraftverk" i 3 s innan sidan stängs (Ke30).
  - Varje Spara blir en version.
- **Spela in ett svar:**
  - Frågan är valfri.
  - Under inspelningen syns en röd punkt med "Spelar in", tiden "02:14 av 10:00" och nivåmätaren.
  - Raden "Lumen gör inget med ljudet förrän du trycker Klar …" står under.
  - Vid **Klar** skriver telefonen ut orden, och ljudfilen raderas. Därefter görs `compress` (K37) **en gång**.
  - Efter Klar öppnas redigeringen med rubriken "Nytt svar" och "FRÅN DIN INSPELNING · 2:14" med ett utdrag.
  - Gränsen är 10 min, som Kelly föreslog.
  - När Lumen lyssnar går det inte att spela in: "Avsluta Lumen för att spela in.".
- **Ångra:**
  - Menyn ⋯ › Tidigare versioner visar högst 10 versioner, med vem som skrev dem ("Din", "Lumens förslag", "Från inspelning").
  - **Återställ** gör en ny version, så inget försvinner.
  - "Radera svaret" (rött) frågar först.
- **I Provläget:**
  - Varje `/answer` skickar `saved_answers` för det aktuella provet, högst 60.
  - När `done.saved_answer` kommer får svaret på Lyssnar brickan **"Ditt svar"** och "Ändra svaret".
  - Skärmen visar elevens exakta text, inte talformen där siffrorna är skrivna som ord (K37).
- **Inställningar › Mina svar:** brytaren "Säg mina svar" och raden "Mina svar · N sparade ›".
  - Av betyder att inga `saved_answers` skickas och att Lumen svarar själv. Inget raderas.

## Tekniskt
- `Core/Study/MyAnswers.swift`:
  - `MyAnswerStore` sparar i `Application Support/Lumen/my-answers.json`, som Minne. Svaren finns bara på telefonen, inte i repot.
  - Versionerna är högst 10, och samma text blir ingen ny version.
  - `payload(for:)` ger provets svar plus de svar som gäller alla prov.
  - `MyAnswersClient` sköter `suggest`, `proofread` och `compress`.
- `Core/Study/AnswerRecorder.swift`:
  - AVAudioEngine skriver till en tillfällig fil.
  - Orden skrivs ut med `SleepRecorder.transcribe`, alltså Apples taligenkänning på telefonen (`requiresOnDeviceRecognition`), som i A49.
  - Filen raderas efter Klar och efter Avbryt.
- **Beslut D133 (avviker från K37:s "transkribera med Scribe"):** inspelningen skrivs ut på telefonen.
  - Ljudet lämnar aldrig telefonen, och inga Scribe-sekunder går åt (D120).
  - Samtyckestexten behöver inte ändras för att ljud skickas, vilket Kelly varnade för i Ke30.
  - Priset är sämre igenkänning än Scribe. Det är en **ej verifierad bedömning** att den räcker för en genomgång.
- `AnswerContext.savedAnswers` finns med i `clamped`, och testet täcker det (A48:s lärdom).
- `AnswerDone.savedAnswer`, `AnswerTurn.savedAnswerID` och `Conversation.markSaved(_:text:on:)`.
- Skärmbildsscenerna `myAnswers`, `myAnswersEmpty` och `myAnswerEdit` är nya, med demosvar.

## Testresultat
- **Enhetstester:** `LumenTests/A53Tests.swift` har 11 tester:
  - versioner, Återställ, gränsen 10 och tom text;
  - payload per prov, och tom när funktionen är av;
  - `clamped` och request-kroppen;
  - `done.saved_answer`;
  - "Ditt svar" med den exakta texten;
  - rättningsraden, klockan och utdraget;
  - `suggest`-kroppen.
- **iOS-bygge och CI-körning:** se A52/A54-rapporten (samma körning).
- **Ej verifierat på enhet:**
  - inspelning med mikrofonen;
  - utskrift av en lång inspelning på svenska;
  - att den sparade texten sägs i örat.
  - Hela vägen till servern är inte heller provad från appen. Oscar har provat K37 live med curl (O39).

## Kända begränsningar och risker
- **Utskrift på telefonen:** SFSpeechRecognizer på enheten är inte provad på 10 min ljud. Den kan ge sämre text än
  Scribe. Det är en **ej verifierad bedömning**. Behövs Scribe kan K37:s väg läggas till och samtycket ändras.
- En ominstallation tar bort Mina svar, som Minne (Kevin K37).
- `saved_answers` skickas bara i Provläget. Kevin föreslog "gärna i Standardläge när ett prov är valt", men det är inte
  gjort: i Standardläge är det oklart vilket prov som gäller.

## Concerns
- **Oscar O39:** Mina svar läser elevens förberedda svar ordagrant i örat när en fråga hörs, också när läraren ställer
  den. Det gör funktionen till ett möjligt fuskhjälpmedel under ett riktigt prov.
  - Jag har byggt det Aron beslutade (D126) inom skydden: indikatorn syns, brickan "Ditt svar" syns och funktionen
    går att stänga av.
  - Texterna säger "i Provläget", inte "på provet".
  - Architect och Deangelo avgör hur funktionen ska beskrivas, och om svar ska sägas bara för elevens egen röst (en
    annan talare än eleven) och inte för lärarens.

## Till Aron
- Inget beslut behövs för att prova.
- Prova så här: Start › Mina svar › Skriv en fråga. Spara svaret, starta Provläge och ställ frågan.

## Nästa
- Toby: Mina svar i simulatorn. Kontrollera att bara det valda provets svar skickas och att avstängningen fungerar (O39 Nästa).
- Oscar: med appen på telefonen.
