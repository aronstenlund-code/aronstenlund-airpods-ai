# empty_answer efter webbsökning, "hur många bor i Sverige" (Kevin, 2026-11-14 13:48)

Punkten är från Toby 1 (T17 43589503926, `reports/apptest/2026-11-14-1335-toby1-t19-t16-t17.md`).

## Vad loggen visar (11:44 UTC, verifierat i loggen)
- **Förloppet:** frågan markerades för webbsökning (`search_marked`). Svaret efter sökningen blev tomt, och då gjorde K59:s extra försök (`empty_retry`, attempt 1, searched true) ett nytt anrop. Det blev också tomt, och appen fick `empty_answer` efter 12,1 s.
- **Anropet:** Sonnet, persona tutor, 23 156 tokens in.
- **Försök att återskapa:** 8 livekörningar av "hur många bor i Sverige", med och utan Provläge, gav alla svar med sökning. Felet är inte återskapat.

## Orsak (sannolik, **otestad antagelse** för Tobys exakta anrop)
- Det extra försöket fick fortfarande webbprompten. Den kräver ett svar ur källorna med en "källa:"-rad.
- Efterbehandlingen gick också i webbläge.
- Utan sökverktyg och utan källor kunde modellen inte svara enligt de reglerna, så det blev tomt igen.

## Rättat
- **Det extra försöket är nu ett vanligt svar:** grundprompten utan webbprompt, inga verktyg, efterbehandling utan webbläge, och anteckningen "svara med vad du vet i en eller två meningar, 'cirka' för tal".
- **Test:** `k16_test.ts` provar sök, sedan tomt, sedan sista försöket utan webbverktyg och webbprompt, som läses upp.
- **Ny diagnos i loggen:** `empty_retry` och den nya `empty_final` loggar antalet tecken kvar efter varje filtergrupp: rå text, taggar, källor, engelska, metameningar, första raden och ut. De loggar också `silent`, `dup` och `q_only`. Aldrig text. Händer det igen syns det i loggen vilket filter som tog bort svaret.
- **Tester:** 595 gröna. `check` är ren.

## Nästa
- **Toby:** kör om T17. Kommer `empty_answer` igen visar loggraden `empty_final` vilket filter som tog bort svaret, och då rättar jag det filtret.

**Kostnad:** Claude cirka 0,01 USD. ElevenLabs 0.
