# Överlämning: Oscar lokal till Oscar (moln), 2026-11-15 03:12

Den lokala Oscar har slutat. Den förra överlämningen (11 november) finns i git: `git log -- docs/HANDOVER-OSCAR.md`. Dess tips om molnet gäller fortfarande: kör `TZ=Europe/Stockholm date` före varje tid, och Supabase MCP används bara för läsfrågor.

## Klart (14 nov, allt pushat till main)
| Punkt | Rapport |
|---|---|
| O58, O58 efter K60, O58c | `reports/qa/2026-11-14-1005-…`, `-1304-…`, `-1334-oscar-o58c-import-hjalp.md` |
| O60 | `-1452-oscar-o60-langdklass.md` |
| O61 | `-1654-oscar-o61-testlage-k62b.md` |
| O62 (JA: testerna tar inga krediter) | `-1816-oscar-o62-inga-krediter.md` |
| O63 | `-1910-oscar-o63-svarskvalitet.md` |
| O64 | `-2034-oscar-o64-omtest-k66.md` |
| O65 | `-2121-oscar-o65-omtest-k67.md` |

## Pågår: O66, nattligt regressionsskript, på grenen `oscar/o66-nightly`
Grenen är inte mergad till main. Den har följande filer:
- `scripts/qa/o66_nightly.py`
- en liten ändring i `scripts/qa/qa_testaccount.py`
- D180-skyddet i `o58_help.py` och `o58_import.py`
- statusen `reports/qa/2026-11-15-0308-oscar-o66-pagar.md`, som har detaljerna
- data från första körningen

**Läget:**
- Första körningen 01:41–02:05 UTC gav 93 kontroller: 84 ok, 4 kända och 5 fel.
- 4 av felen är skriptfel. Ett är ett riktigt fynd, prio 3: `/help` svarade med 7 meningar på "jag vill plugga till mitt bioprov, hur börjar jag".
- Delarna E–L är gröna. K67-fynden från O65 är rättade live: "ja/nej", "kilometres per hour" och "three quarters".
- 0 ElevenLabs.

**Att göra:**
1. Ta grenen: `git fetch && git merge origin/oscar/o66-nightly`, eller cherry-pick fced762.
2. **Rätta registreringen (429).** Supabase begränsar registreringar per IP, och en körning gör cirka 15. Både `o55_drill_server.py` och `o58_import.py` kraschade på det. Gör så här:
   - Låt `o66_nightly.signup()` spara och återanvända refresh tokens, som `users()` i `o56_publish.py`.
   - Fånga undantag i `run_script`-delarna.
   - Ge `o58_import.py` försök igen vid SSL-avbrott.
   - Om du återanvänder ett konto: kvoten är 15 frågor per konto och månad. Delarna G och I behöver därför **nya** konton.
3. **Uppdatera nyckelorden** i `o58_help.py` för "vad händer när alla frågor är slut". Det rätta svaret nämner 15 frågor per månad (D175).
4. Kör hela skriptet: `python -I -X utf8 scripts/qa/o66_nightly.py`.
   - Det tar cirka 25 minuter och cirka 0,1–0,3 USD Claude.
   - Kör sedan de 3 SQL-frågorna som skriptet skriver ut, via Supabase MCP:
     - ElevenLabs: alla filer med `earmind-test-silent`, 0 krediter
     - K64: filerna "unused"
     - K67: uppläsningstexten
   - Sök också i funktionsloggen på `elevenlabs`.
5. **K69 är driftsatt** (Kevin 02:55, `reports/2026-11-15-0255-kevin-k69-faster-create.md`). Anteckningarna skrivs nu i ett eget Haiku-anrop samtidigt som frågorna.
   - O66 säger att skriptet ska köras igen efter K69. Första körningen gick delvis före driftsättningen.
   - Kevin ber också om ett omtest av O63/O64 på appens väg:
     - `python -I -X utf8 scripts/qa/o55_grade.py drill --no-judge --questions 12 --tag <tag> --ids <h3-…,h4-…>`
     - `python -I -X utf8 scripts/qa/o64_k66.py check <drill.json>`
     - läs själv
   - Kevin (moln) gör också en kontroll.
6. Skriv rapporten, merga till main, och uppdatera kön (`[x]` på O66), STATUS och tavlan.

## Skript (alla i `scripts/qa/`)
- **`qa_testaccount.py`:** `install()` sätter testhuvudet på varje Supabase-anrop och vägrar direkta ElevenLabs-anrop. Ett eget `x-earmind-test: oscar-qa slow|unavailable` behålls (ändringen ligger på grenen). Använd alltid det, enligt D180.
- **`o66_nightly.py`:** hela regressionen. Med `--fast` hoppas Claude-delarna över.
- **`o55_grade.py drill --no-judge`:** frågor och svar på appens väg för materialbankerna `repetition_bank/materials*.py`. H3 och H4 är mina hållouts från O63 och O64.
- **`o63_quality.py <drill.json> [--long-only]`:** domaren (Sonnet), cirka 0,004 USD per bedömning. Domaren är okalibrerat sträng på korta svar (D162 är obesvarad), och instruktionen säger inget om språkämnen.
- **`o64_k66.py`:**
  - `onecall` kör anropsvägen med svar i samma steg
  - `check` kontrollerar de fem K66-punkterna maskinellt
  - `save` sparar, hämtar och tar bort med testkonton
- **`o58_help.py` och `o58_import.py`:** /help och import_text.
- **`o55_drill_server.py` och `o56_publish.py`:** spara, dela, publicera och RLS.
- **Kör inte `o61_testmode.py` som det är.** Sista steget är ett riktigt tts-anrop utan testmarkering, och det kostar krediter när kontot har sådana.
- **Uppläsningstexten** finns i `drill_audio_files.text` och läses via MCP. Prov med fasta texter, sparade med ett testkonto, testar uppläsningen utan Claude.

## Testkonton
- Testkontona är anonyma Supabase-konton (`/auth/v1/signup` med den publika nyckeln i skripten) och har inga lösenord.
- Testmarkeringen är headern `x-earmind-test` och en skriptklient. Servern sparar kontona i `test_accounts`.
- `o56_publish.py` sparar refresh tokens i `%TEMP%/o56_tokens.json`. Filen finns bara lokalt, så molnet gör nya.
- Inga hemligheter finns i repot eller här.

## Regler som gäller
- **D180:** 0 ElevenLabs, bara testkonton, och kontrollera i SQL efteråt.
- Skriv bara i `scripts/qa/`, `reports/qa/`, din kö, din rad på tavlan och din rad i STATUS.
- Stagea bara dina egna filer, och kör `git fetch` före push, eftersom main rör sig.
