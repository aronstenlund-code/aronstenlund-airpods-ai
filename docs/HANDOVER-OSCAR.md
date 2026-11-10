# Överlämning: Oscar (QA), 2026-11-11 00:04 (pausad av Aron)

O13 del 3 och O16 del 2 är **inte körda**. Kör dem enligt raderna nedan när `stt-token` ger 200. Testa först med `scratchpad/stt429.py` eller `scripts/qa/tts_alive.py`.

**Kväll 19:27–:** Aron bad om O13 del 3, O16 del 2 (så kort ljud som möjligt, D120) och omtest av K34. Sessionen har komprimerats två gånger (PLAN 2e). Efter de här tre punkterna tar jag inga nya punkter, och nästa session börjar här.
- **O37 (K34) klar** i tre rundor: `reports/qa/2026-11-10-1952-oscar-o37-k34-kris-minne.md`. Kevin lade O17d i testerna, och runda 3 mättes med nya `scripts/qa/o17e_cases.json`: Auto 38/40, tryck-och-prata 10/10, Provläge 10/10, falska 2/40. Runda 4 mättes med nya `scripts/qa/o17f_cases.json`: Auto 39/40, falska 3/40. Gör Kevin en runda till är O17f troligen bränt, så skriv O17g och kör `python -I scripts/qa/o17b_live.py --cases=scripts/qa/o17g_cases.json --all --cap=0.10`, som kostar cirka 0,05 USD. Kontrollera först overlap mot `scripts/k21-crisis-cases.json` och `scripts/k34-holdout-cases.json`. Live-skriptet döper nu utfilen efter case-filen.
- **Minnet (B5):** `node scripts/qa/o37_b5_memory_offline.mjs`. Skriptet kopierar Kevins `isCrisisMemory` och stannar om koden ändras.
- **Scribe i kväll:** `stt-token` gav 429 för alla användare, även nya, från 19:29. Det är den globala dygnsgränsen på 600, ett fast fönster som nollställs 00:00 UTC (01:00 svensk tid). `provlage-eval` transcribe ger 413 på allt över 64 KB (`handler.ts:122` läser kroppen med 64 KB före sin egen gräns), så batch-Scribe går inte heller.
  - O13 del 3: `O6_LIB=<pylib> python -I scripts/qa/o13_del3_terms.py --realtime`. Den använder cachat TTS-ljud i `scripts/qa/audio-cache/o13d3/` (git-ignorerat, 501 tecken, genereras inte igen).
  - O16 del 2: `O6_LIB=<pylib> python -I scripts/qa/o16_keyterms.py --clip scripts/qa/audio-cache/o12/pl-001-eleven_v4_turbo-Adam.npy`, med 1 s tal och 10,5 s mellan försöken.
  - `O6_LIB` = `C:/Users/rothm/AppData/Local/Temp/claude/5e9f3c5b8167a701/8a0033f0-2545-4c05-aafa-35f855276ee4/scratchpad/pylib`.

## Tidigare (12:58)

Sessionen gjorde O14, O12, O15, O16 del 1, O18, O13 del 1, O11, O17 (BLOCKER kvar i K21), O19, O20, O21, O22, O23 (O17b, BLOCKER kvar i K21b), O24 (K20), O25 (K22-integritet), O26 (siffror), O27 (Rizz-filter), O28 (känsliga minnen), O29 (telefonnummer), O30 (eko), O31 (K19), O32 (calc, BUGG med parenteser), O33 (tid) och O34 (bank +44, inte körd). Dagens API-budget är använd (1,93 av 2 USD, plus Arons extra 0,40 USD för O23, av vilka under 0,01 gick åt). Efter O23 gäller bara gratis punkter till 18:00. Läs CLAUDE.md, `prompts/queue/README.md` och `prompts/queue/oscar.md`.

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
- **D113/D114 (12:36):** de enda restriktionerna är de åtta i `docs/RESTRIKTIONER.md` del B. Testa inte Rizz-filtret, 18+-spärren eller minnesstopp för religion och politik som fel (A1–A5).
- **Krisomtest nästa gång:** O17c ligger nog i Kevins tester då. Skriv O17d med indirekta tecken utan dödsord ("när jag är borta", "inte vara kvar på måndag"), metodfrågor utan jag-form och hörfel ("mej"), och kör `python -I scripts/qa/o17b_live.py --cases=scripts/qa/o17d_cases.json --all` (cirka 0,08 USD).
- **Först när Kevin har pushat:** O17b (`o17b_offline.mjs`, live `o17b_live.py` cirka 0,01 USD), O32-parenteserna och O25/K22. Kraven står i respektive rapport.
- **När det finns budget:** O34 (`o15.py --bank scripts/qa/o15c_bank.py`, cirka 0,15 USD), O13 del 2 och 4, och O15:s klockfel (07:20 när klockan var 07:58) med loggad `<now>`.
- **K22 (O25):** Aron ska inte lägga in `SUPABASE_SERVICE_ROLE_KEY` förrän K22 skriver till en artefakt i stället för det publika repot. Kontrollera med `ghapi.sh actions/secrets`. I dag 10:58 fanns bara `SUPABASE_ACCESS_TOKEN`.
- **O17b omtest först** när Kevin har rättat K21b: `node scripts/qa/o17b_offline.mjs` (gratis) och `python -I scripts/qa/o17b_live.py` (cirka 0,01 USD, kräver Arons godkännande eftersom dagens budget är använd). Krav: 40/40 krisfall får krissvaret, 0 tysta och högst 2/40 falska. Har Kevin lagt in O17b-fallen i sina tester behövs en ny uppsättning (O17c). Skriv den med indirekta tecken, metodfrågor, engelska och hörfel, för det är där listorna missar.
- **O16 del 2:** `o16_keyterms.py` med 36 försök (å/ä/ö i byte eller grafem, specialtecken, antal termer) när Scribe har krediter.
- **O13:** del 1 (K16) är klar. Del 2–4 kräver K17–K19, och del 3 kräver dessutom ElevenLabs.
- **Concerns till Architect:** Frågor svarar på lärarens provfrågor (O18 fynd 3) och säger "övrigt prat ignorerar jag" (O15 fall 2).
