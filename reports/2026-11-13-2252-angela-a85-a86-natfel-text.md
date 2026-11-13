# Angela A85 och A86: falskt "Ingen internetanslutning", och "Kom förberedd till provet"

Datum: 2026-11-13 22:52. Roll: Angela (app). Uppdrag: A85 (Arons telefontest 22:13, blockerare) och A86 (Aron 22:19).

## Sammanfattning
- **A85:** felet var appens eget, och felmeddelandet var fel.
  - **Bilderna:** `ExamMaterials.jpeg` gjorde en bild med "högst 1 600" punkter, och `UIGraphicsImageRenderer` ritar
    med skärmens skala (3× på iPhone). Det blev 4 800 px och flera MB per foto.
  - **Serverloggen** (Kevin K51, verifierad i Supabase-loggen): Arons andra anrop var **13,9 MB för 2 bilder** och fick
    413 efter 0,6 s.
  - **Det första anropet** (2,5 MB) fick 502, eftersom skärmfotona inte gick att läsa (`drill_unreadable`, nu 422 med en
    svensk orsak).
  - **Meddelandet:** appen gjorde `.networkConnectionLost` till "Ingen internetanslutning". Det felet uppstår till exempel
    när servern svarar och stänger medan en stor uppladdning pågår.
- **Rättat:**
  1. Sidorna blir högst 1 600 **pixlar** (renderern har skala 1) och högst 1,2 MB, med JPEG 0,7, 0,55 eller 0,4.
     Samma kod används för Provlägets fotade sidor (`PagePhoto`), så de blir också mindre.
  2. Varje anrop till `/exam` loggar statuskod eller URLError-kod, antal byte, tid och nät (wifi/cellular).
  3. En bruten anslutning (`networkConnectionLost`, `timedOut`, `cannotConnectToHost`, `secureConnectionFailed`)
     försöks en gång till efter 1 s.
  4. "Ingen internetanslutning" visas bara när `NWPathMonitor` säger att telefonen saknar nät, eller vid
     `notConnectedToInternet`/`dataNotAllowed`. Annars visas "Det gick inte att skapa frågorna. Försök igen." med
     knappen **Försök igen**.
  5. Serverns 4xx-svar visas med serverns svenska text: 413 för stora bilder, 422 för oläsbart material och 429 för
     gränsen.
- **A86:** rubriken på Hem utan prov, det första man ser efter "Testa nu" sedan A80, heter nu **"Kom förberedd till
  provet"** (var "Plugga med AirPods"). Raden under den är oförändrad (Ke50). **Untested assumption:** att det är den
  här texten Aron menade. Det är den enda texten i början om att förbereda sig för prov. Kelly granskar på bild.

## Test
- **CI (verifierat):** iOS build **43511121798 grön** på dbfa91f. Det omfattar device-bygget, alla enhetstester och
  `Lumen-unsigned.ipa` (15,6 MB).
- **Nya enhetstester** (`LumenTests/A85DrillUploadTests.swift`):
  - ett 3×-foto med ränder blir högst 1 600 px och högst 1,2 MB;
  - vilka URLError-fel som försöks igen;
  - serverns 413-text visas, 502 ger den allmänna texten, och "offline" ger "Ingen internetanslutning".
- **Inte provat:** 2 och 10 skärmfoton på telefon över 5G (A85 punkt "Testa med 2 och 10 skärmfoton"). Aron eller Toby
  gör det med det här bygget. Loggraden "exam drill: 200, N bytes sent, M ms" visar storleken.

## Inte gjort
- **"Skicka i flera anrop om de är många":** K45 tar högst 20 sidor i ett anrop och gör en sammanfattning och en
  frågelista av allt. Delas materialet i flera anrop blir det flera listor som inte går att slå ihop. Med 1 600 px och
  högst 1,2 MB per sida är 20 sidor högst cirka 32 MB base64 i värsta fall, men oftast 4–8 MB. Det ligger under
  serverns gräns på 24 MB för hela anropet vid normala foton, men inte i värsta fall. **Risk:** 20 svårkomprimerade
  skärmfoton kan få 413. Kevin och jag behöver då en uppladdning per sida (K45 med `pages` från Storage). Det är inte
  byggt.
- Kevins nya fält (`questions_possible`/`note`, `error` per fråga, tom `grade`, kvoten 15 per månad) och Kellys
  N1–N4 tas i nästa push.

## Nästa
Kellys N1–N4 och Kevins nya K51-fält, sedan A87 (Apple-stil, D160) och A83.
