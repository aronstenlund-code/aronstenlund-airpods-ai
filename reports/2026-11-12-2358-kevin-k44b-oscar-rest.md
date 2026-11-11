# K44b: Oscars rester efter K44 (O52, prio 3) (Kevin, 2026-11-12 23:58)

Underlag: `reports/qa/2026-11-11-2328-oscar-o52-k44-namn-funktioner.md`. Oscar godkände K44 med 39/40 rätt i Standardläge och 12/12 i Provläge. Klockan och O53 är också rättade enligt honom.

## Ändringar (`Shared/capabilities.json` och kopian i `_shared/`, driftsatt i `9e0e85b`)
1. **Morgonrapport om sömn:** frågan besvaras nu från listan: "Ja. Tryck Sov på kvällen, så får du en morgonrapport när du vaknar."
   - Det nya fältet `model: true` markerar de funktioner där modellen själv utför en konkret begäran: frågor, träning, översättning, webb, socialt, intervju och förhör. Bara de lämnas över till modellen när frågan innehåller "ge mig …".
   - Sömn och de andra funktionerna besvaras alltid från listan.
2. **"Styra Spotify och byta låt"** ger nu "Det kommer snart … I dag kan jag öppna musik åt dig: säg Lumen, spela lugn pluggmusik."
   - Det nya fältet `instead` anger vad Earmind erbjuder i stället medan funktionen kommer.
   - Spotify-raden står nu före musikraden, och den första raden som matchar vinner.
   - "Kan du öppna Spotify" går fortfarande till musik.
3. **Skiljetecken:** inget "?." längre. Ett exempel som slutar med "?" eller "!" får ingen punkt efter sig.

## Tester
- `deno task test`: **506 gröna**. `check` är ren.
- **Live:** alla tre fallen ger rätt svar, och "kan du öppna spotify" ger fortfarande ja.

## Till Angela
`capabilities.json` har två nya fält, `model` och `instead`, och ordningen på raderna har ändrats. Id:na är desamma som förut.

## Till Aron
Inget nytt.
