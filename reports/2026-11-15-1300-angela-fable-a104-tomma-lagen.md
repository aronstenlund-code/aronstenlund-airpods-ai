# A104: tomma lägen och fellägen i repetitionsflödet (Angela Fable, moln)

2026-11-15 13:00. Påbörjad av den lokala Angela Fable (3b4f33b, 3d76e71, 9506c2e), avslutad av molnsessionen.
**Inget är provat på telefon. Inga ElevenLabs-tester (D180): scenerna använder förberett, tyst ljud.**

## Vad som gjordes
Varje läge där något saknas eller går fel har en kort förklaring och en väg framåt, med systemets egna delar
(`ContentUnavailableView`, raden under huvudknappen, avsnitt i listan). Inga tekniska ord.

| # | Läge | Var | Vad användaren ser | Väg framåt | Scen | Sedd på bild |
|---|---|---|---|---|---|---|
| 1 | Inget nät | Nytt prov | Rad överst: "Ingen internetanslutning. Du kan lägga till material nu och skapa frågorna när du är uppkopplad." Knappen grå med "Skapa frågor kräver internet." | Lägg till material nu, skapa senare | repNewOffline | ja, omtagen (se nedan) |
| 1 | Inget nät | Provets skärm | "Ingen internetanslutning. Dela och Publicera fungerar när du är uppkopplad." Starta prov fungerar (A103) | Starta prov | repExamOffline | ja, omtagen |
| 1 | Inget nät | Prov från din skola | Systemets tomläge "Ingen internetanslutning" | Försök igen | repSchoolsOffline | ja |
| 2 | Inga prov | Start | "Kom förberedd till provet" | Nytt prov, Hitta prov från din skola, Klistra in en länk | repHomeEmpty | ja |
| 2 | Inga prov | Prov från din skola | "Inga prov här än" | Publicera ditt nästa prov | repSchoolsEmpty | ja |
| 3 | Kvoten slut | Nytt prov | "Du har inga frågor kvar den här månaden. Nya frågor går att göra från den 1 december." Knappen grå | vänta, eller andras prov | repQuotaUsedUp | ja |
| 3 | Kvoten slut | Provets skärm | Samma mening | Hämta andras prov | repQuotaExam | ja |
| 3 | Kvoten slut | Prova på (hjälpen) | Knappen grå med "Inga frågor kvar den här månaden." | – | repHelpTryUsedUp | ja, omtagen |
| 4 | Ljudet kan inte göras | Start, provet, spelaren | "Ljudet kan inte göras just nu. Försök igen om en stund." i stället för en räknare som står still (A100) | Avsluta, eller starta det som finns | repSoundProblem, repHomeSoundProblem, repWaitingProblem | ja |
| 5 | Ljudet inte klart | Provets skärm | Knappen "Gör ljud …" med "Ljudet görs. Du kan starta när första frågan är klar." | väntar av sig själv | repSoundMaking | ja |
| 6 | Publicering misslyckas | Publicera prov | Felet står under knappen, bredvid knappen som försöker igen | Publicera prov igen | repPublishFailed | ja |
| 7 | Skolan hittas inte | Välj skola | "Ingen skola heter så. Sök på orten i stället." | sök på orten | repSchoolSearchNone | ja |
| 7 | Skolorna går inte att hämta | Välj skola | "Skolorna går inte att hämta" eller, utan nät, "Ingen internetanslutning" | Försök igen | repSchoolSearchFailed | ja, omtagen |
| 7 | Proven går inte att hämta | Prov från din skola | "Proven går inte att hämta. Försök igen om en stund." | Försök igen | repSchoolsFailed | ja |
| 8 | Kameran nekad | Nytt prov | "EarMind får inte använda kameran. Tillåt den i Inställningar, eller välj bilder ur bildbiblioteket." | Öppna Inställningar | ingen scen | **nej** |
| 9 | Tom import | Gör med ChatGPT | "Svaret har inte rätt form" och hur man kopierar rätt; tomt urklipp: "Det finns ingen text att klistra in. Kopiera svaret i ChatGPT först." | Klistra in igen | gptWrong | ja (formen); tomt urklipp nej |
| – | Materialet gick inte att läsa | Nytt prov | "Det gick inte att skapa frågorna. Försök igen." | Försök igen | repMakeError | ja |

