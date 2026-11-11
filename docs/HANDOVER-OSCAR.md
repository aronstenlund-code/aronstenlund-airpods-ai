# Överlämning: Oscar (QA), 2026-11-11 14:17 (molnsession, 11 punkter, inte komprimerad)

Klart i dag: O38 (K38), O16 del 2, O39 (K37), O13 del 2 (K17), O34, O40 (K39), O41 (K36, BLOCKER rättad i K40), O42 (omtest), O44 (K36 godkänd), O43 (enordssvar, BUGG falskt Rätt i sorl). Rapporter i `reports/qa/2026-11-11-*`.

## Det som inte står i rapporterna
- **Molnsessionen saknar det git-ignorerade ljudet:** `scripts/qa/audio-cache/` (O13d3, O12-klipp) finns bara på Arons Windows-dator. O13 del 3 måste köras där (`O6_LIB=<pylib> python -I scripts/qa/o13_del3_terms.py --realtime`) eller med Arons ja till att generera 501 tecken igen. Generera inget utan det (D120).
- **Ljud för Scribe-tester utan ElevenLabs:** `apt-get install -y espeak-ng`, sedan `espeak-ng -v sv -w x.wav "…"` → 24 kHz-npy (se O16). Det duger när innehållet inte spelar roll (keyterm-regler).
- **Python-bibliotek i molnet:** `pip install --target <scratch>/pylib scipy numpy websockets`, `O6_LIB=<scratch>/pylib`.
- **Node 22 i molnet:** `--experimental-strip-types` räcker för `savedanswers.ts`. Filer som importerar `_shared/errors.ts` (parameteregenskaper) eller `npm:` går inte att köra direkt. Klipp i stället ut den rena delen till en tillfällig modul (se `o13_del2_k17_offline.mjs`).
- **Supabase MCP fungerar för läsfrågor** (projekt `xjczbzfkmbjdebwlccki`): `has_table_privilege`, `pg_policies`, `cron.job`. Skriv aldrig via MCP utan att punkten säger det.
- **Containerns `date` är UTC.** Kör `TZ=Europe/Stockholm date` före varje tid du skriver. Jag skrev två gånger en tid 5–7 min fram och fick rätta det.
- **Loggrader kapas vid 110 tecken** i `o15.py`. "Svaret är tjugo" var "tjugofem". Läs svaren i JSON-filen innan du skriver att något är fel.
- **Scribe-strömmar stängs ibland med 1006** efter att transkriptet kommit. Det är brus, inget avvisande. Bara `invalid_request` och 1008 betyder att regeln brutits.

- **O43-ljudet** (367 ElevenLabs-tecken, `scripts/qa/audio-cache/o43/`, plus `babble16k.npy`) finns bara i molnsessionen från 11 november. En ny session måste generera det igen (`o43_short_answers.py` gör det själv första gången) eller köra där cachen finns. Kör O43d med `nohup … &` och vänta i omgångar: 40 strömmar tar över 10 min.
- **Scribe läser upp keyterms i sorl** (O43). Räkna listuppläsningar (3 eller fler keyterms med kommatecken) separat, annars blåser de upp "hörde rätt".

## Öppna trådar
- **O43d omtest** när Kevin eller Angela hanterar listuppläsningen: `O6_LIB=… python -I scripts/qa/o43d_false_right.py --cond silence,wrong`. Krav: 0/20 falskt Rätt.
- **Aron:** lägg in `SUPABASE_SERVICE_ROLE_KEY` (K38 godkänd). Första veckan med kandidater: testa hela kedjan (tabell → Godkänn → approve → commit).
- **Aron-beslut (O16/O34):** "ljud sparas inte" i appen och i självsvaren är inte sant för ElevenLabs Scribe utan enterprise-nivå.
- **Rättat och omtestat (O42/O44):** K17 `planDays` 19/19, självsvaren 11/11, länkar 9/10, K36 29/29. Kör om `o13_del2_k17_offline.mjs`, `o41_k36_live.py` och `o34b_k19_links.py` efter nästa ändring i de delarna.
- **K37:** mina 41 fall i `scripts/qa/o39_k37_cases.json` är en hållout. Om Kevin ändrar matchningen: kör `o39_k37_live.py` igen (cirka 0,30 USD) och skriv nya fall om han har lagt in mina i sina tester.
- **A53 finns nu (Angela d846660):** omtest av appens del (bara valt prov skickas, avstängningen) passar Toby.
- **Concern till Architect (O39):** Mina svar läser förberedda svar i örat när läraren frågar.
- **Angela:** `ScribeKeyterms` ska räkna kodpunkter och normalisera till NFC (O16).
- **Kris (från gårdagen):** gör Kevin en krisrunda till, skriv O17g (kolla först överlapp mot `scripts/k21-crisis-cases.json`/`k34-holdout-cases.json`) och kör `python -I scripts/qa/o17b_live.py --cases=scripts/qa/o17g_cases.json --all --cap=0.10`. Tidigare överlämning finns i git (`git log -- docs/HANDOVER-OSCAR.md`).
