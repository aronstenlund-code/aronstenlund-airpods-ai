# Köp: kreditpaket och veckokort (Kelly (moln), Ke73 + Ke77, D218/D222/D224, 2026-11-17)

Ett förslag till Angela Fable (A134, A141). **Ke77 (D224):** veckokortet 79 kr och 20 000 tecken, "Bäst värde",
ett prov ≈ 6 000 krediter, välkomstkrediter och inbjudan; kapseln "Veckokort" i stället för "Obegränsat" (D222). Bygger på kreditbladet (Ke71) och första skärmen (Ke72). Skisser i
`bilder/kop/<id>.png` (ljust | mörkt), källa `_src/kop.html`, render `node docs/design/_src/kop-render.js`.
**Skisser, inget byggt, inga riktiga köp** (StoreKit-konfigurationsfil i simulatorn, D218). Priserna sätts i App Store
Connect, inte i koden; appen visar `Product.displayPrice`.

## 1. Kreditbladet med köp (`blad.png`)
Uppifrån: rubrik **Krediter** · **Klar**, siffran **{1 236}** och **"krediter kvar"**, sedan:
| Avsnitt | Rad | Knapp |
|---|---|---|
| **FYLL PÅ** | 100 krediter | **10 kr** |
| | 500 krediter | **39 kr** |
| | 2 000 krediter · märket **Bäst värde** | **110 kr** |
| *fotnot* | Ett prov ≈ 6 000 krediter. | |
| **VARJE VECKA** | **Veckokort** · *79 kr i veckan · cirka 3 prov* | **79 kr** |
| **BJUD IN** | **Få 2 000 krediter** · *när en kompis har spelat sin första text* | **Bjud in** (delningsbladet) |

"Bäst värde" är ett litet tonat märke efter namnet, inte en fylld knapp. "Cirka 3 prov" = 20 000 / 6 000 (D224);
taket står exakt i fotnoten och i villkoren.

Prisknapparna är **tonade kapslar** (som "Hämta" i App Store), inte fyllda: inget val är förvalt. Ett tryck öppnar Apples
köpruta (`product.purchase()`); under köpet visar knappen en snurra.

Under: **fotnoten** (Apples krav för prenumerationer, riktlinje 3.1.2):
"Veckokortet kostar 79 kr i veckan och förnyas automatiskt tills du säger upp det, senast 24 timmar före nästa vecka. Säg upp
i Inställningar › ditt namn › Prenumerationer."
och länkraden **Villkor · Integritet · Återställ köp** (`AppStore.sync()`). Sist avsnittet **SÅ RÄKNAS DET** från Ke71.

## 1b. Första gången (`valkommen.png`)
Ett nytt konto har **5 000 välkomstkrediter** (en gång per telefon, D224). Kapseln på första skärmen visar **"5 000
krediter kvar"** som vanligt; ingen ruta och ingen förklaring där. I bladet står under siffran **"välkomstkrediter"** i
stället för "krediter kvar" tills de är slut. När månadens 1 500 läggs till står det "krediter kvar" igen.

## 1c. Bjud in
Raden **Bjud in** öppnar delningsbladet med en länk. Texten i länken: **"Plugga med EarMind. Du får 5 000 krediter att
börja med."** När kompisen har spelat sin första text: en rad överst i bladet nästa gång, **"+2 000 krediter. {Namn}
har börjat."** (utan namn om kompisen inte visar något: **"+2 000 krediter för en inbjudan."**). Efter 10 inbjudningar
i månaden: undertexten blir **"Du har bjudit in 10 i månaden. Fler ger krediter nästa månad."** och knappen finns kvar.

## 2. Krediterna räcker inte (`slut.png`)
Raden vid Spela (Ke72) får en länk: **"{120} krediter · du har {88} · Fyll på"**. "Fyll på" öppnar bladet. Vid 402
från servern: samma rad (D212).

## 3. Med veckokort (`vecka.png`, `vecka-hem.png`)
- Kapseln: **"Veckokort"** (D222; "Obegränsat" bara för admin, D216). Kostnadsraden vid Spela: **"Ingår"**.
- Bladet: **"Veckokort"** stort, under **"till {24 nov} · {16 200} av 20 000 tecken kvar i veckan"**, raden **Hantera
  veckokortet** (`showManageSubscriptions`), fotnoten **"Förnyas automatiskt den {24 nov} för 79 kr."**, och paketen under
  (tonade) med samma länkrad.
