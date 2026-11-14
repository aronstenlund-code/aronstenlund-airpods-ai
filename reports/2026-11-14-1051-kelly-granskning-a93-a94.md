# Kelly: granskning av A94 (första starten) och A93 (Gör med ChatGPT) på bild

Datum: 2026-11-14 10:51. Bilder: CI "Simulator screenshots" på 1780d8b, alla gröna: **43580443638** (iPhone 17 Pro),
**43580454162** (17 Pro, största text), **43580446583** och **43580450489** (iPhone SE, standard och största text), ljust
och mörkt. Kontaktblad: `reports/2026-11-14-a93-a94-granskning/` (`a` 17 Pro ljust, `ad` mörkt, `b` största text,
`c` SE). Underlag: `docs/design/forsta-starten.md` (Ke55) och `docs/design/gor-med-chatgpt.md` (Ke58), med mina svar
till Angela Fable.

## Bedömning
**A94 och A93 godkända.** Båda följer skisserna och texterna nära.

| Scen | Bedömning |
|---|---|
| `fsWelcome` | **Godkänd.** Appikonen, "Välkommen till Earmind", tre rader med symbol och text, raden om data med Läs mer, och Fortsätt fast nederst. Ingen Elias, ingen mikrofon. |
| `fsReadMore` | **Godkänd.** Data och integritet med Klar: DET HÄR SKICKAS (med ChatGPT-raden), DET HÄR SPARAS ("sparas hos Earmind") och MIKROFONEN. Fotnoten "Du behöver inte skapa något konto." Mina ändringar är med. |
| `fsNewDrill` | **Godkänd.** "Senare" uppe till vänster, raden "Börja med materialet till ditt nästa prov.", Fota sidor i accentfärg, fotnoten om kameran, PROV med valfritt namn, Vilken årskurs? och Antal frågor. Ingen Gör med ChatGPT i första starten. |
| `gptSteps` | **Godkänd.** Tre numrerade steg, en fylld knapp åt gången (Kopiera prompten), Öppna ChatGPT och Klistra in tonade, och fotnoten om ChatGPT/OpenAI. |
| `gptFound` | **Godkänd.** "Hittade 20 frågor med svar", frågorna med kort svar, "och 16 frågor till", Spara frågorna fast nederst. Röstvalet (D151) finns i koden under frågorna (`DrillVoiceChoice`), men under det synliga i bild. |
| `gptWrong` | **Godkänd med ett lågt fynd** (nedan). |

Mörkt läge, SE och största text har inga fel. I största text rullar Välkommen-skärmen under den fasta Fortsätt, och
nästa steg syns hela tiden.

## Fynd
| # | Scen | Fynd | Ska vara | Nivå |
|---|---|---|---|---|
| G1 | `gptWrong` | Klistra in-knappen är grå i scenen, eftersom prompten "inte är kopierad" där. Den som hamnar på felskärmen har redan klistrat in en gång. | På felskärmen ska knappen alltid ha accentfärgen, eftersom den är skärmens enda handling. Skärmbildsscenen kan också sätta `copied = true`. | Låg |
| G2 | `fsWelcome`, största text | Raderna under rubriken syns bara delvis innan man rullar (datatexten och Fortsätt tar halva skärmen). | Okej så länge sidan rullar och Fortsätt syns. Kan förbättras genom att datatexten följer med i rullningen vid tillgänglighetsstorlekar och bara Fortsätt står fast. | Låg |

## Kvar
- Samtyckets plats (lyssningens samtycke först vid första lyssnande läget) behöver fortfarande Deangelos ja
  (`forsta-starten.md`). Det syns inte i bild.
- Tobys T21 (ny användare) testar flödet.

## Test
Simulatorbilder, inte telefon.
