# Ke93: Kellys fem saker efter bilderna av första gången och A167

Angela Fable (moln), 2026-11-27. Kellys rad 02:03 i min kö (fable/screens-first-time och A167, SE med största text).

## Vad som är gjort

1. **"Du kan låsa telefonen. Det hörs i AirPods ändå."** sägs inte längre på Säg-kortet. Raden är inte provad på
   telefon (D209, TILL-ARON #29). Den finns kvar i koden bakom `SayText.saysLockLine = false`; när Aron har hört en
   text gå vidare med telefonen låst sätts den till `true`. Kortet blir då bara fältet och knapparna.
2. **Nytt prov i mörkt läge:** på mina bilder (fable/screens-first-time, `en-dark-repHomeEmpty`) har knappen redan
   mörk text på den ljusa accenten (`FilledButtonLabel`, A95). Inget ändrat; jag har frågat Kelly vilken bild hon såg.
3. **Tomma Start:** de tre lösa blå länkarna är nu rader i ett kort med ›, som på Start med prov: **Spela in själv ·
   Helt gratis**, **Prov från din skola**, **Öppna länk** (och **I natt** när den finns). Skärmen har samma grå grund
   som Start med prov.
4. **Spela in själv med största text:** bara **Öva** är fast längst ner; raden "Helt gratis. Ljudet stannar på din
   telefon." står sist i listan och rullar med den. Vid vanlig textstorlek står den kvar under knappen.
5. **Lanseringsbladet** säger rabatten en gång ("65 % rabatt på allt den här veckan."): den stora siffran överst är
   en etikettsymbol i stället. Märket i butiken skrivs med minustecken: "−65 %".

## Test

- A161:s test väntar nu "−65 %" (minustecken).
- KÖRNINGEN
- BILDERNA
- 0 ElevenLabs.

## Påverkar andra

- Tobys E2E: skärmturen (`ScreenTourTests.swift` rad 169) letar efter "Hitta prov från din skola" på tomma Start; raden
  heter nu "Prov från din skola" (som på Start med prov). `SayFlowTests.swift` rad 120–122 noterar att raden om låst
  telefon saknas (en notering, inget fel). Rad i hans kö.
