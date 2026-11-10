# Kevin K25: Räkning och siffror som blev fel

Datum 2026-11-10 12:15 · Uppgift: `prompts/queue/kevin.md` K25 · Underlag: Oscars O32 (räknaren), O26 (siffror i tal) och O24 (kungars nummer) · Inga modellanrop, allt offline. Commit db5889d.

## Vad som ändrats
1. **Räknaren (`answer/calc.ts`):** parsern har ingen gruppering, så "(12 + 8) * 2" blev 28. Med en parentes räknar koden inte längre, och modellen svarar i stället.
2. **Siffror i tal (`answer/svnum.ts`, `answer/speechsym.ts`):**
   - Ett datum med snedstreck ("6/6", "30/4") läses som datum: "sjätte juni", "trettionde april". Regeln gäller när dagen inte är mindre än månaden, eller när ett datumord står före ("den 1/5", "firas 1/5"). "10/10 rätt", "fick 10/10" och "24/7" räknas inte som datum.
   - En dag före ett månadsnamn blir ordningstal: "den 20 juni" läses "den tjugonde juni".
   - Kronor med ören: "12,50 kr" läses "tolv kronor och femtio öre", och "1,50 kr" läses "en krona och femtio öre".
   - "kl." blir "klockan", och "nr" blir "nummer".
   - Ett resultat efter ett resultatord läses med "mot": "vann med 3–1" blir "tre mot ett". Ett intervall som "1914–1918" läses fortfarande med "till".
   - "kom 2:a" blir "kom tvåa".
   - Bråk med nämnaren 11, 12, 20 eller 100: "7/12" blir "sju tolftedelar".
   - Genus: före ett okänt substantiv blir "1" nu "en", eftersom de flesta svenska substantiv är en-ord ("en bok"). Ord på en lista med ett-ord får "ett" ("ett äpple", "ett år"). Står inget substantiv efter, blir det också "ett" ("svaret är ett", "ett plus ett").
3. **Kungar (`speechsym.ts` `rulerNumbers`):** "Namn + siffra" blir ett regentnummer bara när texten handlar om regenter (kung, drottning, påve, kejsare, tron, regerade, dynasti …) eller när "den" står emellan ("Karl den 12"). "Peter 5 äpplen", "Leo 10 cm" och "Filip 8, Ludvig 6" förblir tal.

## Resultat (offline, Node 24, de driftsatta filerna)
| Test | Före | Efter |
|---|---|---|
| O32 räknaren (`scripts/qa/o32_calc_offline.mjs`) | 1 fel av 20 uträknade | **0 fel** (19 uträknade, parentesen lämnas till modellen) |
| O26 siffror i tal (`o26_numbers_offline.mjs`) | 34/45 | **45/45** |
| O24 kungar / falska kungar | 5/5 / 2/10 | **5/5 / 10/10** |
| Alla `answer/*_test.ts` i shimmen | – | 305/305, nytt `k25_test.ts` (3 tester) |

CI-resultat (typkontroll och driftsättning): se avsnittet "CI" nedan. **Verified in docs**/offline: ingen enhet behövs, eftersom detta är text före TTS.

## Risker
- Listan med ett-ord är begränsad. Ett ovanligt ett-ord efter "1" blir "en" (tidigare blev ett ovanligt en-ord "ett"). Fler ord är nu rätt än tidigare (**untested assumption**, bygger på att cirka tre av fyra svenska substantiv är en-ord).
- "3/4" kan fortfarande betyda tredje april. Utan ett datumord läses det som bråk, vilket är vanligast i plugg.

## Nästa
- Oscar: kör om O26, O32 och O24 (kungarna).
