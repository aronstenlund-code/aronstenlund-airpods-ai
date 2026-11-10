# A47 – "Lägg till prov" med snabbformen (Angela, 2026-11-10)

Det här är en stående uppgift enligt `docs/PLAN.md` 2b och har en egen punkt i kön. Underlaget är Kellys Ke14 och fynd 6 i Ke18
(`reports/2026-11-10-1249-kelly-granskning-a30-ke18.md`): "Lägg till prov" hade fortfarande 19 val. **Ändringen är kod,
och den är bara byggd i CI. Den är inte provad på telefon och inte fotad än.**

## Vad som gjordes
"Lägg till prov" från Start använder nu samma snabbform som första starten:

| | Första starten | Lägg till prov från Start |
|---|---|---|
| Rubrik | "Har du prov snart?" | "Lägg till prov" |
| Rösten | Lumen frågar högt direkt, eftersom den redan lyssnar | Knappen "Säg det i stället" (mikrofonen startar aldrig av sig själv) |
| Formuläret | Bakom "Skriv i stället" | Syns direkt |
| Knappen längst ner | "Inte nu" | "Avbryt" |

**Formuläret:**
- ett område (Matte, NO, SO, Språk, Annat) med ett valfritt delämne;
- datum och årskurs;
- ett nytt, valfritt fält: **"Vad handlar provet om?"**. Det behövs för studieplanen (A19) och förhöret, så snabbformen
  kan inte förlora det.

Hela formuläret finns kvar, men bara för att **ändra** ett prov ("Ändra" på provkortet, A42).

Med rösten från Start frågar Lumen: "Vilket prov? Säg ämnet och när det är." Svaret går samma väg som i A33.

## Tester
Inga nya enhetstester, eftersom det här är vy-logik. Svarets tolkning testas i A33Tests. Kelly granskar med scenen
`addExam`, som nu visar snabbformen.

## CI
Grönt i CI: iOS build 42833839914 (`eab30d1`). Bygget för enhet räknar varningar som fel, och alla LumenTests är gröna.
