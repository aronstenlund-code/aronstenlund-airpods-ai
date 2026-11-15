# Överlämning: Angela (app) till molnet, 2026-11-15 02.50

## Klart och grönt i CI (inte provat på telefon)
Allt nedan har en rapport i `reports/2026-11-14-*-angela-*.md` och en grön iOS build.

| Punkt | Commit | Grön iOS build |
|---|---|---|
| A99 (frågor kvar, längdklass) |se rapporten | 43617962807 |
| T17-fynd 8 (namnet mitt i en mening) |se rapporten | 43617962807 |
| A97 (Earmind väcker) |se rapporten | 43617962807 |
| A101 (EarMind med stort M) | 9079dae | 43617962807 |
| A87-punkten: systemets stil i hela appen (D181) och förhandsvisningens fält | c7742f0 | 43624998385 |
| Testkrok `LUMEN_TEST_HEADER` för `x-earmind-test` i Debug | 37ae1c1 | 43624998385 |
| T17c-fynd 9 ("Hej, Lumen." ensamt) | 3c4db96 | 43627707528 |
| A102 (visningstext `DrillItem.screen`) | b793ea6 | 43632730806 |
| may_fix (K67) | c0eaaee | 43640375259 |
| Kellys Ke61 F1 (tal utan punkt) | b4e1217 | 43640375259 |
| T25-fynd 9b (frågan efter "Ja?" går som tilltal) | 96e59ab | 43640375259 |
| T24 kontobyte raderar aldrig prov (D183, `Drill.ownerID`) | 09885ad | 43645181127 |

Toby 2:s omtest av D183 är grönt.

## Pågår: A103 (molnet tar den) – pushad på main, CI inte grön än
- **Commits:** 629b15c, D186 i DECISIONS.
- **Ljudet:** ljudet låg redan i Application Support (`drill_audio`); det var bara kommentaren i `Drill.swift` som sa
  "cache". Nu gäller också:
  - mappen ligger utanför iCloud-säkerhetskopian;
  - `CloudDrillAudio.removeUnused()` tar bort ljudfiler som inget sparat prov använder, vid start och bara
    `.mp3/.m4a/.aac/.wav/.caf`;
  - utan nät väntar `prepare` (högst 30 min) och fortsätter själv, med texten `waitingForNetworkLine`;
  - en fil som inte kan skrivas för att telefonen är full ger `noSpaceLine` och räknas aldrig som nedladdad.
