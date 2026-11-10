# Överlämning Toby (apptest), 2026-11-10 20:15
Sessionen har gjort T7, T8 och T9 i dag (efter T4, T1, T2, T3, T6 och T5 i går) och har komprimerats. Kön har T5b,
T7b och T8b (alla väntar på ElevenLabs-kvoten) samt T10.

## Det som inte står i rapporterna
- **Windows utan Xcode.** CI är kompilatorn. Pusha till `toby/<punkt>` och läs körningarna via GitHub API med
  token från `git credential fill`.
  - Jobbloggar och artefakter svarar med en omdirigering. Följ den **utan** auth-huvudet, annars får du 401.
- **Utlösare:** en push till `toby/**` som rör `AppTests/E2E/**` startar T3 (screens, cirka 80 min för 7 lägen) och
  T8 (firstuser). En push till main startar screens, men andras pushar avbryter den. Kör därför på egen gren.
- **Delad utcheckning.** Jobba i en egen worktree. På main byter du bara dina egna rader (STATUS, BOARD,
  `prompts/queue/toby.md`), från `origin/main` och om igen vid krock.
- **Python på Windows:** Bash-verktyget gör om `\\` i heredoc. Skriv Python-filer med Write/Edit, inte heredoc.
- **ElevenLabs-kvoten var slut 07:45–19:15 (påfylld i kväll).** Det som stod här gällde då: Scribe svarar `quota_exceeded`, och iPhone-igenkänningen fungerar inte i
  simulatorn. Alla ljudtest står därför (T5b, T7b, A17-omtest).
  - Det som går är UI: skärmturen, och förstagångstestets kontroll av "Lyssnar" inom 15 s.
- **A18/A22 bytte knappord:**
  - "Hoppa över" före första svaret ("Fortsätt" bara efter ett svar).
  - "Lumen hör dig inte" när mikrofonen är nekad.
  - Provsteget heter "Har du prov snart?" och har knappen "Inte nu".
  - Start har "Bara fråga" och "Fler lägen" (Provläge, Intervju, Socialt och Rizz 18+).
  - Inställningar har "Feedback och förslag", "Röstkommandon" och "Avancerat".
- **upload-artifact** vägrar filnamn med `"`. XCTest döper bilagor till `Debug description for "…"`, så
  `screens_index.py` tar bort de tecknen.

## Öppna trådar (20:15)
- **D120:** krediterna är påfyllda, men slösa inte. Talet görs med `say`. `apptest-retest` kör som standard bara
  `fragor,block`, och `apptest-firstuser` bara `skip`. Skärmturen körs inte längre på varje push till main, bara
  nattligt (03:30), manuellt och på egen gren när `AppTests/E2E/Screens/**` ändras. Den öppnar Scribe.
- **`/stt-token` svarar 429 `rate_limited`** sedan kvällen, troligen dagstaket på 600 för hela appen. Det nollställs
  00:00 UTC (01:00 svensk tid). Rapport `reports/apptest/2026-11-10-2007-toby-t10-del2-stt-tak.md`, till Kevin.
- **01:05:** `at0105.sh` (scratchpad, bakgrund) startar `apptest-more`, `apptest-firstuser paths=skip` och
  `apptest-retest sets=fragor,block` på main. Läs dem och skriv slutrapporten för T5b, T7b och T8b. Om 429 är kvar:
  skriv det och kör inte om.
- **T10:** del 2 är grön (`apptest-outage`, en 503-stub i testprocessen, 0 krediter). Kvar är bara telefonsteget
  (DEVICE-TEST-QUICK steg 6).
- **Fullrundan på main (42851614197):** "Bara fråga" öppnar inte Lyssnar efter första starten, eftersom
  `startMode` hoppar till `switchMode`. Appfel, till Angela. Turen är rätt. "Studiekort" på SE och "Rå
  transkription"/"Diagnostik" vid största text missas ibland av turens rullning.
- Grenen `toby/t5b-t7b-t8b` är flyttad till main (ce7411c).
