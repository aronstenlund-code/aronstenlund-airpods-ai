# A49 – Sömnläge (D123, C5) (Angela, 2026-11-11)

Underlag: D123 och kön. **Det här är kod och enhetstester. Inget är provat på telefon** (untested assumption):
- en natt på nattduksbordet;
- Apples ljudklassning av snarkning och sömnprat;
- den svenska taligenkänningen på telefonen;
- batteriet per natt.

Bilderna är inte tagna än. Scenerna `sleep` och `sleepReport` finns.

## Vad som gjordes
- **"Sov"** finns i Fler lägen. Lumens vanliga lyssnande stängs först, eftersom bara en i taget kan använda mikrofonen.
  Sedan visas skärmen "Sov gott" med tre rader:
  - lägg telefonen nära sängen med laddaren i;
  - inget skickas, och klippen sparas bara på telefonen i 30 dagar;
  - delar du rum kan även den andras prat spelas in.

  Knappen "Vakna" avslutar natten.
- **Hela natten på telefonen** (`SleepRecorder`):
  - Apples ljudklassning (SoundAnalysis, version 1) skiljer tal, snarkning och andra ljud åt.
  - Tal sparas som ett klipp: 1,5 s före, och sedan tills det varit tyst i 2 s, högst 30 s.
  - Efter natten skrivs klippen ut ordagrant med telefonens egen taligenkänning (`requiresOnDeviceRecognition`).
  - Inget skickas till servern.
  - Mikrofonindikatorn syns hela natten.
- **Morgonrapporten:**
  - "Du pratade 2 gånger i sömnen";
  - snarkning i minuter, oroliga perioder och batteriet;
  - en tidslinje i delar om 10 minuter: prat, snarkning, oroligt eller lugnt;
  - "Det du sa" med tiden, texten och ▶ för klippet;
  - "Radera natten".

  Start visar "I natt …" i 16 timmar efter att man vaknat.
- **Lagring:** nätterna och klippen finns i Application Support/Sleep och raderas efter 30 dagar.

**Kod:**
- `Lumen/Core/Sleep/SleepNight.swift`, `SleepRecorder.swift` och `SleepController.swift`;
- `Lumen/Features/Sleep/SleepViews.swift`;
- `ListeningModel.sleep` och `startSleep()`;
- `HomeView` med Fler lägen.

## Tester
`LumenTests/SleepTests.swift`:
- sammanfattningen stämmer;
- tidslinjen stämmer: prat, lugnt, snarkning, oroligt, prat, lugnt;
- antalet oroliga perioder stämmer;
- nätter äldre än 30 dagar raderas med sina klipp;
- nätterna sparas och kan läsas tillbaka.

## CI
Grönt i CI: iOS build 42917153228 (`5fb0a5a`). Bygget för enhet räknar varningar som fel, och alla LumenTests är
gröna, SleepTests inräknade.

## Concerns
Sömnläget spelar in ljud, till skillnad från resten av appen.
- Det sker bara när användaren själv trycker på "Sov". Klippen stannar på telefonen och raderas efter 30 dagar.
- Delar användaren rum kan den andras prat spelas in. Skärmen säger det, men det är den personens röst utan deras
  samtycke.

Jag har byggt efter D123 inom de dokumenterade skydden: man slår på det själv, mikrofonindikatorn syns och inget
skickas. Arkitekten bör ändå ta ställning till om klipp av andras röster ska raderas eller ignoreras, till exempel med
röstprofilen (D81).

## Kvar
- Bilder i Simulatorn, så Kelly kan rita Ke27.
- Ett test på telefonen: en natt och batteriet.
- Ikonen ▶ byter inte tillbaka när ett klipp har spelats klart.
