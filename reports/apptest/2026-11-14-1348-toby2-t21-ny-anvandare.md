# T21 – Ny användare i första starten (A94), simulatorn (Toby 2, 2026-11-14 13:48)

**Simulatorn räknas aldrig som verifiering på enhet.** Kameran, AirPods-trycken och ljudet i örat syns bara på Arons
telefon.

## Vad som testades
- **Bygget:** A94 på main (iOS-bygge 43582585113 grönt, 99c0f9c), plus det som kommit på main fram till 12:17.
- **Körning:** [43594095637](https://github.com/aronstenlund-code/aronstenlund-airpods-ai/actions/runs/43594095637) på
  `toby/t21` (efc5a0a). Den gick hela vägen till första frågan.
- **Uppsättning:**
  - En raderad simulator (iPhone 17 Pro, iOS 26) utan behörigheter.
  - En bild av materialet (fotosyntestexten) i bildbiblioteket via `simctl addmedia`.
  - Test: `AppTests/E2E/Screens/NewUserRepetitionTests.swift`, `scripts/apptest/newuser.sh` (+ `material_png.swift`),
    `.github/workflows/apptest-newuser.yml`.
  - Testet trycker bara på det som syns på skärmen.
- **Testtryck räknas inte som användarens:**
  - Antal frågor från 20 ner till 3 (D120: ungefär 0,15 USD röst, inte 1 USD).
  - Tre "Hoppa över" på Styr med dina AirPods, eftersom simulatorn saknar AirPods.
  - En titt i Läs mer.
- **Rådata och bilder:** `reports/apptest/2026-11-14-t21/`.

## Resultat
| Krav / mått | Mätt | Utfall |
|---|---|---|
| Högst 3 skärmar före kameran | **2** (Välkommen → Nytt prov, Fota sidor är första raden) | Uppfyllt |
| Ingen BETA-text i första starten | Ingen på Välkommen, Läs mer, Nytt prov eller Stämmer det här? | Uppfyllt (se fynd 2) |
| Tryck till kameran | 1 (Fortsätt), Fota sidor är tryck 2 | – |
| Tryck till första frågan | 9: Fortsätt, Fota sidor, Välj bilder, bilden, Lägg till, Skapa frågor, Ser rätt ut, Starta prov, Starta (efter kontrollskärmen) | – |
| Skapa frågor → Stämmer det här? | 12 s | – |
| Ser rätt ut → ljudet klart | 24 s (3 frågor, "Ljud: 0 av 6 klara" under tiden) | – |
| Första frågan | "Fråga 1 av 3 · Varför behövs klorofyll?" med betänketid och "Tryck på AirPods för svaret" | Rätt |

Hela körningen tog 279 s från att appen öppnades. Ungefär 160 s av det var testets egna väntetider och
bildbibliotekets svar i simulatorn, så tiden säger inget om en människas tempo.

Texterna stämmer med Kellys Ke55: "Välkommen till Earmind", de tre raderna, raden om data med Läs mer, "Börja med
materialet till ditt nästa prov.", Senare (inte Avbryt) och Fota sidor först. Frågorna blev bra av bilden:
"Varför behövs klorofyll?", "Vad bildas vid fotosyntesen?" och "Vad används sockret till?". Ämnet blev Biologi och
provet heter Biologiprovet.

## Fynd
1. **Skriv text är ett tomt blad** (`t21-02-skriv-text-utan-tangentbord.png`).
   - Bladet har ingen platshållare, ingen markör och inget tangentbord, så en ny användare ser inte att man kan skriva
     där.
   - Testet fick aldrig fokus i fältet: varken tryck, långt tryck eller att skriva direkt till appen fungerade. Det
     gällde i tre körningar och både före och efter bildbladet (43585273570, 43586474124, 43587898100).
   - Om ett tryck fungerar på telefonen är en **untested assumption**.
   - **Förslag till Angela:** en platshållare (t.ex. "Klistra in eller skriv texten här") och `.focused` med fokus
     direkt när bladet öppnas.
   - Angela Fable har fått fyndet i sessionen.
2. **"Fler lägen · Beta · använder mikrofonen" syns på Start före första frågan.**
   - Efter Ser rätt ut hamnar man på Start (provkortet med Starta prov), inte i en egen frågelista. Där står raden
     Fler lägen med texten "Beta · använder mikrofonen".
   - Enligt Ke55 är det tänkt: BETA nås via Fler lägen. Men det är det första en ny användare ser efter första
     starten, före första frågan.
   - **Deangelo/Kelly avgör** om Start räknas till första starten. Testet räknar nu BETA bara i A94:s egna skärmar
     och loggar Start för sig.
   - På skärmarna efter Start (kontrollskärmen och spelaren) ligger Start under, så raden finns i trädet men syns inte.
3. **Fota sidor öppnar bildbiblioteket i simulatorn**, eftersom den saknar dokumentkamera. Att den riktiga
   dokumentkameran öppnas på telefonen är en **untested assumption**, och Aron ser det i sin första start.
4. **Upprepade texter i tillgänglighetsträdet**, till Angela Fable (A95).
   - På Styr med dina AirPods och i spelaren finns varje rad två gånger, t.ex. "tryck 1 gång för frågans A-svar." och
     "Långt svar, 1 tryck på AirPods".
   - Betänketiden läses bara som en siffra ("4").
   - VoiceOver kan läsa dubbelt. Det ska kontrolleras med A95-granskningen.

5. **Ljudet fastnade på 3 av 6 i den andra hela körningen**
   ([43596613226](https://github.com/aronstenlund-code/aronstenlund-airpods-ai/actions/runs/43596613226), 2e262ae).
   - Provet sparades 13:01:43 med "audio 3/6", och i 300 s rörde sig "Ljud: 3 av 6 klara" inte. Därför blev Starta
     prov aldrig tryckbart.
   - Ingen felrad i appens logg. Appen loggar inte sin hämtning av ljudet, och `drill` och `drill_answers` gav 200.
   - I körningen före gick det på 24 s (2/6 → klart).
   - Det har hänt en gång. **Till Kevin** (drill_audio / K46-jobbet 12:01–12:06 UTC) och **Angela** (en loggrad per
     hämtning av ljudet, och vad användaren ser om ljudet står still). Ej undersökt i backend: Supabase-MCP:n är inte
     inloggad i den här sessionen.
   - Testet kördes inte om, eftersom vägen redan är bevisad (D120).

## Även gjort under passet (åt Angela Fable, A95)
- `.github/workflows/apptest-a11y.yml` och `AccessibilityAuditTests.swift` kör XCTests tillgänglighetsgranskning och
  sparar trädet per Debug-scen.
- Konfigurationer: iPhone 17 Pro med standardtext och iPhone SE med största text.
- Filerna skrivs per scen, och en vakthund stoppar en granskning som fastnar.
- 30 av 30 scener på båda (43593653293). Granskningen fäller aldrig körningen. Angela kör den själv.

## Mina egna fel under passet
- Sju körningar behövdes innan testet kom igenom. Orsaker:
  - skärmens texter lästes medan ett blad animerades;
  - simulatorns tangentbord;
  - Skriv text;
  - fel bild i bildbiblioteket, två gånger.
- Allt skedde på `toby/t21` och påverkade inte main.
- Varje körning kostade bara modellanrop fram till Skapa frågor. Bara 43594095637 gjorde ljud (3 frågor).

## Nästa steg
1. Lägg in Arons telefonsvar (bygget 43543518435) och hans första start, märkt **verified on device**.
2. Kör T21 igen när Angela har rättat Skriv text, och då med Skriv text-vägen (`LUMEN_T21_ORDERS=text-first`).
3. Deangelos besked om fynd 2.
