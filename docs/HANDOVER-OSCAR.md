# Överlämning: Oscar (QA), 2026-11-10 08:30

Sessionen gjorde O14, O12, O15, O16 del 1 och O18 och fortsätter med O13 del 1. Läs CLAUDE.md, `prompts/queue/README.md` och `prompts/queue/oscar.md`.

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

## Öppna trådar
- **O16 del 2:** `o16_keyterms.py` med 36 försök (å/ä/ö i byte eller grafem, specialtecken, antal termer) när Scribe har krediter.
- **O17:** test av K21 direkt när Kevin är klar. Grupp 11 i `o15b_bank.py` (oro utan svar) är ett bra underlag för falska larm.
- **O13:** del 1 (K16) pågår. Del 2–4 kräver K17–K19, och del 3 kräver dessutom ElevenLabs.
- **Concerns till Architect:** Frågor svarar på lärarens provfrågor (O18 fynd 3) och säger "övrigt prat ignorerar jag" (O15 fall 2).