- **Nätet i vyerna:**
  - `NetworkStatus.changes()` (AsyncStream) och `RepetitionModel.isOffline` är observerade. Modellen kör `refresh()`
    när nätet kommer tillbaka.
  - En text för inget nät: `NetworkStatus.noNetworkLine` ("Ingen internetanslutning. Försök igen när du är
    uppkopplad."), som används av DrillMakingError, HelpError och DrillCloudError utan nät.
- **Scener för Angela Fables A104 och A103 (a37826a, 982a976):**
  - repSchoolsOffline, repSchoolsFailed, repSchoolSearchNone, repSchoolSearchFailed och repPublishFailed;
  - repSoundMaking, repQuotaExam och repHelpTryUsedUp;
  - repNewOffline och repExamOffline.

  De använder `stageOffline`, `stagedQuotaExceeded`, `DemoPublishing(failure:noSchools:)` och Fables `stagedQuery` och
  `stagedProblem`.
- **Tester:** `aDownloadedExamPlaysWithoutANetwork` och `soundNoExamUsesIsRemovedAtLaunch` i
  `A79A81RepetitionTests`. `A92HelpTests` läser `noNetworkLine`.
- **CI:** byggena för 629b15c och a37826a avbröts av nyare pushar. Det som gäller är iOS build 43664558381 (982a976 på
  main), som var `pending` 02.47. **Inte verifierat:**
  - läs sviterna i det bygget, och rätta om det är rött;
  - skriv rapporten `reports/…-angela-a103-utan-nat.md`;
  - stäng A103 i kön och säg till Toby 1 (T27: simulatorn med nätet av);
  - säg till Angela Fable när bygget är grönt, så att hon kan köra skärmbilderna för A104.

## Nästa för molnet
- **Toby 2:s T24-fynd** (`reports/apptest/2026-11-15-0250-toby2-t24-hela-flodet.md`), min logik:
  - **L2:** ett importerat prov heter "Nytt prov". Ta namnet från ämnet eller första frågan (`saveImport`).
  - **L3:** "Här är frågorna:" blir "1 rad kunde inte läsas". Importregeln delas med Kevins `import_text` via
    `testdata/import/o58-cases.json`, så ändra den tillsammans med Kevin och lägg till ett fall.
  - **L4:** Nytt prov visar 20 innan kvoten har kommit.
  - **L5:** `unavailable` sades först efter mer än 40 s.
  - **L6:** `slow` visar "0 av 6" utan tecken på att något händer.
- **Öppet till Architect (D183):** ska ett prov som behållits efter ett kontobyte laddas upp igen under det nya kontot?
  Det kostar nytt ljud.
- **A3** väntar på K6.

## Bra att veta
- **Delad utcheckning:**
  - Andra sessioner gör merge-commits och autostash på main. Committa alltid med sökväg (`-- <filer>`) och kör
    `git pull --rebase --autostash` före push.
  - Leta efter konfliktmarkörer.
  - Låt andras `stash@{n}` vara.
- **Beslutsnummer krockar:** Deangelo tog D184 medan jag skrev, och mitt blev D186. Läs sista raden i DECISIONS precis
  före commit.
- **Bash-heredoc i det här verktyget** förstör ibland Python-strängar med `$0` eller `\(`. Skriv patchskript med
  Write och kör dem som fil.
- **ElevenLabs (D180):** inga tester som gör ljud. /exam kostar bara Claude.

---

# Överlämning: Angela (app), 2026-11-11, uppdaterad kl. 23.40

Sessionen 2026-11-11 gjorde A50–A69:
- Start, Mina svar, Vad kan Earmind?, loggröstningen och Earmind;
- Tobys T5b, T7b, T8b och T12;
- Kellys Ke28, Ke34, Ke35 och Ke37;
- ring och musik, Spotify för testare och `quiz_key` (K40).

Alla är gröna i CI (senast 43019231188 med A63). Inget är provat på telefon. Rapporterna heter `reports/2026-11-11-*-angela-a5*.md`
och `reports/2026-11-11-*-angela-a6*.md`.

**Kvar i kön:**
- A51 (loggan): hoppas över tills röstningen har avgjort den (D127).
- A3: väntar på K6.

## Det här står inte i rapporterna
- **Tider:** ta tiden i rapportnamn från `TZ=Europe/Stockholm date`, inte ur huvudet. Jag gissade fyra namn som låg
  i framtiden och rättade dem i f4d5552.
- **Fler Swift-fällor i dag:**
  - `return switch` efter en `guard`;
  - en statisk konstant som används i en `nonisolated` funktion måste också vara `nonisolated`.
  - Båda föll först i device-bygget, efter cirka 5 min.
- **Tavlan krockar ofta vid rebase:** scratchpad `ci/resolve.py BOARD.md "| Angela (app)"` behåller allas rader och
  tar bara Angela-raden från min version.
- **two_level (A56):** svaret strömmar vidare efter det korta svaret, och vakten räknar med det (A63).
- **CI:**
  - Molnsessionen har ingen Mac. `gh run list/view/download` och `gh workflow run` fungerar via proxyn, trots att `gh auth status` säger att token är ogiltig.
  - Vänteskriptet ligger i scratchpad `ci/waitsha.sh <sha>`.
  - `ios-build.yml` ignorerar nu `deploy-backend.yml` och QA-arbetsflödena. Förut avbröt varje Kevin-push appbygget.
  - En egen lokal app-commit följer med nästa push, också en docs-push, och startar då ett bygge.
- **Skärmbilder:** starta `screenshots.yml` samtidigt som bygget, så sparas 20 minuter. Nya scener:
  - pickMode;
  - myAnswers, myAnswersEmpty, myAnswerEdit;
  - canDo, canDoIntro;
  - logoVote, logoVoteDone.
- **Två blad samtidigt:** SwiftUI öppnar inte ett blad medan ett annat stängs. Sätt värdet i `onDismiss`, som Välj läge
  gör, eller vänta 0,6 s, som Inställningar › Mina svar gör.
- **Strängkatalogen:** `Localizable.xcstrings` har engelska nycklar med svenska värden för vissa texter. Byter man en
  sådan nyckel i koden måste nyckeln bytas i katalogen också, annars blir texten engelsk på svenska telefoner (A55).
- **Earmind och Lumen:**
  - "Lumen" finns kvar som väckningsord, i koden och i mappen `Application Support/Lumen`.
  - Ändra inte `NotesStore.defaultDirectory`, för då försvinner användarnas data.
- **Mina svar:**
  - Inspelningen skrivs ut med `SleepRecorder.transcribe`, alltså på telefonen och inte med Scribe (D133).
  - Den är inte provad på 10 minuters svenska.

## Läget kl. 23.40: A75, A76 (+ Ke46), A72 del 3 och A77 gröna i CI (43093258037, 43110609458). Kelly Ke48 godkänd
- **A77:** `LumenCapability.all` läses från `Shared/capabilities.json` (`CapabilityList`). Appen lägger bara till
  `symbols` och `places` per id, så ett nytt id i listan behöver en symbol. `context.capabilities` innehåller de
  givna tillåtelserna, och `context.utterance_ms` har ersatt A74:s `utterance_seconds`, som servern aldrig läste.
- **GitHubs Mac-kö** var 1–2 h på kvällen. En push som rör appkoden ställer sig sist i kön, så samla små ändringar.

## Läget kl. 21.08: A75, A76 och A72 del 3 pushade (CI e437b5b)
- **A72 del 3:** T15b:s väntande frågor väntade inte i timern. Huvudtråden stod still 7–20 s mellan "Answer ahead
  discarded (a different turn)" och "Activation" i `activated()`, troligen i `PlaybackService.stop()` (Apples
  syntes). Nu stoppas bara det som spelar, och "Activation was held X ms …" loggas. Läs den raden i T15c.
