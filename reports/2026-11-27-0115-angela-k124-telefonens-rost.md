# K124 – telefonens egen röst när ElevenLabs-kvoten är slut

Angela Schrute (moln, Opus 5.5), 2026-11-27. Uppdrag: Kevins rad i min kö (K124/D267, 2026-11-27 01:00): `/tts` svarar 503 `tts_quota` med `fallback: true` när ElevenLabs-kvoten är slut, och sedan direkt i 10 minuter utan nytt försök; proven får `audio_unavailable`. "Appen läser då upp med telefonens egen röst (AVSpeechSynthesizer) och säger det kort." Inga krediter dras.

## Kort

- **Lyssnandet:** appen läste redan med telefonens röst när ElevenLabs inte svarade, mening för mening. Nu frågar den inte ElevenLabs igen på 10 minuter efter ett `tts_quota`, så varje mening slipper en tur till servern innan telefonen läser. Kortet "Rösten fungerar inte just nu" visas som förut.
- **Proven och Säg i AirPods:**
  - Förut visades provet bara som text när ljudtjänsten var slut ("Uppläsningen är tillfälligt avstängd", A112b). Nu **läser telefonens röst** frågorna, svaren och texterna genom samma spelare.
  - Skärmen säger "Telefonens röst läser just nu." / "The phone's voice is reading for now."
  - Det servern redan har gjort spelas som det är; bara det som saknas läses av telefonen.
  - Rösten följer provets språk (svenska eller engelska).
- Inga krediter, inga anrop till ElevenLabs eller modellen. Inte provat på telefon.

## Teknik

- **`Lumen/Core/Voice/Speaker.swift`**:
  - `premiumPausedUntil` sätts till nu + `Speaker.quotaPause` (10 min) när ett fel är `tts_quota` (`Speaker.isQuotaOut`).
  - Under pausen går både uppläsningen och förhämtningen (D80) direkt till telefonens röst.
  - Andra nätfel (inget nät, en annan 503) prövar ElevenLabs igen vid nästa mening, som förut.
  - `now` kan bytas i test.
- **`Lumen/Core/Repetition/DrillCloud.swift` (`CloudDrillAudio`)**:
  - `phoneVoice` ger en `DeviceVoiceDrillAudio` per språk. Det är samma telefonröst som låtsasläget redan använde, med filer i `Application Support/drill_audio_phone`.
  - `phone(for:)` är bara satt när servern har sagt att ljudtjänsten är slut för provet (`unavailableLine`).
  - Då gäller tre saker:
    - `track` och `reading` ger serverns fil om den finns, annars telefonens.
    - `progress` räknar telefonens filer.
    - `problem` säger `phoneLine`.
  - `prepare` frågar först servern som förut (då märks det när kvoten är tillbaka) och låter sedan telefonen göra det som saknas.
  - `startAudio`: vid `audio_unavailable`, eller en vägran med 503 `tts_quota`, startar telefonen och svaret är "på väg", i stället för att bara visa text.
  - `tts_quota` räknas till `unavailableCodes`.
  - Provets språk tas fram med `NLLanguageRecognizer` (svenska eller engelska); `NaturalLanguage` är ett av Apples egna ramverk, inget nytt beroende.
- **`Lumen/App/AppContainer.swift`**: kopplar in telefonrösten för den riktiga servern. Låtsasläget använder `DeviceVoiceDrillAudio` direkt, som förut.
- `RepetitionModel.isReadingAloudOff` jämför med `unavailableLine`. När telefonen läser är den därför falsk, och vyerna visar spelaren i stället för textläget. **Ingen vy är ändrad** (repetitionsvyerna är Angela Fables).

## Testresultat

BYGGRAD

- `LumenTests/K124PhoneVoiceTests.swift`, 7 tester:
  - Speaker: efter `tts_quota` frågas ElevenLabs en gång, och nästa mening går direkt till telefonen. Efter 10 minuter frågas ElevenLabs igen. Ett vanligt nätfel pausar inte.
  - Proven:
    - När ljudtjänsten är slut startar Starta prov med telefonens filer, och raden "Telefonens röst läser just nu." visas.
    - `RepetitionModel` visar spelaren, inte textläget.
    - Utan telefonrösten blir det text som förut.
    - När servern inte längre säger `audio_unavailable` slutar telefonen läsa.
  - Språket: ett svenskt prov får sv-SE, ett engelskt en-US.
  - Att `tts_quota` räknas som att ljudtjänsten är slut, men inte `provider_quota` (modellen).
- **Röd först:** bara ett test kunde köras rött mot main: `tts_quota` i `unavailableCodes` (`angela/k124-test-rod`, `LumenTests/K124RedTests.swift`). Resten använder nytt API och kompilerar inte mot main.
- Telefonens röst skriver inga ljudfiler i testerna (`makesSound: false`); testet skriver tysta filer själv. Att AVSpeechSynthesizer gör riktiga filer på en telefon är *untested assumption* för den här vägen. Samma kod har använts i låtsasläget på simulatorn.

## Kända begränsningar

- **Provets kostnadsrad står kvar.** Ett prov som inte är startat visar "Kostar … krediter" innan man trycker Starta prov, också när telefonen sedan läser och inget dras. Det är Angela Fables vy; rad till henne.
- **Två röster i samma prov** när servern hann göra några frågor innan kvoten tog slut: de frågorna har ElevenLabs-rösten, resten telefonens.
- **Tobys `FullFlowTests`, läget "unavailable",** väntar sig "Uppläsningen är tillfälligt avstängd" efter Starta prov. Nu kommer "Telefonens röst läser just nu." och spelaren. Rad till Toby.
- **När kvoten är tillbaka** frågar appen servern igen när provet öppnas eller appen kommer tillbaka (A112), och nästa Starta prov gör ElevenLabs-ljudet.

## Nästa steg

- Aron på telefon, medan ElevenLabs-kvoten är slut:
  1. Säg i AirPods med en kort text → Spela.
  2. Det ska höras med telefonens röst, och raden "Telefonens röst läser just nu." ska synas.
  3. Ett sparat prov utan ljud → Starta prov: frågorna ska läsas upp.
