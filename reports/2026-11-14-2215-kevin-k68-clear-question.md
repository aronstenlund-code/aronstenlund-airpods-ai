# K68: en tydlig fråga är aldrig "not a question" i Standardläget (Kevin, 2026-11-14 22:15)

## Kort
- **Klart och verifierat live** (aac0d26).
- **Regel:** i Standardläget (`mode: "auto"`) är en mening som börjar med ett frågeord och slutar med "?" alltid en fråga.
  - Det räcker med ett frågeord: vad, vem, vilken, hur, när, var, varför, vart, varifrån eller what/who/which/how/when/where/why, gärna efter "och", "men", "så" eller "okej".
  - Meningen måste ha minst tre ord.
  - En sådan mening går den direkta vägen, som när man trycker för att fråga, utan klassningen som avgör om det är en fråga. Därför blir bedömningen densamma varje gång.

## Live med testkonto (`scripts/k68-live-check.py`)
| Transkript | Resultat |
|---|---|
| "Hur länge har hallar funnits?" (Tobys T25 w43) | besvarad **5/5** |
| "Vad betyder inflation?" | besvarad 2/2 |
| "Varför är himlen blå?" | besvarad 2/2 |
| "hur länge har han funnits" (utan "?") | tyst 2/2, som förut |
| "Jag tror det regnar i morgon." | tyst 2/2 |

- **Varför bedömningen varierade:** modellen avgjorde själv om en felhörd mening var en fråga. Samma mening gav ibland "not a question" (T25) och ibland ett svar (T17c).
- **Kostnad Claude:** cirka 0,01 USD.
- **Kostnad ElevenLabs:** 0, eftersom `/answer` aldrig anropar ElevenLabs.

## Tester
- 617 gröna, `check` ren.
- Nytt test: K68 i `answer/k16_test.ts` med regeln och samma fråga tre gånger.

## Risker
- **En överhörd fråga med "?" besvaras.** Om Scribe skriver ett frågetecken efter en fråga som klasskamrater ställer varandra, svarar appen nu i Standardläget. Det följer Deangelos regel. Det är också det läget är till för: att höra frågor och svara.
- **En felhörd fråga besvaras som den hördes.** "hallar" besvarades som hallar, inte hajar. Det kan servern inte veta.
- **Fynd 9b** (nästa mening efter "Hej, Lumen.") är Angelas del. Med den här regeln beror w10 inte längre på servern när meningen har ett frågeord och "?".

## Nästa
- **Toby:** T17 igen, när det passar.
- **Kevin:** väntar på kö.
