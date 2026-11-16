# Kevin (moln): K78 – slut på ElevenLabs-krediter kostar inget för användaren (D200) – 2026-11-16 19:45

Driftsatt i `9c0b586` och `41a3f05` (deploy 43932305337 och 43933148660 gröna). **0 riktiga ElevenLabs-anrop** (kvotfelet fejkat i testerna och med `x-earmind-test: unavailable` live).

## Kartläggning (före)
- `/exam` (drill, drill_answers, read) anropar aldrig ElevenLabs, bara Claude. Där finns inget kvotfel att hantera.
- `/drill`: kvoten räknades vid spara/Starta prov, **innan** ljudet gjordes. När ElevenLabs svarade 401/402 quota fick filerna `audio_unavailable` (K62), och efter 10 minuter försökte `status` igen. Användaren hade då redan dragits frågor för ljud som inte blev av, och appen fick bara felet per fil.

## Nu
1. **Ingen dragning:**
   - Har en riktig fil misslyckats av kreditskäl de senaste 10 minuterna skickar `save`/`start` inget till ElevenLabs och räknar inget. Provet förblir ostartat (`audio_started: false`), så nästa Starta prov gör ljudet när saldot är tillbaka.
   - Tar krediterna slut **mitt i** en generering ger `get`/`status` tillbaka de frågor vars filer misslyckades. Det sker en gång per fråga (`drills.refunded`, rpc `refund_drill_quota`, aldrig under 0), och svaret har `refunded_questions`. Läsläget räknar tillbaka på samma sätt per 800 tecken.
2. **Tydlig kod med texten:** svaret är 200 med frågor och svar som vanligt plus `"audio_unavailable": true` och `"notice": {"code":"audio_unavailable","message":"Uppläsningen är tillfälligt avstängd. Texten fungerar som vanligt."}`. Det gäller i `save`/`start` när de hålls tillbaka, och i `get`/`status` när en fil misslyckats så eller när ljud saknas och krediterna är slut. Koden står i `prompts/queue/angela-fable.md` under A112 och i `backend/README.md`.
3. **Ljudet kommer tillbaka:** `status` försöker misslyckade filer igen efter 10 minuter (som K62), och nästa `start` gör resten. En fil som misslyckats räknas aldrig igen.
- Testtrafik ser bara teströsternas fejkade fel och riktig trafik bara riktiga fel, så ett test kan aldrig stänga av ljudet för riktiga användare.

## Tester
- `deno task test` 652/652, `deno task check` grön. Fyra nya fall i `drill/handler_test.ts`:
  - slut mitt i, ger tillbaka en gång
  - känt slut vid start, inget skickas, inget räknas, saldot tillbaka ger ljudet som vanligt
  - testets fejkade fel påverkar inte riktig trafik
  - `get` på ett prov som hölls som text
- **verified live** (`scripts/k78-live.py` i `kevin-live.yml`, run 43933584120, testkonto med `x-earmind-test: unavailable`):
  - sparningen hölls tillbaka (`generated 0`)
  - `status` gav `audio_unavailable`, rätt `notice` och båda frågorna som text
  - kvoten var oförändrad (0 → 0)
  - Starta prov räknade 0 och provet förblev ostartat
- **Inte nått live:** återbetalningen mitt i en generering. Det fejkade felet från första körningen (18:49) höll tillbaka den andra redan vid spara. Den vägen täcks av enhetstesterna. **untested assumption** live.
- Migration `drill_quota_refund` (kolumnen `drills.refunded`, funktionen `refund_drill_quota`) är tillämpad.

## Begränsningar
- En fråga som räknats som provkredit i `/help` (D177) och sedan ges tillbaka räknas som en återbetald fråga (ger tillbaka en som aldrig drogs). Det är sällsynt och till användarens fördel.
- Gränsen är de senaste 10 minuterna. Den första sparningen efter att kontot tog slut räknas och ges tillbaka vid nästa `status`.

## Nästa
Angela Fable: A112. Kevin: nästa punkt i kön (Oscars O71-fynd om testkontrollens IP-lista).
