# Kevin (moln): K77 – Repetitionsläget i Arons analys (D197, D116) – 2026-11-15 22:25

Driftsatt i `72c2f98` (deploy 43762966667 grön). **0 ElevenLabs-anrop.**

## Vad som byggdes
- Raderna skrivs i **samma tabell som qa-log** (`qa_log`). De följer därför med i samma leverans (`backend/webtest/qa.html`), raderas med samma "Hämtat" och rensas senast efter 14 dagar (`purge_qa_log`). Ingen ny tabell och ingen ny sida. qa-sidan har fått etiketterna "Repetitionsläget" och "Läsläget".
- **`save`** (`drill/analysis.ts`, `saveRows`), för frågeprov:
  - `sparad`: en ny fråga med sitt långa svar.
  - `ändrad`: en fråga eller ett svar som användaren ändrat, med "Fråga/Svar före:" och "efter:".
  - En sparning utan ändringar, och Starta prov, skriver inget.
- **Nytt `stats`-anrop** för tryckstatistik: `{"action":"stats","id","presses":{"1","2","3"},"per_question"?,"minutes"?}` → `{"logged"}`. Det blir en `tryck`-rad med ämnet, totalen och för frågeprov tryck per fråga (med frågan). Högst 6 i minuten och 100 om dagen per konto. Kontraktet till Angela står i `backend/README.md`, "Repetitionsläget i Arons analys".
- **Följer aldrig med:**
  - läslägets text (den är materialet, B4), bara dess tryck
  - foton och material, som aldrig når `/drill`
  - testkonton (`currentTest()`, alla anrop från Actions och testhuvudet)
  - importerade och publicerade kopior (de är originalets frågor, inte mottagarens; mottagarens egna ändringar loggas)
  - användar-id (som i qa-log)
- Siffror maskas med qa-logs `maskNumbers` (personnummer, kort- och kontonummer).
- Fel vid skrivningen stoppar aldrig sparningen (loggas som `analysis_log_failed`).

## Tester
- `deno task test` 648/648, `deno task check` grön. Tre nya fall i `drill/handler_test.ts`:
  - sparad, ändrad, oförändrat och start
  - text, tryck, test, kopia
  - maskade siffror
- **verified live** (`scripts/k77-live.py` i `kevin-live.yml`, run 43763217587, plus SQL): spara, redigera och `stats` svarar 200, och `stats` säger `logged: false` för testkontot. Ett felaktigt `presses` ger 400. `qa_log` har 0 rader med `repetition`/`read`.
- **Inte verifierat live:** att en riktig användares rad hamnar i `qa_log`. Från Actions är varje anrop ett test (GitHubs IP, D180), och riktiga anrop härifrån skulle göra riktigt ljud. Skrivvägen är densamma som qa-logs `insertMany` och täcks av enhetstesterna. Första riktiga raden syns på Arons qa-sida. **untested assumption**

## Concerns
- D197 säger att repetitionsläget omfattas av D116. Samtyckestexten och integritetspolicyn bör nämna att frågor och svar man skapar och ändrar i proven skickas till analys (Angela/Kelly). `/drill` har ingen samtyckesflagga som `/answer` har (`qa_log: true`). Vill Architect ha en sådan, är det en rad i `analyse()`.

## Nästa
Oscar O70. Angela skickar `stats` när ett pass slutar.
