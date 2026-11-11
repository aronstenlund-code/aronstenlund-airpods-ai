# K42b: Oscars rester efter K42 (O51-omtestet) (Kevin, 2026-11-11 20:26)

Underlag: `reports/qa/2026-11-11-2020-oscar-o51-omtest-k42.md`.
- **Klart enligt Oscar:** fakta 20/20, korta ord 0/20 som kommando, "utveckla" 10/10.
- **Kvar (prio 2):** namn 9/10, längd 8/10, klagomål 4/10, och "utveckla det" med låg säkerhet.

## Ändringar (driftsatta i `cfa988b`)
1. **"Lumen, vad heter appen"** ger nu namnet. `NAME` fångar också "vad heter appen", "vad är appens namn", "vilken app är det här" och "what's your name".
2. **Längden räknas i ord, inte i tecken.** "Ungefär N ord" stoppas vid sista meningsslutet inom 1,15 N ord, och "högst N ord" inom N. Svaret skickas då mening för mening, så att ingen halv mening hinner läsas upp. Pythagoras med femtio ord gav 71 korta ord inom teckentaket. "Minst N", "utförligt" och meningar fungerar som förut.
3. **Klagomål:** fler former fångas i kod:
   - "varför sa/svarade/gjorde du samma sak, två gånger, på engelska, inget …";
   - "du är så dålig/seg/värdelös …" och "appen är buggig/seg/trasig …";
   - "du missförstod mig", "du förstår inte" och "sluta svara/prata/avbryta …".
   
   Ett klagomål som börjar med "Lumen" omfattas också. "Varför svarade du på engelska" får nu det ärliga svaret i stället för löftet "Jag ska svara på svenska".
   
   **Medvetet oförändrat:** "varför sa du att Vänern är störst" frågar om innehållet och går till modellen, eftersom den kan rätta sig.
4. **"utveckla det", "berätta mer", "säg mer" och "fortsätt då"** räknas som ensamma kommandoord (upp till 3 ord, `MORE_START`). Utan säkerhet eller med för kort tid blir det tystnad.

## Tester
- `deno task test`: **494 gröna**. Nya tester i `k42_test.ts`: ordtaket släpper bara hela meningar och stoppar inom taket, plus nya klagomålsformer och sådant som inte är klagomål. `check` är ren.
- **Live** (`cfa988b`, Auto, "Lumen, …"):

| Fråga | Resultat |
|---|---|
| "vad heter appen" | "Jag heter Earmind." |
| Pythagoras, femtio ord | **55 ord** (förut 71) |
| Max tjugo ord | **20** (förut 23) |
| Hundra ord | 107 |
| "du är så dålig", "appen är buggig", "varför svarade du på engelska" | Det ärliga svaret |
| "utveckla det" (säkerhet 0,45, 280 ms) | Tyst |

- Oscars skript har jag inte kört, eftersom de skriver i hans mapp.

## Till Oscar
Omtest av O51:s fyra rester.

## Till Aron
Inget nytt.
