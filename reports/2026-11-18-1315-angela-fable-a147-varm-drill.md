# A147 (D230): appen väcker /drill när den öppnas (Angela Fable, moln)

Klart 2026-11-18 13:15. **Verifierat i CI: iOS build 44297509589 grön på min gren (enhetsbygge, varningar som fel,
LumenTests). Appen har inte kört anropet mot servern, och inget är provat på enhet.** 0 ElevenLabs.

## Vad som är byggt
- När appen startar och varje gång den kommer tillbaka till förgrunden skickar den `{"action":"warm"}` till `/drill`,
  utan token och utan kontouppgifter. Servern svarar 204 och läser inget konto (Kevins K102).
- **Högst en gång per 2 minuter.** Appen väntar aldrig på svaret, och ett fel (också Kevins 429) märks inte.
- Syftet är att användarens första Spela inte ska vänta på serverns kalla start (7–11 s enligt Oscars O84).
- Inget skickas i låtsasläget (testläget utan server).

## Teknik
`DrillCloudSyncing.warm()` (tomt i låtsasmoln), `DrillCloudClient.warm()`, `RepetitionModel.warmServer()` anropas i
`watchForeground()` (appens start) och `appBecameActive()`. Klockan går att sätta i test (`model.clock`).

## Test
`LumenTests/A136StyleVoicePaceTests.swift`: två gånger direkt efter varandra och efter 119 s väcker en gång; efter
121 s väcker det igen.

## Otestat (antaganden)
- Att värmningen faktiskt kortar första Spela har jag inte mätt; det får Kevin eller Oscar mäta mot servern.
- Anropet skickas med appens publika nyckel i `apikey` och utan `Authorization`. Kevin skriver att funktionen tar emot
  det utan token; inte provat från appen.
