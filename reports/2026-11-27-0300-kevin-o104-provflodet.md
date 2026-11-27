# Kevin (moln) – O104: provflödets fynd (rättning, provkedja, Provläge)

**Datum:** 2026-11-27 03:00. **Uppdrag:** Deangelo 01:50. Fynden är tagna i hans ordning.
**Regler:** inga riktiga modellanrop, 0 ElevenLabs.
**Svit:** 912/912. **Driftsatt:** två pushar till main. Funktionskoden ändrades i `exam/` och `answer/`.

## Rättat (varje fynd har test först)

| Fynd | Rättning | Test |
|---|---|---|
| **G-a** "en"/"ett" i facit lästes som talet 1 | I ett facit med ord och utan siffror (fler än fyra ord) räknas "en" och "ett" som artiklar. Ett kort facit som är själva talet ("Svaret är ett") och tal skrivna i ord ("tjugofem") gäller som förut. Ett helt rätt svar på syra- och basfrågan får nu E1 C1. | `exam/o104_grading_test.ts` |
| **G-b** K1.7 skrev över återkopplingen för fel årtal | "Visa hur du räknar" gäller bara räkneuppgifter (`isCalculationTask`: bedömningen nämner metod eller uträkning, eller uppgiften räknar). "Vilket år …", "När …" och "Hur många ben …" behåller modellens rättelse. | samma |
| **E1** trimmet tog bort de enda orsaks- och definitionsfrågorna | Den enda varför-frågan och den enda definitionen tas aldrig bort. En definition ("Vad är …") räknas inte längre som ren minnesfråga. Ren tid eller person ("När …", "Vem …", "When …", "Who …") går före "Vilka …" och "Which …". Engelska frågeord är med. | `exam/o104_chain_test.ts`. Ett äldre test i `drill_test.ts` som låste det gamla beteendet är uppdaterat. |
| **E2** en avvisad omskrivning lånade ut sina `sources` | När slutkontrollens omskrivning avvisas tas dess `sources` och `a` bort för frågan, eftersom de gällde omskrivningen. | samma |
| **E3** `dropNearSame` var för grov | Två frågor som frågar efter olika saker (orsak, mängd, tid, person, hur, definition) är inte samma fråga, även om orden liknar varandra. Samma sak i andra ord tas fortfarande bort. | samma |
| **G-c** rättningen var alltid på svenska | En engelsk uppgift (efterfrågad så eller skriven på engelska) får `<language>en</language>` i rättning och ledtråd. Regeln säger "in the language of <language>". Svenska uppgifter får ingen tagg, som förut. | `exam/o104_grading_test.ts` |
| **G-d** övningsregeln krockade med återkopplingsregeln | Övningsregeln säger nu att den ersätter återkopplingsregeln ovan, och ger de engelska inledningarna "Correct." och så vidare. | samma |
| **E4** påfyllda frågor hamnade alltid först | De behållna frågorna placeras också i sina delar, så att påfyllningen hamnar i materialets ordning. | återspelning (PX1) |
| **E6** foto-prov fick ingen `<language>` | Foton utan text från en engelsk app (`x-earmind-lang: en`) får `<language>English</language>` i anteckningar och frågor. Med en svensk app gäller promptens regel som förut. | `scripts/k122_test.ts` |
| **T-a** svaret på kontrollfrågan skickades som `confirmation` | När svaret gäller Provläges kontrollfråga skickas `<last_assistant_turn>check_question</last_assistant_turn>`. Betydelsen står i rättningsnoten, inte i den cachade systemprompten, så prompten för alla andra växer inte. | `scripts/k122_test.ts` |

## Oscars 22 fall omkörda med K122 och hans egna svar (verifierat i återspelning)

| Fall | Före | Efter |
|---|---|---|
| PX1 | påfylld fråga först | i materialets ordning |
| PX2 | ingen definition | "Vad är en syra?" är med. Avvägning: "Vad händer när en syra och en bas blandas …" går. |
| PX4 | bara minnesfrågor | "Varför bor zorbierna i städer under marken?" är med |
| PX6 | ingen orsaksfråga | "Varför har jordens medeltemperatur stigit?" behålls bredvid "Hur mycket …" |
| PF2 | "What happened … in 1793?" (ren minnesfråga) | en förståelsefråga i stället: "What followed from the revolution for the idea of equality?" |
| G3 | "Visa hur du räknar" för ett årtal | "Ingen poäng, 1523 är året då Gustav Vasa valdes till kung, inte när Sverige blev ett arvrike …" |
| H1 | – | samma ledtråd. Bara token-uppskattningen ändrades, eftersom prompten blev längre. |
| övriga 15 | – | oförändrade |

PF1 är oförändrat ("inget om cellkärnan"). Med Oscars svar blir det samma trim, och det fallet behöver riktig eval.

## Inte gjort (låga, inte beställda nu)

- **E5:** meningsdelaren kräver versal efter punkt.
- **E7:** påfyllningens antal och `used_sentences`.
- **T-b**, samt P-fynden.

Ändringarna i E1 påverkar vilka frågor ett prov får. De bör mätas med riktig eval när krediterna är tillbaka, så att täckningen och A-nivån håller. Det är en untested assumption på riktig modell.

## Nästa

- **Oscar:** omtest av O104 med K122. Raden ligger i hans kö.
- **Riktig eval:** E1 (frågevalet) och G-c (engelsk återkoppling).
