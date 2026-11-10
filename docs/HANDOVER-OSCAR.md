# Överlämning: Oscar (QA), 2026-11-10 11:07

Sessionen gjorde O14, O12, O15, O16 del 1, O18, O13 del 1, O11, O17 (BLOCKER kvar i K21), O19, O20, O21, O22, O23 (O17b, BLOCKER kvar i K21b), O24 (K20), O25 (K22-integritet), O26 (siffror), O27 (Rizz-filter), O28 (känsliga minnen) och O29 (telefonnummer). Dagens API-budget är använd (1,93 av 2 USD, plus Arons extra 0,40 USD för O23, av vilka under 0,01 gick åt). Efter O23 gäller bara gratis punkter till 18:00. Läs CLAUDE.md, `prompts/queue/README.md` och `prompts/queue/oscar.md`.

## Det som inte står i rapporterna
- **Hjälpskript:**
  - `scripts/qa/o15.py` kör vilken bank som helst (`--bank`, `--only g5,g6-03`, `--cap`, `--tag=-x` med likhetstecken). Skriptet sparar JSON efter varje fall och väntar ut inloggningsspärren.
  - Banker: `o15_bank.py` (215 fall) och `o15b_bank.py` (82 fall).
  - `tts_alive.py` kontrollerar om rösten lever med ett anrop.
  - `o12_tts.py` mäter TTS och `o16_keyterms.py` testar Scribe-termer.
- **Supabase spärrar anonym signup per nät** (`429 over_request_rate_limit`, cirka en timme) om flera skript kör samtidigt. Kör aldrig tre körningar parallellt.
  - En användare klarar 35 anrop (40 per timme de första 10 minuterna, sedan 20 per minut).
  - `demo.signup()` kraschar vid 429. Använd `o15.signup()`.
- **ElevenLabs-krediterna tog slut 2026-11-10 07:45** (mina O12 och Deangelos ljudtest). Både `/tts` och Scribe ger kvotfel. Starta ingen TTS eller Scribe förrän `python -I scripts/qa/tts_alive.py` ger 200.
- **A/B-ljud:**
  - `.github/workflows/oscar-ab-audio.yml` (workflow_dispatch) körs via API: `ghapi.sh actions/workflows/oscar-ab-audio.yml/dispatches -X POST -d '{"ref":"main"}'`. `ghapi.sh` finns i scratch `ci/` och använder token från `git credential fill`.
  - En push av en ny workflow-fil startar iOS-bygget. Kolla att inget iOS-bygge redan körs.
- **Klockan:** läs `date` och skriv aldrig gissade tider i kö eller rapporter. Jag skrev 09:30 när klockan var 07:40 och fick döpa om filen.
- **Delad checkout:**
  - Commita kö- och tavelrader direkt.
  - Kör `grep '^<<<<<<<'` före varje commit.
  - Commita med pathspec (`git commit -m … -- <mina filer>`).
  - `stash@{0}` (autostash 08:2x) innehåller bara filer som redan finns i HEAD och mina gamla köändringar. Den kan tas bort när någon bekräftar det, men jag har låtit den ligga.
- **Gradera för hand:** nyckelordsmatchning missar stavningar ("Frans Ferdinand") och missar fel innehåll som ändå har nyckelordet (Kebnekaise 2 099 m). Läs alla fel och alla "båda går"-fall.

- **Gratis offline-tester** (Node 24 kör backendens `.ts` direkt): `o17_k21_offline.mjs` och `o17b_offline.mjs` (krisfall), `o19_k12_offline.mjs`, `o20_web_routing.mjs`, `o21_k15_nav_offline.mjs`, `o22_corrections_offline.mjs`, `o24_k20_offline.mjs`, `o27_rizz_filter_offline.mjs`, `o28_memory_sensitive_offline.mjs`, plus Python `o25_k22_privacy.py`. Kör dem igen efter varje rättning från Kevin. De tar en sekund och kostar inget.
  - Filer som importerar `speech.ts` (`o26_numbers_offline.mjs`, `o29_phone_guard_offline.mjs`) kräver `node --experimental-transform-types`, eftersom klassen har parameteregenskaper.
  - `memory/handler.ts` importerar `npm:`. Därför läser `o28` de två reguljära uttrycken direkt ur filen.
- **Mönstret i dag:** varje kodlager som bygger på ordlistor (kris, K22-rensning, minnesfilter, Rizz-filter, självfrågor, navigering) klarar författarens egna fall men bara 0–50 % av nya. Rekommendationen har varit densamma varje gång: en liten Haiku-kontroll eller en flagga i modellens klassning i stället för längre listor.

## Öppna trådar
- **K22 (O25):** Aron ska inte lägga in `SUPABASE_SERVICE_ROLE_KEY` förrän K22 skriver till en artefakt i stället för det publika repot. Kontrollera med `ghapi.sh actions/secrets`. I dag 10:58 fanns bara `SUPABASE_ACCESS_TOKEN`.
- **O17b omtest först** när Kevin har rättat K21b: `node scripts/qa/o17b_offline.mjs` (gratis) och `python -I scripts/qa/o17b_live.py` (cirka 0,01 USD, kräver Arons godkännande eftersom dagens budget är använd). Krav: 40/40 krisfall får krissvaret, 0 tysta och högst 2/40 falska. Har Kevin lagt in O17b-fallen i sina tester behövs en ny uppsättning (O17c). Skriv den med indirekta tecken, metodfrågor, engelska och hörfel, för det är där listorna missar.
- **O16 del 2:** `o16_keyterms.py` med 36 försök (å/ä/ö i byte eller grafem, specialtecken, antal termer) när Scribe har krediter.
- **O13:** del 1 (K16) är klar. Del 2–4 kräver K17–K19, och del 3 kräver dessutom ElevenLabs.
- **Concerns till Architect:** Frågor svarar på lärarens provfrågor (O18 fynd 3) och säger "övrigt prat ignorerar jag" (O15 fall 2).
