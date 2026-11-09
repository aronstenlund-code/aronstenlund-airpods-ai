# Kevin K2: D87 till målet (Provläge på Sonnet 5.5)

Datum 2026-11-09 · Uppgift: `prompts/queue/kevin.md` K2 · Föregående: överlämningen i K2 (steg 1–3, commits `15d0e1f`, `f684da0`, `c171a52`, `ddcbef2`).

## Kort
- **Målet ≥ 90 % "första svaret räcker" är nått:** hela banken (191 fall) med Sonnet 5.5 ger **91,6 %** (Opus-bedömare, rubrik v2). **verified live** (anrop mot driftsatt backend, commit `ff35fa2`, deploy-run 42646102235).
- Provläge går nu på **Sonnet 5.5** som standard (`DEFAULT_CONFIG.tutorModel`), D90. `TUTOR_MODEL` kan byta tillbaka till Haiku utan ny kod. Demon påverkas inte (den använder aldrig `tutorModel`).
- Priset: ungefär 21 gånger dyrare per svar (0,0079 mot 0,00038 USD) och 0,2–0,3 s längre till första ord.
- Inget är testat på telefon eller AirPods.

## Exit 4 (felsökning)
Det gick inte att återskapa. En provkörning med 2 fall och en ny `--tokens`-fil gick igenom direkt (exit 0), och båda jämförelserna och hela banken gick sedan igenom utan fel. Skriptet själv returnerar bara 0. Den troligaste orsaken till exit 4 var miljön (en lång förgrundskörning som avbröts) eller en misslyckad anonym inloggning. Inloggningen gav tidigare bara en traceback. **Åtgärd:** `signup()` i `scripts/provlage-eval.py` försöker nu igen 4 gånger med väntetid, och ger annars ett tydligt fel ("anonymous sign-in limit? reuse --tokens"). Jag körde allt i bakgrunden med en `--tokens`-fil i scratchpad, alltså 4 anonyma inloggningar totalt. **verified live**.

## Jämförelse på nuvarande kod (urval, var tredje fall, 64 fall)

| | Haiku 5.5 | Sonnet 5.5 |
|---|---|---|
| Första svaret räcker | **87,5 %** | **92,2 %** |
| Rätt / A-nivå / räcker / täcker | 90,6 / 93,8 / 95,3 / 79,7 % | 92,2 / 95,3 / 98,4 / 87,5 % |
| Naturligt (bedömare) | 64,1 % | 82,8 % |
| Längd i kod (≤ 6 meningar, ≤ 115 ord) | 67,2 % | 32,8 % |
| Ord p50 / p90 | 106 / 123 | 116 / 136 |
| Första text, server p50 / p90 | 939 / 1 249 ms | 1 183 / 1 574 ms |
| Första text, klient p50 | 1 297 ms | 1 388 ms |
| Kostnad per svar (med cachning) | 0,000376 USD | 0,008821 USD |
| Cacheträffar | 63 av 64 (4 270 token lästa) | 58 av 64 (4 270) |

Filer: `reports/eval/provlage-2026-11-09-haiku-k2b-sample.*`, `…-sonnet-k2b-sample.*`. Jämfört med omräkningen av gårdagens svar (Haiku 83,3 %, Sonnet 91,7 %) gav K2 steg 1–3 Haiku +4 punkter. Sonnet låg redan över 90.

**Val:** Sonnet. Det är den enda modellen över målet, och den är bättre på varje bedömningspunkt utom längd. Haikus missar är oftare sakfel ("Kungen undertecknar lagar", logaritmen som "invers till potensfunktionen", "Sweden" mitt i svensk text). Tiden till första ord ökar med ungefär 0,1 s på klienten och 0,25 s på servern, och det märks mindre än ett felaktigt svar. Kostnaden är det tunga: se Risker.

## Hela banken med vinnaren (Sonnet 5.5, 191 fall)

**Första svaret räcker: 91,6 %** (175 av 191, 0 fel och 0 tomma svar). Strikt (täcker även alla förväntade punkter): 78,0 %.

