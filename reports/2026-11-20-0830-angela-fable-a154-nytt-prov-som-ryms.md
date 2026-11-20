# A154 – Nytt prov som ryms i krediterna, och välkomsten (D239, D241) (Angela Fable (moln), 2026-11-20 08:30)

Oscars O90: ett nytt konto har 1 500 krediter, men appen föreslog 20 frågor (cirka 9 800 krediter), och ett prov
nekades först efter att frågorna hade gjorts. Uppdraget: aldrig ett prov som först görs och sedan nekas.

## Vad som är gjort

1. **Standarden är 12 frågor** i stället för 20 (`Drill.defaultQuestionCount`).
2. **Appen läser serverns nej före genereringen** (Kevins K109/K110: 402 med `fits`, `min_questions`,
   `per_question`). Inget har då gjorts och inget dragits. Appen minns vad servern sa att en fråga kostar.
3. **Ryms minst tre frågor** sänks antalet till det som ryms, och Nytt prov säger "Krediterna räcker till 5 frågor."
   med knapparna "Skapa 5 frågor" och "Fyll på". Stegaren går sedan inte över det som ryms.
4. **Ryms färre än tre** föreslås inget prov. Överst står "Du har 1,5k krediter. Det räcker inte till ett prov (minst
   3 frågor)." med "Fyll på", och Skapa frågor är avstängd med raden "Krediterna räcker inte till ett prov." (D241).
5. **"Fyll på" öppnar krediter-bladet.** När det stängs läses krediterna om och antalet sätts till det som ryms nu
   (aldrig över 12).
6. **Kostnaden frågas före sparandet** ("annars kostnaden före sparandet"). "Ser rätt ut" frågar servern vad det
   färdiga provet kostar. Räcker krediterna inte sparas provet inte; det står kvar med "Det här kostar … Du har …
   kvar." och "Fyll på". Får appen inget svar (inget nät) sparas provet som förut.
7. **Raden under Skapa frågor** sa "3,3k av 1,5k krediter kvar den här månaden" för ett konto med köpta eller givna
   krediter. Nu står "3,3k krediter kvar" när det finns mer kvar än månadens egna.

**Välkomsten (del 2) var redan rättad på main** av Angela Schrute i går kväll (e6b19b3a, efter Oscars O90): en 503 eller
ett nätfel räknas inte som ett försök, och gamla försök glöms. Jag hade skrivit samma sak på min gren, upptäckte det
när jag slog ihop main, tog hennes version och behöll bara tre tester som prövar regeln med A154:s ord.

Beslutet står i DECISIONS (D248).

## Tekniska detaljer

- `DrillServices.swift`: `DrillMakingError.tooFewCredits(ExamRefusal)`; `DrillClient.refusal` läser `fits`,
  `min_questions`, `per_question`, `cost`, `remaining` ur ett 402. `ExamRoom` (pris per fråga, minsta antal, svarens
  längd): `fits(left:)`, `canMakeAnExam`, `covers(cost:left:)`.
- `RepetitionModel.swift`: `make` sparar serverns pris i `examRoom`; `newDrillFits`, `newDrillHasNoRoom`,
  `newDrillRoomLine`, `examCost(_:)`; `newDrillSettings` och `newDrillQuestionRange` följer det som ryms. Priset
  gäller bara för den svarslängd det räknades för (Inställningar › Avancerat).
- `NewDrillView.swift`: raderna överst, "Fyll på", kostnadskontrollen i `save`.
- `DrillCloud.swift`: `/drill quota` skickas med `long_words`, och ett fält `exam` läses om servern skickar det.
  **Servern skickar det inte i dag.** Jag har bett Kevin om det; med det kan Nytt prov säga vad som ryms redan när
  det öppnas. Utan det får appen veta det när användaren trycker Skapa frågor (serverns nej kommer på cirka 1 s).

## Testresultat

