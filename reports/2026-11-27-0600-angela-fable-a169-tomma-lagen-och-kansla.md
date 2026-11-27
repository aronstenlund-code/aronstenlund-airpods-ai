# A169: Tomma lägen, laddning och känsla i repetitionen

Angela Fable (moln), 2026-11-27. Beställt av Deangelo 05:16. Inget nytt flöde, bara känslan.

## Genomgång

| Del | Läge före | Efter |
|---|---|---|
| Tomma lägen | Start utan prov: knappen Nytt prov och raderna (A165, Ke93) – bra. Säg i AirPods utan historik: fältet säger vad man gör, + och Spela – bra. Spela in själv: ingången öppnar en ny samling direkt – bra. **Prov från din skola utan prov:** "Inga prov här än" utan knapp. | Knappen **Hämta igen** i det tomma läget (någon kan ha publicerat). |
| Laddning | **Prov från din skola:** en snurra mitt i en tom lista. Övriga snurror står i knappar eller med en rad om vad som händer ("Läser dokumentet …", "Gör ljudet …", köp) – de får stå. | Tre stilla platshållarrader (grå staplar i formen av en rubrik och en rad, `redacted`) där proven kommer; VoiceOver hör "Hämtar proven". |
| Rörelse | Reglerna från A150 (`SayMotion`): fjädrar utan överslag (`.smooth`), bara studs efter en svepning (`settle`), avbrytbara eftersom de startar där saker är, toningar på 0,15 s med Reduce Motion. | Oförändrat; de nya vyerna (A165–A168) använder samma regler. |
| Haptik | Bara i butiken (köp lyckades / misslyckades). | En lätt stöt när en egen inspelning **startar** och **stoppar** (samma ögonblick som den röda punkten kommer och går), och **provet klart** när sammanfattningen efter Avsluta kommer. |
| Avstånd, typsnitt, färger | Bladen (Spela in själv, lanseringen, sammanfattningen) har samma marginaler (24/20) och systemets typsnitt; grå text är `LumenColor.secondaryText`. | Oförändrat. |

**"Rätt svar"** finns inte i mina repetitionsvyer: rättningen sker i Provfrågor och provsessionen (Fler lägen), som
är Angela Schrutes. Haptik för ett rätt svar hör hemma där (rad i hennes kö).

## Teknik

- `SayMotion.swift`: `PlaceholderRow` (stilla, ingen skimmer) och `Feel` (`recording(from:to:)` → `.start`/`.stop`,
  `quizDone` = `.success`).
- `PublishViews.swift`: platshållarna medan listan laddas, Hämta igen i det tomma läget, snurran borttagen.
- `OwnDeckViews.swift`: `sensoryFeedback` på inspelningen. `PracticeSummaryViews.swift`: `.success` när bladet kommer.

## Test

- 2 nya enhetstester (`A169FeelTests` i `LumenTests/A168ComingBackTests.swift`): när haptiken ges, och de nya orden på
  sv och en.
- **iOS build 45938790413 på min gren grön i sin helhet (enhetsbygge utan varningar, alla enhetstester, App Store-arkivet)** (verifierat i CI, Simulator).
- Bilder (Fable screens 45938789982, iPhone 17 Pro, Simulator; "före" från A104:s körning, samma vy):
  `reports/2026-11-27-a169-bilder/a169-skolans-prov-fore-efter.jpg` – det tomma läget före och efter (sv, en mörkt),
  och felet med Försök igen som förut. Platshållarraderna medan listan laddas syns inte på en stillbild (demo-listan
  kommer direkt); de är kontrollerade i koden.
- Sett på bilden: den engelska stora rubriken "Quizzes from your sch…" kapas (systemets stora rubrik). Ett kortare
  ord är Kellys sak; rad i hennes kö.
- Haptik syns inte på bilder och känns inte i Simulatorn: **otestat antagande** att den känns rätt på telefon.
- 0 ElevenLabs.