| rätt | A-nivå | räcker | täcker | naturligt | längd (kod) | ingen oönskad fråga (kod) | första text server p50 / p90 | klient p50 | kostnad per svar |
|---|---|---|---|---|---|---|---|---|---|
| 91,6 % | 96,3 % | 99,0 % | 84,3 % | 82,2 % | 36,1 % | 99,0 % | 1 154 / 1 570 ms | 1 476 ms | 0,0079 USD |

Per typ: exam 24/24, exam_soon 3/4, followup 30/32, half 9/10, mathlevel 11/12, misheard 18/23, short 6/6, term 74/80.
Grundskolan (Åk 6–9, 121 fall) 91,7 %, gymnasiet (70 fall) 91,4 %. A-nivå 95,0 respektive 98,6 %.
Fil: `reports/eval/provlage-2026-11-09-sonnet-k2-full.*`. Banken hade 191 fall, inte 179, eftersom K1.3 lade till 12 mattefall.

**De 16 missarna** är nästan alla små sakfel, som ett human-bedömt prov också hade gett avdrag för: "miljoner celler", "pepparfjärilen", Wienkongressen "samma år" som 1821, "noll upphöjt till noll", "sex delar" men bara fem uppräknade. Andra är felhörningar som går åt fel ämne: "perifera systemet" i Kemi blir nervsystemet i stället för periodiska systemet. Kodfelet i pl-184 ("blir 3x." uppläst som "tre gånger") är rättat efter körningen, se nedan.

## Ändrat i den här delen
- `answer/handler.ts`: `DEFAULT_CONFIG.tutorModel = claude-sonnet-5-5`, pris 2 / 10 USD per miljon token (loggas per svar som förut).
- `answer/speechsym.ts`: "3x" sägs "tre x" även när operatorn står i ord ("3x minus 7", "3x är lika med 21"), efter en potens eller parentes ("e^{3x}"), när texten eller de senaste 120 tecknen innehåller matteord ("ekvationen", "derivatan", "lös"), och när termen står sist i en mening ("… blir 3x."). "Ta tabletten 3x per dag" och "2x snabbare" är oförändrade ("gånger"). Unit-testat (`k7_test.ts`, lokalt under Node-shim: 228/228). Den sista regeln driftsätts med nästa push och var inte med i 191-körningen. **untested assumption** live.
- `scripts/provlage-eval.py`: omförsök vid inloggning.

## Risker och begränsningar
- **Kostnad:** 0,0079 USD per Provläge-svar. 50 frågor om dagen är cirka 0,40 USD per elev och dag, eller 12 USD i månaden. Max-organisationens nyckel har 100 USD i månaden, så det räcker för testfasen men inte för många användare. Vill Aron hellre ha Haiku (87,5 %) sätter han Supabase-hemligheten `TUTOR_MODEL` = `claude-haiku-5-5`, `TUTOR_PRICE_IN_PER_MTOK` = `0.10` och `TUTOR_PRICE_OUT_PER_MTOK` = `0.50` (Dashboard → Edge Functions → Secrets → Add). Ingen kod behövs.
- **Längd:** Sonnet håller längdgränsen i kod (≤ 6 meningar, ≤ 115 ord) i bara 36 % av svaren, p50 114 ord. Bedömaren räknar inte längden in i "räcker", och Oscar tyckte att den gamla gränsen var för sträng. Uppläst är 115–137 ord ungefär 45–55 s. Bör prövas på telefon.
- Bedömaren är en modell (Opus 5.5). Oscars granskning visade att den kan vara för sträng på detaljer, och 1–2 punkter är brus. Varje fall kördes bara en gång.
- Sonnets tidsvariation: server p90 1,57 s.
- Ingenting på telefon/AirPods.

## Kostnad för K2 i dag
Svar 2,09 USD (Haiku 0,02, Sonnet 0,56 + 1,50), bedömning 2,70 USD, totalt cirka 4,8 USD.

## Nästa
- K7 (Oscars O1-fynd), direkt efter detta. Dess nya fall i banken (`leveltalk`, `quote`, `logic`) mäts i K7:s körning.
- Den nattliga bankkörningen (`provlage-eval`) bör använda `--model sonnet` så att den mäter det som är driftsatt. Jag ändrar det i K7 om arbetsflödet har modellen hårdkodad.
