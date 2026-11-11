# A58 – K36:s telefonverktyg: ring och öppna musik (egen punkt, dagens mål 3)

Angela, 2026-11-11. Underlag: Kevins K36 (`reports/2026-11-11-1104-kevin-k36-spotify-calls.md`, `docs/AGENT.md`,
D132). Deangelo hade inte lagt in punkten. Jag tog den som egen punkt (README 8), eftersom dagens mål 3 säger att
samtal byggs.

## Vad som är gjort
- **`call_contact` (”Lumen, ring mamma”):**
  - Appen erbjuder verktyget i `tools_available`, som de andra telefonverktygen (A48).
  - Med ett `number` som eleven själv sa ringer appen det numret. Servern behåller bara siffror som sades (B6).
  - Annars slås `name` upp i Kontakter. Tillåtelsen frågas första gången, och behörighetstexten är ny.
  - Namnet matchas mot smeknamn ("Mamma"), hela namnet, förnamnet och företaget, och bestämd form ("tandläkaren" =
    "Tandläkare …").
  - **En träff:** mobilnumret väljs först, och appen öppnar `tel://`. iOS frågar själv "Ring …?", och det kräver ett
    tryck. Lumen frågar inte en gång till.
  - **Flera träffar** ger `{error: "several", names: [...]}`, så att Lumen kan fråga vilken. **Ingen träff** ger
    `no_contact`, och **ingen tillåtelse** ger `no_permission`.
  - Inget från Kontakter skickas till servern, bara resultatet. Vid flera träffar skickas högst fyra namn.
- **`music_open` (”Lumen, spela lugn pluggmusik”):**
  - Appen öppnar Spotify med sökningen (`spotify:search:…`). Saknas appen öppnas `open.spotify.com/search/…`.
  - Eleven trycker själv på spela.
- **Vad kan Earmind?:**
  - "Ring" visar behörigheten till Kontakter, med Tillåt.
  - Den nya raden "Öppna musik" lyder "Öppnar Spotify med sökningen".
  - **Spotify-styrningen står kvar som "Kommer snart".** OAuth-piloten (Premium, högst 5 konton, Arons Spotify-app)
    är inte byggd.
- Exemplen på Start har inte fått tillbaka ”ring” och ”spellistan”. Det väntar tills Aron har provat på telefon
  (Ke29 S2).

## Tekniskt
- `PhoneTool.callContact` och `.musicOpen`.
- `Core/Agent/PhoneCall.swift` innehåller `PhoneCall` och `MusicSearch`. De är rena och testade.
- `LivePhoneTools.lookUpContact` använder CNContactStore utanför MainActor, som EventKit-verktygen.
- `NSContactsUsageDescription` finns i Info.plist och `InfoPlist.xcstrings` (sv/en). `LSApplicationQueriesSchemes`
  hade redan `spotify`.

## Testresultat
- **Enhetstester:**
  - `LumenTests/A58Tests.swift` har 6 tester: smeknamn och mobilnummer, två Elin, bestämd form, nummer, sökning och
    verktygsnamnen.
  - `PhoneToolsTests` räknar nu `PhoneTool.allCases`.
  - `A52Tests` har uppdaterats för Ring.
- **iOS-bygge och enhetstester:** CI 43005793046 (867fbff), **grön**: device-bygget, alla enhetstester och `Lumen-unsigned.ipa`.
- **Ej verifierat på enhet:**
  - frågan om Kontakter;
  - att `tel:` öppnas medan appen lyssnar i bakgrunden. Med telefonen i fickan kan iOS vägra, och då blir resultatet
    `cannot_call`.

## Till Aron
- Prova "Lumen, ring …" med någon i dina kontakter. iOS frågar först om Kontakter och sedan "Ring …?".
- Spotify-styrningen: Kevins klickväg i `docs/AGENT.md`, om du vill vara pilot (Premium).
