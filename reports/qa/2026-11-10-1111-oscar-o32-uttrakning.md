# Oscar O32: Tal som räknas ut i kod (D46, calc.ts), offline

Datum: 2026-11-10, 11:09–11:11
Uppgift: stående uppgift (PLAN 2b).
- **Varför det är viktigt:** när koden räknar ut ett tal läses resultatet upp utan modell (`spokenComputed`, historikrättelsen 2026-11-08). Ett fel sägs alltså med full säkerhet.
- **Skript:** `scripts/qa/o32_calc_offline.mjs`. Det kör den driftsatta `answer/calc.ts` (`computeFragment`) med klockan låst till 2026-11-10 11:00. Kostnad: 0 USD.
- **Rådata:** `reports/qa/data/2026-11-10-1109-o32-calc.json`

**Verified in code.**

## Resultat
- Koden räknade ut 20 av 30 fall, och 19 av dem var rätt.
- De 10 som lämnas till modellen ger inget fel i koden: "499 med 20 procent rabatt", "minus fem plus tre", "hälften av 37", "3/4 av 60", "en tredjedel av nittio", "moms 25 procent på 800", "1,5 miljoner gånger 2", "18 av 24 rätt, hur många procent", "5 procent av 1 000 000" och veckodagsfrågan.

**Rätt (urval):**
- "17 gånger 24 = 408" och "270 gånger 270 = 72 900";
- "roten ur 144" och "2 upphöjt till 10";
- "12 + 8 × 2 = 28" (räkneordningen stämmer) och "0,1 + 0,2 = 0,3";
- "100 °F = 37,8 °C", "5 miles = 8,05 km" och "1 kg = 2,2 pund";
- "44 dagar till julafton" (torsdag 24 december 2026).

## BUGG: parenteser tas bort, och svaret blir fel
| Inmatning | Kod räknar | Rätt |
|---|---|---|
| "vad är (12 + 8) * 2" | 12 + 8 × 2 = **28**, uppläst "12 plus 8 gånger 2 är 28" | 40 |
| "2*(5-1)" | 2 × 5 − 1 = **9** | 8 |
| "vad är 2 gånger (5 minus 1)" | **9** | 8 |
| "(10-4)/2" | 10 − 4 ÷ 2 = **8** | 3 |
| "vad är 100/(2+3)" | 100 ÷ 2 + 3 = **53** | 20 |
| "(3+4)^2", "-(5+5)" | ingen uträkning (går till modellen) | 49, −10 |

**Var det spelar roll:**
- textläget i appen;
- demosidan, där besökare skriver;
- Provläge, när eleven läser upp en uppgift från boken som innehåller parenteser.

Talat språk har sällan parenteser. Scribe skriver dem inte heller, men det skriver "gånger" och siffror.

## Till Kevin
- **Rätta först:** `tokenize` i `calc.ts` ska antingen tolka parenteser (en enkel rekursiv tolkare) eller **returnera null när det finns en parentes**, så att modellen räknar. Att returnera null är det minsta ingreppet och kan aldrig ge fel tal.
- Fall som gärna får räknas i kod: "X procent rabatt på Y", "hälften av", "en tredjedel av", "N av M rätt i procent", "moms 25 procent på" och tal med tusentalsmellanslag ("1 000 000").
- Lägg de 36 fallen i testerna: `node scripts/qa/o32_calc_offline.mjs`. Se också de sex parentesfallen i rapporten.

## Kostnad
0 USD.
