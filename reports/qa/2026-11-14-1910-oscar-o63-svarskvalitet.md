# O63: svarskvaliteten i repetitionsläget på 6 nya hållout-prov (Oscar, 2026-11-14 19:10)

Status för varje påstående: **verifierat live** (mot driftsatt `/exam`, `/drill` och `/provlage-eval`), **verifierat i docs** eller **antagande, ej testat**.
Ingen app eller enhet. Allt gick via testkonton (`scripts/qa/qa_testaccount.py`), med falskt ljud och **0 ElevenLabs-krediter** (sparade prov: `credits` 0 eller tomt). Claude **0,72 USD** (frågor 0,22 och domare 0,51), under taket på 1 USD.

## Kort
- **Arons krav (tydligt nog för att inte behöva upprepa sig, och A-nivå också i åk 7–9) håller i stort, men inte helt.**
  - **Långa svaret:** rätt fakta i 67/69 och A-nivå i 66/69 för hand. Domaren gav 64/69 och 66/69.
  - **Korta svaret** (första meningen ensam): fullgott i 64/69 för hand. Domaren gav 42/69, men den kräver hela A-djupet i en mening (samma okalibrerade stränghet som i O57).
- **R3 förståelsefrågor:** 74 % för hand (krav minst 70 %). Ordregeln ger 70 % (48/69), och den är en undre gräns.
- **Längdklass normal: 69/69 enligt servern** (krav minst 90 %). Max 735 tecken.
- **Påhittat ur materialet:** 0 frågor som är rena påhitt. Men 1 fråga har en premiss som strider mot materialet, och 2 frågar varför där materialet inte har något svar. Det är de sämsta nedan.
- **De 5 sämsta** står nedan. Tre av dem har samma orsak: frågan kräver en förklaring som materialet inte innehåller, och då blir svaret cirkulärt.

## Proven
`scripts/qa/repetition_bank/materials_holdout3.py` är ny, påhittad och aldrig använd förut. 12 frågor begärdes per prov, utan ämne och årskurs i anropet.

| Prov | Format | Årskurs i materialet → läst | Frågor | Långa rätt / A (för hand) | Korta fullgoda (för hand) |
|---|---|---|---|---|---|
| Historia, franska revolutionen | 5 foton | åk 8 → åk 8 | 12 | 12 / 12 | 11 |
| Kemi, atomer | docx | åk 7 → åk 7 | 9 | 8 / 9 | 8 |
| Samhällskunskap, riksdagen | PDF | åk 9 → åk 9 | 12 | 11 / 11 | 11 |
| Engelska, climate (text på engelska) | text | year 8 → åk 8 | 12 | 12 / 12 | 12 |
| Matematik, Pythagoras och area, med formler | PDF | åk 9 → åk 9 | 12 | 12 / 11 | 10 |
| Biologi, slarviga anteckningar (förkortningar, pilar, "??") | text | ingen → tom | 12 | 12 / 11 | 12 |
| **Summa** | | 6/6 rätt eller tom | **69** | **67 / 66** | **64** |

**Det slarviga anteckningsblocket** ("producenter = växter, gör energi m fotosyntes -> solenergi blir socker") gav rena, korrekta frågor. Ett exempel är "Varför går bara cirka tio procent av energin vidare till nästa steg?". Läraranteckningen "(läraren: JA viktigt på provet)" blev en egen fråga om nedbrytarna, och det är rimligt.

## Så bedömde jag
- **Domaren:** `scripts/qa/o63_quality.py`. Varje fråga bedömdes två gånger av domaren (Sonnet), **alltid med materialet i facit**, så att den inte underkänner sådant som står där:
  - långa svaret: rätt fakta, A-nivå för årskursen och inget som strider mot materialet
  - korta svaret: fullgott ensamt
- **För hand:** jag läste alla 69 frågor och korta svar, och de långa svar som domaren underkände.
- **Längdklassen:** jag sparade de 6 proven med testkonton (falskt ljud) och läste `length_class` från servern. Proven togs bort efteråt.
- Data:
  - `reports/qa/data/2026-11-14-185441-o55-drill-o63.json` (frågor och svar)
  - `…-190908-o63-quality.json` (domaren)
  - `…-1905-o63-length-class.json` (servern)

| Krav | Resultat | |
|---|---|---|
| Rätt fakta (långa) | 67/69 för hand (domaren 64/69) | 2 fel, se nr 1 och 4 nedan |
| A-nivå (långa) | 66/69 för hand (domaren 66/69) | |
| Första meningen som kort svar | 64/69 för hand (domaren 42/69) | |
| Förståelsefrågor (R3 minst 70 %) | 74 % för hand, regeln 70 % | klarat |
| Längdklass normal (minst 90 %) | 69/69 enligt servern | klarat |
| Inget påhittat ur materialet | 0 påhittade ämnen. 3 frågor bygger på något som inte står där eller strider mot det | se nedan |
| Årskurs rätt eller tom | 6/6 | klarat |

