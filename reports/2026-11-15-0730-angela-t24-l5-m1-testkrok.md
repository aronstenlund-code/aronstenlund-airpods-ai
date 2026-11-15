# T24 L5 och M1, Tobys testkrok för AirPods-tryck

Angela Schrute (moln), 2026-11-15 07:22–07:45. Commit 60d83ce. Från Toby (moln):
`reports/apptest/2026-11-15-0655-toby-moln-t24-hela-flodet.md` och `-0625-toby-moln-t27-utan-nat.md`.
Beslut: D189.

## 1. L5: "Ljudet kan inte göras just nu" syns inte på Start

### Var raden ska stå (A100)
På Start, på provets kort, efter antalet frågor: **"3 frågor · Ljudet kan inte göras just nu"**. Det är meningens
första del, utan punkt (`RepetitionHomeSection.shortProblem`). Provets egen sida har hela meningen: "Ljudet kan inte
göras just nu. Försök igen om en stund." Spelaren visar samma rad. Toby läser alltså på rätt ställe.

### Orsaken (hittad innan något rättades)
1. **Testets frågor har redan ljud.** Tobys tester importerar samma fast inskrivna frågor i varje körning
   (`FullFlowTests.chatGPTAnswer`). All testtrafik använder samma teströst (`TEST_VOICE_ID`), och filnamnet räknas ur
   texten, modellen och rösten (D144). Därför gjordes ljudet en gång i en tidigare körning och är "klart" sedan dess.
   - Läget `unavailable` underkänner bara filer som inte redan är klara (`testPump`: `status !== "done"`), så det har
     inget att underkänna.
   - Det syns i Tobys egen steglogg och bild: efter 40 s står alla prov som "3 frågor · ljud klart"
     (`reports/apptest/2026-11-15-t24/t24-b-43661618294.txt` rad 69 och `t24b-07-lage-unavailable.png`). Läget `slow`
     har samma orsak.
   - *Verifierat i docs* (koden i `drill/handler.ts` och Tobys artefakter), inte i en ny körning.
2. **Ett riktigt fel i appen, som Toby skulle ha stött på med unik text:** en omstart i simulatorn ger ett nytt
   anonymt konto (D183).
   - `status` för ett prov som laddades upp före omstarten svarar då 404.
   - `CloudDrillAudio.prepare` behöll provet och skulle spara det på nytt "nästa gång". Till dess stod
     **"3 frågor · Provet finns inte"** på kortet, trots att provet finns, och ljudets läge syntes aldrig.

### Rättningen
- Vid 404 behålls provet som förut, men det sparas på nytt direkt under det nya kontot, i samma `prepare`. Kortet visar
  sedan ljudets läge. Det ändrar bara när provet sparas, inte att det sparas. Den öppna frågan om D183 påverkas inte.
- Testet `T24RelaunchTests.afterARelaunchAsANewAccountTheCardSaysTheSoundProblemNotNotFound` skrevs före rättningen.
  - Med den gamla koden fallerar det på två förväntningar: raden blir "Provet finns inte" och ingen ny sparning görs.
  - **Det röda läget är spårat i koden, inte kört i CI:** en egen körning bara för testet hade krävt en tvingad push
    till molngrenen, och den nekades.

### Till Toby
- **Gör texten unik per körning** i lägena `slow` och `unavailable`, till exempel körningens id i varje fråga. Då
  måste servern göra ljud, och lägena prövas på riktigt.
- Raden står på Start, på provkortet, som "3 frågor · Ljudet kan inte göras just nu". Läget `slow` ger
  "Ljudet dröjer" (L6).

## 2. M1: Provläge och Mina svar ser repetitionsproven (D189)

### Orsaken
Det finns två listor som aldrig kopplades ihop:
- Provläge (Fler lägen) och Mina svar läser `ExamPlanStore` (`exam-plans.json`, prov som sagts eller lagts till där).
- Repetitionsflödet läser `DrillStore`.

