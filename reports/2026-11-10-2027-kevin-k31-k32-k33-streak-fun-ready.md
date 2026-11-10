# Kevin K31, K32, K33: streak och notiser, roliga kommandon, "% redo"

Datum 2026-11-10 20:15–20:27. Uppgift: `prompts/queue/kevin.md` K31, K32 och K33. Commit `9f15d58`. Inga modellanrop i något av dem.

## K31: streak och notisens text (D115 C2/C3), till Angelas A38
`POST /study-plan` tar nu också **`quiz_days`**: varje datum (elevens egen kalender, YYYY-MM-DD) med minst en besvarad förhörsfråga. Appen har dem redan. Svaret får två nya fält:
- **`streak`**: `{current, best, done_today, at_risk}`.
  - `current` är antalet dagar i rad som slutar i dag, eller i går om dagens fråga inte är gjord än.
  - En missad dag nollställer streaken (som Duolingo, utan frysning).
  - `at_risk` betyder att dagens fråga inte är gjord och att streaken försvinner vid midnatt.
- **`notification`**: `{title, body}`, eller `null` när dagens fråga redan är gjord (då behövs ingen påminnelse).
  - Rubriken räknar ner till närmaste prov: "3 dagar kvar till Biologiprovet", "I morgon är det provet", "I dag är det Kemiprovet. Lycka till!". Utan prov blir den "5 snabba frågor".
  - Texten innehåller "5 snabba frågor", plus begreppet som är på tur eller det svagaste: "5 snabba frågor på cellandning håller din svit på 2 dagar vid liv." eller "… Det tar två minuter."
- `exams` kan nu saknas om bara `quiz_days` skickas.

## K32: roliga kommandon i alla lägen (D115)
- Fyra nya kommandofamiljer i `answer/commands.ts`:
  - `fun:sing`: sjung (om X)
  - `fun:rap`: rappa (om X)
  - `fun:joke`: berätta ett skämt / dra en vits (om X)
  - `fun:style`: säg det som en pirat / sportkommentator / robot
- De är kommandon och inga egna lägen. I Auto och i de sociala lägena krävs "Lumen" först.
- Svaret kommer alltid som ett vanligt talat svar till användaren och är aldrig tyst.
- Sången och rappen är alltid egna texter, aldrig befintliga låttexter.
- Allt står i `docs/COMMANDS.md`, avsnittet "roliga kommandon i alla lägen".
- **Angela:** i Socialt och Rizz kommer svaret som `delta`, inte som `suggestions`. Spela upp det som ett vanligt svar.

## K33: hur redo är eleven (N1), till Angelas A43
Varje prov i `/study-plan` får **`readiness`**: `{ready_pct, practiced, total, weakest: [{concept, score, why}], explain}`.

**Formeln** (dokumenterad i `study-plan/progress.ts`):
- Alla provets begrepp väger lika. Ett begrepps poäng kommer från dess Leitner-låda efter alla svar. Förhör, studiekort, övningsprov och repetitioner i planen räknas alla som historik.
- Poäng per begrepp:

| Läge | Poäng |
|---|---|
| Aldrig övat | 0 |
| Fel senast | 0 |
| Rätt en gång | 0,5 |
| Rätt två gånger i rad | 0,75 |
| Rätt tre gånger i rad | 1,0 |
| Repetitionen är försenad (dagen har passerat) | 80 % av poängen |

- "% redo" = medelpoängen × 100, avrundat.
- **De tre svagaste** sorteras på lägst poäng och sedan flest fel. Var och en får ett skäl: "fel senast", "inte övat än", "dags att repetera" eller "rätt, men behöver fler gånger".
- `explain` är en mening till eleven: "Räknat på 12 begrepp, 7 övade. Ett begrepp räknas fullt när du har haft rätt tre gånger i rad."
- **Angela:** skicka studiekortens och vändkortens resultat (A46) som historik på begreppet (`{date, ok}`), så räknas de med.

## Test
- `study-plan/progress_test.ts` (4 tester): streak, notiser, formeln och hela anropet.
- `answer/k32_test.ts` (2 tester): fraser och hela flödet i Auto, Provläge, Standardläge och Socialt.
- `k9_test.ts` har varianter för de nya familjerna. Där bytte jag också ett testfall: "säg det som en rubrik" är nu `fun:style`, så den fria instruktionen testas med "gör om det till tre punkter".
- Allt grönt i Node-shimmen: answer 314/314, study-plan 8/8.
- CI för `9f15d58`: se tavlan.
- **Inte testat live.** Allt är kod utan modellanrop. Live-delen är appens (A38, A43).

## Kostnad
0 USD.
