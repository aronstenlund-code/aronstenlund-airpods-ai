# A106: läslägets vyer (D185, Kelly Ke63) (Angela Fable, moln)

2026-11-15 13:10. Underlag: Kellys `docs/design/lasa.md` (Ke63) och Angela Schrutes A105
(`reports/2026-11-15-0325-angela-a105-laslage.md`). **Inget är provat på telefon. Inga ElevenLabs-tester (D180).**

## Vad som byggdes
| Skärm | Vad | Fil |
|---|---|---|
| Nytt prov | Avsnittet **Gör** med segmenterad kontroll **Frågor · Läs upp texten** (inte i första starten). Med Läs upp texten försvinner Antal frågor och årskurs, två fotnoter säger vad det blir och vad det kostar, och knappen heter **Skapa uppläsning** | `NewDrillView.swift` |
| Läser ditt material | Stegen Läser sidorna · Tar reda på ämne och årskurs · Gör texten klar för uppläsning | `NewDrillView.swift` |
| Stämmer det här? (text) | Ämne, årskurs, **Rubriker** med antal stycken, längden i minuter, rösten, och under knappen "Texten räknas som 1 fråga. 11 kvar sedan." Räcker kvoten inte är knappen grå med Kellys mening. För långt material: Kellys mening om de första sidorna | `NewDrillView.swift` |
| Provets skärm (text) | "Text · 11 meningar · cirka 1 min · ljud klart", hela texten i ett kort med rubrikerna i fetstil, "Tryck på en mening för att börja där.", Starta prov eller Fortsätt fast nederst. ⋯-menyn utan Ändra ordning och Gör med ChatGPT | `DrillView.swift` |
| Spelaren | Avsluta (textknapp) och provets namn, "Mening 6 av 11" med rubriken och en tunn linje, texten med **meningen som läses fullfärgad, halvfet och markerad** (grå markering i paus), resten grå. Texten skrollar så att meningen står i övre tredjedelen. Skrollar man själv slutar den följa, och knappen **Till meningen** visas. Tryck på en mening läser därifrån. ⏮ ⏸/▶ ⏭ och raden med trycken | `ReadingViews.swift` (ny) |
| Spelaren: slut | "Slut på texten", "Du har lyssnat igenom hela {namn}.", **Börja om** | `ReadingViews.swift` |
| Spelaren: väntar | "Gör ljud …", utan nät "Ingen internetanslutning. Resten av texten kommer när du är uppkopplad.", eller ljudets fel | `ReadingViews.swift` |
| Start | Provkortet: "Text · cirka 1 min", efter avbrott "Du var på mening 6 av 11". Raden under andra prov: "Text · cirka 1 min · ljud klart" | `RepetitionHomeSection.swift` |
| Styr med dina AirPods (text) | "Medan texten läses:" och textens tre tryck. Visas första gången man startar en text (egen nyckel `repetition.textControlsChecked`) | `ControlCheckView.swift` |

## Tekniskt
- `SentenceText` är en `UITextView` i SwiftUI (`UIViewRepresentable`). SwiftUI:s `Text` kan inte ge olika färg, vikt
  och bakgrund per mening i löpande text och samtidigt säga vilken mening man tryckte på. Texten byggs en gång; när
  meningen byts ändras bara färg, vikt och markering, så platsen på skärmen står kvar. Inget nytt beroende.
- Knapparna skickar samma händelser som AirPods (`session.press`): bakåt `.pauseToggle`, paus `.long`, framåt `.short`.
- `PressesRow` tar en lista med tryck (`titles`), så textens rad och frågornas rad är samma vy.
- T24 L4: Antal frågor visar inget tal förrän månadens kvot har kommit (`model.quotaIsKnown`).
- Scener (i `RepetitionScreenshots.swift`, Angela Schrutes fil, bara Debug): repTextNew, repTextConfirm, repText,
  repTextPlay, repTextPaused, repTextEnd, repTextWaiting, repHomeText, repTextControls.

## Avvikelser från Kellys skisser (till Kelly)
1. **Stycken, inte meningar, under Rubriker** i Stämmer det här?. Servern delar texten i meningar först när den
   sparas, så före sparningen finns bara stycken. Raden under säger "Cirka 1 min." utan antal meningar.
2. **Ingen rättelse** ("Något fel? Skriv det") för en text: `/exam read` tar ingen rättelse (K70).
3. **Rubrikerna räknas som meningar** ("Mening 6 av 11" i stället för 5 av 9): de läses upp, så spelaren räknar dem (A105).
4. **Markeringen har raka hörn** och går ut till radens slut på första raden (textvyns bakgrundsfärg).
5. **Lästa och kommande meningar har samma grå** (systemets sekundära textfärg) för kontrastens skull.
6. Slutskärmen använder systemets tomläge med symbolen `text.alignleft`.

## Testresultat
- **iOS build 43708424966 grön** (e25fb97, min gren): device-bygget med varningar som fel och LumenTests. *Verifierat i CI.*
- **Sedd på bild av mig** (simulatorn, inte enhet): iPhone 17 Pro ljust och mörkt (Fable screens 43708431075),
  iPhone SE med största text (43710717475). Efter SE-bilderna: med de största textstorlekarna är spelarens text i
  brödtextstorlek och tryckraden dold, så att texten får plats. **Den ändringen är inte sedd på bild än.**
- Bilder: grenarna `fable/screens-a106-17pro-1` och `fable/screens-a106-se-xxxl-1`, kontaktblad i
  `reports/2026-11-15-a106-bilder/`.
- **Inte testat:** att skrollningen följer med under riktig uppläsning, tryck på en mening (träffytan), Till meningen,
  VoiceOver (texten läses som ett stycke; knapparna har namn), AirPods-trycken och låsskärmen. *Untested on device.*
- **Kelly har inte granskat än** (Ke64).

## Kända begränsningar och risker
- VoiceOver når inte enskilda meningar i texten, bara knapparna Förra meningen, Pausa och Nästa mening.
- Kontrollskärmen för en text spelar första stycket en gång så att trycken kommer fram. *Untested assumption* att
  trycken når fram på samma sätt som för en fråga.
- `repTextMaking` (ljudet görs) visade "ljud klart" i simulatorn och är inte med bland bilderna.

## Kvar
- Kellys granskning (Ke64) och rättningar.
- T28 (Toby): läsläget i simulatorn.
- A107 (redigera svaren, förlopp vid Starta prov) är nästa punkt.