- **Testerna skrevs först.** `LumenTests/A154ExamRoomTests.swift`, 15 tester: standarden, serverns nej med och utan
  `fits`, vad som ryms, Nytt prov efter nejet (5 av 12, färre än 3, konto utan gräns, annan svarslängd), kostnaden
  före sparandet, raden om vad som är kvar, välkomsten (503, nätfel, riktigt nej, gamla försök). Tre äldre tester som
  väntade sig 20 frågor är ändrade till 12.
- **Verifierat i CI:** iOS build 44695356529 på min gren är grön (bygget för enhet utan varningar, alla
  enhetstester, Release-bygget), med main ihopslaget. Main-bygget: se tillägget nedan.
- **Sett i Simulator (bilder), inte på enhet:** `reports/2026-11-20-a154-bilder/nytt-prov-ljust.jpg` och
  `nytt-prov-morkt.jpg` (iPhone 17 Pro). Från vänster: inget prov ryms (1 500), fem frågor ryms (3 300), och den
  gamla skärmen för slut på frågor som jämförelse. Bilderna togs före ändringen av raden under knappen, så
  "3,3k av 1,5k" syns i den mittersta.
- **Inte prövat mot servern.** Serverns nej är Kevins riktiga svar inklistrat i testet (K110, körning 44591156654),
  men appen har inte fått det från servern i en körning. Kostnadskontrollen före sparandet är inte körd utanför
  testerna.
- 0 ElevenLabs.

## Kända fel, begränsningar, risker

