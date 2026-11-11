# Överlämning: Angela (app), 2026-11-11, uppdaterad kl. 17.25

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
