# T10 del 1: När ElevenLabs ligger nere (Toby, 2026-11-10 17:10)

**Allt här kommer från simulatorn (iOS 26.5, iPhone 17 Pro) och är inte verifierat på en enhet.** Ingen egen simulering
behövdes. ElevenLabs-kvoten är slut på riktigt i dag: Scribe svarar `quota_exceeded`/429 och `/tts` är tom. Underlaget
är T8-körningen [42825446414](https://github.com/aronstenlund-code/aronstenlund-airpods-ai/actions/runs/42825446414) på
main `f557d2a` (A45 ingår). Den körde två vägar från ny installation (hoppa över provet och lägg till prov). Varje
skärms texter loggades.

## Resultat
| Krav i T10 | Resultat | Märkning |
|---|---|---|
| Appen går över till iPhonens taligenkänning | Den försöker. Skärmen säger "Taligenkänningen gick ner. Lumen försöker igen av sig själv", eftersom iPhone-igenkänningen inte går i simulatorn. Om den tar över på telefonen är **inte visat** | untested assumption |
| Appen blir inte döv | **Kan inte avgöras i simulatorn.** Inga svar kom på 60 s (Standardläge) eller 90 s (Provläge) i någon väg | – |
| Appen blir inte tyst (iPhonens röst) | Inget svar kom, så ingen röst hördes. Otestat | untested assumption |
| A45:s rad visas en gång | **Ja.** "Lumen hör och pratar lite sämre just nu" fanns som en rad per session, i både Standardläge och Provläge, aldrig dubbel | simulator |

## Fynd
1. **Första frågan säger bara "Lyssnar" i 60 s** när taligenkänningen inte fungerar (bild 01). Där finns ingen A45-rad
   och inget "Jag hör inte". En ny användare tror att appen hör och väntar förgäves. Det är den första skärmen man
   möter, så ett ElevenLabs-avbrott ser ut som att appen inte fungerar.
2. **Standardläge visar "Lyssnar" och "Jag hör inte just nu" samtidigt** (bild 02, skärmen efter första starten).
   Statusraden och kortet säger emot varandra. Provläge visar i stället "Hör inte, försöker igen" (bild 03), vilket
   stämmer med kortet.
3. Raden "Lumen hör och pratar lite sämre just nu" och kortet "Jag hör inte just nu" visas båda. Den första säger att
   det går sämre, den andra att det inte går alls. Vilken gäller? Det är ett förslag till Kelly: visa en av dem.

## Kvar i T10
- **Telefon:** med kvoten slut, eller utan nät till ElevenLabs, ställ en fråga och kontrollera att iPhonens
  igenkänning tar över och att svaret läses upp med iPhonens röst. Det kan bara Aron göra. Steget passar i
  `docs/DEVICE-TEST-QUICK.md`, och nästa session lägger till det.
- **Simulatorn med 503:** ett test som får `/stt-token` och `/tts` att svara 503 i stället för slut kvot. Det kräver en
  testkrok i appen. Om det behövs frågar jag Angela i nästa rapport.

## Till Angela
- Fynd 1 och 2: visa "Hör inte" (eller A45-raden) även på första frågan, och låt statusraden följa kortet.

## Till Kelly
- Fynd 3: två meddelanden för samma avbrott.

Bilder: `reports/apptest/2026-11-10-t10-elevenlabs-nere/`.
