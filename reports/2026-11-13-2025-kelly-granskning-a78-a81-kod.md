# Kelly: granskning av A78–A81 i koden (före skärmbilderna)

Datum: 2026-11-13 20:25. Roll: Kelly Kapoor (design). Uppdrag: Ke50 del 2, "granska A78–A81 mot din design". Underlag:
`docs/design/repetition.md` (Ke49), `docs/design/repetition-texter.md` (Ke50), `SYSTEM.md` och D147.

## Läge
- Koden är utkastet b669d02 (Toby på Arons uppdrag, D147) och A78 del 1 (3ce9fc0). CI "iOS build" för 6d35e76 är
  **failure** (43490256034), så **det finns inga skärmbilder än**. Granskningen är gjord **i koden** och är inte
  verifierad på bild eller telefon. Granskningen på bild görs när CI är grön (scenerna står i `repetition.md` §7).
- Texterna jämförs i `repetition-texter.md`, kolumnen "I koden nu". De tas inte upp igen här, utom där de bryter
  mot ett beslut.

## Fynd
| # | Var | Fynd | Ska vara | Nivå |
|---|---|---|---|---|
| R1 | `RepetitionPlayerView.swift:30` | Avsluta har `kind: .danger`, alltså en röd knapp. | Neutral sekundär knapp (`surface`), 64 pt. Rött betyder fel (SYSTEM §3, `repetition.md` regel 3). | **Hög** |
| R2 | `RepetitionPlayerView.swift:56` | Frågan står i `LumenFont.handwriting`. | `LumenFont.text(34, .bold, relativeTo: .largeTitle)`. Handstilen togs bort ur gränssnittet i Ke12 (SYSTEM §2). | **Hög** |
| R3 | `RepetitionPlayerView.swift:76` | "Pausad …" står i rött. | `muted` och brickan "Pausad" i grått. Paus är inget fel. | Medel |
| R4 | `RepetitionPlayerView.swift:81–90` | Tre stora knappar för Långt, Kort och Paus på skärmen. | Ingen svarsknapp på skärmen: trycken visas som en tyst rad ●/●●/●●● (`spelar-*.png`). Under paus fortsätter ett tryck var som helst på skärmen. Låsskärmens knappar är reserven. Skälet är att skärmen ska gå att läsa på en sekund och att telefonen ligger i fickan. Vill Angela eller Toby behålla knapparna för tillgänglighet kan de stå kvar som VoiceOver-åtgärder (`accessibilityAction(named:)`) på frågan. | Medel |
| R5 | `RepetitionPlayerView.swift` | Ingen ring för betänketiden. "Tänk" är bara text, och stapeln med ett streck per fråga saknas. | En ring som räknar ner sekunderna, och stapeln under "Fråga 7 av 20" (`spelar-tank.png`). | Låg |
| R6 | `DrillView.swift:72` | Starta prov är avstängd tills **allt** ljud är klart. | Starta när första frågans ljud finns. Ljudet görs i spelordning (R1: första ljudet inom 20 s efter Starta prov). Knappen säger "Gör ljud …" tills dess. | Medel |
| R7 | `RepetitionHomeSection.swift` | Hem med prov har ingen blå knapp. Man trycker på provet, och sedan Starta prov i nästa vy (2 tryck). | Det närmaste provet som ett kort på Hem, med **Starta prov** som den enda blå knappen (`hem.png`). Andra prov: ▶ startar direkt, och raden öppnar provet. | Medel |
| R8 | `RepetitionHomeSection.swift:81–90` | BETA-märket är blått på `soft`. | Grå kontur (`muted`), ingen fyllning. Märkning och ingen uppmaning (SYSTEM §11). VoiceOver: "Beta, under utveckling". | Låg |
| R9 | `ControlCheckView.swift:52` | "Paus, och 3 igen för att fortsätta". | "Vilket tryck som helst fortsätter" (D143/D147 punkt 2). | Medel |
| R10 | `ControlCheckView.swift` | Instruktionen ligger i en ruta under listan. Det finns ingen stor puls med prickarna, och raden som testas är inte markerad. | En sak i taget: puls med ●●, "Tryck två gånger nu" stort, och raden som testas blå (`kontroller.png`). | Låg |
| R11 | `RepetitionHomeSection.swift:113` | "Fortsätt där du var?" är en `.alert`. | Ett blad med frågan synlig (`fortsatt.png`). En alert fungerar, men är godkänd bara tills vidare. | Låg |
| R12 | `NewDrillView.swift:167` | Felet "Word-filer går inte att läsa än". | Ta bort. K45 `doc_text` läser .docx (999a1bd). | Medel |

## Godkänt i koden
- Kontrollskärmen frågar aldrig efter modell. Den visar instruktionen för AirPods 1/2 och har "Starta ändå" (R11 i
  specen).
- Fler lägen har ingressen och BETA på varje lyssnande läge. "Förhör med rösten (BETA)" finns i Provläge.
- Dela är avstängd med förloppet tills ljudet är klart, och foton och dokument delas inte.
- "Varv" visas först från varv 2, vilket är bättre än skissen.
- Fotnoten om att material inte sparas finns och stämmer med D138.

## Till Angela
Rätta R1 och R2 först: de bryter mot SYSTEM.md och syns direkt. Därefter R4, R6, R7, R9 och R12 samt texterna i
`repetition-texter.md`. Jag granskar på bild när CI "Simulator screenshots" är grön med scenerna i `repetition.md` §7.

## Test
Bara kodläsning. Inget är byggt (CI 43490256034 failure), inget är på bild och inget är provat på telefon.