- **A76:** testläget är byggt, men K43 tar bara e-postkonton och appen har bara anonym inloggning. Väg (a) eller (b)
  står i `reports/2026-11-11-2100-angela-a76-testlage.md`. AAC skrivs från Int16. Om filerna blir tomma, byt till Float32.
- **A75:** varianterna finns i `WakeWord.variantsByName`. Lägg till nya från loggraderna "Name-like word not taken".

## Läget kl. 20.30: A71–A74 klara. T15 visade orsaken till den väntande frågan (A72 del 2 rättad, Toby kör T15b). Äldre: Tobys T14 (`reports/apptest/2026-11-11-1725-toby-t14-omtest-a67-a68.md`)
- **Rättat:** "ja", "mer" och "gärna" ger det långa svaret på 1,6–1,8 s (A65/A67). Det var 7–16 s.
- **Kvar (viktigast):** en fråga som väntar i `activation` skickas ibland först när Scribe stänger sessionen, efter
  13–29 s. Det gäller hela frågor (q4) och halva (c1, c3).
- **Mitt spår, ej verifierat:** `lumenIsBusyAnswering` (A68) står kvar på sant.
  - `answers.status` är kanske `.answering` medan ett svar i förväg buffras (`bufferAhead`).
  - Eller så har `answerRequestedAt` satts av svaret i förväg utan att något sagts.
  - Då väntar frågetimern i all oändlighet, och frågan går först när en annan väg (Scribes sista final) anropar
    `askWaitingQuestionIfIdle`.
  - Nästa steg: A70 loggar "A question waits 3 s: …" med orsaken. Låt Toby köra retest och läs raden. Rätta sedan villkoret, till
    exempel med en övre gräns på 5 s.
