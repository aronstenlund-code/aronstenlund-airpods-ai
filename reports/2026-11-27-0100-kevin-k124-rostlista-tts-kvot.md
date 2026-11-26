# Kevin (moln) – K124 (D267): röster utan provljud och när ElevenLabs tar slut

**Datum:** 2026-11-27 01:00. **Uppdrag:** Deangelo 00:46.
**Regler:** 0 ElevenLabs (låtsas-ElevenLabs i alla tester), inga modellanrop. **Svit:** 904/904. **Driftsatt:** deploy 386.

## (1) Oscars G2: röster utan provljud visas inte

- `GET /voices` listar för vanliga användare bara katalogröster som har ett https-`preview_url`, det vill säga ElevenLabs gratis provljud. Granskarens "previews are free" stämmer därmed.
- Admin ser fortfarande alla röster, så katalogen går att rätta.
- Inget provljud görs och inget nytt ElevenLabs-anrop sker.
- Standardrösten fungerar som förut även om den saknar provljud. `default_voice` är oförändrat.
- Test: `voices/voices_test.ts`. K99-fixturen fick provljud, så att den fortfarande testar granskningsrösterna.
- **Live:** LIVE_HÄR

## (2) /tts och drillens ljud när ElevenLabs-kvoten är slut

| | Före | Efter K124 |
|---|---|---|
| ElevenLabs säger att kvoten är slut (401 eller 402 `quota_exceeded`), eller att det är för lite kvar för texten ("You have 12 credits remaining, while 40 are required") | 503 `provider_quota` | **503 `tts_quota`, `fallback: true`**. Text på svenska: "Uppläsningen med rösten är slut för tillfället." På engelska: "Reading aloud with the voice is not available right now." |
| Användarens teckenbudget för /tts | räknades trots att inget ljud gjordes | **ges tillbaka** (minut- och dygnsfönstret; det globala fönstret behåller sin räkning) |
| Nästa anrop efter ett nej om kvoten | gick till ElevenLabs igen | **svarar `tts_quota` direkt i 10 minuter**, utan ElevenLabs-anrop och utan att räkna tecken. Därefter görs ett nytt försök. |
| Drillens ljud när ElevenLabs är slut | krediterna gavs tillbaka (K78), `audio_unavailable` | samma, plus **`tts: {code: "tts_quota", fallback: true}`**. Sparandet är fortfarande 200, eftersom texten fungerar som vanligt. |

- Test: `tts/k124_quota_test.ts` (tre fall), `tts/handler_test.ts` (koden ändrad till `tts_quota`) och `drill/handler_test.ts` (K124).
- Live: ett nej om kvoten kan inte visas utan en riktig ElevenLabs-dragning. Testtrafiken får alltid tyst testljud (D180). Allt ovan är därför verifierat i test.
- "Nästan slut" täcks av ElevenLabs eget nej när det som finns kvar inte räcker till texten.
- Det finns ingen förhandskontroll av saldot (`/v1/user/subscription`). Den skulle vara ett extra ElevenLabs-anrop per uppläsning eller per period. Kan läggas till med ett tak, till exempel "under 2 000 tecken = `tts_quota`", om Deangelo vill.

## Till Angela Schrute

Rad i `prompts/queue/angela.md`: när `/tts` svarar `tts_quota`, eller drillens svar har `tts.code == "tts_quota"`, läser appen upp med telefonens egen röst (AVSpeechSynthesizer) och säger det kort. Det gamla `provider_quota` på /tts finns inte längre.

## Nästa

- Angela: appens del.
- Oscar kan pröva /tts-koden med låtsas-ElevenLabs i K122 om det behövs. Live går det inte utan att dra krediter.
