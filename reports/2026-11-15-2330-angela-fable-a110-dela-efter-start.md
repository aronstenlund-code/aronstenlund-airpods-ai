# A110 (D198): Dela och Publicera efter Starta prov, och ett avsnitt Påminnelser (Angela Fable, moln)

2026-11-15 23:30. Beslutet är Deangelos D198 (svar på Kellys N4 och P1).
**Inget är provat på telefon. Inga ElevenLabs-tester (D180).**

## Vad som gjordes
| Del | Före | Nu | Fil |
|---|---|---|---|
| Dela (verktygsfältet) | Grå för ett prov som inte är startat | **Dold** tills provet har startats | `DrillView.swift` |
| Publicera prov (⋯-menyn) | Grå | **Dold** tills provet har startats | `DrillView.swift` |
| Raden som säger varför | – | Under frågorna, och under texten för en text: **"Starta provet först så kan du dela det."** | `DrillView.swift` |
| Inställningar | Två avsnitt: Påminnelse (kl. 18) och Påminnelser (kl. 16) | **Ett avsnitt, Påminnelser**, med fyra rader: Påminn mig att plugga, Tid, Påminn mig varje dag (med underraden "Studieplanen i Fler lägen") och Tid för studieplanen | `ReminderViews.swift`, `Settings/SettingsView.swift` |

- "Startat" är samma sak som i A107: ljudet är begärt (`drill.awaitsAudioStart` är falskt). Äldre prov räknas som
  startade, så för dem ändras ingenting. Regeln ligger i `DrillShareGate.isOffered`.
- Inga inställningar är borttagna. Nycklarna, standardvärdena och det som händer vid en ändring är desamma som förut;
  bara platsen och två etiketter är nya ("Studieplanen i Fler lägen" under reglaget och "Tid för studieplanen").
  Fotnoten har en rad per påminnelse.
- Utan repetitionsflödet visas avsnittet som förut, med bara studieplanens påminnelse.

## Egna ordval (till Kelly)
D198 ger bara raden "Starta provet först så kan du dela det." Underraden "Studieplanen i Fler lägen", etiketten "Tid
för studieplanen" och fotnotens andra rad ("Studieplanen: en gång om dagen med dagar kvar till provet och 5 snabba
frågor. Ingen påminnelse de dagar du redan har övat.") är mina, gjorda för att två reglage och två tider i samma
avsnitt ska gå att skilja åt. Kelly får ändra dem.

## Testresultat
- **4 nya tester** i `LumenTests/A110SharingAfterStartTests.swift`: ett ostartat prov erbjuds inte för delning, ett
  startat gör det (också äldre prov), en text följer samma regel, och raden har Deangelos ordalydelse.
- **iOS build 43764595099 grön** (min gren): device-bygget, varningar som fel och LumenTests med de nya testerna.
  *Verifierat i CI.* Det första bygget (43763081615) föll: mitt typnamn `DrillSharing` fanns redan i logiken. Bytt till
  `DrillShareGate`.
- **Sedd på bild av mig** (simulatorn, inte enhet), Fable screens 43764603042 (iPhone 17 Pro, ljust och mörkt) och
  43764605647 (iPhone SE, största text):
  - `repUnstarted` och `repUnstartedText`: ingen Dela-knapp, raden står under listan respektive texten;
  - `repList` och `repText` (startade): Dela finns kvar;
  - `settings`: ett avsnitt Påminnelser med fyra rader.
- Bilder: `reports/2026-11-15-a110-bilder/`, grenarna `fable/screens-a110-17pro-2` och `fable/screens-a110-se-xxxl-2`.
- **Inte sett:** att Publicera prov saknas i ⋯-menyn (menyn måste öppnas), och avsnittet Påminnelser på iPhone SE med
  största text (det ligger längre ner än bilden når). *Untested.*
- **Inte testat:** att Dela och Publicera kommer fram direkt efter Starta prov. Det är Tobys test.

## Kända begränsningar
- Ett prov som är startat men vars ljud inte är klart har Dela kvar, grå, som förut ("Delas när ljudet är klart").
- Tobys tester som delar eller publicerar måste starta provet först.

## Nästa session
Läs Kellys och Tobys svar. Bygget på main efter pushen står på tavlan.