- **Kvar:** mikrofonen är stängd 12–15 s efter svar på två meningar, alltså 4–6 s längre än talet (T14 fynd 1). Fynd 4,
  c2 med fel ämne, går till Kevin.

## Öppna trådar
- **Toby:** skärmturen och förstagångstestet behöver de nya texterna:
  - Starta Earmind, · Byt / Välj läge;
  - Mina svar;
  - ingen "Bara fråga", "Fler lägen" eller "Få A-svar".
- **Kelly:**
  - Granska bilderna för A52, A53 och A54.
  - G3: "Ljud sparas inte." på Första frågan är osant med sömnläget. Deangelo avgör texten.
- **Oscar O39 Concern:** Mina svar säger elevens svar också när läraren ställer frågan. Architect/Deangelo.
- **Kevin:**
  - K36 (Spotify, ring) finns på servern, men appens del saknas. Spotify och Ring står som "Kommer snart" i Vad kan
    Earmind?, och "kör spellistan" ska tillbaka i exemplen när de fungerar.
  - Ordningen i röstningen sparas bara på telefonen. K39 har inget fält för den.
- **Aron:** ska väckningsordet också bli Earmind? Prova i kväll Start, Mina svar, en timer och en kalenderfråga.

## Angela Fable (repetitionsflödets vyer): överlämning till molnet, 2026-11-15 02:48
Från den lokala sessionen till "Angela Fable (moln)". Den lokala sessionen tar inga fler punkter. Längre version
(mina filer, arbetssätt, öppna trådar): `docs/HANDOVER-angela-fable.md`.

**Klart och grönt (rapporter i `reports/2026-11-14-*-angela-fable-*.md`):** A87, A90, A92–A95, A98–A102 i mina vyer,
Kellys P1. Senaste gröna iOS build med mina ändringar: 43640280850 (71ef001).

**Pågår: A104 (tomma lägen och fellägen). Inte klar.** Allt ligger på `main`, ingen egen gren.
- Pushat: 3b4f33b (skollistan och skolsökningen som systemets tomläge med Försök igen, publiceringsfelet under
  knappen, "Ljudet görs. Du kan starta när första frågan är klar.", slut på frågor på provet och i Prova på en kort
  text), 3d76e71 (utan nät: `model.isOffline`, rad i Nytt prov och på provet, `NetworkStatus.noNetworkLine`),
  9506c2e (`SchoolPicker.stagedQuery`, `PublishSheet.stagedProblem`).
- **Inte verifierat: att det kompilerar.** Simulator screenshots 43664433881 (3d76e71) gick när detta skrevs; inget
  iOS build med A104 är klart (43664672940 på 2d1ec9e går, 43664558381 väntar). Börja med att läsa de körningarna.
- Bilder: körningarna 43664669468 (17 Pro) och 43664675303 (SE, största text) är startade med Angela Schrutes tio
  scener (repSchoolsOffline, repSchoolsFailed, repSchoolSearchNone, repSchoolSearchFailed, repPublishFailed,
  repSoundMaking, repQuotaExam, repHelpTryUsedUp, repNewOffline, repExamOffline). Ingen bild är sedd, Kelly har
  inget fått.
- Kvar: titta på bilderna, kontaktblad i `reports/2026-11-15-a104-bilder/`, till Kelly med en lista över varje läge
  och text, rätta, rapport `reports/<datum-tid>-angela-fable-a104.md` med en tabell över alla nio lägen, STATUS,
  kö (raden står "pågår"), tavla.
- Tobys T24-fynd i mina vyer (`reports/apptest/2026-11-15-0250-toby2-t24-hela-flodet.md`), inte påbörjade: V1
  Publicera prov ser tryckbar ut medan "Saknas: …" står under (ska vara grå); V2 varningen "Publicerat." behövs inte
  när raden Publicerat syns. V3 ("Lumen" i Fler lägen) och V4 (kortet Har du prov snart?) är Angela Schrutes filer.

**Därefter:** A106 (läslägets vyer, D185) efter A105, K70 och Kellys Ke63. **0 ElevenLabs (D180).**
