# Överlämning: Angela (app), 2026-11-11 kl. 11.20

Sessionen 2026-11-11 (förmiddag) gjorde fem punkter:
- A50 ny Start;
- A53 Mina svar;
- A52 Vad kan Earmind?;
- A54 loggröstningen;
- A55 Earmind.

A50–A54 är gröna i CI 42999877208. Inget är provat på telefon. Rapporterna heter `reports/2026-11-11-1100-angela-a5*.md`
och `reports/2026-11-11-1130-angela-a55-earmind.md`.

**Kvar i kön:**
- A51 (loggan): hoppas över tills röstningen har avgjort den (D127).
- A3: väntar på K6.

## Det här står inte i rapporterna
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
