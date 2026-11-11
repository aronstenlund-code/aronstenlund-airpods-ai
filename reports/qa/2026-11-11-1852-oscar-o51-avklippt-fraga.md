# Oscar O51: Oberoende test av Kevins omgång 15 (avklippt fråga i Auto blir tyst): REGRESSION

Datum: 2026-11-11, 18:49–18:52 (svensk tid)
Uppgift: stående uppgift (PLAN 2b). Kevins omgång 15 (`reports/2026-11-11-1746-kevin-standing15-cut-off.md`, driftsatt `4eb8755`) är den senaste klara K-punkten utan O-punkt. `isCutOff` (`answer/handler.ts:102`) gör en fråga i **Auto** tyst (`done.cut_off: true`, utan modellanrop) när den saknar "?" och slutar på något av orden "har hade är blir blev mellan och eller som att en ett min mitt mina din ditt dina sin sitt vilken vilket vilka än".

**Skript:**
- `scripts/qa/o51_cutoff_offline.mjs`: 30 nya fall, offline, 0 USD. Inga av dem finns i `k_standing7_test.ts`.
- `scripts/qa/o51b_cutoff_live.py`: 8 fall live i Auto, Haiku, cirka 0,01 USD.

**Rådata:** `reports/qa/data/2026-11-11-185105-o51.json` och `…-185159-o51b.json`. En första offlinekörning med tre felmärkta fall togs bort. Den var gratis, och fallen är rättade.

## REGRESSION (prio 1): hela frågor blir tysta i Standardläge
I svenska bisatser hamnar verbet sist. Därför slutar många **hela** frågor på "är", "blir" eller "har". Scribe skriver oftast inget "?".

| | Resultat |
|---|---|
| Riktigt avklippta frågor blir tysta (offline) | **14/18**. Missade: "vad är huvudstaden i", "när började det andra", "vilken är den största", "vad heter Sveriges" |
| **Hela frågor besvaras (offline)** | **2/12**. 10 blir tysta |
| **Live i Auto, med samma ord som en elev säger** | **6/8 tysta** (5 `cut_off` och 1 tyst av annat skäl) |

**Tysta live (verified live, `mode: auto`):**
- "**kan du säga vad klockan är**"
- "vad tror du att svaret är"
- "hur svårt tror du provet blir"
- "vad betyder ordet och"
- "hur gammal tror du att jag är"
- "när tror du att bussen kommer" (tyst utan `cut_off`. Modellen tolkade den som "ingen fråga", vilket är ett annat lager)

**Besvarade:** "Lumen, vet du vad klockan är" (den börjar med "vet", som inte finns i regelns lista över frågeord) och "kan du kolla hur varmt det blir i morgon" (slutar på "i morgon").

**Ytterligare tysta offline:** "vem tror du att mördaren är", "vad tror du det blir", "hur många katter tror du att hon har", "vad är skillnaden mellan som och att", "kan du ge exempel på en mening med som" och "vad heter det på engelska när man säger än".

**Rättning (till Kevin, prio 1):**
- Ta bort verben (`har hade är blir blev`) och `än` ur `DANGLING`.
- **Eller:** räkna dem som avklippta bara när det inte finns ett subjekt före verbet ("du", "jag", "det", "hon", "han", "vi", "ni", "de", "man", eller ett substantiv efter "att"). Då blir "hur många invånare har" avklippt, men "vad tror du att svaret är" blir det inte.
- Ord som eleven frågar *om* ("ordet och", "mellan som och att") ska aldrig räknas.
- Lägg mina 12 hela frågor som en hållout, alltså inte i testerna, så att omtestet blir oberoende.

## Till Aron (i kväll)
I Standardläge ger "kan du säga vad klockan är" och "vad tror du att …" just nu **tystnad**. Säg "Lumen, vad är klockan?" eller avsluta med en fråga som inte slutar på "är", "blir" eller "har", tills Kevin har rättat. Felet kom med Kevins ändring 17:46 (Tobys T14).

## Nästa
Omtest (`o51_cutoff_offline.mjs` och `o51b_cutoff_live.py`, cirka 0,01 USD) så fort Kevin har rättat. Sedan O50 när K41 är driftsatt.
