# A152: privacy manifest och App Privacy-svaren ur koden (D238)

Angela Schrute (moln, Fable 5.2), 2026-11-19 17:50–19:30. Main, sammanslagning 669a7041 (grenen
`claude/fervent-fermi-34hrer`). 0 ElevenLabs. **Verifierat i CI, inte på enhet och inte mot App Store Connect.**

## 1. Vad som är gjort
- **`Lumen/Resources/PrivacyInfo.xcprivacy`** (appen) och **`LumenControls/PrivacyInfo.xcprivacy`** (widgeten).
- **`scripts/privacy_manifest_check.py`**: läser koden och jämför med manifesten, åt båda håll. Körs i bygget.
- **Två steg i `ios-build.yml`**: manifesten stämmer med koden; manifesten finns oförändrade i Release-appen, med
  en lista över paketens egna manifest och deras användning av samma API:er.
- **`A152PrivacyManifestTests`**: filen finns i appen testerna kör i och säger det som är bestämt.
- **Svaren på granskning.md §2 punkt 3 och 4** är inskrivna där, märkta [V i koden].

## 2. API:er med krav på skäl (kontrollerat i koden, inte gissat)
| Kategori | Var i koden | Skäl | Varför det skälet |
|---|---|---|---|
| UserDefaults | 120 ställen i appen (inställningar), `Shared/ExamWidgetSnapshot.swift` (appgruppen) | `CA92.1`, `1C8F.1` | appens egna inställningar, och de som delas med widgeten i samma appgrupp |
| Filers datum | `DrillCloud.swift:810` (`contentModificationDateKey`) | `C617.1` | ljudcachen i appens egen mapp rensas från äldsta filen |
| Systemets uppstartstid | `PlaybackService.swift:120, 135`, `FileCaptureService.swift:123` (`mach_absolute_time`) | `35F9.1` | tid mellan händelser i appen (uppspelningens fördröjning, ljudbitarnas tider) |
| Diskutrymme | **inte appens kod**: FluidAudio, `LFM3AudioConfig.swift:81` (`volumeAvailableCapacityKey`) | `E174.1` | paketet kollar ledigt utrymme innan en modell laddas ner |
| Aktiva tangentbord | används inte | – | – |

- **Widgeten** använder bara de delade inställningarna: `1C8F.1`.
- Skälkoderna och kategorierna är lästa på Apples sidor 2026-11-19
  (`developer.apple.com/documentation/bundleresources/app-privacy-configuration`), inte ur minnet.
- **Spårning: nej** (`NSPrivacyTracking` false, inga domäner).

## 3. Paketen
| Paket | Eget manifest | API:er med krav på skäl i koden | Åtgärd |
|---|---|---|---|
| SpotifyiOS (binärt ramverk, 5.0.1) | **ja**, i `Lumen.app/Frameworks/SpotifyiOS.framework/` | Spotifys ansvar | ingen |
| FluidAudio (källkod, länkas in i appen) | **nej** | ledigt diskutrymme, en rad (se ovan) | deklarerat i appens manifest, eftersom koden blir en del av appens binär |
| LumenScoring, LumenVAD (egna, i repot) | – | inga | ingen |

EarMind använder bara FluidAudios röstdetektering och anropar aldrig raden om diskutrymme. Ändå finns den i appen: Release-binären importerar `NSURLVolumeAvailableCapacityKey` (byggsteget skriver ut symbolerna med `nm`), tillsammans med `NSUserDefaults`, `mach_absolute_time` och `NSURLContentModificationDateKey`. Det är precis de fyra kategorierna i manifestet, och inga andra. **Verifierat i bygget.**

## 4. Insamlade datatyper i manifestet
| Datatyp | Kopplad | Syfte |
|---|---|---|
| Användar-ID | ja | appens funktioner |
| Annat användarinnehåll | ja | appens funktioner, **analys** |
| **Kundsupport** | ja | appens funktioner |
| Foton | nej | appens funktioner |
| Ljuddata | nej | appens funktioner |
| Kontakter | nej | appens funktioner |
| Köphistorik | ja | appens funktioner |
| Produktinteraktion | ja | appens funktioner |

