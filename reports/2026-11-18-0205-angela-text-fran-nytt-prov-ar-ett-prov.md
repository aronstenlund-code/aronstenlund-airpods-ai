# En text från Nytt prov är ett prov, inte en Säg-text (fynd i Tobys T51)

Angela Schrute (moln, Fable 5.2), 2026-11-18 01:45–02:05. Main, commit 00452053. Inte en köpunkt: felet hittades
när jag läste loggarna från Tobys omkörning av T51 (44198544586).

## 1. Felet
- En text som görs i Nytt prov med **Läs upp texten**, utan namn, ämne och årskurs, blev inget prov på Start. Den
  låg bara som en kapsel under Senaste i Säg-kortet, och det fanns ingen Starta prov.
- Orsak: servern döper en namnlös text efter första rubriken (`backend/supabase/functions/exam/read.ts`). Det är
  samma namn som Säg-fältet ger en text. `Drill.isSaid` (A132) känner igen Säg-texter från före märket `said` på
  just det: en text utan ämne, årskurs och innehåll, döpt efter sina första ord. *Verifierat i koden.*
- Felet kom med A132 (2026-11-17) och fanns på main. Det har inget med A137 att göra.
- Vem som träffas: den som inte har valt årskurs (tryckt Senare vid första starten), inte skriver något namn, och
  vars text börjar med en rubrik. Tobys T28 gör precis så.

## 2. Rättningen
- `DrillTextDraft.drill` (`Lumen/Core/Repetition/DrillServices.swift`) märker texten `said = false` när den görs i
  Nytt prov. Regeln för gamla Säg-texter gäller bara texter utan märke, så den träffar inte längre.
- Nytt test: `A122LockedPhoneTests.aTextFromNyttProvNamedAfterItsHeadingIsAnExam`. Det visar att texten utan märke
  tas för en Säg-text, och att texten från Nytt prov inte gör det.
- `Drill.swift` och vyerna är orörda (Angela Fables filer); hon har fått besked.

## 3. Testresultat
- **CI:** iOS build 44212887216 på main (00452053) — resultatet står nedan.
- Inte provat på telefon. Inte kört som flöde än; Tobys T28 prövar det när han kör om.
- 0 ElevenLabs.

## 4. Kvar, inte gjort
- **Märket `said` skickas inte till servern.** En text som hämtas från molnet till en ny telefon, eller ett delat
  textprov utan ämne, har inget märke och bedöms av samma regel. Då kan ett textprov bli en Säg-text, eller en
  Säg-text ett prov. Det säkra är att servern sparar märket. Det är en punkt för Kevin och Angela Fable som
  Deangelo får lägga ut; jag har inte gjort något åt det.
- Texter som redan har sparats med felet på en telefon (mellan A132 och den här rättningen) har inget märke och
  ligger kvar under Senaste. Appen är inte släppt, så det gäller bara testtelefoner.

## 5. Vad Aron kan prova på telefon
1. Nytt prov → fota eller klistra in en text som börjar med en rubrik → Läs upp texten → skriv inget namn → Skapa
   uppläsning → Ser rätt ut. Texten ska stå som prov på Start med Starta prov, inte bara under Senaste.
