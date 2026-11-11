# Stående uppgift, omgång 15: en avklippt fråga i Auto fylldes i från förra svaret (Tobys T14) (Kevin, 2026-11-11 17:46)

Fynd: Tobys T14 fynd 4 (`reports/apptest/2026-11-11-1725-toby-t14-omtest-a67-a68.md`):
- "Hur många invånare har …" (resten, "Sverige ungefär?", sades medan mikrofonen var stängd) fick svaret "Canberra har ungefär fyrahundratusen invånare". Ämnet kom från förra frågan.
- I T12 och T13 sa servern "not a question" om den första halvan.
- **Troligen orsakat av min omgång 5**, där förra svaret får fylla i ett ämne som "saknas".

**Kostnad:** cirka 0,01 USD. ElevenLabs: 0.

## Ändring (`answer/handler.ts` `isCutOff`)
- I **Auto** räknas en fråga som slutar på ett ord som kräver en fortsättning, och som saknar "?", som avklippt: "har", "är", "mellan", "och", "som", "att", "en", "ett", "vilken" … Det ger tystnad (`is_question: false`, `done.cut_off: true`) utan modellanrop, så att appen väntar på resten (A21/A63).
- Prepositioner räknas inte, eftersom svenska frågor ofta slutar på en ("vad ska jag plugga på", "vad handlar boken om").
- **Provläge påverkas inte.** Där ska en halv fråga besvaras utifrån sina egna ord (D87-typen "half", till exempel "vad är skillnaden mellan riksdag och"). Fyra bankfall skulle annars ha blivit tysta.
- Inga fall i live-evalen påverkas (0 av 388 turer).

## Live (Auto, förra svaret om Canberra, driftsatt `4eb8755`)
| Fragment | Förut | Nu |
|---|---|---|
| "Hur många invånare har" | "Canberra har cirka …" (2/2) | **tyst (2/2)** |
| "Vilka är de största?" | svar | svar (städer i Australien) |
| "Och hur många bor där?" | svar | svar |
| "Vad är skillnaden mellan ett virus" | svar | svar. Det slutar på ett substantiv, så det går inte att känna igen som avklippt, men svaret om virus och bakterier är rimligt |

## Tester
`deno task test`: **479 gröna** (nya i `answer/k_standing7_test.ts`, även att Provläge fortfarande svarar på en halv fråga). `deno task check` är ren.
