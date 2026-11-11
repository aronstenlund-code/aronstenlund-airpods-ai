# Stående uppgift, omgång 13: rättelser med egna ord via en liten modellkontroll (Oscars O47) (Kevin, 2026-11-11 15:38)

Fynd: Oscars O47 (`reports/qa/2026-11-11-1532-oscar-o47-rattelser-kommandon-nya.md`).
- Nya, oberoende formuleringar (O22b) ger rättelser **5/20** och appkommandon **4/10**, med 0 falska träffar.
- Ordlistor täcker bara de fraser författaren har skrivit.
- Oscar rekommenderar en liten modellkontroll när koden inte hittar något.

**Kostnad:** cirka 0,01 USD (70 Haiku-kontroller, 4 utdata-tokens var). ElevenLabs: 0.

## Gjort (`memory/handler.ts`)
- **Rättelser:** när koden (`detectCorrection`) inte känner igen ett kort yttrande (högst 15 ord) frågar `/memory` Haiku en gång: `shorter | longer | simpler | examples | careful | none`.
  - Bara exakt ett av de sex orden godtas, och vid osäkerhet ska svaret vara "none".
  - Allt annat (nonsens, "kanske kortare?", tomt, timeout på 3 s) räknas som ingen rättelse.
  - Svaret anger `by: "code" | "model"`.
  - Koden är kvar som snabbväg: ett känt yttrande anropar aldrig modellen.
- **Appkommandon** får ingen modellkontroll. De avgörs i `/answer`, och en extra kontroll skulle göra varje vanligt svar långsammare. De är kvar i koden: 9/10 på O22 och 4/10 på O22b.

## Live mot `/memory` (driftsatt `915211e`, `f901141`), Oscars O22b som hållout (inte i mina tester)
| | Bara kod (O47) | Kod + modell, första versionen | Kod + modell, kategorierna bredare beskrivna |
|---|---|---|---|
| Rättelser | 5/20 | **14/20** | **18/20** |
| Vanliga meningar som blir rättelser (falska) | 0/15 | **0/15** | **0/15** |

- **Förbehåll:** den tredje kolumnen mättes på samma hållout efter en ändring i prompten. Jag använde inte Oscars fraser som exempel, bara allmänna beskrivningar, men mätningen är inte helt oberoende. Ett nytt varv med nya fraser (O22c) behövs.
- **Kvar:** "nej nej, det var helt galet" och "är du säker? det låter fel" (noggrannare).

## Tester
`deno task test`: **477 gröna** (nytt i `memory/handler_test.ts`: modellen anropas bara för okända korta yttranden, och "none"/nonsens/tomt ändrar inget). `deno task check` är ren.
