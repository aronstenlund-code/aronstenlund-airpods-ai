# empty_answer efter webbsökning, orsaken hittad (Kevin, 2026-11-14 15:10)

Punkten är från Toby 1, T17b (`reports/apptest/2026-11-14-1505-toby1-t17b.md`). Där gav 4 av 20 webbfrågor `empty_answer`: Sverige, Norge, Finlands president och statsministern, plus Grönland i den andra körningen.

## Vad loggen `empty_final` visade (verifierat i loggen, 13:25–13:34 UTC)
- **Svaret efter sökningen:** modellen skrev 226–378 tokens, men bara 1–18 tecken nådde svarsfiltren. `raw` var 1 eller 18.
- **Det extra försöket:** 0 tecken nådde filtren.
- **Filtren tog alltså inget.** Texten försvann före dem.

## Orsak (verifierad i test)
- **Tvånivåläget.** Appen skickar `two_level`. Där är texten före `[[MER]]` det korta svaret som läses upp, och resten kommer som `more_delta`.
- **Felet efter en webbsökning:** svaret började direkt med `[[MER]]`. Då var det korta svaret tomt, och allt hamnade i "mer". `raw` = 1 var radbrytningen.
- **Felet i det extra försöket:** tvånivålägets tillstånd (`inMore` och `shortFinished`) nollställdes inte mellan försöken. Därför gick också det sista försökets text till "mer", och `raw` blev 0.

Min förra rättning (`cb92e6d`) tog bort webbprompten i det extra försöket, men det var inte felet.

## Rättat
- **Tomt kort svar:** ett `[[MER]]` som kommer innan någon kort text har skrivits tas bort, och texten efter blir det korta svaret.
- **Omförsök:** tvånivålägets tillstånd nollställs vid varje omförsök.
- **Test:** `k16_test.ts` provar `two_level`, sedan sök, sedan ett svar som börjar med `[[MER]]`. Svaret läses upp utan markören.

## Live (verifierat live, efter driftsättningen 1646785)
- **Tobys fem frågor:** `two_level`, med och utan Provläge, 4 gånger var, gav **20/20 svar**. 17 av dem gjordes med webbsökning.
- **Loggen:** inga `empty_retry` eller `empty_final` efter driftsättningen.
- **Kvar att visa:** att det håller i appen. Toby bör köra om T17 när Scribe-kvoten är påfylld (Till Aron #16).

## Tester och kostnad
- **Tester:** 600 gröna, och `check` är ren.
- **Kostnad Claude:** cirka 0,06 USD för 20 frågor med webbsökning.
- **Kostnad ElevenLabs:** 0 tecken.
