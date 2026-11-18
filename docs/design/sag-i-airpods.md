# Säg i AirPods: form och texter (Kelly (moln), Ke69, D203–D205, 2026-11-16)

Underlag till Angela Fable (A115 fältet, A116 "+", A117 krediterna). Skisser i `bilder/sag/<id>.png` (ljust | mörkt),
källa `_src/sag.html`, render `node docs/design/_src/sag-render.js`. **Skisser, inget byggt, inget provat på telefon.**

## 1. Idén: Terminal, inte hackerfilm
Aron vill ha terminalkänsla: monospace, blinkande markör, mörkt. Förebilden är **Terminal och Xcode-konsolen** på Mac:
ett mörkt, lugnt fält med systemets monospace och en markör. Det som gör det barnsligt lämnas bort: grön text,
skanningslinjer, ASCII-konst, skrivmaskinsljud och glödeffekter. Resten av Prov-skärmen är oförändrad Apple-stil.

## 2. Skärmarna
| Skärm | Bild | Det viktigaste |
|---|---|---|
| Prov, tomt fält | `prov-tom.png` | Fältet ligger **överst**, under rubriken Prov, före Nästa prov. Det är mörkt i både ljust och mörkt läge (eget verktyg). Rubriken "Säg i AirPods" i systemtypsnittet, raden i monospace med en `›` i accentfärg och en blinkande blockmarkör. Platshållare: "Skriv eller klistra in det du vill höra". Under: `+`, Hur länge, tempo och **Spela** (grå tills det finns text). Krediterna står som en kapsel uppe till vänster. |
| Med text | `prov-text.png` | Antal tecken uppe till höger i fältet, och under fältet kostnaden innan något görs (D205): "Kostar {764} krediter. Upprepningar kostar inget." (D213) Spela blir fylld. |
| Hur länge | `hur-lange.png` | Systemets `Menu` på knappen: En gång (förvald), Upprepa 5 min, Upprepa 10 min, Upprepa 20 min. Knappen visar "En gång" eller "10 min" med upprepningssymbolen. |
| + för material | `material.png` | Systemets `Menu`: Fota sidor, Välj bilder, Lägg till fil, Klistra in länk (D204). Texten som läses ur materialet läggs i fältet, så att man ser vad som läses upp. |
| Krediterna | `krediter.png` | Blad från kapseln: siffran stort, "krediter kvar den här månaden" (D213), vad som kostar vad och när det fylls på. |
| Spelar | `spelar.png` | Läslägets spelare (D185) med texten i monospace. Överst alltid **"● Spelar i AirPods"** och vid upprepning "Varv {3} · {7:12} kvar av {10} min". Avsluta stoppar direkt. |

## 3. Regler
1. **Markören** blinkar bara när fältet har fokus (som systemets textmarkör), 1 s cykel, och står still med *Reduce
   Motion*. Blockmarkör i accentfärgen (`#7F9BFF` på det mörka fältet), inte grön.
2. **Färger:** fältets bakgrund `#101319` (ljust läge) och `#15181F` (mörkt läge), text `#E7E9EF`, platshållare och
   metadata samma färg med 42–55 % opacitet. Kontrast text/bakgrund > 14:1.
3. **Typsnitt:** `.monospaced` design av systemets typsnitt (SF Mono) i fältet och i spelarens text, body-storlek, följer
   Dynamic Type. Rubriken "Säg i AirPods" och knapparna i vanlig SF Pro.
4. **Tempo** är en knapp med siffran (`1,0×`) som öppnar en meny: 0,5× · 0,75× · 1,0× · 1,5× (ett urval av D151:s
   tempon, samma som Inställningar; 1,25× finns inte). Den sparas till nästa gång.
5. **Synligt och ärligt (CLAUDE.md, D203):** inget spelas utan att spelaren visas, raden "Spelar i AirPods" syns hela
   tiden, och upprepningen slutar när tiden är slut. Ingen schemaläggning, ingen ikon eller namn som får appen att se ut
   som något annat.
6. **Utan krediter (D200):** Spela fungerar inte; raden under fältet säger "Uppläsningen är tillfälligt avstängd.
   Texten fungerar som vanligt." och inget dras.
7. **Kostnaden sägs före:** räcker krediterna inte är Spela grå och raden säger hur många som behövs (se texterna).
8. **Största text:** fältet växer på höjden; knapparna under bryts till två rader (`+`, Hur länge och tempo på första,
   Spela ensam på andra, full bredd).

