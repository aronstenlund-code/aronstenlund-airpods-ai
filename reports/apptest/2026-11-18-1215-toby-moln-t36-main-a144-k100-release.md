# T36 på main: A144, K100, T44, T48 och Release utan testläge (D227)

Toby (moln), 2026-11-18 12:15. Simulatorn (iPhone 17, iOS 26, Xcode 26.6), riktig server med x-earmind-test, falskt ljud, 0 ElevenLabs. **Allt är verifierat i Simulator eller i bygget, inget på enhet.**

## Körningar
- T36 44283940066 och 44294585063 på toby/t44. Det är main med A142, A143, A144 och K100 (grönt bygge 44277444246), plus mina tester.
- Release-kontrollen 44294628876 på toby/release-check.

## Resultat
- **K100** (en ny Säg-text sparas och startas i ett anrop): Spela gav kortets läge efter 1,1–1,6 s ("Gör ljudet …", "9:50 kvar", "Spelar i AirPods · Adam"), i fyra mätningar. Att det är *ett* anrop syns inte i appens logg. Supabase-loggen kunde jag inte läsa från den här sessionen (untested assumption: ett anrop; verifierat: svaret på under 2 s).
- **T44:** kapseln 1 500 före och 1 400 efter första Spela av en ny text, i båda körningarna. Krediterna dras med testljud.
- **T48 efter Fables rättning:** utan produkter står "Fyll på" med "Paketen kunde inte hämtas från App Store just nu." och Försök igen. Återställ köp svarar "Det gick inte att hämta köpen just nu. Försök igen om en stund." inom 20 s. Testköp är fortfarande otestat (StoreKit-filen når inte ett UI-test).
- **T50:** röstkapseln "Röst, Adam" syns nu (K99), och rösten Louise spelade i takt.
- **A144 med fejkade tider (`x-earmind-test: slow`): fynd, till Angela Fable 11:30.**
  - Med K100 går kortet efter Spela direkt till spelläget: "Gör ljudet …", tiden räknas ner ("9:20 kvar"), Pausa och Stoppa.
  - Varken "Det tar längre tid än vanligt." (8 s) eller "Ljudet kunde inte hämtas." med Försök igen (25 s) kom på 45 s, i båda körningarna.
  - För användaren: "Gör ljudet …" utan slut när ljudet inte kommer.
- **Release utan testläge (D227):** egen kontroll, oberoende av Angela Schrutes steg i ios-build. Debug och Release byggs för enheten utan signering, och båda söks igenom. Debug är kontrollen: alla märken ska finnas där. Inget körs.

| Märke | Debug | Release |
|---|---|---|
| `functions/v1/debug-audio` (testläget D140) | 1 fil | 0 |
| `DebugAudioWriter`, `DebugAudioClient`, `DebugAudioController` | 1 | 0 |
| `LUMEN_TEST_HEADER` (x-earmind-test) | 1 | 0 |
| `LUMEN_TEST_PRESSES`, `earmind.test.press` (tryckkroken) | 1 | 0 |
| `LUMEN_TEST_MATERIAL` | 1 | 0 |

## Kvar
- A145 (Radera konto): första försöket nådde inte Inställningar, eftersom bladet Krediter stod kvar efter Klar och tolv tryck. Det är rättat i testet (dra ner bladet, och säga om Klar inte stängde). Omkörning 44300125934.
- Appens "Auth:"-rader kom inte med i loggen. Den fångar hela appens subsystem på nivån info, så raderna loggas troligen på debug.
- T53 när A148 är på main. T54 när Angela Schrute säger till om grenarna angela/g7-7b-rostkanalen och angela/g7-7c-provstarten.

## Tillägg 2026-11-18 18:00: A145 Radera konto och en ny sak utan nät
T36 44312213280 på toby/t44 (main med A145, be0b66f3), Simulator. Kontot är det som simulatorn skapade vid första starten, bara för den här körningen.
- **A145 OK:**
  - Konto ligger sist i Inställningar och syns efter två svep.
  - Frågan heter "Radera kontot?". Avbryt gör ingenting.
  - Utan nät: "Det gick inte att radera kontot, för telefonen har inget nät. Inget är raderat. Försök igen när du är uppkopplad.", och texten i Senaste finns kvar.
  - Med nät: "Kontot är raderat", "EarMind börjar om som ny på den här telefonen." och Välkommen.
  - Efteråt finns 0 kapslar och inga provrubriker, och kapseln visar 1 500 krediter (nytt konto).
- **T48 OK igen:** "Paketen kunde inte hämtas från App Store just nu.", och Återställ köp svarar. Krediter-bladet stängdes med Klar.
- **Ny sak utan nät (till Fable):** en ny text med nätet av gav ingen rad alls på 25 s. Knappen hette kvar "Spela i 10 min", och varken "Ingen internetanslutning …" eller "Ljudet kunde inte hämtas …" kom. Före K100 (44235040986) kom "Ingen internetanslutning …" efter 1,9 s.
- **A144:** väntraderna kommer fortfarande inte på det spelande kortet (samma fynd som 11:30).
- **K100:** Spela till "Gör ljudet …" eller "Spelar" på 1,4–6,0 s.