- När veckans 20 000 tecken är slut: kostnadsraden **"Veckans tak är nått · Fyll på"** och Spela grå tills nästa vecka
  eller ett paket.

## 4. Största text (`se-kop.png`)
Raderna staplas: namnet över, prisknappen under, vänsterställd. Fotnoten och länkarna går att skrolla till.

## 5. Texter
| Ställe | Text |
|---|---|
| Avsnitt | FYLL PÅ · VARJE VECKA · BJUD IN · SÅ RÄKNAS DET |
| Paket | {100} krediter · *knapp* {10 kr} |
| Märke | Bäst värde (bara på 2 000) |
| Fotnot under paketen | Ett prov ≈ 6 000 krediter. |
| Veckokort | Veckokort · {79 kr} i veckan · cirka 3 prov |
| Fotnot (krav 3.1.2) | Veckokortet kostar {79 kr} i veckan och förnyas automatiskt tills du säger upp det, senast 24 timmar före nästa vecka. Säg upp i Inställningar › ditt namn › Prenumerationer. |
| Länkar | Villkor · Integritet · Återställ köp (Villkor → earmind.vercel.app/villkor, Integritet → /integritet, Ke78, när Aron har sagt ja) |
| Första gången, bladet | 5 000 · välkomstkrediter |
| Bjud in, rad | Få 2 000 krediter · när en kompis har spelat sin första text · *knapp* Bjud in |
| Bjud in, länktext | Plugga med EarMind. Du får 5 000 krediter att börja med. |
| Inbjudan klar | +2 000 krediter. {Namn} har börjat. / +2 000 krediter för en inbjudan. |
| Tio i månaden | Du har bjudit in 10 i månaden. Fler ger krediter nästa månad. |
| Räcker inte | {120} krediter · du har {88} · Fyll på |
| Med veckokort, kapsel / kostnad | Veckokort / Ingår |
| Med veckokort, bladet | Veckokort · till {24 nov} · {16 200} av 20 000 tecken kvar i veckan · Hantera veckokortet · Förnyas automatiskt den {24 nov} för {79 kr}. |
| Veckans tak nått | Veckans tak är nått · Fyll på |
| Köpet misslyckades | Köpet gick inte igenom. Inget har dragits. |
| Återställ, inget att hämta | Det fanns inga köp att hämta. |
| Köpt men servern nås inte (A134) | Köpet är gjort. Krediterna kommer när EarMind har kontakt igen. |
| Köpet väntar (Be om köp) | Köpet väntar på godkännande. Krediterna kommer när det är godkänt. |
| Återställ misslyckades | Det gick inte att hämta köpen just nu. Försök igen om en stund. |

Priserna i texterna är exempel: appen visar `Product.displayPrice` (D218), så "79 kr" kommer från App Store Connect.

## 6. Ordet "Obegränsat" (avgjort, D222)
Prenumeranter ser **"Veckokort"**. "Obegränsat" finns bara för admin (D216), där det är sant.

## 7. Nytt prov när krediterna är få (A154, D239; Kelly (moln) 2026-11-20)
| Läge | Ruta överst | Knappen längst ner | Rad under knappen |
|---|---|---|---|
| Inget prov ryms | "Ett prov med 3 frågor kostar cirka {1,6k} krediter. Du har {1,5k}." · Fyll på | Skapa frågor (avstängd) | Krediterna räcker inte till ett prov. |
| Några frågor ryms | "Krediterna räcker till {5} frågor." · Fyll på | **Skapa {5} frågor** (fylld) | {3,3k} krediter kvar |
| Provet kostar mer när det är klart | "Det här kostar {1,6k} krediter. Du har {1,5k} kvar. Nya krediter den {1 december}." · Fyll på | – | – |

- **En knapp som skapar:** knappen längst ner säger antalet ("Skapa 5 frågor"); rutan har bara Fyll på.
- **Läs upp texten:** gäller valet Läs upp texten spärrar inte rutan om prov; kostnaden för uppläsningen avgör.
- Raden under knappen säger "{3,3k} krediter kvar", aldrig "av 1,5k … den här månaden" (köpta och givna krediter räknas in).
