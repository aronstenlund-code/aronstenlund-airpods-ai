# Kevin K19: Länkar till bra filmer och sidor om det man pluggar

Datum 2026-11-10 09:50 · Uppgift: `prompts/queue/kevin.md` K19 (godkänt av Aron) · Driftsatt (Deploy backend 42782308350, commit 13bcf21) · **Verified live** (`scripts/k19-eval.py`, 8 förfrågningar i Provläge, åk 8). Länkarna har hämtats en gång till av mätskriptet. **Inte testat på telefon.**

## Resultat
| Fråga | Länk (källa) | Hämtad igen |
|---|---|---|
| film om fotosyntes | UR Play: "NO naturligtvis: Fotosyntes" | 200 |
| film om franska revolutionen | UR Play: "Plugga historia: Franska revolutionen" | 200 |
| video om Pythagoras sats | UR Play: "Kalkyl: Pythagoras sats" | 200 |
| film om andra världskriget | UR Play: "Plugga historia: Andra världskriget" | 200 |
| film om syror och baser | UR Play: "Snabbkoll!: Syror" | 200 |
| film om plattektonik | SLI (en sökvy som kräver inloggning, "Logga in"). Svaret säger att den kan kräva skolkonto | 200 |
| sida om ekvationer | ingen. Svaret: "Jag hittade ingen bra film eller sida om det just nu …" | – |
| film om cellen | ingen (samma svar) | – |

**6/8 med länk, 6/6 svarar 200, 5/6 är en film om rätt ämne och 0 påhittade adresser.** Det som sägs är till exempel "Jag skickade en länk till en film om fotosyntes från UR Play, säg till om du vill ha en annan." Fil: `reports/eval/k19-2026-11-10.json`.

## Hur det fungerar (DECISIONS: se raden "K19")
- **Förfrågan:** "har du en film om …", "finns det någon bra sida om …", "skicka en länk" och liknande, i Provläge och Frågor. Inte i Auto, demon eller sociala lägen.
- **Sökningen:** högst 2 sökningar, och bara på urplay.se, binogi.se, sli.se, skolverket.se, ne.se och khanacademy.org. Modellen svarar med `LÄNK: <url> | <titel>` och en mening.
- **Kontrollen i kod:**
  - domänen finns i listan;
  - sidan hämtas och svarar 200;
  - ett ämnesord (de 6 första bokstäverna) finns i titeln, sidans `<title>` eller adressen.

  Annars skickas ingen länk, utan svaret "Jag hittade ingen …".
- **`done.resource`** = `{url, title, source, login_likely}`. Binogi, SLI och NE kräver ofta skolkonto, och då säger svaret det.
- Inom webbtaket (3 per minut och 20 per dag per användare). Ungefär 0,01–0,02 USD per förfrågan.

## Inte gjort
- **"Ibland av sig själv när eleven kört fast (högst en gång per session)":** inte byggt. Den behöver en signal från appen om att eleven kört fast, till exempel två "jag fattar inte" i rad, och `context.resource_sent`. Den signalen finns inte i dag. Förslag: Angela skickar `stuck: true`, så söker /answer en länk en gång.

## Till Angela
Visa `done.resource` som en tryckbar länk (titel och källa) i lyssnarskärmen och i Anteckningar. Läs upp den talade meningen som vanligt.

## Risker
- Kontrollen av ämnet är grov: ett ämnesord i titeln eller adressen. En sida om "syror" godtas för "syror och baser".
- En sida som kräver inloggning kan inte kontrolleras närmare (SLI visade "Logga in").
- UR Play dominerar resultaten, eftersom deras sidor syns bäst i sökningen.

## Kostnad
Ungefär 0,1 USD (8 förfrågningar med sökning).
