# Tobys fynd "Spela in svaret nås inte" och Kellys Ke64b N1–N3 (Angela Fable, moln)

2026-11-15 15:00. **Inget är provat på telefon. Inga ElevenLabs-tester (D180).**

## 1. Mina svar → Spela in: "Spela in svaret" och Avbryt nåddes inte (Toby, T24-omtest 09:05)
**Orsaken ligger i testet, inte i vyn. Ingen kod i vyn är ändrad.**

- `MyAnswerRecordView` har redan huvudknappen i `safeAreaInset(edge: .bottom)` (`MainActionBar`, D160). Ingen detent,
  ingen egen höjd på bladet och ingen ScrollView utan inset. *Verifierat i koden.*
- **Sedd på bild** (Fable screens 43717187444, 43717189933, 43717192108; scenerna myRecordEmpty, myRecordQuestion,
  myRecording, myRecorded): knappen ligger fast längst ner på iPhone 17 Pro, iPhone SE och iPhone SE med största
  text, i alla fyra lägena. Avbryt syns uppe till vänster. `reports/2026-11-15-spela-in-bilder/`. Simulatorn, inte enhet.
- **Vad testet gör** (`AppTests/E2E/Screens/FullFlowTests.swift`, `recordOwnAnswer`):
  1. Det trycker **Välj ur provet**. Då öppnas ett blad med provets frågor ovanpå Spela in.
  2. Det väljer ingen fråga i bladet, utan letar direkt efter **Spela in svaret**. Knappen finns, men ligger under
     bladet och går inte att trycka. Sex svep skrollar bara frågelistan i bladet.
  3. Sedan letar det efter **Avbryt** och hittar först Spela in-skärmens Avbryt, som också ligger under bladet.
- Det stämmer med Tobys rad: "utanför skärmen efter 6 svep, inte tryckbar" och "samma sak med Avbryt i det bladet".
  **Inte kört:** jag har inte kört om testet med ändringen, det är Tobys fil. *Untested assumption* tills han har kört.
- **Till Toby:** efter "Välj ur provet", tryck på en fråga i bladet (första raden) innan "Spela in svaret". Utan en
  fråga är knappen dessutom grå med "Välj eller skriv frågan först." under.

## 2. Kellys Ke64b (`reports/2026-11-15-1353-kelly-ke64b-a107.md`)
| Fynd | Rättat | Sedd på bild |
|---|---|---|
| N1 kvoten räknas vid Starta prov | Under knappen för ett ostartat prov: "Räknas som 2 av dina 12 frågor kvar." Räcker kvoten inte: grå knapp och "Provet har 2 frågor och du har 1 kvar den här månaden. Ta bort frågor eller vänta till den 1 december." | ja (repUnstarted, repUnstartedTooMany) |
| N2 raden om ljudet två gånger | Under frågorna står bara "Tryck på en fråga för att ändra frågan eller svaret." | ja |
| N3 samma ord överallt | "Gör ljudet …" i spelaren, på knappen och i läsläget | ja (17 Pro); SE-bilderna inte lästa |
| N4 Dela och Publicera före start | Hos Deangelo | – |

- För en text räknas kostnaden som en fråga per påbörjade 800 tecken, på telefonen. Servern kan räkna annorlunda
  efter städningen. *Untested assumption.*
- Provkortet på Start har ingen rad under knappen, så där står kostnaden inte. Räcker kvoten inte säger provets
  skärm det.

## Testresultat
- **iOS build 43716223776 grön** (min gren, med N1–N3): device-bygget, varningar som fel, LumenTests. *Verifierat i CI.*
- **iOS build 43716019269 grön på main** (cc5c10a, A107-vyerna och Ke64-fynden). *Verifierat i CI.*
- Bilder: `fable/screens-a107-17pro-2`, `fable/screens-a107-se-xxxl-2`, `fable/screens-spelain-17pro`,
  `fable/screens-spelain-se`, `fable/screens-spelain-se-xxxl`. Kontaktblad: `reports/2026-11-15-a107-bilder/ke64b-17pro-ljust.jpg`
  och `reports/2026-11-15-spela-in-bilder/`.

## Kvar
- Toby: rätta testets steg och kör om; A107-flödet och T28.
- Kelly: titta på N1–N3.
- V4 (Lägg till prov i Provläge → Nytt prov): inte gjord.
