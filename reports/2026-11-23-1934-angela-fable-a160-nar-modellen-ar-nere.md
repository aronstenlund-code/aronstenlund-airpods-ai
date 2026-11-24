# A160 (D258, D260): öva sparade prov när modellen bakom EarMind är nere

Angela Fable (moln), 2026-11-23. Beställt av Deangelo 19:17. Bara iOS-appen på main; webbetan är orörd.

## Viktigt först: var rättningen finns

Uppdraget säger "repetitionsvyerna". I repetitionsflödet (Start, Nytt prov, spelaren) finns ingen rättning av
användarens svar: där spelas frågan upp och man trycker fram svaret. Rättning finns på två ställen, båda under
Fler lägen (lägena som lyssnar): **Provfrågor** (övningsprovet) och **provsessionen**, som båda frågar `/exam`
(`grade`). Punkt 2 är därför byggd där rättningen finns. Punkt 1 och 3 gäller repetitionsflödet som beställt.

## Vad som är gjort

1. **Sparade prov går att öva som vanligt.** De behöver inte modellen: ljudet finns redan, och Starta prov frågar
   bara om ljudet. Inget är ändrat där; ett test håller fast att ett sparat prov startar som förut medan modellen
   är nere.
2. **Svaret rättas av telefonens modell när serverns modell är nere.** När `/exam` svarar 503/502 med en
   `provider_*`-kod rättar Apples modell på telefonen (Foundation Models, guided generation): rätt, delvis eller
   fel och en mening, på språket man pratar. Det sägs och visas som "Telefonens modell: Rätt. …" /
   "The phone's model: Right. …"; vid delvis och fel följer facit. Rätt ger uppgiftens poäng, delvis hälften, fel
   inga. **Finns ingen modell på telefonen**, kan den inte språket eller ger den inget, visas facit utan rättning
   med Deangelos rad: "Facit visas – rättningen är tillbaka när EarMind kan svara igen." / "Showing the answer –
   grading is back when EarMind can answer again." Frågan räknas då som överhoppad, inte som fel.
3. **Nytt prov kan inte skapas, och knappen säger det.** Efter serverns nej står det på knappen "Kan inte skapa
   prov just nu" med raden "Sparade prov går att öva. Försök igen om en stund." (engelska: "Can't create quizzes
   right now" / "Saved quizzes still work. Try again in a moment."), i stället för ett felmeddelande. Efter två
   minuter är knappen sig själv igen och ett tryck frågar servern på nytt; lyckas ett prov försvinner raden direkt.
   Materialet man lagt in ligger kvar.
4. **Inga krediter dras.** Serverns nej kostar inget, och för telefonens rättning skickas ingenting.

## Teknik

- `Lumen/Core/Study/AnswerGrader.swift` (ny): `LocalGrade`, protokollet `AnswerGrading`, `OnDeviceGrader`
  (guided generation med `@Generable`: ett av tre omdömen och en mening) och `PhoneGradeText` (orden runt
  rättningen och facit, på talspråket).
- `Lumen/Core/Study/ExamMaterials.swift`: `ExamClient.grade(…, language:)` skiljer på "modellen är nere"
  (`provider_*`) och andra fel. `Graded.by` säger vem som rättade (`phone`, `keyOnly`; nil = servern). Andra fel
  ger som förut ingen rättning.
- `PracticeExamController` och `ExamSessionController` (Angela Schrutes lägen): skickar talspråket och hanterar
  facit utan rättning. Inget annat är ändrat där.
- `DrillMakingError.modelDown` (i stället för ett vanligt nekande), `RepetitionModel.modelIsDown()` och
  `NewQuizText`; `NewDrillView` visar det på knappen.
- **Gemensam on-device-hjälpare:** `Lumen/Core/Answer/OnDeviceModel.swift` är Angela Schrutes (A159), tagen
  oförändrad från hennes gren. Min rättare frågar om modellen finns genom den, och i testbyggen gäller hennes
  startargument `-OnDeviceMock sv,en | none` också rättningen (för Tobys T57).

## Test

- **Skrivna först:** `LumenTests/A160ModelDownTests.swift` (13 tester) med låtsasserver (503 `provider_quota`,
  502 `provider_unavailable`) och låtsasrättare: telefonen rättar (rätt, delvis, fel; svenska och engelska; uppgift
  utan poäng); facit med raden när modellen saknas, inte kan språket eller inget ger; serverns rättning används när
  den svarar; andra fel ger ingen rättning; serverns nej känns igen som "modellen nere"; knappens ord, tvåminuters-
  fönstret och att ett sparat prov startar som förut; orden på båda språken. Eftersom CI är kompilatorn har jag
  inte kört dem röda först i en egen körning (det hade kostat ett Mac-bygge till).
- **iOS build 45236692487 på min gren: enhetsbygge utan varningar och alla enhetstester gröna (13 nya).** Verifierat i CI (Simulator). Första försöket fick ingen Mac hos GitHub
  ("The job was not acquired by Runner"), så körningen startades om; det var inget fel i koden.
- **Foundation Models finns inte i CI-simulatorn** (D258 punkt 5): den riktiga rättningen är inte körd någonstans.
  `@Generable`/`@Guide` och `respond(to:generating:)` är kompilerade mot SDK:n men otestade mot en riktig modell.
- 0 ElevenLabs (D180).

**Tillägg 2026-11-24 22:25:** iOS build 45484689536 på min gren grön i sin helhet (enhetsbygge utan varningar, alla enhetstester, App Store-arkivet). Bygget innehåller A160, A161 och A163 tillsammans med Angela Schrutes A159 och
A162 från main. Rättaren frågar efter telefonens modell genom Angela Schrutes `OnDeviceModel` (hennes fil,
oförändrad); körningarna i går fick två gånger ingen Mac hos GitHub och avbröts, därav dröjsmålet.

## Kända brister och risker

- **Otestat på telefon.** Kräver en iPhone med Apple Intelligence påslaget (15 Pro eller senare) för rättningen.
- Telefonens modell är svagare än serverns; därför sägs alltid "Telefonens modell:" före omdömet.
- Raderna runt rättningen följer språket man pratar (svenska/engelska), inte appens språkval, som resten av det
  lägena säger högt.
- Knappen i Nytt prov vet först efter ett försök att modellen är nere (servern har ingen egen fråga för det).
- "Låt EarMind skriva svaret", "Gör om med rättelsen" och Fråga om EarMind säger som förut O97-raden.

## Farhågor

Inga nya.

## Kvar / nästa session

- Arons telefonprov: Provfrågor med modellen nere (rättning från telefonen), och på en telefon utan Apple
  Intelligence (facit med raden).
- Om rättning önskas i repetitionsflödet (skriva eller säga ett svar till ett sparat prov) är det en ny funktion
  och en egen punkt.
