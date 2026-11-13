# Testa repetitionsläget på telefonen (högst 10 minuter)

Toby, 2026-11-13. Gäller A78 (spelaren) och A80/A81 (kontrollskärmen). Spec: `docs/design/repetitionslage.md` (D142–D146).
Allt annat (ordningen i tre varv, betänketiden, att listan börjar om) testar Toby i simulatorn. Det här är bara det som kräver
din iPhone och dina AirPods.

**Bygget:** iOS-bygge 43501199803 (10bf4a0, grönt) eller senare. Simulatortestet T18 körs samtidigt: Toby skriver resultatet i sin rapport.

**Före start (räknas inte i tiden):**
- Senaste bygget är installerat. Appen öppnar nu direkt på Start med "Plugga med AirPods" och **Nytt prov**.
- Skapa ett prov med **Nytt prov**. Klistra in texten nedan, ställ antal frågor på **5** och tryck **Skapa frågor**, sedan **Ser rätt ut**.
- Vänta tills provet visar "Ljud klart". Ljudet görs på servern med ElevenLabs: 5 frågor är ungefär 3 000 tecken, cirka 0,25 USD (knappt 3 kr, specen §6, variant B).
- Båda AirPods är i öronen och ingen annan app spelar (pausa Spotify).

Text att klistra in:
> Fotosyntes. Växter tillverkar socker av koldioxid och vatten med hjälp av solljus. Klorofyllet i bladen fångar ljuset. Syre bildas och släpps ut. Sockret ger växten energi och byggmaterial.

| Steg | Tid | Gör så här | Det här ska hända | Skicka tillbaka |
|---|---|---|---|---|
| 1. Kontrollskärmen (R11) | 1 min | Öppna provet. På skärmen före start ("Styr med dina AirPods") spelas första frågan en gång. Tryck en, två och tre gånger på AirPods när appen ber om det ("Tryck en gång nu" …). | Varje tryck får en bock. Appen visar 1 = långt svar, 2 = kort svar, 3 = paus. Ingen fråga om vilken modell du har. | Fick alla tre bock? Om inte: vilket och vilken text som visades. |
| 2. Starta och lås (R9) | 0,5 min | Skriv upp klockslaget. Tryck **Starta prov**. Titta högst upp till höger, lås sedan skärmen. | Första frågan hörs i AirPods inom några sekunder. **Ingen orange prick** (mikrofonen) syns, varken i appen eller på låsskärmen. | Prick: ja/nej. Klockslaget. Sekunder till första frågan (ungefär). |
| 3. Knapparna med låst skärm (R6) | 2,5 min | Under en fråga eller tystnaden efter: tryck **1 gång** (5 gånger på olika frågor), sedan **2 gånger** (5 gånger), sedan **3 gånger** och **3 gånger igen** (5 gånger). | 1 tryck: det långa svaret, sedan nästa fråga. 2 tryck: bara första meningen (det korta svaret), sedan nästa fråga. 3 tryck: tystnad. 3 igen: fortsätter. | Antal rätt av 5 för varje: 1 tryck, 2 tryck, 3 tryck. Hur lång fördröjning på ett tryck kändes (kort/lång)? |
| 4. Fortsätt från samma ord (R7) | 1 min | Mitt i ett långt svar: tryck 3 gånger. Vänta 5 s. Tryck **1 gång** (inte 3). Gör det 3 gånger. | Svaret fortsätter från ordet där det stannade (högst ett ord fel), inte från början och inte nästa fråga. | Rätt ord av 3. |
| 5. Avbrott (R8) | 1 min | (a) Ta ut en AirPod, vänta 3 s, sätt tillbaka, tryck 1 gång. (b) Säg "Hej Siri, vad är klockan", vänta på svaret. | (a) Uppspelningen pausas när luren tas ut och fortsätter efter trycket. (b) Uppspelningen fortsätter efter Siri eller med ett tryck. Läget avslutas aldrig. | För (a) och (b): fortsatte det, och från rätt ställe? |
| 6. Lång paus (R8) | 4 min | Tryck 3 gånger (paus), lägg ifrån dig telefonen låst i 4 minuter. Tryck sedan **2 gånger**. | Uppspelningen fortsätter (alla tryck fortsätter under paus) från samma ord. | Fortsatte: ja/nej. Om nej: vad visade låsskärmen? |
| | **10 min** | Avsluta med den stora **Avsluta**-knappen i appen. | Läget slutar bara där. Appen säger "Sparat på fråga …", och nästa Starta prov frågar "Fortsätt där du var?". | Stämde frågans nummer? |

## Skicka tillbaka
En rad per steg i chatten, till exempel: "1 ok. 2 ingen prick, 3 s. 3: 5/5, 4/5, 5/5, kort. 4: 3/3. 5a ok, 5b ok. 6 ok."
Skriv också iPhone-modell, iOS-version och vilka AirPods du använde.

## För Toby
- **R9, andra halvan:** med klockslaget från steg 2 läser Toby serverloggen och ser att inget `stt-token`-anrop kommer i det tidsfönstret.
- **R7:** "samma ord" bedöms här efter gehör. En exakt mätning kräver en diagnostikrad från Angela med ordet vid paus och ordet vid fortsätt (ElevenLabs-tidsstämpeln mot spelarens position).
- Knappnamnen kommer från Kellys texter (Ke50) och Angelas A82. På telefonen är de en **untested assumption**.
- **AirPods 1 och 2:** om kontrollskärmen visar "Dina AirPods har dubbeltryck per lur" ställer appen in att 1 tryck pausar
  under ett svar (`onePressPausesAnswer`). Steg 3 och 6 gäller då vänster lur (kort svar) och höger lur (långt svar, paus).
- **Det som simulatorn redan har kontrollerat (T18)** står i Tobys rapport. Telefonen behövs för AirPods, låst skärm,
  den orange pricken och riktiga avbrott.

## Inte med i de 10 minuterna (Toby tar dem senare eller i beta)
- 60 minuter med pauser på 15 och 30 min, ett riktigt samtal och AirPods ur fodralet och tillbaka (resten av R8).
- 20/20 per knapp (R6 fullt): dina 5/5 räcker som första kontroll.
- Spara och logga in på en annan telefon (R5), delning (R5c) och andra AirPods-modeller.