**Två avvikelser från tabellen i granskning.md §2**, eftersom koden gör det i Release:
- **Analys** på "Annat användarinnehåll": frågeloggen och delad historik (punkt 3 a, b, d nedan).
- **Kundsupport**: "Fel svar?", talat "rapportera" och Feedback och förslag (punkt 3 c).
Kelly för in dem i tabellen (Ke84). Kalenderhändelser ligger under "Annat användarinnehåll", som i tabellen.

## 5. Svaren på granskning.md §2 punkt 3 och 4 [V i koden]
**Punkt 3: läser utvecklaren frågor i Release? Ja, på fyra sätt.** Inget är bortkompilerat (bara testläget är det).
| Flöde | När | Kopplat till kontot | Sparas |
|---|---|---|---|
| a. Frågeloggen i lyssnarlägena (D116) | efter lyssnarsamtycket, i Fler lägen | nej | högst 14 dagar |
| b. Frågeloggen i repetitionsläget (D197) | varje sparat frågeprov, **utan samtyckesflagga** | nej | högst 14 dagar |
| c. Rapporter och feedback (D57) | "Fel svar?", "rapportera", Feedback och förslag | ja | högst 90 dagar |
| d. Delad historik (D57) | frivilligt, av från början | ja | högst 12 månader |
Filer och rader står i granskning.md.

**Punkt 4: sparas minnen på servern? Nej.** De ligger i `memories.json` på telefonen, skickas med frågan och till
`/memory`, och servern sparar ingen text (`/memory` skriver ingenting i databasen utom en rad utan text).

## 6. Concerns
- **Frågeloggen i repetitionsläget (b) har inget samtycke och nämns inte i Välkommen.** Välkommen › Läs mer säger
  att proven sparas hos EarMind, inte att utvecklaren läser nya frågor och svar i upp till 14 dagar. Det gäller appens
  huvudflöde och alla användare utom testkonton. Antingen en mening i Välkommen och i policyn, eller så stängs loggen
  av för App Store-versionen (Kevin). **Beslut: Deangelo/Aron.** Manifestet säger sanningen som koden är nu.
- **"14 dagar" i hjälpsvaret (D135)** gäller frågeloggen. Rapporter ligger kvar upp till 90 dagar och delad historik
  upp till 12 månader. Policyn (Ke78) bör säga alla tre.

## 7. Testresultat
- **CI:** tre byggen på grenen, alla gröna: 44570636918 (manifesten i Release-appen, testerna), 44576379179 (raden i FluidAudio utskriven) och **44584413378 på 653bb8d9** (med diskutrymme; `A152PrivacyManifestTests` gick igenom; steget "Privacy manifests are in the Release app" visar `Lumen.app/PrivacyInfo.xcprivacy` och `Lumen.app/PlugIns/LumenControls.appex/PrivacyInfo.xcprivacy`, båda lika med källfilerna). Bygget på main efter sammanslagningen körde när rapporten skrevs.
- **Lokalt:** skriptet går igenom på Linux (samma som i bygget).
- **Inte prövat:** att App Store Connect godtar manifestet. Det visar sig först vid en uppladdning (Apples mejl
  "Missing API declaration" kommer annars efter den).

## 8. Kända begränsningar
- Skriptet letar efter namn i Swift-koden. Ett nytt paket som hämtas vid bygget syns inte i skriptet, bara i
  byggstegets lista; därför står FluidAudios rad inskriven för hand i skriptet (`LINKED_PACKAGE_CODE`).
- Byter FluidAudio version måste raden kontrolleras igen (byggsteget skriver ut den varje gång).
- Manifestets datatyper är en beskrivning, inte något bygget kan bevisa. De följer granskning.md och koden i dag.

## 9. Nästa steg
- Deangelo/Aron: beslutet om frågeloggen i repetitionsläget.
- Kelly (Ke84): tabellen och policyn.
- Vid första uppladdningen till App Store Connect: läs Apples svar om manifestet.

## Tillägg 2026-11-20 07:52: main är grönt
iOS build 44588379984 på main (669a7041) är grön, med båda A152-stegen och `A152PrivacyManifestTests`. Nästa bygge
på main (44598313619, a5f4a2c8, med A153) är också grönt: skriptet godtar Angela Fables tangentbordsrad. **Verifierat i CI.**
