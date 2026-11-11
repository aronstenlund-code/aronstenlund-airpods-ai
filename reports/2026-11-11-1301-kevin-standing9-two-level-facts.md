# Stående uppgift, omgång 9: "ja" efter ett faktasvar i Standardläge (Kevin, 2026-11-11 13:01)

Fynd: Tobys T12 (`reports/apptest/2026-11-11-1300-toby-t12-omtest-a56.md` fynd 3), fråga till Kevin och Angela:
- "Ja" efter ett kort faktasvar i Frågor gav ett nytt anrop, och det tog 6,7 s till tal.
- T7:s krav är under 1 s.
- `done.more` (K13, D100) gavs bara i Provläge och för förklaringar.

**Kostnad:** cirka 0,01 USD (Haiku). ElevenLabs: 0.

## Beslut och ändring (`answer/handler.ts`)
- När appen skickar `two_level: true` i Standardläge (`auto`, tryck och prata, text) får även ett kort faktasvar det utvecklade svaret i förväg (`more_delta`, `done.more`).
- Det betyder att "ja" kan spelas direkt.
- Svaret är Haiku i Standardläge, så den utvecklade delen kostar nästan inget.
- Webbsvar (`need`), uträkningar och textbegäran är undantagna som förut.

## Live (driftsatt `95e7554`, `two_level: true`)
| Fråga | Kort (ord) | `done.more` (ord) |
|---|---|---|
| "Lumen, vad är huvudstaden i Kanada?" (auto) | 5 | 53 |
| "när började första världskriget" (tryck och prata) | 21 | 36 |
| "vad är fotosyntes" (tryck och prata) | 21 | 67 |
| "Lumen, varför är himlen blå?" (auto) | 39 | 163 |
| "Lumen, vem skrev Röda rummet?" (auto) | 9 | – (modellen skrev ingen `[[MER]]`) |
| "Lumen, hur många invånare har Sverige?" (auto) | 25 | – (webbsökning, undantagen) |

- Ingen markör lästes upp.
- 3 s från "Ja." till anropet är appens egen väntan (Angela, Tobys fynd 3).

## Till Angela
Spela `done.more` på "ja" eller "mer" även i Standardläge, när det finns.