Ett prov från Nytt prov fanns därför inte i Provläge. "Har du prov snart? Lägg till prov" visades, och Mina svar, som
hänger på ett `ExamPlan`-id, fanns inte.

### Lösningen
Repetitionsproven är användarens prov:
- `ExamPlanStore.sync(with:)` håller ett `ExamPlan` per `Drill`, med samma id som provet (så Mina svar följer
  provet). Det har `drillID`, provets namn (`title`) och skolans datum när provet är publicerat, annars `undated`.
- `DrillStore.onChange` och starten (`AppContainer`) håller listorna i takt: nytt, ändrat och borttaget.
- **Prov utan datum** syns i Provläge och Mina svar med "Inget datum". De står sist och har ingen nedräkning på kortet.
  De räknas inte med i studieplanen, påminnelserna eller widgeten (`upcomingDated`).
- Prov som sagts i Provläge (utan `drillID`) är kvar som förut.
- Äldre `exam-plans.json` läses som förut (testat).

### Till Angela Fable (V4)
"Lägg till prov" i Provläge bör leda till Nytt prov, så att det finns en väg till ett prov. Logiken behöver inget mer
för det.

## 3. Tobys testkrok för AirPods-tryck (bara i Debug)
- Startmiljön `LUMEN_TEST_PRESSES=1` och Darwin-notiserna `earmind.test.press.1`, `.2` och `.3` ger 1, 2 och 3 tryck.
  - De går till `RepetitionSession.press`, samma väg som AirPods fjärrkommandon. Det gäller frågornas spelare och, i
    läsläget, `ReadingPlayer` (1 = paus/fortsätt, 2 = nästa mening, 3 = förra).
  - Från CI-maskinen: `xcrun simctl spawn booted notifyutil -p earmind.test.press.2`. Från testprocessen i simulatorn:
    `CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), …)`.
  - *Untested assumption* att båda vägarna når appen i simulatorn. Det är Tobys första körning som visar det.
- Filen `Lumen/Core/Repetition/TestPresses.swift` ligger helt inom `#if DEBUG` och finns inte i Release.
- Inget ljud görs av kroken (0 ElevenLabs, D180).

## Testresultat
- 8 nya tester i `LumenTests/T24FindingsTests.swift`: L5 efter omstart, M1 (spegling, ordning, namn, borttag,
  datum, gamla filer) och kroken (bara med startmiljön, tryck i läsläget).
- **CI: iOS build 43685626219 grön** (60d83ce): device-bygget, varningar som fel och LumenTests, med sviterna `T24RelaunchTests`, `T24OneExamListTests`, `TestPressesHookTests` och de tidigare A105 och T24. *Verifierat i CI.*
- Ej provat på telefon.

## Kända begränsningar och risker
- Ett prov som läggs till från en skola (inte ett eget publicerat) har inget datum hos oss, eftersom
  `fromPublication` saknar datumet. Det står därför som "Inget datum" i Provläge.
- Skärmbilderna i Provläge kan visa repetitionsprov som tidigare inte syntes där, om scenen har prov i
  `DrillStore`.
- Mina svar för ett borttaget prov ligger kvar i sitt lager utan prov.

## Nästa
- Toby: unik text i `slow` och `unavailable`, och kroken i T27/T28.
- Angela Fable: V4.

## Tillägg 2026-11-15 20:44: testkroken LUMEN_TEST_MATERIAL (Toby T28)
- Bara i Debug: med startmiljön `LUMEN_TEST_MATERIAL=<text>` öppnas Nytt prov med texten som material, som under Skriv
  text. `\n` i startmiljön blir radbrytning, och texten kortas till 40 000 tecken.
  - Koden ligger i `TestMaterial` i `Lumen/Core/Repetition/TestPresses.swift`.
  - En rad i Angela Fables `NewDrillView` (`.task`, inom `#if DEBUG`) sätter texten.
- **Test:** `TestMaterialHookTests`. **CI: iOS build 43752158888 grön** (dbedcd6). *Verifierat i CI.* Att det fungerar
  i simulatorn är Tobys första T28-körning.