- **Ett nytt konto med 1 500 krediter kan inte göra något prov** förrän välkomsten (5 000) är på, vilket kräver Team
  ID på servern (Kevins K110, TILL-ARON #31). Appen säger det nu tydligt, men det är fortfarande det första en ny
  användare möter i Nytt prov.
- Första gången får användaren veta vad som ryms först efter att ha valt material och tryckt Skapa frågor. Det löses
  av fältet jag bett Kevin om.
- "Skapa 5 frågor" i raden och "Skapa frågor" längst ner gör samma sak. Kelly får säga om en ska bort.
- Kostnadskontrollen lägger ett serveranrop före sparandet; knappen visar att den arbetar under tiden.
- Orden i de nya raderna är mina; Kelly har inte granskat dem.
- I välkomstregeln på main räknas en 429 (för många anrop) som ett nej. Det är osannolikt där, och det är inte min
  kod; jag nämner det bara.

## Kvar

- Kellys granskning av orden och bilderna.
- Tobys T55 mot main: ett nytt konto ska få raden och "Fyll på" i stället för ett tyst nej.
- Kevins fält i `/drill quota` (`exam`), om han lägger till det.

## Nästa session

Läs Kellys och Tobys svar. När Kevin säger att `exam` finns i `/drill quota`: kontrollera att Nytt prov säger vad
som ryms direkt när det öppnas (koden finns i `refreshQuota`).

## Tillägg 09:10: Kellys granskning av orden (kop.md §7), inlagd

- **Inget prov ryms:** raden säger nu vad det minsta provet kostar: "Ett prov med 3 frågor kostar cirka 2,0k
  krediter. Du har 1,5k." med "Fyll på" under. (Talet är serverns pris per fråga gånger tre.) Raden under den
  avstängda knappen står kvar.
- **Fem ryms:** "Skapa 5 frågor" är borta ur rutan. Knappen längst ner heter i stället "Skapa 5 frågor", så det finns
  en knapp som skapar. Rutan är "Krediterna räcker till 5 frågor." och "Fyll på".
- Raden före sparandet och "3,3k krediter kvar" är godkända som de är.
- Väljer man Läs upp texten spärrar rutan om prov inte; så var det redan (rutan och spärren gäller bara Frågor).
- Bilderna i `reports/2026-11-20-a154-bilder/` är från före de här ändringarna. **De nya orden är inte sedda på bild.**

## Tillägg 09:50: byggena på main, och Kellys godkännande

- **A154 är grön på main:** iOS build 44698909566 (bygget för enhet, alla enhetstester, Release-bygget).
  **Verifierat i CI.**
- **Kellys ord:** bygget 44699128469 på main har byggt för enhet och kört alla enhetstester gröna; Release-steget
  kör när detta skrivs och är inte avläst.
- **Kelly har godkänt orden** (09:01) och vill inte ha nya bilder (D217). De nya orden är alltså inte fotade.
- **10:25: bygget 44699128469 (Kellys ord) är helt grönt på main**, också Release-steget. **Verifierat i CI.**

## Tillägg 10:55: första körningen mot riktiga servern visade ett fel i A154, rättat

Tobys T55 44708423048 (granskarens väg, nytt konto, riktig server, appen från main 10:10). **Läst i CI-loggen.**

- **Serverns nej före genereringen prövades inte.** Körningar från GitHub Actions med testhuvudet hoppar över
  uppskattningen (Kevins undantag för mätningar, K109), så servern gjorde 5 frågor av texten trots 1 406 krediter.
  Vägen med `fits` är alltså fortfarande bara prövad i enhetstester. Den går att pröva med `user-path` i testhuvudet.
- **Kostnadskontrollen före sparandet stoppade provet, som den ska:** efter "Ser rätt ut" stod formuläret kvar och
  inget prov sparades. Förut hade provet sparats och nekats.
- **Men raden syntes inte.** Den stod sist i formuläret, nedanför skärmen, så "Ser rätt ut" såg ut att inte göra
  någonting. Det är mitt fel i A154.
- **Rättat:** raden ("Det här kostar … Du har … kvar.") och "Fyll på" står nu först i formuläret, formuläret rullar
  dit, och under knappen står "Krediterna räcker inte till provet." **Inte sett på bild eller i en körning än**;
  Tobys nästa T55 visar det.

## Tillägg 11:35: belägg ur Tobys T55 44712185537 (riktig server, koden före rättningen)

**Läst i CI-loggen (Simulator mot riktiga servern), inte på enhet.**

- Kostnadskontrollen före sparandet: efter "Ser rätt ut" stod "Det här kostar 2,5k krediter. Du har 1,5k kvar. Nya
  krediter den 1 december." med "Fyll på", och "Fyll på" öppnade krediter-bladet. Provet sparades inte.
- Raden låg nedanför skärmen ("found after 1 drags", "nothing visible changed at the button"). Det är felet som
  rättades 10:55; rättningen är inte sedd i en körning än.
- **Till Kevin:** tre frågor kostade här cirka 2,5k, mer än gränsen i K110 (642 per fråga, 1 926 för tre). Körningen
  gick förbi uppskattningen (testhuvudet från Actions), så inget nej kom före genereringen; men om en verklig kostnad
  kan ligga över gränsen är `fits` inte en garanti. Appens kontroll före sparandet fångar det i så fall.
- Main-bygget med rättningen, 44714865507: bygget för enhet och alla enhetstester är gröna; Release-steget kör när
  detta skrivs och är inte avläst.

## Tillägg 12:01: rättningen grön på main, och Kevins fråga om kostnaden

- **iOS build 44714865507 på main är helt grön** (raden om kostnaden först i formuläret och vid knappen).
  **Verifierat i CI.** Rättningen är fortfarande inte sedd i en körning eller på bild.
- Kevin frågade vilken svarslängd körningen 44712185537 hade, eftersom 2,5k för tre frågor stämmer med "Längre"
  (130 ord) men inte med "Normal". **Appen skickade 90** i alla fyra anropen (läst i koden; Tobys test ändrar inte
  inställningen). Svaret står i `prompts/queue/kevin.md`, med en möjlig orsak som jag inte kan belägga härifrån:
  appen sätter det korta svaret först i det långa om serverns långa svar inte redan börjar med det, vilket kan göra
  det långa svaret längre än de 90 ord servern räknade med. Kevin kontrollerar efter 16:00.
