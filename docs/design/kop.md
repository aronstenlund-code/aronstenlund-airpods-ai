# Köp: kreditpaket och veckokort (Kelly (moln), Ke73, D218/D214, 2026-11-17)

Ett förslag till Angela Fable (A134). Bygger på kreditbladet (Ke71) och första skärmen (Ke72). Skisser i
`bilder/kop/<id>.png` (ljust | mörkt), källa `_src/kop.html`, render `node docs/design/_src/kop-render.js`.
**Skisser, inget byggt, inga riktiga köp** (StoreKit-konfigurationsfil i simulatorn, D218). Priserna sätts i App Store
Connect, inte i koden; appen visar `Product.displayPrice`.

## 1. Kreditbladet med köp (`blad.png`)
Uppifrån: rubrik **Krediter** · **Klar**, siffran **{1 236}** och **"krediter kvar den här månaden"**, sedan:
| Avsnitt | Rad | Knapp |
|---|---|---|
| **FYLL PÅ** | 100 krediter | **10 kr** |
| | 500 krediter | **39 kr** |
| | 2 000 krediter | **110 kr** |
| **VARJE VECKA** | **Veckokort** · *80 kr i veckan · upp till 40 000 tecken nytt ljud* | **80 kr** |

Prisknapparna är **tonade kapslar** (som "Hämta" i App Store), inte fyllda: inget val är förvalt. Ett tryck öppnar Apples
köpruta (`product.purchase()`); under köpet visar knappen en snurra.

Under: **fotnoten** (Apples krav för prenumerationer, riktlinje 3.1.2):
"Veckokortet kostar 80 kr i veckan och förnyas automatiskt tills du säger upp det, senast 24 timmar före nästa vecka. Säg upp
i Inställningar › ditt namn › Prenumerationer."
och länkraden **Villkor · Integritet · Återställ köp** (`AppStore.sync()`). Sist avsnittet **SÅ RÄKNAS DET** från Ke71.

## 2. Krediterna räcker inte (`slut.png`)
Raden vid Spela (Ke72) får en länk: **"{120} krediter · du har {88} · Fyll på"**. "Fyll på" öppnar bladet. Vid 402
från servern: samma rad (D212).

## 3. Med veckokort (`vecka.png`, `vecka-hem.png`)
- Kapseln: **"Obegränsat"**. Kostnadsraden vid Spela: **"Ingår"**.
- Bladet: **"Obegränsat"** stort, under **"till {24 nov} · {36 200} tecken kvar den här veckan"**, raden **Hantera
  veckokortet** (`showManageSubscriptions`), fotnoten **"Förnyas automatiskt den {24 nov} för 80 kr."**, och paketen under
  (tonade) med samma länkrad.
- När veckans 40 000 tecken är slut: kostnadsraden **"Veckans tak är nått · Fyll på"** och Spela grå tills nästa vecka
  eller ett paket.

## 4. Största text (`se-kop.png`)
Raderna staplas: namnet över, prisknappen under, vänsterställd. Fotnoten och länkarna går att skrolla till.

## 5. Texter
| Ställe | Text |
|---|---|
| Avsnitt | FYLL PÅ · VARJE VECKA · SÅ RÄKNAS DET |
| Paket | {100} krediter · *knapp* {10 kr} |
| Veckokort | Veckokort · {80 kr} i veckan · upp till 40 000 tecken nytt ljud |
| Fotnot | Veckokortet kostar {80 kr} i veckan och förnyas automatiskt tills du säger upp det, senast 24 timmar före nästa vecka. Säg upp i Inställningar › ditt namn › Prenumerationer. |
| Länkar | Villkor · Integritet · Återställ köp |
| Räcker inte | {120} krediter · du har {88} · Fyll på |
| Med veckokort, kapsel / kostnad | Obegränsat / Ingår |
| Med veckokort, bladet | Obegränsat · till {24 nov} · {36 200} tecken kvar den här veckan · Hantera veckokortet · Förnyas automatiskt den {24 nov} för {80 kr}. |
| Veckans tak nått | Veckans tak är nått · Fyll på |
| Köpet misslyckades | Köpet gick inte igenom. Inget har dragits. |
| Återställ, inget att hämta | Det fanns inga köp att hämta. |

## 6. Till Deangelo: ordet "Obegränsat"
Veckokortet har ett tak (40 000 tecken i veckan, D218). "Obegränsat" i kapseln kan läsas som en lovad egenskap som inte
stämmer, och App Store granskar sådant (riktlinje 2.3 och 3.1.2). Jag visar taket på varje ställe där kortet säljs och
beskrivs ("upp till 40 000 tecken nytt ljud"). Vill Deangelo vara säker: kapseln **"Veckokort"** i stället för
"Obegränsat". Jag har ritat "Obegränsat" som uppdraget säger.
