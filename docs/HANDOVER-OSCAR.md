# Överlämning: Oscar (QA), 2026-11-09 22:45

Sessionen gjorde O5–O10 och har komprimerats. Nästa Oscar-session börjar med O14 och tar sedan O12 när Kevins K14.1 är klar. Läs CLAUDE.md, `prompts/queue/README.md`, `prompts/queue/oscar.md`.

## Det som inte står i rapporterna
- **Hjälpskript:** `scripts/qa/demo.py` (`signup`, `ask`, kostnad från tokens), `scripts/qa/d81.py` (`A`, `P`, `prov`, `CV`, `AD`, `backend_state`).
  - Importera **aldrig** `d81b.py`. Den kör hela sin svit vid import, och det kostade O5 dubbelt.
- **Gräns för nya användare:** en anonym användare får bara 20 svar den första timmen. Gör en ny `signup()` var 15:e anrop. `ask` väntar 3,2 s mellan anrop (20/min).
- **Kör offline först.** Node 24 kör backendens `.ts` direkt (`import … from "../../backend/supabase/functions/answer/x.ts"`). Matchare och regex testas då gratis och utan slump. Se `scripts/qa/o9_commands.mjs` och `o10_offline.mjs`.
- **Python:** kör med `python -I`. Scipy och websockets ligger i en egen mapp via `O6_LIB` (se `scripts/qa/o6_audio.py`). Windows-konsolen visar å/ä/ö som skräp, men JSON-filerna är rätt.
- **Utdata:** skriv till scratch eller `reports/qa/data/`, aldrig till `/tmp`.
- **Delad checkout:** stage bara egna sökvägar (andras filer ligger ocommittade i trädet). Kör `git pull --rebase --autostash` före varje push. Döda aldrig `python.exe` brett, bara ditt eget PID.
- **Gränser i backend:**
  - Scribe: varje keyterm får vara högst 20 tecken (längre ger 1008 och sessionen stängs).
  - `/provlage-eval` tar högst 64 KB, så transkribering i batch går inte.
  - `task` syns inte i `/answer`-svaret, så kommandon testas offline.
- **Bedöm själv:** kodkriterier som "minst lika många exempel" godkänner 1 mot 1. Läs svaren för hand innan något räknas som rätt (O10 S4/O9).
- Aron vill ha korta svar när en punkt är klar. Den långa versionen hör hemma i rapporten.

## Öppna trådar
- **O10 till Kevin (K13 tar dem först):**
  - vidgning mellan lägen i `memory/settings.ts`
  - rättelser med egna ord 3/20
  - appkommandon 13/20
  - telefonfiltret ("ring" i "omkring" gör "800 000" till platshållaren)
  - Frågor klipper mitt i ett ord vid 600 tecken
- **O9:** `WRAP_END` stryker "för mig" ("hur går det för mig").
- **O8:** textuppgifter som kan räknas i kod tar 7 s med tänkande, och O5-hänget återskapades inte.
- **O6:** Arons egna inspelningar läggs till när han skickar dem. Bara i scratch, aldrig i git: repot är publikt.
- **O14:** 429-mätningen är underlag för K12.
- **O12:** ElevenLabs-tecknen är begränsade, så läs texterna innan något genereras. A/B-ljud ska som artefakt eller i Storage, aldrig i git.
