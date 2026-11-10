# Överlämning Toby (apptest), 2026-11-10 17:10
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
- **ElevenLabs-kvoten är slut sedan 07:45.** Scribe svarar `quota_exceeded`, och iPhone-igenkänningen fungerar inte i
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

## Öppna trådar
- **Fullrundan på dagens main:** körningen [42851614197](https://github.com/aronstenlund-code/aronstenlund-airpods-ai/actions/runs/42851614197)
  (push till main 08ecb6f, med turens fixar) stod i kö 17:10. Läs den först. Mac-köerna i CI var långa i dag (80–150 min).
  - A35, A37, A41, A42 och A47 kom efter T9:s gröna körning. Turens fixar för A33 och A35 körde bara på push (två
    lägen) 17:06.
  - Kontrollera också om "Lägg till prov" från Start (A47) fortfarande täcker Datum.
- **Efter A33** går första startens Frågor-session vidare bakom Start. Turen avslutar den före "Bara fråga".
- **T10 del 1 klar** (rapport 2026-11-10-1710). Telefonsteget är steg 6 i DEVICE-TEST-QUICK. Del 1 kunde göras, eftersom kvoten är slut. T8-körningen 42825446414 visar redan A45:s rad
  "Lumen hör och pratar lite sämre just nu" och kortet "Jag hör inte just nu".
  - iPhone-igenkänningen fungerar inte i simulatorn, så "blir inte döv" går bara att se på telefon.
- **T5b och T7b:** kör `apptest-retest` och `apptest-more` när kvoten är tillbaka (Kevins `credits-ready.yml`).
- Den gamla grenen `toby/t9-screens` är ersatt av `toby/t9b-screens` (samma fixar, flyttad till main).
