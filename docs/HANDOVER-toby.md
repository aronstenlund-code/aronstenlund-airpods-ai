# Överlämning Toby (apptest), 2026-11-09 23:50
Sessionen gjorde 6 punkter (T4, T1, T2, T3, T6, T5) och har komprimerats. Nästa i kön: **T7** (A15 är klar), **T8**, och **T5b** när A21 är klar.

## Det som inte står i rapporterna
- **Windows-maskin utan Xcode.** CI är kompilatorn. Pusha till en egen gren `toby/<punkt>` och läs körningarna via GitHub API med git-uppgifterna, inte `gh`.
- **Utlösare för workflows:**
  - En push till `toby/**` som rör `AppTests/E2E/Chain/**` startar T1, som kostar (live Scribe och /answer). `AppTests/E2E/**` startar T3. Avbryt de körningar du inte behöver.
  - På main körs bara screens.
  - `apptest-long.yml` kör 5 min på push. 60 min körs manuellt med input `minutes: "60"`.
- **Delad utcheckning.** `D:\OneDrive\Airpods ai` har andra sessioners filer som inte är incheckade. Jobba i en egen worktree, `fetch` före push, och stage bara egna filer.
  - I STATUS och BOARD: byt bara din egen rad, med skript eller Edit.
- **Python på Windows:**
  - Använd `PYTHONIOENCODING=utf-8 python -I -X utf8`.
  - Skriv inte `\n` i heredoc-redigeringar av Python-filer, där blir det en riktig radbrytning. Använd `chr(92)` eller Edit.
- **WAV-kroken:**
  - `LUMEN_AUDIO_FILES`, `_GAP` och `_LOOP`. Den inledande tystnaden är fil 0 och loopas också.
  - Avgränsa varje fall med `currentFile` (se `ListeningE2ETests`/`CommandsE2ETests`).
  - Fortsättningar efter paus: två `say`-filer ihopfogade med python `wave` (`scripts/apptest/retest.sh`).
- **Apples röst i stället för ElevenLabs:** spara `VoiceChoice.appleDefault` under `voice.choice`. Då kostar uppläsningen ingenting.
- **Var försiktig med:**
  - "Lyssnar" på skärmen är `isListening && isHearing` (A11).
  - D74: läget visar standard medan appen är pausad. Det är avsiktligt och inget fel.
  - D82 stänger igenkänningen medan Lumen pratar. Långtestet läser inte upp svar, så det prövar inte D82.
- **429 från /answer:** körs flera lägen i följd i T6 kommer cirka 30 "Instruction failed" per läge. Lägg in en paus eller kör färre lägen per körning.
- **CI-krasch utan testkoppling:** "Test crashed with signal abrt before establishing connection" är ett fel i simulatorn. Kör om via API:t (`rerun`).

## Öppna trådar
- T5-fynd 1–4 till Angela (A21): Provläge-segment under en tur, svar i förväg på en halv fråga, mikrofonen stängd efter långt svar, 6–17 s väntan. T5b kör samma fall med `apptest-retest.yml`.
- T6-fynd: Angela har rättat dem i A14, men ingen har testat om dem. Kör om `apptest-commands` någon gång.
- `docs/DEVICE-TEST-QUICK.md` saknar Frågor med en fortsättning efter paus. Lägg in det när A21 är klar.
