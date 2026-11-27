# Det vanligaste flödet: lyssna → fråga → A-svar i AirPods → historik

Angela Schrute (moln), 2026-11-27. Uppdrag: Deangelo 2026-11-26 22:38 ("När kön är tom: gå igenom appens vanligaste flöde … och rätta det som känns krångligt eller långsamt, med test") och 00:12 ("Fortsätt där du var … grenen flode-rod"). Från 00:12 körs sessionen på Opus 5.5 (Fable-gränsen).

## Kort

Sex rättningar i Standardläget. Fyra av dem var riktiga fel:
- "Försök igen" frågade om fel fråga.
- Pausa på skärmen pausade inte under "Mer?"-fönstret.
- En falsk röd rad stod bakom samtyckesbladet.
- Varje återanslutning av taligenkänningen väntade på en kostnadsrapport, och under tiden tappades ord.

Två är förenklingar: Historik nås med ett tryck från Lyssnar och går att söka i, och Avsluta leder tillbaka till sidan där man startade.

Inget är provat på telefon. Testerna kör i CI med fejkad server, 0 ElevenLabs och inga riktiga modellanrop.

## Hur jag gick igenom flödet

En kartläggning av koden (läsning, inga ändringar) gick igenom fem saker:
- varje tryck från Start till lyssnande och vidare till Historik;
- varje väntan och timer från slutet på frågan till första talade ordet;
- vad som mäts;
- när ett svar skrivs till Historik;
- vilka fel- och tomlägen som lämnar användaren utan besked.

Varje fynd nedan är kontrollerat i koden innan det rättades (*verified in code*).

## Rättat

### 1. "Försök igen" frågar den fråga som misslyckades (fel)

- **Felet:** Kortet "EarMind kan inte svara just nu" frågade `conversation.answers.last?.question` i första hand. Hade passet redan ett svar, ställdes den **förra, redan besvarade** frågan igen, och den som misslyckades försvann.
- **Rättat:** kortet frågar nu den fråga som ställdes sist (`pendingQuestion`), och tidigare svar bara om den saknas (`askFailedQuestionAgain()`).

### 2. En talad fråga som inte fick svar kan ställas igen (fel)

- **Felet:** A74 tar bort samma fråga inom 60 s, så att den inte besvaras två gånger. Men den räknade också frågor som aldrig fick svar. Den som upprepade en fråga efter "EarMind kan inte svara just nu" fick därför tystnad i en minut.
- **Rättat:** en fråga som misslyckas glöms i `RepeatGuard`, både när svaret faller (`answerFailed`) och när man trycker Försök igen. En besvarad fråga tas fortfarande bort inom minuten (testat).

### 3. "Ingen internetanslutning" har en Försök igen-knapp

- Kortet lovade att EarMind "svarar igen när du är uppkopplad", men hade ingen knapp och frågade aldrig om.
- Nu har det **Försök igen**, som frågar den fråga som inte fick svar. Texten "Försök igen" fanns redan på båda språken.

### 4. Pausa på Lyssnar pausar, också i "Mer?"-fönstret (fel)

- **Felet:** Efter ett kort svar är "Mer?"-fönstret öppet i 5 s (A15). Under den tiden betydde **knappen Pausa på skärmen** "mer": den bad om det långa svaret i stället för att pausa. Det beror på att skärmknappen och AirPods-trycket går genom samma `togglePause()`.
- **Rättat:** skärmknappen anropar `togglePause(fromScreen: true)`, som stänger fönstret och pausar. Ett AirPods-tryck i fönstret betyder fortfarande "mer" (A15, testat).

### 5. Ingen röd "EarMind kom inte igång" bakom samtyckesbladet (fel)

- **Felet:** Starta EarMind på Fler lägen utan samtycke öppnar samtyckesbladet. Bakom bladet stod då "EarMind kom inte igång. Tryck igen om en stund." i rött, och raden stod kvar om man avbröt.
- **Rättat:** villkoret ligger nu i modellen (`ListeningModel.startDidNotTake`) och räknar med att samtycket frågas (`asksForListeningConsent`).

### 6. Taligenkänningen tappar inga ord vid återanslutning (långsamt)

- **Felet:**
  - Varje återanslutning av Scribe stänger först den gamla sessionen. Det sker när nyckelorden ändras, vid pausinställningen, vid lägesbyte och när sessionen tar slut.
  - Stängningen (`ScribeProvider.stop()`) väntade på kostnadsrapporten för sekunderna: inloggningstoken och en POST till servern.
  - Under den tiden tog appen inget ljud, så ord som sades då försvann.
  - Brickan visade dessutom "Hör inte, försöker igen".
- **Rättat:** rapporten skickas vid sidan av, och den nya sessionen kan starta direkt. Uppgiften håller kvar leverantören tills rapporten är skickad. Att en rapport kan gå förlorad var redan accepterat (D47).
- **Hur mycket det sparar per återanslutning är inte mätt på telefon.** Det är en tur till servern, i fejktestet 2 s mot under 0,5 s.

### 7. Historik med ett tryck från Lyssnar, och sök

