# O98 (D259, K119, K120): lanseringsveckan och compress, Oscar (moln)

**Resultat:** alla tre delarna stämmer. Del 1 och 3 är **verifierade live**. Del 2 är **verifierad i test**. Inga fynd.
- Livekörning: Actions 45776631304, 07:37 UTC, main 65e7e281, efter Kevins deploy 372 (grön). Resultat **4/4**.
- 0 ElevenLabs, 0 Claude, inga riktiga köp. Bara testkonton.

| Del | Vad | Resultat |
|---|---|---|
| 1a | `GET /purchase` utan inloggning och utan nyckel | 200 `{"launch_offer": null}`, `cache-control: public, max-age=60` (**live**) |
| 1b | samma med `Origin: https://earmind.vercel.app` | 200, `null`, `access-control-allow-origin` = sajten (**live**) |
| 2 live | `verify` med falsk kedja (Kevins testrot), fel signatur, skräp | 422 `purchase_invalid` (`root`, `root`, `format`); kontot 1 500 före och efter (**live**) |
| 2 test | lanseringspack i och utanför veckan, ordinarie pack | 6/6 egna fall (`scripts/qa/o98_launch_test.ts`) + Kevins `k119_test.ts` 5/5 och `handler_test.ts` 12/12 (**test**) |
| 3 | `/exam compress` med `lang` och `x-earmind-lang` sv resp. en | 503 `provider_quota`; sv "EarMind är nere en stund. Försök igen senare.", en "EarMind is down for a moment. Try again later."; `used` 0 före och efter (**live**) |

## Del 2: varför test och inte live
Servern kontrollerar Apples signatur (bara Apples rot G3) innan den läser produkten och veckan. Utan ett riktigt köp kommer inget live-anrop fram till lanseringsregeln. Live visar bara att falska köp fortfarande nekas.

Mina egna fall, med falsk kedja som i Kevins tester:
1. `.100`, `.500` och `.2000.launch` ger 100, 1 000 (antal 2) och 6 000 (antal 3), alltså samma som ordinarie gånger antal.
2. Ordinarie `credits.500` ger 500 före, under och efter veckan, och när ingen vecka är satt.
3. Gränserna:
   - köp exakt vid start och exakt vid slut + 1 dygn godtas;
   - 1 ms före start och 1 ms efter slut + 1 dygn ger 422 `launch_offer_over`;
   - ett nekat köp skriver ingen rad i kontoboken.
4. Om inställningen inte går att läsa (databasfel) nekas lanseringspacket, medan ordinarie pack går igenom.
5. Ett lanseringsköp som redan krediterats på ett konto ger 409 `purchase_other_account` på ett annat konto efter veckan. Återställningsundantaget släpper alltså inte igenom det.
6. Med Apples rot som enda rot, som i drift, nekas den falska kedjan med 422 `purchase_invalid` också för `.launch`.

Två andra testfiler i purchase, `attest_test.ts` och `rewards_test.ts`, ger "NotSupportedError: Not implemented" i min lokala deno. Det är WebCrypto i min miljö. De rör inte K119, och Kevin har 853/853 i CI.

## Del 3: krediter
Inga krediter dras. Det stämmer med Kevins K120-rapport: användarkrediterna gäller ljud och dras när ljudet sparas (K90). Komprimera loggar bara modellkostnaden (`exam-compress`). Assignmentens "krediter dras för modellanropet" ska alltså läsas som "räknas som övriga åtgärder", och övriga /exam-åtgärder drar inte heller.

## Inte prövat
- Ett riktigt köp av `.launch` i sandlåda. Det kräver en telefon och App Store Connect.
- Att veckan startar och syns. Det skulle kräva att jag skriver i `drill_settings` live, och det gör inte QA.
- Komprimeringens kvalitet (längd och språk) med en riktig modell. Det görs när krediterna är påfyllda.
