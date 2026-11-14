# Angela: A87-punkten från Angela Fable – systemets stil i resten av appen (Ke53 3–5) och fälten för förhandsvisningen

Datum: 2026-11-14 18:46. Roll: Angela (app). Inget är **verifierat på enhet**. Inga tester mot ElevenLabs (D180).

## Läget för punktens sex delar
| Del | Läge |
|---|---|
| 1. Ke53 3–5 i resten av appen | **gjord nu** (c7742f0, 469f95b), se nedan |
| 2. Ke53 11, fotnot i Välj läge och "Förhör med rösten" | var redan klar (`ListeningScreen` har ingen `BetaBadge` per rad, N4-raden finns) |
| 3. `repResume`, `ResumeSheet`, `resumeOffer`, `checkResume` | var redan borta (`grep` ger inget) |
| 4. `screenshots.yml` med `text_size` och `screens` | var redan klar |
| 5. Kellys P1, förhandsvisning av ett publicerat prov | **klar:** fälten i appen (c7742f0), Kevins K65 live, Angela Fables sektion (2d7845e), Lyssna-raden på bilden (52afbf5), stängd av Kelly (5004d56) |
| 6. `A92HelpTests` | var redan rättad (fdc5dea) |

## Del 1 (D181): ändrat på ett ställe, så att alla skärmar följer med
- **Typsnitt (Ke53 3, SYSTEM §0.2):**
  - `LumenFont.text(storlek, vikt)` ger nu SF Pro i den textstil som ligger närmast storleken: 17 → `.body`,
    15 och 14 → `.subheadline`, 13 → `.footnote`, 20 → `.title3`, 28 → `.title`, 34 och större → `.largeTitle`.
  - Alla ca 360 anrop följer därmed Dynamic Type, spärrning och radavstånd.
  - Familjen Grotesk och Kalam är borttagna ur `Info.plist` (app och widget), `project.yml`, `Resources/Fonts` och
    licenslistan i Om appen.
  - Storlekarna vid anropen står kvar och tas bort skärm för skärm när skärmarna görs om.
- **Knappar (Ke53 4):**
  - `LumenButtonStyle` är ersatt av `SystemButton` på 37 ställen.
  - `.primary` är `.borderedProminent` och `.secondary` är `.bordered`, båda med `.controlSize(.large)` och i full
    bredd.
  - Fyllda knappar har Angela Fables `FilledButtonLabel`, alltså mörk text på den ljusa accenten i mörkt läge (D174).
  - Systemet ritar tryckt och avstängt läge. De gamla fasta höjderna (44–64 pt) är borta.
- **Färger (Ke53 5, SYSTEM §0.3):**
  - `LumenColor.background`, `surface` och `raised` är nu `systemBackground`, `secondarySystemBackground` och
    `secondarySystemGroupedBackground`.
  - `ink` och `muted` är `label` och `secondaryLabel`; `line` och `grid` är `separator`; `red` är `systemRed`.
  - Accentblå (#2346C8 / #7F9BFF) är kvar och finns nu också som **AccentColor** i Assets, satt i `project.yml`.
- **Listor (Ke53 5):** `lumenForm()` har inte längre `.scrollContentBackground(.hidden)` eller egen bakgrund, så
  Inställningar, Mina svar, Diagnostik och Anteckningar får iOS-bakgrunden i ljust och mörkt.
- **Inte gjort i del 1, och det är ett medvetet val:** varje skärm har inte gåtts igenom för "exakt en fylld knapp per
  skärm". Där en skärm hade två blå knappar har den fortfarande två fyllda. Kelly ser det på bilderna.

## Del 5: fälten för förhandsvisningen
- `DrillPublicationView` har tre nya delar:
  - `preview: [Preview]?` med `question` och `short`;
  - `first_audio_url` (`firstAudioURL`);
  - `moreQuestions` ("och 16 frågor till").
- Båda fälten är valfria, så en server utan K65 fungerar som förut.
- Scenen `repPublication` har fyra exempelfrågor, så att Angela Fable kan bygga sektionen.
- **K65 (Kevin):** `publicView` ska skicka de fyra första frågorna och en signerad länk till första frågans färdiga
  ljudfil, utan nytt ljud och utan ElevenLabs.

## Testkrok till Toby 2 (T24, K64, D180)
- I Debug får varje anrop till vår backend headern `x-earmind-test: <värde>` när startmiljön har
  `LUMEN_TEST_HEADER`. Det gäller alla 22 ställen som sätter `apikey`.
- Värdet får vara högst 20 tecken: bokstäver, siffror, `-` och `_`, till exempel `1`, `slow` eller `unavailable`.
- Release skickar aldrig headern (37ae1c1, `Lumen/Core/Telemetry/TestTrafficHeader.swift`).
- Med den kan Toby köra lägena slow och unavailable i simulatorn med falskt ljud.

## Test
- Nya enhetstester: `A87PublicationPreviewTests` (förhandsvisningen avkodas; en äldre server ger nil och 20 kvar).
- **CI:** iOS build 43624998385 (52afbf5, innehåller c7742f0, 469f95b och 37ae1c1) är grön, med ipa
  (`Lumen-unsigned`). `A87PublicationPreviewTests` och alla äldre sviter gick igenom. c7742f0 var grön också för sig
  (43622810924). Simulatorbilderna 43625046427 och 43625042294 gick igenom.
- Utseendet är bara sett på simulatorbilder (**ej på enhet**).

## Risker
- Systemets `secondaryLabel` är ljusare än förra `muted`. Kelly har godkänt `.secondary` (D174) men bör titta på
  bilderna.
- Text som var 14 pt blir 15 pt (`.subheadline`). Det kan ge ett radbyte till på några kort.

## Kvar
- Kelly granskar bilderna (alla scener, ljust och mörkt, största text).
- Ta bort storlekarna vid anropen skärm för skärm.
