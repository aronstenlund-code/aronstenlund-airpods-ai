# Oscar O52: "Vad är klockan?" ger fel tid (prio 1) + omtest av O51s och O51 efter Kevins rättningar

Datum: 2026-11-11, 20:53–20:58 (svensk tid). Stående uppgift (PLAN 2b) och omtest.
**Kostnad:** cirka 0,12 USD (Haiku), 0 ElevenLabs.

## FEL (prio 1): Lumen säger fel klockslag i Standardläge
`scripts/qa/o52_clock_live.py`, rådata `reports/qa/data/2026-11-11-205730-o52-clock.json` (och 20:56-raderna i O51b-omkörningen):

| Klockan (Stockholm) | Fråga | Lumen sa |
|---|---|---|
| 20:53 | "kan du säga vad klockan är" | "Klockan är **tjugo över åtta** på kvällen." |
| 20:53 | "Lumen, vet du vad klockan är" | "Klockan är **tjugo över åtta** på kvällen, alltså **tjugo och femtiotre**" (säger emot sig själv) |
| 20:56 | "Lumen, vad är klockan" | "**tjugo över åtta** … det vill säga tjugo och femtiosex" |
| 20:56 | "kan du säga vad klockan är" | "**tjugo över nio**" |
| 20:57 | 5 formuleringar | **0/5 rätt**: "tjugo över nio" ×3, "tjugo över åtta", "tjugo över nio … nej, rätt tid: klockan är tjugo i tio" |

**Orsak:** modellen (Haiku) får tiden i prompten, men gör om "20:57" till vardagssvenska fel. Den läser minuterna som "tjugo över" och timmen som 8 eller 9. Det finns ingen kodväg för den lokala tiden, bara `zoneClock` för andra städer (`answer/timezone.ts`). O33 testade tidsfunktionerna i kod och fick 11/11, men den här frågan går aldrig dit. Samma fel syntes i O15 den 10 november ("07:20 när klockan var 07:58").

**Rättning (till Kevin, prio 1):**
- Svara på "vad är klockan", "hur mycket är klockan" och "vet du vad klockan är" i kod, med samma tid som prompten har, i formen "Klockan är tre minuter i nio" (fem över, kvart över, halv, fem i och så vidare).
- Det kostar inget modellanrop.
- Lägg in 5 nya formuleringar och 3 olika klockslag som tester.

## Omtest O51s: hela frågor tysta i Standardläge, **RÄTTAD**
Kevins `59bf5f6`: ett verb sist räknas bara som avklippt i en huvudsats utan subjekt. "än" och ord som eleven frågar om räknas aldrig.
- Offline (`o51_cutoff_offline.mjs`, `…-205311-o51s-omtest.json`):
  - **hela frågor 12/12 besvaras** (var 2/12);
  - avklippta 14/18 blir tysta (oförändrat).
- Live (`o51b_cutoff_live.py`, `…-205357-o51b.json`): **`cut_off` 0/8** (var 5/8).
  - "kan du säga vad klockan är", "vad betyder ordet och" och "hur gammal tror du att jag är" besvaras nu.
  - Fyra är fortfarande tysta, men av modellens eget "ingen fråga"-beslut i Auto, inte av den nya regeln: "vad tror du att svaret är", "hur svårt tror du provet blir", "kan du kolla hur varmt det blir i morgon" och "när tror du att bussen kommer". De saknar sammanhang, så tystnad i Auto är försvarbart.

## Omtest O51 (K42-resterna efter `cfa988b`, K42b)
`o51_k42_live.py --only name,length,complaint`, `…-205357-o51-k42-efter2.json`:

| | O51 (20:20) | **Nu** |
|---|---|---|
| Namnet | 9/10 | 9/10. "vad heter appen" ger nu Earmind, men "presentera dig" var tyst den här gången |
| Uttalad längd | 8/10 | **10/10** |
| Klagomål | 4/10 | **10/10**. Inga tysta och inga löften |

## Till Aron
Fråga inte Lumen vad klockan är i kväll. Svaret är oftast fel med en timme, eller fel på minuterna. Kevin har fått felet som prio 1.
