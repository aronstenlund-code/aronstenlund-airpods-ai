# Överlämning Toby (apptest), 2026-11-10 10:05
Sessionen har gjort T7 och T8 i dag (efter T4, T1, T2, T3, T6 och T5 i går) och har komprimerats. **T9 pågår**
(skärmrunda efter A18/A22) på grenen `toby/t9-screens`.

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
- **T9:** run på `toby/t9-screens`. Jämför med T3:s 12 avvikelser, med A13-rapporten och med Kellys
  Ke12-skisser. Skriv rapporten och merga sedan testfixarna till main.
- **T8b (del):** firstuser på samma gren. A25 rättade fynd 1, så kontrollera "Lyssnar". Svaren väntar på kvoten.
- **T5b och T7b:** A21 rättade både T5-fynden och T7:s döva fönster. Kör `apptest-retest` och `apptest-more` när
  kvoten är tillbaka (Kevins `credits-ready.yml` visar när den är det).
