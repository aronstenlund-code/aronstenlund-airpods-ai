# K111: omskriven fråga som blev dubblett får tillbaka originalet

Kevin (moln), 2026-11-19. **0 ElevenLabs.** Testkonton, inga webbsök. Tester: **783/783**. Claude cirka 1 USD (tre provmätningar). Commit 3296ade4, deploy-backend 350 grön.

## Vad som gjordes (Deangelos ja 20:05 till K109-förslaget)
- **Svarssteget skriver inte om något mer.** När alla svar finns jämför koden de korta svaren med k102-measures mått.
  - Har en omskriven fråga (`may_fix`) samma svar som en annan fråga, får den **tillbaka sin ursprungliga fråga och sitt svar**.
  - Inget nytt anrop görs.
- **Vad jag hittade, verifierat i loggen:** Vasa 6 och 8 i K109-körningen skrevs om redan i **första** svarsanropet, inte i ett omförsök. Det fanns ingen `drill_unanswered`.
  - Något svar på originalfrågan fanns alltså inte, och "utan nytt anrop" gick inte att lösa med det som fanns.
- **Lösningen:**
  - När modellen skriver om en fråga lämnar den i samma svar även `original`, alltså sitt svar på frågan som den var ställd. Det kostar några tokens på de omskrivna frågorna, men inget nytt anrop.
  - Koden använder också ett tidigare svar på originalfrågan, om ett sådant finns från ett omförsök.
- **Originalet lämnas tillbaka bara när:**
  - svaret besvarar frågan, alltså inte "framgår inte" eller "inte känt" (K110); och
  - svaret inte självt är en dubblett av en annan fråga.
  
  Annars står omskrivningen kvar, och loggen skriver `drill_rewrite_same {back, kept}`.
- **Testfall** (`exam/k111_test.ts`):
  - **Vasa 8:** omskrivningen fick fråga 9:s svar. Originalfrågan om Gustav Vasas bibel och dess svar kommer tillbaka, med ett enda anrop.
  - **Vasa 6:** originalet ("Varför ville Gustav Vasa komma åt kyrkans rikedomar …?") besvaras i materialet bara med skulderna till Lübeck. Det är samma svar som fråga 5, eller "inte känt härifrån".
    - Därför står omskrivningen kvar, och ett "framgår inte"-svar kommer aldrig tillbaka.
    - Paret 5/6 kommer från materialet självt: en enda mening bär båda frågorna. Det ligger i den sista kontrollen (samma källa), inte här.

## Mätt på Oscars fem prov (`k102-measure.py --answers`)
| | Före (K110, 44593607800) | Efter, körning 1 (44594897633) | Efter, körning 2 (44594918755) |
|---|---|---|---|
| Par med samma korta svar | 9 (1, 2, 3, 3, 0) | 10 (2, 2, 0, 3, 3) | 11 (3, 3, 0, 3, 2) |
| Fulla prov | 5 av 5 | 5 av 5 | 5 av 5 |
| Förståelse | 0,64–0,79 | 0,36–0,79 (Vasa 0,36) | 0,57–0,86 |
| `drill_rewrite_same` | – | 1 omskriven dubblett, behållen | 1 omskriven dubblett, behållen |

**Ärligt resultat: K111 påverkar inte paren mätbart.**
- Före: 9 par. Efter: 10 och 11. Skillnaden är brus mellan körningar.
- Loggen visar att regeln hittade **två** omskrivna frågor med samma svar som en annan, på tio prov. Ingen av dem kunde få tillbaka sitt original:
  - originalet besvarades inte; eller
  - det var en dubblett också.

  Det är samma läge som Vasa 6, där materialet bara har en mening.
- **Min slutsats i K109 var fel.** Där skrev jag att de flesta par kommer från svarsstegets omskrivningar, men det byggde på en enda Vasa-körning. I de här tre körningarna kommer nästan alla par från frågor som **aldrig skrevs om**. Det är två frågor som den sista kontrollen släppte igenom men som besvaras med samma fakta.
- K111 står kvar. Det kostar inget extra anrop, gör det rätta när ett original finns, och loggar varje fall.

## Vasa: förståelseandelen
I körning 1 var Vasas förståelseandel 0,36, alltså under hälften (D230). I körning 2 var den 0,57. Det är samma variation som Oscar såg (5/14). Det hänger inte ihop med K111: ingen fråga ändrades av regeln.

## Förslag till Deangelo (paren)
Paren uppstår mellan frågor som den sista kontrollen redan har godkänt. De kan bara tas bort **innan listan visas**, alltså i sista kontrollen.
- **(a)** Gränsen för hur många som får tas bort höjs från en tredjedel till hälften när påfyllningen kan fylla upp. Vasa når taket varje gång.
- **(b)** Den sista kontrollens svarsmening jämförs med ett lösare mått. I dag krävs minst 4 gemensamma ordstammar och 60 %. Förslaget är 3 ordstammar och 50 %, eller samma första källmening. Vill du ha det mäter jag före och efter med två körningar per sida, eftersom en körning är för brusig.
- **(c)** Paren lämnas som de är. De är cirka 2 per prov, och båda frågorna är rätt besvarade.

Min rekommendation är (a) tillsammans med (b), med mätning. Om du hellre vill hålla kostnaden nere är (c) rimligt.

## Till Oscar
Se oscar.md: K111 att testa om, med Vasa 6 och 8 som exempel. Omskrivna dubbletter loggas som `drill_rewrite_same`.
