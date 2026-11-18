# Kallstart (O84), sakfel och dubbletter (O79 omtest), refresh-token (A143)

Kevin (moln), 2026-11-18 12:00. 0 ElevenLabs. Mätningen O79 kostade 0,23 USD, bara Claude. Tester: 719/719.

## 1. Kallstart: `drill` hålls varm
- **Orsaken** (stegloggen och O84):
  - Inne i handlern tar en kall save högst cirka 5,5 s. Databasanslutningarna tar cirka 1 s per anrop första gången.
  - Före handlern kommer funktionens kallstart, CI-listan (rättad 11:00) och JWKS.
- **Byggt:**
  - `POST /functions/v1/drill {"action":"warm"}` utan token startar funktionen och förvärmer databasen, inställningarna, röstkatalogen, CI-listan och nycklarna för inloggning. Svaret är 204 utan innehåll. Inga kontodata läses.
  - `drill` deployas nu utan gatewayens JWT-kontroll, precis som `purchase`. Varje annan åtgärd kontrollerar token i koden som förut.
- **Verifierat live** (k100-warm, run 44289767402):
  - `warm` svarade 204 på cirka 0,1 s.
  - `list` utan token gav 401, och med en falsk token också 401.
  - Ett testkonto gav 200.
- **Till Deangelo:** kör `20261118120001_k100_warm_drill.sql`. Den gör ett pg_cron-anrop var 2:a minut, på samma sätt som drill-purge, och utan nyckel.
- **Ej verifierat:** att det håller den första användarens tryck under 8 s. Det kan bara mätas efter en stunds vila, när cronen har körts. Oscar mäter O84 igen.

## 2 och 3. Sakfel och dubbletter: en sista kontroll av hela frågelistan
- **Varför felen slank igenom:** frågorna som fylldes på per avsnitt kontrollerades aldrig. Kontrollen i förkortningssteget kom före dem.
- **Nytt:** `finalCheck` gör ett anrop till svarsmodellen (Sonnet, för korrektheten) med materialet och hela den färdiga listan. Den:
  - rättar en fråga som förutsätter något materialet inte säger, eller säger annorlunda (Lübeck-exemplet står i prompten);
  - gör om en varför-fråga utan orsak i texten till en vad- eller hur-fråga;
  - tar bort en fråga vars svar är detsamma som, eller ingår i, en tidigare frågas svar.
- **Skydd i koden:** aldrig den första frågan, högst en tredjedel, aldrig den sista frågan i ett avsnitt. En omskrivning får vara högst 4 ord längre och får inte luta sig mot materialet.
- `usage.final_check` visar `{fixed, dropped}`.
- **Verifierat i test**, med fejk.

**Mätt på Oscars fem material** (`qa/o79_quality.py`). Före = run 44280047510, 09:54. Efter = run 44290142634, 10:58. **Verifierat live**, och jag har läst alla frågor:

| | Före | Efter |
|---|---|---|
| Vasa, Lübeck | – (frågan kom i Oscars omtest 11:22) | "Varför hade kronan skulder till Lübeck?" (stämmer med texten) |
| inflation, frågorna 2 och 14 (samma svar, 2022) | båda med | en kvar |
| printing 8/10, ljud 1/4 (Oscars par) | med | borta |
| antal frågor (ekosystem, printing, ljud, vasa, inflation) | 14, 14, 10, 14, 14 | 11, 12, 10, 13, 11 |
| avsnitt utan fråga | 0 | 0 |
| varför/hur-frågor | 10, 11, 7, 10, 10 | 7, 7, 7, 3, 10 |

- **Avvägning:** Vasa har nu bara 3 förståelsefrågor av 13. Materialet säger sällan varför, och Oscars O79 F3 visade att varför-svaren då hittar på orsaker. Det är alltså avsiktligt, men färre "varför" i historia är ett val för Deangelo. Alternativet är att låta varför-frågor stå kvar när svaret kan säga "texten säger inte varför".
- **Färre frågor:** när dubbletter tas bort fylls listan inte på igen, och svaret säger då "Materialet räckte till N frågor". En påfyllning skulle kosta ett anrop till.
- **Kvar enligt Oscars mått:** ljud flaggas fortfarande med 4 par. Jag läser dem som olika frågor (vakuum, gitarrsträngen, "vad är ljud", styrka och hörsel). Vasa 4 är en dubbelfråga ("vilken dag … och vad hände då") och kunde delas.
- **Inte mätt:** hur mycket det sista anropet förlänger skapandet av ett prov. Det är ett anrop till Sonnet efter fördelningen, troligen 3–6 s.

## 4. Refresh-token i Supabase Auth (Angela Schrutes A143)
- Jag försökte läsa inställningen med Management-API:t (workflown `kevin-auth-config.yml`, bara läsning). Svaret var 403, eftersom nyckeln saknar behörigheten `auth_config_read`.
- Klickvägen till Aron står i **TILL-ARON #32**. Standardvärdet är 10 s enligt Supabases dokumentation (verifierat i docs). Vårt värde är okänt tills Aron har tittat.

## Nästa
- **Deangelo:** kör `20261118120001_k100_warm_drill.sql`. Ta också ställning till varför-frågorna i historia.
- **Oscar:** O84 kallstart efter cronen, och O79 en gång till.