- Förut tog det tre tryck och en lång rullning från Lyssnar: Tillbaka, kugghjulet, rulla förbi 13 avsnitt, Historik. Nu finns **⋯ › Historik** på Lyssnar. Det öppnas som ett blad, och lyssnandet fortsätter under.
- Historik har ett sökfält (`.searchable`):
  - Varje ord man skriver ska finnas i frågan, svaret, sammanfattningen eller ett förslag.
  - Stor eller liten bokstav spelar ingen roll, och inte heller accenter ("ar" hittar "är").
  - Utan träff visas systemets egen "Inga resultat".
  - Att svepa bort en rad tar bort den rad man ser, också medan man söker.
- Inga nya texter: "Historik" och "Klar" fanns redan.

### 8. Avsluta leder tillbaka till Fler lägen

- Förut kom man efter Avsluta på Lyssnar tillbaka till provlistan på Start, och lyssnandet fanns två tryck bort (Fler lägen › Starta EarMind).
- Nu ägs sidan "Fler lägen" av modellen (`ListeningModel.showsMoreModes`), så den står kvar genom passet. Avsluta leder till sidan med Starta EarMind.
- Efter första starten (A166) öppnas samma sida när passet tar slut.
- Inte provat i en riktig navigering: i en SwiftUI-`NavigationStack` ska en `navigationDestination(isPresented:)` som redan är sann visa sidan när vyn kommer tillbaka. Det är *untested assumption* tills Toby eller Aron har tryckt igenom det.

## Inte ändrat (medvetet)

- **Frågor som ställs utan "Lumen" sparas utan frågetexten i Historik.** Det är D56:s integritetsregel, som har ett eget test. Raden visar svaret eller sammanfattningen.
- **Ingen "jag hörde dig"-ton före svaret.** En ton spelas i samma spelare före talet och skulle fördröja svaret upp till 0,12 s. Det är Kellys ljudval (A34).
- **Kortare startbuffert för rösten (0,3 s).** Det är A4:s beslut mot hack i ljudet och kräver prov på telefon.
- **Den levande texten medan man talar.** Lyssnar visar bara nivåmätaren medan man pratar. Kelly bör bestämma om den löpande texten ska synas.
- **Rösterna och modellen anropas inte i något test** (D180, D258).

## Testresultat

- **iOS build 45910685671 grön** på `claude/fervent-fermi-34hrer` (665f1196): enhetsbygge med varningar som fel, hela sviten (1 189 gröna testrader, 0 röda), Release-arkivet och Release-kontrollen. `FlowTests`, `FlowRetryTests` och `ScribeStopTests` gröna. *Verified in CI.*
- **Röd körning först: 45910689257** på `angela/flode-test-rod` (bara testerna, mot main) föll på fyra av sex tester, som väntat:
  - "Försök igen" frågade `"vad är pi"`, alltså den förra frågan, i stället för `"vad är fotosyntes"`.
  - En talad fråga som misslyckats ställdes inte igen, varken med knappen eller med rösten (A74 tog bort den).
  - `ScribeProvider.stop()` tog **2,03 s** med en långsam rapport, mot gränsen 0,5 s.
  - Två tester var gröna redan på main: den första frågan som misslyckas, och att en besvarad fråga inte ställs två gånger.
- Min första röda körning (45909390188) kompilerade inte på grund av ett fel i mitt eget test (språket som text i stället för `.swedish`). Rättat innan den riktiga röda körningen.
- På main slogs grenen ihop med Ke91, Angela Fables A167 och Kevins K124 utan krockar. Main-bygget skrivs in i STATUS.

- **Röda först** (`angela/flode-test-rod`, bara befintligt API, mot main): `LumenTests/FlowRetryTests.swift` med fem tester för Försök igen, upprepad fråga och besvarad fråga, plus ett test för Scribe-stängningen.
- **Nytt API** (`LumenTests/FlowTests.swift`, 10 tester): Pausa från skärmen i och utanför fönstret, AirPods-tryck i fönstret, Försök igen offline, startkontrollen med och utan samtycke, Fler lägen genom ett pass och efter första starten, Historik från Lyssnar och sökningen. De kan inte köras röda, eftersom de inte kompilerar mot main.
- `LumenTests/ScribeTests.swift`: det gamla testet väntade på att rapporten var skickad när `stop()` kom tillbaka. Nu väntar det på rapporten efteråt.

## Risker

- Rättning 6 ändrar ordningen vid varje återanslutning: den nya sessionen kan ansluta innan den gamla rapporten är skickad. Generationsskyddet i `TranscriptionCoordinator` släpper redan inte igenom den gamla leverantörens ord. Inte provat mot riktiga Scribe.
- Rättning 8 gör att Fler lägen visas igen efter varje pass som startades därifrån. Den som vill till provlistan trycker Tillbaka.

## Nästa steg

- Toby: tryck igenom Avsluta → Fler lägen och ⋯ › Historik på simulatorn (E2E).
- Kelly: ska den löpande texten synas medan man talar? Ska det finnas en "jag hörde dig"-ton?
- Aron på telefon: ställ en fråga, stäng av nätet och ställ en till, slå på nätet och tryck Försök igen. Det rätta svaret ska komma.