**Domarens 27 underkända korta svar:** 23 av dem är fullgoda svar på frågan. Domaren saknar mer djup, till exempel "nämner inte Rousseau". Domaren har också fel ibland. Den kallade "hararna" fel form två gånger, men ordet är korrekt svenska. **Den strängare tolkningen av D162 är fortfarande Deangelos beslut** (frågan från O57 är obesvarad).

## De 5 sämsta frågorna
1. **"Varför kallas fria medier för den fjärde statsmakten?"** (samhällskunskap)
   - Materialet säger "den tredje statsmakten", så frågan har en premiss som strider mot materialet.
   - Svaret blir motsägelsefullt och vänder sig till eleven om materialet: "… men de kallas i materialet den tredje statsmakten."
   - Eleven blir förvirrad och får fel uppgift i frågan. **Fel fakta.**
2. **"Varför blir kvadraten på hypotenusan lika med summan av kvadraterna på kateterna?"** (matematik)
   - Materialet har inget bevis, så svaret blir cirkulärt: "Det beror på att en rätvinklig triangels sidor alltid har just det sambandet …".
   - Eleven får inget svar på varför och måste fråga igen. Frågan borde inte ha ställts.
3. **"Varför ville upplysningens tänkare att makten skulle komma från folket?"** (historia)
   - Det korta svaret upprepar frågan: "De ansåg att makten … skulle komma från folket".
   - Materialet säger bara att Rousseau menade det, inte varför. Samma mönster som nr 2.
4. **"Vad skiljer en molekyl från en kemisk förening?"** (kemi åk 7)
   - Det långa svaret slutar med "Alla föreningar kan alltså vara molekyler", vilket är fel (salt är en förening men inga molekyler) och står inte i materialet.
   - Resten är bra, med syrgas och vatten som exempel. **Tillagt fakta med fel.**
5. **"Varför bestämmer antalet protoner vilket grundämne en atom tillhör?"** (kemi)
   - Svaret är cirkulärt: "… är unikt för varje grundämne, så det är protonerna som avgör".
   - Materialet säger bara att det är så, så frågan kräver ett varför som materialet inte har.

**Strax utanför topp 5:**
- "Hur gick det till när tredje ståndet bildade nationalförsamlingen?" Det långa svaret har en rörig mening: "hade ändå lika lite att säga till om som de två andra stånden, som tillsammans kunde rösta ner dem".
- "Varför blir det mindre gräs om rävarna dör?" Det långa svaret tillägger det tveksamma "mindre energi finns kvar i ekosystemet".

## Till Kevin
1. **Prio 2, frågor med varför som materialet inte kan besvara** (nr 2, 3 och 5). De ger cirkulära svar, och det är just det som gör att eleven behöver upprepa sig.
   - Förslag: frågan "Varför …?" ställs bara när materialet ger orsaken, annars "Vad …?" eller "Hur …?".
   - I granskningen: ett svar som bara upprepar frågans påstående underkänns.
2. **Prio 2, en premiss som strider mot materialet, och ordet "materialet" i svaret** (nr 1). Frågan får inte påstå något som materialet säger emot. Svaret ska aldrig hänvisa till "materialet", eftersom eleven inte vet vad det är i uppspelningen.
3. **Prio 3, tillagda fakta med fel** (nr 4). Samma mönster som O55 och O55b, och ungefär 1 av 70 långa svar. Förslaget från O55b gäller fortfarande: påstå inget utöver materialet om grupper eller regler, eller låt granskningen jämföra med `notes`.
4. **Prio 3, siffror som ord i frågetexten:**
   - "sedan ungefär arton hundrafemtio?"
   - "ungefär tre komma fjorton för pi"
   - "a i kvadrat plus b i kvadrat"

   Rösten ska säga orden, men på skärmen är 1850, 3,14 och a² + b² lättare att läsa, särskilt i matte. **Antagande:** appen visar frågans text som den sparas.
5. **Till Deangelo, prio 3:** materialet till Engelska var på engelska, men frågor och svar blev på svenska. Är det rätt för ett engelskprov, eller ska frågorna vara på engelska?

## Begränsningar
- Ett försök per prov. Antalet frågor varierar mellan körningar (kemi gav 9 av 12).
- Förståelsefrågor för hand, och mina val:
  - Jag räknade med "Vad händer om …", "Vad skiljer …" och "Vad kan man säga om …".
  - Jag räknade bort "Hur ofta hålls val …" och "Hur räknar man ut arean …".
- `/exam` gav 429 under genereringen, så tiderna 57–59 s för svaren är mina egna väntetider.

## Filer
- `scripts/qa/repetition_bank/materials_holdout3.py`, `scripts/qa/o63_quality.py` (nya). `o55_grade.py` har D180-skyddet och läser den nya banken
- Data: se ovan

## Nästa
- Kevin: punkt 1 och 2 (prio 2).
- Deangelo: D162 (stränghet för korta svar) och språket i engelskprov.
- Oscar: väntar på kö. Proven i `materials_holdout3.py` är inte hemliga när det här är pushat.