## 4. Texter
| Ställe | Text |
|---|---|
| Fältets rubrik | Säg i AirPods |
| Platshållare | Skriv eller klistra in det du vill höra |
| Längd (uppe till höger) | {104} tecken |
| Under fältet, rad 1 (D209, A122) | Du kan låsa telefonen och lägga undan den. Det hörs i AirPods ändå. *(alltid, även tomt fält)* |
| Under fältet, rad 2 (D213) | Kostar {764} krediter. Upprepningar kostar inget. *(när det finns text)* |
| … ljudet finns redan | Kostar inget. Ljudet finns redan. |
| … krediterna räcker inte (före och vid 402, D212/D213) | **Det här kostar {764} krediter. Du har {312} kvar. Nya krediter den 1 {december}.** *(halvfet, i stället för rad 2; Spela grå)* |
| … nekat utan servertext | Det gick inte att spela just nu. Försök igen om en stund. |
| … utan krediter (D200) | Uppläsningen är tillfälligt avstängd. Texten fungerar som vanligt. |
| Huvudknapp i fältet | Spela |
| Hur länge, meny (D210, A124) | 10 min · 15 min · 20 min · 25 min · 30 min · 35 min · 40 min · 45 min · 50 min · 55 min · 1 timme *(standard 10 min; ersätter En gång och 5/10/20)* |
| Hur länge, knappen | {10} min · 1 timme *(med upprepningssymbolen)* |
| Tempo, meny | 0,5× · 0,75× · 1,0× · 1,5× *(D151:s tempon; 1,25× finns inte)* |
| + meny | Fota sidor · Välj bilder · Lägg till fil · Klistra in länk |
| Länken gick inte att läsa | Sidan gick inte att läsa. Kopiera texten och klistra in den i stället. |
| Kreditkapseln | {1 236} krediter kvar *(tusental med mellanslag)* |
| Provkortet och provets skärm före start | Kostar {2 340} krediter *(frågor + långa svar som behöver nytt ljud)* |
| Bladet, rubrik | Krediter · *knapp:* Klar |
| Bladet, stor siffra och rad under | {1 236} / krediter kvar den här månaden |
| Bladet, avsnitt | SÅ RÄKNAS DET |
| Bladet, rader | 1 tecken nytt ljud · 1 kredit / Ljud som redan finns · 0 / Upprepa samma text · 0 / Prov som andra har delat eller publicerat · 0 |
| Bladet, fotnot | Du får 1 500 krediter varje månad. Nya krediter den 1 {december}. Oanvända krediter sparas inte. |
| Bladet, exempel (en rad överst i fotnoten) | En text på 764 tecken kostar 764 krediter. |
| Platshållare vid största text | Skriv här |
| Spelaren, överst | ● Spelar i AirPods |
| Spelaren, rad | Varv {3} · {7:12} kvar av {10} min  |
| VoiceOver på fältet | Säg i AirPods (iOS lägger till "textfält"; Ke79) |
| VoiceOver på kostnaden | Kostar {120} krediter |
| VoiceOver på Senaste | {hela texten}, {stil eller röst} · hint: Lägger tillbaka texten |
| VoiceOver på + | Lägg till material |
| VoiceOver på Hur länge | Hur länge, {Upprepa 10 minuter} |
| Spela väntar, efter 8 s (D225, A144) | Det tar längre tid än vanligt. (snurran går vidare, ingen knapp) |
| Spela ger upp efter 25 s, nätet uppe | Ljudet kunde inte hämtas. · *knapp* Försök igen (↻) |
| Telefonen saknar nät | Ljudet kunde inte hämtas. Kolla nätet. · *knapp* Försök igen (↻) |

## 4b. Hur länge (D210, Kelly väljer formen)
**Systemets `Menu`**, inte ett hjul. Elva val ryms i en meny utan att ta plats i fältet, menyn är samma form som
`+` och tempo, och ett hjul skulle kräva ett eget blad eller flytta Spela. Den valda tiden har en bock. Knappen visar
"10 min" eller "1 timme" med upprepningssymbolen. Spelaren visar "Varv {3} · {7:12} kvar av {10} min" som förut.

## 5. SwiftUI-förslag (till Angela Fable)
- Fältet: `TextField(..., axis: .vertical).lineLimit(3...8).font(.body.monospaced())` i en `RoundedRectangle(cornerRadius: 16)`
  med fast mörk fyllning och `.environment(\.colorScheme, .dark)` inuti, så att systemets kontroller blir mörka även i
  ljust läge. `.tint(Color(hex: 0x7F9BFF))` ger markören accentfärgen (systemmarkören, ingen egen animation behövs om
  den räcker; den egna blockmarkören bara för det tomma läget utan fokus).
- Knapparna: `Menu` med `Label` för `+`, Hur länge och tempo (`.buttonStyle(.bordered)`, `.controlSize(.small)`), Spela
  `.borderedProminent`.
- Kreditkapseln: `ToolbarItem(placement: .topBarLeading)` med en `Button` som öppnar `.sheet` med `presentationDetents([.medium])`.
