# Kevin (moln) – svaren i lyssnarläget, grindens N1 och O107 (foto, minne)

**Datum:** 2026-11-27 07:00. **Uppdrag:** Deangelo 04:09, i tre delar.
- (1) Rad 482 i kön, om den inte redan är klar.
- (2) Svarets kvalitet i lyssnarläget, utan att det kostar mer.
- (3) Oscars fynd om Provläge med foto, delning och minnet.

**Regler:** inga riktiga modellanrop, 0 ElevenLabs. **Svit:** 936/936. **Driftsatt:** pushar till main.

## (1) Rad 482

Den var redan klar: engelska knappnamn i hjälpen, gjort 05:30.

## Grindens N1 (Oscars omtest av D272)

- Grinden läser nu bara sitt första ord. "nej, det är en fråga till kompisen" räknas alltså som nej. Max 3 token.
- Exemplen i grindens prompt är inte längre Oscars testfall ordagrant, så hans fall mäter något annat än exemplen.
- Test: `answer/o106_gate_test.ts`.

## (2) Svaren i lyssnarläget: kortast möjliga som ändå är rätt (verifierat i test och återspelning)

| Ändring | Före | Efter |
|---|---|---|
| En fråga som hörs i rummet, inte riktad till appen (inget namn, ingen handling, inte aktiveringsordet) | full längd för förklaringar (A15: 5 meningar), budget cirka 880 token | samma regel som när andra pratar: "at most three short sentences, the core only". Förklaringssvar får budgeten 360 token, vilket blir 440 med metaradens utrymme. **Det kostar mindre.** |
| "hur lång tid tar det att flyga dit" (A19) | ledtråden "study" | "fact", alltså en till två meningar |
| "som en AI"-prat | inget filter | En inledande sats om att vara en AI tas bort ("Som en AI har jag inga egna åsikter, men de flesta …" blir "De flesta …"). En mening som bara säger vad assistenten inte kan försvinner helt. Bara svarets första tecken hålls, och bara så länge de kan vara början på en sådan sats, så andra svar fördröjs inte. Frågar användaren om den är en AI blir svaret ärligt som förut (D113 A3). |
| Årtal (L3, A17) | "tvåtusen trettioen har …" och "tvåtusen trettioett" i samma svar | Ett årtal före ett verb eller sist räknas "ett". Saker som räknas behåller sitt genus ("2031 kronor", "1021 elever"). |
| Avklippt fråga på ett ägande ord (L2) | "och vad hette hennes" gick till modellen | `isCutOff` känner nu igen hennes, hans, deras, dess, sina och er/era, så appen väntar på resten. |

- Oscars 34 lyssnarfall är omkörda med hans egna svar, också grindens.
- A17 läses nu som ett årtal. Övriga fall är oförändrade.
- Hans svar på A15 och A19 är skrivna mot den gamla prompten. Där är det prompten som har ändrats: kortregeln och lägre budget för A15, ledtråden "fact" för A19. Han behöver spela modellen igen för att se effekten.

Test: `answer/o106_quality_test.ts`.

## (3) O107 (foto, delning, minne)

| Fynd | Gjort | Test |
|---|---|---|
| **F1** sifferkontrollen | "5 miljoner" är ett tal, "minus 4" är −4 och ett tal sist i en mening läses (förut lästes "… med 5000000." inte alls). Flera rötter ("x = 2 eller x = −4") lämnas till bedömningsreglerna, så en rätt rot inte ger 0 poäng av koden. | `exam/o107_numeric_test.ts` |
| **M-1** hälsa i minnet | Penicillin, antibiotika, kortison, antidepressiva, EpiPen, hörsel- och synnedsättning, KBT, psykolog och missbruk sparas aldrig (D113 B5). | `memory/o107_memory_test.ts` |
| **F3** uppgiftens talade text | "tre x plus fem är lika med tjugo", "x i kvadrat", "roten ur", "gånger", "H två S O fyra" (som O105-3), "(miljoner)", "till exempel". En tabell eller figur sägs som "Tabell: …". En punkt kommer före poängen, och fördelningen sägs: "Den ger två poäng, en E-poäng och en C-poäng." | `exam/o107_spoken_test.ts` |
| **F2** engelska prov | Talramen för ett engelskt prov är engelsk: "Question one. … It gives two points, one C point and one A point." Språket avgörs för hela provet med en detektor för korta uppgiftstexter. Läsprompten och svarsskrivaren följer provets språk. | samma |
| **M-4** en ändring utan "jag/min" | "provet i kemi är flyttat till nästa onsdag" når modellen när ett ändringsord och ett eget ord (kemi) finns i ett minne. Småprat och prov som inte finns i minnet kostar fortfarande inget. | `memory/o107_memory_test.ts` |

Oscars foto-fall (P1–P6, PT1–PT2) är omkörda: talet blir som i tabellen. P6 och PT2 får engelsk ram, de svenska proven svensk.

### Inte gjort, och varför

- **M-2 (telefon, adress och e-post i minnet): krockar med D113 A5**, Arons ägarbeslut. Där står att bara hälsa, kris och ID-nummer stoppas i kod, och att adress uttryckligen inte stoppas. Ett befintligt test låser det. Enligt regeln i CLAUDE.md byggs det inte. **Fråga till Deangelo eller Aron:** ska telefon och e-post stoppas trots D113 A5?
- **M-3 (uppgifter om andra personer, till exempel "Pappan heter Johan och är arbetslös")** behöver ett beslut. Namn på andra är tillåtna och förväntade, som M02 "min bror heter Elias" i svarsbanken. Var gränsen går för andras förhållanden är inte bestämt.
- **F4–F6** (låga) är inte gjorda.

## Nästa

- **Oscar:** omtest. Raden ligger i hans kö.
- **Deangelo:** beslut om M-2 och M-3.
