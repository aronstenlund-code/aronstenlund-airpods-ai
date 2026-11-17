# D215 i logiken: en Säg-text är inget prov i provlistan eller i påminnelsen

Angela Schrute (moln, Fable 5.2), 2026-11-17. På main i d01713d3 och add68438. Efter en fråga från Angela Fable
om A132 (D215) påverkar min kod.

## 1. Vad som var fel
Sedan A132 är en text sagd i "Säg i AirPods" inget prov: den är aldrig "Nästa prov" och står inte bland "Andra
prov". Två ställen i logiken behandlade den fortfarande som ett prov:
- **Provläges provlista (D189).** Varje repetitionsprov speglas som ett prov som Provläge och Mina svar läser. Också
  Säg-texterna speglades, så en text som "Hej hej hooooo" blev ett prov där.
- **Övningspåminnelsen (D194).** Påminnelsen nämner och öppnar "senaste provet", alltså det som övades sist. Var det
  en Säg-text, nämnde och öppnade påminnelsen den.

När jag läste koden hittade jag ett tredje fel, som är mitt eget från A108:
- **Reservvalet tog det äldsta provet.** När inget var övat än skulle påminnelsen gälla senaste provet. Listan är
  sorterad med nyaste först, och koden tog det sista i listan, alltså det äldsta.

## 2. Rättningen
- `ExamPlanStore.sync(with:)`: Säg-texter blir inga prov i listan. En Säg-text som redan hade speglats försvinner ur
  listan vid nästa synkning. Texter gjorda med "Läs upp en text" är fortfarande prov.
- `RepetitionModel.reschedulePracticeReminders`: påminnelsen gäller aldrig en Säg-text. Om det som övades sist var
  en Säg-text, eller om inget är övat, gäller den det nyaste provet.
- Inga vyer är rörda. Att lyssna på en Säg-text räknas fortfarande som övning den dagen (D194 är oförändrat där).

## 3. Tester
- Nytt: `T24OneExamListTests.aSaidTextIsNoExamInProvlage`. Säg-texter, också de från före märket, blir inga prov. En
  uppläst text blir det.
- Nytt: `A108PracticeStreakTests.theReminderIsForTheLatestExamNeverForASaidText`. Påminnelsen gäller provet också
  när Säg-texten övades sist, och det nyaste provet när det finns flera.
- **Mitt första test var fel:** det antog att listan var sorterad med äldsta först. Det hade fallit i CI. Det är
  rättat i add68438, och bygget för d01713d3 hann aldrig köra.
- **CI: iOS build 44151590219 grön** på main (add68438), med båda de nya testerna. *Verifierat i CI.*
- 0 ElevenLabs. Inget är provat på telefon.

## 4. Vad Aron kan prova på telefon
1. Säg en text i "Säg i AirPods". Öppna sedan Provläge (Fler lägen). Texten ska inte stå som ett prov där.
2. Ha ett prov och en Säg-text. Lyssna på Säg-texten sist på dagen. Nästa dags påminnelse ska nämna provet, inte
   texten, och öppna provet.

## 5. Kvar
- Mina svar som hörde till en Säg-text som har speglats som prov ligger kvar i lagret men syns inte. Det är samma
  regel som för ett borttaget prov (D189). Säg till om de ska rensas.
