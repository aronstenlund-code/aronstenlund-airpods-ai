# A112 (D200): "Uppläsningen är tillfälligt avstängd" (Angela Fable, moln)

2026-11-16 20:59. Servern är Kevins K78 (`reports/2026-11-16-1945-kevin-k78-out-of-credits.md`), beslutet D200.
**Inget är provat på telefon. Inga ElevenLabs-anrop (D180): serverns svar är fejkat i testerna, och bilderna använder
förberedda lägen.**

## Vad som gjordes
När servern svarar `audio_unavailable: true` (HTTP 200, frågor och svar som text) är provet text tills vidare:

| Var | Vad användaren ser |
|---|---|
| Provets skärm (frågor) | Varje fråga med **hela svaret** under, i textfärg. Under Starta prov: "Uppläsningen är tillfälligt avstängd. Texten fungerar som vanligt." Ingen ljudräknare, ingen stapel, ingen rad om vad provet kostar |
| Provets skärm (en text) | Hela texten som förut, och samma rad under knappen |
| Start | Provkortet: "5 frågor · Uppläsningen är tillfälligt avstängd" |
| Spelaren (frågor), om den väntar på ljud | Frågan, **svaret som text** och raden, i lugn grå text |
| Spelaren (en text), om den väntar på ljud | Texten med markerad mening som förut, och raden ovanför knapparna |

- **Starta prov** på ett prov som inte är startat: appen frågar servern. Säger den att ljudet inte kan göras förblir
  provet text och ostartat, spelaren öppnas inte, och raden visas. Nästa Starta prov frågar igen; enligt K78 kostar det
  inget och gör ljudet när saldot är tillbaka.
- **Räknaren:** servern räknar inget (K78). Ger den tillbaka frågor (`refunded_questions`) läser appen om månadens
  kvot. Appens rad "Räknas som 2 av dina 12 frågor kvar." visas inte så länge uppläsningen är av.
- **Inga felrutor:** inget larm och ingen röd text. Raden ersätter den gamla "Ljudet kan inte göras just nu. Försök
  igen om en stund." överallt (samma lägen: K62, A100).
- Dela och Publicera följer A110: de finns bara för ett startat prov, och är gråa tills ljudet är klart.

## Tekniskt
- `DrillCloudView` läser `audio_unavailable` och `refunded_questions` (`Core/Repetition/DrillCloud.swift`).
- `CloudDrillAudio`: `startAudio` lämnar provet ostartat och säger raden när svaret har `audio_unavailable` och
  `audio_started: false`; `prepare` säger raden i stället för en räknare som står still; `isReadingAloudOff` och
  `refunds` är nya. `unavailableLine` har D200:s ordalydelse.
- `RepetitionModel.isReadingAloudOff(_:)` är det vyerna frågar. `prepareAudio` läser om kvoten efter en återbetalning.
- Vyerna: `DrillView.swift`, `RepetitionPlayerView.swift` (läslägets vy och Start läser raden som förut).
- `DrillCloud.swift` och `RepetitionModel.swift` är Angela Schrutes filer. A112 lades på mig, så jag gjorde ändringarna där.

## Testresultat
- **6 nya tester** i `LumenTests/A112ReadingAloudOffTests.swift`, med skenmoln och Kevins svar som fejkad JSON:
  raden har D200:s ordalydelse; svaret avkodas; Starta prov utan krediter håller provet som text och ostartat och
  räknas inte som att månaden är slut; ett startat prov säger raden och återbetalningen noteras; ett sparat prov
  säger det redan före Starta prov; när servern slutar säga det är raden borta.
- **iOS build 43940942624 grön** (min gren): device-bygget, varningar som fel och LumenTests med de nya testerna.
  *Verifierat i CI.*
- **Sedd på bild av mig** (simulatorn, inte enhet), Fable screens 43935880746 och 43940954849 (iPhone 17 Pro, ljust
  och mörkt), 43935886191 och 43940960806 (iPhone SE, största text): provets skärm ostartat och startat, en text,
  Start, spelaren för frågor och för en text. `reports/2026-11-16-a112-bilder/`, grenarna `fable/screens-a112-*`.
- Efter de första bilderna: raden stod två gånger på provets skärm (nu en gång, under knappen), och svaret klipptes
  i spelaren på iPhone SE med största text (nu skrollar det). Båda sedda på bild efter rättningen.
- **Inte testat mot servern:** appen har inte körts mot Kevins `x-earmind-test: unavailable`. Det är Tobys test.
  *Untested.*

## Kända begränsningar
- Raden försvinner först när appen frågar servern igen (provets skärm öppnas, eller Starta prov trycks). Den släcks
  inte av sig själv medan man tittar på skärmen.
- Ett startat prov utan något ljud alls har Starta prov grå. Texten finns i frågelistan, men det finns ingen
  bläddring fråga för fråga utan ljud.
- Tobys simulatortester letar efter den gamla meningen "Ljudet kan inte göras just nu" (`RepetitionStatesTests`,
  `FullFlowTests`) och blir röda tills de är ändrade. Han är meddelad.
- `docs/design/repetition-texter.md` rad 120–121 har den gamla meningen (Kellys fil).

## Nästa session
Läs Tobys körning mot `x-earmind-test: unavailable` och Kellys syn på bilderna.
