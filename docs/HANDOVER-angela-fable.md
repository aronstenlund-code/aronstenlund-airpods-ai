# Överlämning: Angela Fable (repetitionsflödets vyer), 2026-11-15 02:46 (lokal session, Windows)

Till "Angela Fable (moln)". Den lokala sessionen **fortsätter med A104 så länge Arons dator är på**. Innan du rör
mina vyfiler: `git log --since="40 minutes ago" --author-date-order --oneline | grep "Angela Fable"`. Finns färska
commits från mig är jag igång; ta då inget i samma filer, utan vänta en runda.

**Mina filer:** `Lumen/Features/Repetition/` (ControlCheckView, DrillView, DrillVoiceChoice, HelpChatView, NewDrillView,
PublishViews, RepetitionHomeSection, RepetitionPlayerView, ChatGPTImportView, GradeChoice), `Onboarding/WelcomeView.swift`,
`Listening/MyAnswerRecordView.swift` och repetitionsdelen av `HomeView.swift`. Logik, modeller, scener
(`RepetitionScreenshots.swift`, `ScreenshotStage.swift`) och `screenshots.yml` är Angela Schrutes: be henne.

**A104, läget 02:46** (rapport finns inte än; skriv `reports/<datum-tid>-angela-fable-a104.md` när den är klar)
- Pushat: 3b4f33b (skollistan och skolsökningen som `ContentUnavailableView` med Försök igen, publiceringsfelet under
  knappen, "Ljudet görs. Du kan starta när första frågan är klar.", slut på frågor på provet och i Prova på en kort
  text), 3d76e71 (utan nät: rad överst i Nytt prov och på provet, Dela/Publicera/Skapa frågor avstängda,
  `NetworkStatus.noNetworkLine`), 9506c2e (`stagedQuery`, `stagedProblem` för scenerna).
- Redan på plats sedan tidigare: inga prov, ljudet kan inte göras (A100), kameran nekad (A94), tom import (A93),
  kvoten slut i Nytt prov (A99).
- **Inte gjort:** kompileringen är inte bekräftad (Simulator screenshots 43664433881 och iOS build på 3d76e71 gick
  när detta skrevs). Inga bilder tagna. Kelly har inte sett något. Scenerna finns (a37826a, 840a695):
  repSchoolsOffline, repSchoolsFailed, repSchoolSearchNone, repSchoolSearchFailed, repPublishFailed, repSoundMaking,
  repQuotaExam, repHelpTryUsedUp, repNewOffline, repExamOffline.
- Nästa: kör "Simulator screenshots" med de tio scenerna (17 Pro, SE, största text), kontaktblad i
  `reports/2026-11-15-a104-bilder/`, skicka till Kelly med en lista över varje läge och text, rätta, rapport.
- Därefter A106 (läslägets vyer, D185), efter Angela Schrutes A105, Kevins K70 och Kellys Ke63.

**Arbetssätt som inte står i rapporterna**
- Ingen Xcode: CI är kompilatorn. "Simulator screenshots" (`workflow_dispatch`, `device`, `text_size`, `screens`) är
  den snabba kompileringskollen (cirka 10 min). Samma enhet och textstorlek avbryter föregående körning. Ett väntande
  iOS build ersätts av nästa push: samla Swift-pushar.
- Tillgänglighet: Tobys `apptest-a11y.yml` (input `scenes`) ger `a11y-<scen>.audit.txt` och `.tree.txt`.
- **0 ElevenLabs (D180).** Scenerna använder förberett ljud.
- Delad utcheckning lokalt: committa med sökväg, `git fetch` + `git merge origin/main --no-edit` före push. Vid krock
  i `prompts/queue/angela.md`: behåll båda sidor.
- Patcha Swift med ett Python-skript med exakta `assert count == 1`; backslash i heredoc försvinner (använd `chr(92)`).
- Kelly svarar inom minuter på bilder. Hon vill ha systemets grå text kvar utom för samtyckesraden och förklaringen
  under en grå huvudknapp (D174).

**Öppna trådar:** VoiceOver på riktig telefon; "text som inte nås" i Nytt prov (granskningen, inte utrett); att
Lyssna på första frågan verkligen spelar; Kellys P2 (röstnamn, Aron).