## Molnsessionens del
- **Tobys T24 V2 och V2b:** inga larm "Publicerat." och "Publiceringen är borttagen." Raden Publicerat på provet säger
  det (`PublishViews.swift`).
- **Tobys T24 V1** (Publicera prov ser tryckbar ut med "Saknas: …" under): **inte återskapad.** På bilden `repPublish`
  är knappen grå med "Saknas: provdatum" under. Koden stänger knappen (`isDisabled`). Toby får titta igen.
- **Skolsökningen** skiljer inget nät ("Ingen internetanslutning", "Skolorna går att söka när du är uppkopplad.") från
  annat fel ("Skolorna går inte att hämta"). Förut visades symbolen för inget nät i båda fallen.
- **Två scener var trasiga på de första bilderna** (körning 43707813309):
  - `repNewOffline` och `repExamOffline` visade ingen rad om nätet. Simulatorns eget nät skrev över det förberedda
    läget. `stageOffline` håller nu sitt läge (bara i Debug, `RepetitionModel.swift`).
  - `repHelpTryUsedUp` var en tom sida med en varningstriangel. Scenen visar nu sidan direkt.
  - De två filerna är Angela Schrutes. Hennes session har slutat schemalägga, så jag gjorde ändringarna själv. De
    rör bara Debug och scenerna.
- **Eget bildflöde:** `.github/workflows/fable-screens.yml` tar samma bilder som Simulator screenshots, gör dem små
  (högst 1400 punkter, pngquant) och pushar dem till en egen gren. Molnsessionerna kan inte hämta artefakter
  (nätreglerna nekar `productionresultssa0.blob.core.windows.net`), men `git fetch` fungerar.

## Bilder
- Grenarna (PNG per scen, `light-<scen>.png` och `dark-<scen>.png`, `RUN.txt` säger körning och commit):
  - `fable/screens-a104-17pro` (iPhone 17 Pro, körning 43707813309, 091e3b9);
  - `fable/screens-a104-se-xxxl` (iPhone SE, största text, körning 43707815601, 091e3b9);
  - `fable/screens-a104-17pro-2` (de omtagna scenerna, körning 43710715096, 7028ac9).
- Kontaktblad: `reports/2026-11-15-a104-bilder/`.
- Hämta: `git fetch origin fable/screens-a104-17pro` och `git archive origin/fable/screens-a104-17pro | tar -x -C <mapp>`.

## Testresultat
- **Simulatorbygget kompilerar** (Fable screens 43707813309 och 43710715096). *Verifierat i CI.*
- **iOS build 43708424966 grön** (e25fb97 på min gren: device-bygget, varningar som fel, LumenTests) med A104 fram
  till V2b och A106. **iOS build 43712177752 grön på main** (7fda731, med scenrättningarna). *Verifierat i CI.*
- Sett på bild av mig: iPhone 17 Pro ljust och mörkt, iPhone SE med största text. Simulatorn, **inte enhet**.
- **Kelly har inte granskat än.** Punkt i hennes kö (Ke64).

## Kända begränsningar
- Kameran nekad har ingen scen (läget kräver att iOS har sagt nej). Inte sedd på bild.
- På `repQuotaExam` står både "Ljud: 4 av 6 klara · Görs i spelordning" och att frågorna är slut. Räknaren borde
  bytas mot en rad som säger att resten av ljudet inte görs. Kelly får säga texten.
- Med största text på iPhone SE fyller "Du har inga frågor kvar …" hela skärmen ovanför knappen i Nytt prov.

## Kvar
- Kellys granskning och det hon hittar.
- V4 (kortet "Har du prov snart?" i Provläge ska leda till Nytt prov) och "Spela in svaret" utanför skärmen i Mina
  svar (Toby, *untested assumption* att det är vyn): inte gjorda, de ligger efter A106 och A107.

## Nästa session
Läs Kellys svar i `prompts/queue/kelly.md` (Ke64) och rätta. Bilder tas med
`gh workflow run fable-screens.yml --ref main -f branch=fable/screens-<namn> -f screens="<scener>"` (ny gren varje gång).
