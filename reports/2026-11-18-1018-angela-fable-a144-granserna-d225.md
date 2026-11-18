# A144 (D225): gränserna när Spela väntar på en ny text (Angela Fable, moln)

Klart 2026-11-18 10:18. **Verifierat i CI: iOS build 44268556092 grön på min gren (enhetsbygge, varningar som fel,
LumenTests). Inte sett på bild, inte provat mot servern och inte på enhet.** 0 ElevenLabs.

## Vad som är byggt
- **Efter 8 sekunder** utan svar står "Det tar längre tid än vanligt." under fältet. Det är inget fel: snurran går
  kvar och Spela fortsätter vänta.
- **Efter 25 sekunder** ger Spela upp: "Ljudet kunde inte hämtas." och knappen Försök igen.
- **Vet telefonen att nätet saknas** ger den upp direkt, med "Ljudet kunde inte hämtas. Kolla nätet."
- Ljud som redan finns på telefonen spelas direkt och kommer aldrig hit.
- Kommer svaret mellan 8 och 25 sekunder spelas texten och raden försvinner. Efter att Spela gett upp startar
  inget av sig självt (som förut).

## Två saker att veta
- **Felraden med nätet uppe är "Ljudet kunde inte hämtas."** utan "Kolla nätet." D225 citerar raden så, och jag ville
  inte skylla på nätet när det är uppe. Kelly har inte sett just den varianten.
- **Första bygget föll utan att något test körde:** simulatorn gav upp direkt efter "Testing started", utan ett enda
  testresultat. Omkörningen av samma kod gick grön. Jag har inte sett orsaken.

## Tester
`LumenTests/A122LockedPhoneTests.swift`: tyst före 8 s, raden från 8 s, ger upp vid 25 s, och direkt utan nät.
`A136StyleVoicePaceTests`: orden. Regeln är en ren funktion (`SayText.wait(after:online:)`), så tiderna är fejkade.
Själva väntan i vyn (en koll per sekund) är inte testad.

## Sedan i morse, i samma push
- Main är grön med Tobys T48-rättning (44267230197) och med pilen på Försök igen (44267482417).
- Senaste-kapselns tillägg finns på bild: `reports/2026-11-18-granskning-bilder/senaste-stil-rost.jpg`
  ("1918: Vapenstillestånd. · Lugnt").

## Kvar hos andra
Kevin gör save och start snabbare (K100), Angela Schrute tar inloggningen som höll tillbaka Spela (A143).

## Tillägg 10:35: ett anrop i stället för två (Kevins K100)
- En ny Säg-text sparas och startas nu i **ett anrop** (`save` med `start: true`). Kevin mätte cirka 1,5 s mot
  servern, mot 9–10 s för de två anropen tidigare. Prov med frågor, och en server utan det nya anropet, går den
  gamla vägen. **iOS build 44274972565 grön på min gren**; test i `A136StyleVoicePaceTests`. Appen har inte kört
  anropet mot servern.
- **Mitt fel 10:20:** jag pushade konfliktmarkörer i `prompts/queue/angela-fable.md` till main (sammanfogningen gav
  en konflikt, och mitt skript gick vidare). Rättat några minuter senare; Kevins K100-rad står kvar som egen rad.

