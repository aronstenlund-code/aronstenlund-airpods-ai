# A36 – Fota sidan du pluggar (Angela, 2026-11-10)

Underlag: beslutet D115 (U4) och kön. **Det här är kod och enhetstester. Kameran och ett riktigt `/exam`-anrop med en
fotad sida är inte provade på telefon.**

## Vad som gjordes
1. **Knappen:** provkortet på Start har "Fota sidan du pluggar" (kamera). Simulatorn saknar kamera och visar
   bildbiblioteket i stället.
2. **Texten läses på telefonen** med Vision (`RecognizeTextRequest`, svenska och engelska, noggrann nivå). Bilden
   skickas aldrig och sparas inte. Under tiden står "Läser sidan …" på kortet.
   - Är texten kortare än 40 tecken står det: "Jag kunde inte läsa sidan. Fota den rakt uppifrån, i bra ljus."
3. **Ämnesorden** hämtas ur sidan till Förberedelser som "Fotad sida 10 nov 14:52", med telefonens egen
   termutdragning (punkt 9). De följer sedan med varje fråga och hjälper igenkänningen.
4. **Övningsfrågor:** sidans text går till `/exam parse` med `text` (K15).
   - **Bara när ingenting tas bort.** Det sker om det inte finns något övningsprov, eller om det som finns också är
     en fotad sida. Ett uppladdat övningsprov ersätts aldrig.
   - Blir det frågor startar Lumen övningsprovet (A16) på dem, en fråga i taget.
5. **Annars förhöret:** blir det inga frågor, eller fanns ett annat prov, startar "Förhör mig" (Provläge). Sidans
   ämnesord finns då med i varje fråga.

**Kod:**
- `Lumen/Core/Study/PagePhoto.swift` är ny: Vision, titeln och regeln om när en sida får ersätta ett prov.
- `Lumen/Features/Listening/PagePhotoPicker.swift` är ny: kameran.
- `ListeningModel.studyPhotographedPage` är ny.
- `HomeView` har fått knappen och visar läget.
- `NSCameraUsageDescription` finns på svenska och engelska: "Fota sidan du pluggar på, så förhör Lumen dig på den.
  Texten läses på telefonen, och bilden sparas inte."

## Tester
`LumenTests/A36Tests.swift`:
- ett uppladdat övningsprov ersätts inte, men inget prov eller en fotad sida får ersättas;
- **Vision läser en tryckt sida i simulatorn**: en ritad bild med "Fotosyntesen omvandlar …" ger texten tillbaka. Det
  testet kör den riktiga Vision-koden.

## Kända begränsningar och risker
- **Untested assumption:** att K15:s `parse` gör frågor av en sida ur en lärobok. Den är byggd för prov och
  instuderingsfrågor. En vanlig textsida kan ge noll uppgifter, och då blir det förhöret i stället.
- Handskrivna anteckningar läses sämre än tryck.
- Kamerans fråga om behörighet kommer första gången man trycker på knappen, inte förut.

## Till Kevin
Om `/exam parse` med en vanlig lärobokssida ger noll uppgifter kan den kanske få ett läge, `"source": "page"`, som gör
3–5 instuderingsfrågor med facit. Säg till om det blir så, så skickar appen det.

## Till Kelly
Se över knappen "Fota sidan du pluggar" på provkortet. Den har samma stil som Minitest-länken.

## CI
Se slutet av rapporten när körningen är klar.
