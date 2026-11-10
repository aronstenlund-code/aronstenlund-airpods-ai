# Kevin K35 (D122): agentverktyg, fas 1 (telefonverktyg)

Datum 2026-11-10 20:44–20:56. Uppgift: `prompts/queue/kevin.md` K35. Commits `77ebae5` och `c9d6e39`, driftsatta (CI 42889385200 och 42889863146).

## Vad som byggts
- **Designen finns i `docs/AGENT.md`:**
  - protokollet för telefonverktyg (till Angelas A48);
  - verktygstabellen;
  - säkerhetsreglerna;
  - Shopify-piloten (planerad, inte byggd).
- **`/answer` med Claudes tool use** (`answer/phonetools.ts`), för sex verktyg: `calendar_add`, `calendar_list`, `reminder_add`, `timer_start`, `alarm_set` och `note_add`.
  - Verktygen erbjuds bara när appen skickar `tools_available`, i Standardläge (tryck och prata, text) och Provläge. Aldrig i Auto, de sociala lägena eller demon i fas 1.
  - Definitionerna är `strict: true`. Koden kontrollerar dessutom varje indata innan något skickas till appen: datum i ISO-format, tid HH:MM och timer 1–86 400 s. Fel indata och okända verktyg tappas och loggas (`tool_call_dropped`).
  - SSE-händelsen `tool_call` har `{id, name, input, confirm, kind}`. `confirm` är en svensk ja/nej-fråga för det som ändrar något, och skrivs av koden, inte av modellen. Kalender, påminnelse och larm har en, timer och anteckning inte. `done.tool_pending` är true.
  - `tool_round` är andra anropet. Där skickar appen resultatet (`ok`, `declined` eller `error`), och modellen säger en kort mening om resultatet.
  - En regel i systemprompten läggs bara till när verktyg erbjuds, så vanliga anrop har kvar sin cachade prompt.
- **Providern (`llm/anthropic.ts`):**
  - `tool_use`-block blir `tool_use`-chunkar (indata-JSON samlas per block och tolkas strikt).
  - `messages` kan skickas hela.
  - Text hålls bara tillbaka för serververktyg, eller när yttrandet låter som en handling (se nedan).
- `llm/deadline.ts`: ett verktygsanrop räknas som första utdata, så ingen reserv startas.
- **Rättat efter första livetestet:** Haiku sa ett engelskt resonemang före `calendar_add` ("The user asks to add a dentist appointment …"), och det skulle ha lästs upp. För yttranden som låter som en handling ("lägg in", "påminn", "sätt en timer", "väck mig", "vad har jag i …") hålls texten nu tills ett verktygsanrop kommer, och då slängs den. Kommer inget anrop, sägs texten när svaret är klart.

## Test
- Node-shimmen: answer 318/318, med bland annat `k35_test.ts` (verktygsdefinitioner, validering, bekräftelsetext, `tool_call`, `tool_round`, nekad runda, 400 vid fel runda, inga verktyg utan `tools_available`) och `llm_test.ts` (`tool_use`-block, `messages`, att texten hålls tillbaka).
- **Verified live** (`scripts/k35-tools-live.py`, Haiku, tryck och prata), `reports/eval/k35-tools-2026-11-10.json`: **12/12 rätt.**
  - "lägg in tandläkaren på torsdag klockan tre" gav `calendar_add` med start 2026-11-12T15:00 och bekräftelsen "Ska jag lägga in Tandläkaren torsdag den 12 november klockan 15:00 i kalendern?".
  - Timer 300 s, påminnelse 2026-11-11T07:00, larm 06:30, kalenderläsning för i morgon och en anteckning blev också rätt.
  - Fem vanliga frågor gav inget verktyg, bland dem "vad betyder ordet påminnelse" och "min kompis sa att hon skulle boka biljetter".
  - Ingen text sades före ett verktygsanrop.
  - Rundan efter `ok` gav "Tandläkaren är inlagd i kalendern på torsdag den tolfte november klockan femton."
- **Inte testat:** på telefon (A48 finns inte än), i Provläge med Sonnet, och `calendar_list` med riktiga händelser tillbaka.

## Till Angela (A48)
Protokollet står i `docs/AGENT.md` under "Telefonverktyg: protokollet":
- Skicka `tools_available` med de verktyg appen kan köra.
- Spela upp `confirm` och kör verktyget bara efter ett ja.
- Skicka `tool_round` med samma fält som anropet.

Tider är lokal svensk tid utan zon.

## Kvar
- **Shopify (fas 2)** kräver tre saker från Aron: en Shopify Partner-app (gratis), där `SHOPIFY_CLIENT_ID` och `SHOPIFY_CLIENT_SECRET` blir hemligheter, en testbutik och ett beslut om kopplingar på anonyma konton. Då bygger jag `connect-shopify`, tabellen `connections` (token krypterad med `CONNECTIONS_KEY`) och verktyget `shop_status`.
- Telefonverktyg i Auto (fas 2): kräver att metahuvudet och verktygsanropet hålls isär.

## Kostnad
Live-testet: 13 Haiku-anrop, under 0,01 USD.
