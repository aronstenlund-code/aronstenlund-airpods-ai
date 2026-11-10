# Oscar O30: Ekofiltret (D82), offline

Datum: 2026-11-10, 11:06–11:08
Uppgift: stående uppgift (PLAN 2b).
- **Hur filtret fungerar:** i Provläge och Auto tas fyra eller fler ord i rad som upprepar förra svaret bort innan modellen ser frasen. Är inget kvar blir det tystnad (`answer/echo.ts`, `stripEcho`).
- **Risken:** en elev som citerar svaret för att fråga om det, eller upprepar det för att kontrollera, förlorar sin fråga.
- **Skript:** `scripts/qa/o30_echo_offline.mjs`, som kör den driftsatta filen. Kostnad: 0 USD.
- **Rådata:** `reports/qa/data/2026-11-10-1107-o30-echo.json`

**Verified in code.**

## Resultat: 8/12
**Riktigt eko tas bort (4/4):** hela svaret upprepat, "cellens kraftverk och gör energi av socker" och Arons fall från D82.
- Brus som "gånger med fem" (hörfel för "gångrar") och "Gud- ehm" blir kvar. Därför beror det på modellen om den svarar på bruset.

**Följdfrågor som förlorar innehållet (4 av 8):**
| Förra svaret (kort) | Eleven säger | Modellen får |
|---|---|---|
| "… kemisk energi i form av glukos." | "vad menar du med i form av glukos" | "vad menar du med" |
| "Fotosyntesen omvandlar ljusenergi till kemisk energi …" | "så fotosyntesen omvandlar ljusenergi till kemisk energi?" (kontrollfråga) | "så" |
| "… gör energi av socker och syre." | "vad betyder gör energi av socker och syre" | "vad betyder" |
| "… när Tyskland anföll Polen." | "vänta, när Tyskland anföll Polen, vad hände sen" | "vänta, vad hände sen" |

Följdfrågor som klarar sig, eftersom de inte upprepar fyra ord i rad: "varför kallas mitokondrien för cellens kraftverk", "började andra världskriget den första september eller den tredje", "varför lägger man till tio" och "kan du säga det igen fast enklare".

## Till Kevin
- Ta inte bort ekot när det som blir kvar är början på en fråga som behöver ett objekt. Exempel: "vad menar du med", "vad betyder", "så …?", "vad hände sen", "varför", "hur", eller en rest som slutar på en preposition.
- Låt i stället modellen se hela frasen, med det upprepade märkt. Exempel: `<fragment>vad menar du med <echo>i form av glukos</echo></fragment>`, plus regeln "ett eko i slutet av ett svar besvaras inte, ett citat i en fråga är en del av frågan".
- **Bättre på sikt (Angela):** appen vet när uppläsningen slutade. Ett eko kommer under uppläsningen eller strax efter den (cirka 1,5 s). Det som sägs senare är eleven.
- Lägg de 12 fallen i testerna: `node scripts/qa/o30_echo_offline.mjs`.

## Kostnad
0 USD.
