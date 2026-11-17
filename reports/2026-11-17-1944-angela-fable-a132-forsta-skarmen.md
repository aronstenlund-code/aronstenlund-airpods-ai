# A132 (D215): första skärmen efter Kellys Ke72 (Angela Fable, moln)

På main 2026-11-17 19:44, utom kostnaden från servern före Spela (K92) och "Obegränsat" (A133), som byggs härnäst.
**Verifierat på simulatorbild och i bildflödets simulatorbygge; hela testbygget har inte gått på de tre sista
ändringarna (se Tester). Inget på enhet.** 0 ElevenLabs (D180).

## D215 punkt för punkt
| # | Regel | Läge |
|---|---|---|
| 1 | Högst en fylld blå knapp åt gången | **Gjort.** Med text i fältet (eller när det spelas) är "Spela i 10 min" fylld och Starta prov tonad; annars är Starta prov fylld. |
| 2 | Inga förklaringar av det självklara | **Gjort.** Kortet har bara fältet och knappraden (ingen rubrik "Säg i AirPods", ingen teckenräknare). Raden "Du kan låsa telefonen. Det hörs i AirPods ändå." visas tills Spela har tryckts en gång. Kostnaden är två ord ovanför knappen: "120 krediter", eller halvfet "120 krediter · du har 88" med grå Spela. |
| 3 | Säg-texter är aldrig Nästa prov eller Andra prov | **Gjort.** De ligger som "Senaste" (tre kapslar) under kortet; ett tryck lägger tillbaka texten, långt tryck: Ta bort. Texter som sagts före ändringen känns igen utan märke (text utan ämne och årskurs, döpt efter sina första ord), så Arons "HISTORIA – 1880–1918" flyttas dit. Samma text sparas aldrig två gånger. |
| 4 | Fältet högst 5 rader, 3 utan fokus | **Gjort.** Utan fokus 3 rader som tonar ut nedåt; med fokus högst 5 och sedan rullar det inuti. |
| 5 | Platshållare och "Klistra in" | **Gjort.** Tomt fält och text i urklippet: huvudknappen är "Klistra in" (tonad). |
| 6 | Tid kvar och paus på kortet medan det spelas | **Gjort.** "● Spelar i AirPods", texten (tre rader), paus, "7:03 kvar" (pausad: "… · pausad") och Stoppa. Tryck på texten öppnar spelaren med meningarna. |
| 7 | Ingen stor rubrik "Prov" | **Gjort.** Kortet står direkt under kapseln. |
| 8 | Kostnaden från servern före Spela (K92) | **Inte gjort än.** Före Spela visas appens teckenräkning med serverns regel (kan bara bli för hög). Kevins `cost`-anrop finns nu och byggs in härnäst. |

Menyn Hur länge är nu timersymbolen utan ord, med rubriken "Spela i"; huvudknappen säger tiden ("Spela i 1 timme").

## Ändrat beteende att känna till
- **Spela öppnar inte längre spelaren över hela skärmen.** Texten spelas med kortet kvar på Start. Utan ljud (D200)
  öppnas spelaren som förut, eftersom texten då läses på skärmen.
- **"Klistra in" läser urklippet** när man trycker; iOS kan då visa sin egen fråga om att tillåta det. Att urklippet
  har text kontrolleras utan att läsa det.

## Farhågor
Uppspelningen syns mindre än förr: ett kort på Start i stället för en hel skärm. Det som finns kvar: kortet säger
"Spelar i AirPods" med tid och Stoppa så länge det spelas, låsskärmen visar "EarMind · Säg i AirPods", det startar
bara när man själv trycker, och inget är fördröjt eller dolt. Tillsammans med upprepning i upp till en timme (D210)
och "lås telefonen" (D209) gör det appen lättare att använda under ett prov. Det är ägarens beslut (D215); jag
noterar det och har inte byggt något som döljer uppspelningen.

## Tester
- **iOS build 44134055100 grön på min gren** för hela Ke72-kortet (enhetsbygge, varningar som fel, LumenTests), med
  nya tester: en Säg-text är inte ett prov på Start och spelas på kortet utan att spelaren läggs över; en text sagd
  före märket känns igen; kortets ord (Spela i …, kreditraden, kapslarna); raden om låst telefon.
- **De tre sista ändringarna** (största text inom kortet, kortet under kapseln, tonen nedåt; bara vyer) har byggts
  för simulatorn i bildflödet (44139551926, 44139555818) men **inte i hela testbygget**: 44139313044 och 44139535043
  avbröts i byggkön efter 35 minuter utan att starta. Bygget på main efter den här pushen kör allt; resultatet skrivs
  på tavlan.
- **Kelly har godkänt** 17 Pro och SE med största text (`reports/2026-11-17-1838-kelly-granskning-a132.md`, omgång 3).
- **Bilder** i `reports/2026-11-17-a132-bilder/` (grenarna `fable/screens-a132-17pro-2`, `-17pro-4`,
  `-se-xxxl-4`): tomt, med text, krediterna räcker inte, Senaste, bara Säg-texter, spelar; SE med största text.

## Otestat (antaganden)
- "Klistra in", fältets 5 rader med fokus och menyn "Spela i" finns inte på bild (Toby tar dem i T46).
- En SE-bild i omgång 2 visade iOS hemskärm i stället för appen; i omgång 4 visar alla SE-bilder appen. Om det var
  ett fångstfel eller en krasch är inte belagt.
- Uppspelning på kortet med riktigt ljud, och att tiden räknar ner med låst skärm: bara på enhet.

## Prova på telefonen (Aron, med nästa app)
1. Öppna appen: ingen rubrik "Prov", fältet överst. Kopiera en text någonstans och kom tillbaka: knappen säger
   "Klistra in".
2. Med text i fältet: "Spela i 10 min" är blå och Starta prov ljusare. Byt tid med klocksymbolen.
3. Tryck Spela: kortet visar "Spelar i AirPods" och tiden som är kvar; paus och Stoppa fungerar; tryck på texten
   öppnar spelaren.
4. Stoppa och titta under kortet: texten ligger under "Senaste", inte som Nästa prov.

## Nästa session
- K92: serverns kostnad före Spela. A133: "Obegränsat" för admin (när Kevins fält finns). Tobys T46.
