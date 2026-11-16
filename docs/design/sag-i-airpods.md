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
| Med text | `prov-text.png` | Antal tecken uppe till höger i fältet, och under fältet kostnaden innan något görs (D205): "Räknas som {1} fråga. Upprepningar kostar inget." Spela blir fylld. |
| Hur länge | `hur-lange.png` | Systemets `Menu` på knappen: En gång (förvald), Upprepa 5 min, Upprepa 10 min, Upprepa 20 min. Knappen visar "En gång" eller "10 min" med upprepningssymbolen. |
| + för material | `material.png` | Systemets `Menu`: Fota sidor, Välj bilder, Lägg till fil, Klistra in länk (D204). Texten som läses ur materialet läggs i fältet, så att man ser vad som läses upp. |
| Krediterna | `krediter.png` | Blad från kapseln: siffran stort, "frågor kvar den här månaden", vad som kostar vad och när det fylls på. |
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
| Under fältet | Räknas som {1} fråga. Upprepningar kostar inget. |
| … krediterna räcker inte | Texten räknas som {3} frågor, och du har {1} kvar. Korta texten eller vänta till den 1 {december}. |
| … utan krediter (D200) | Uppläsningen är tillfälligt avstängd. Texten fungerar som vanligt. |
| Huvudknapp i fältet | Spela |
| Hur länge, meny | En gång · Upprepa 5 min · Upprepa 10 min · Upprepa 20 min |
| Hur länge, knappen | En gång · {10} min |
| Tempo, meny | 0,5× · 0,75× · 1,0× · 1,5× *(D151:s tempon; 1,25× finns inte)* |
| + meny | Fota sidor · Välj bilder · Lägg till fil · Klistra in länk |
| Länken gick inte att läsa | Sidan gick inte att läsa. Kopiera texten och klistra in den i stället. |
| Kreditkapseln | {312} frågor kvar |
| Bladet, rubrik | Frågor kvar · *knapp:* Klar |
| Bladet, under siffran | frågor kvar den här månaden |
| Bladet, rader | Vanlig fråga · 1 / Lite längre fråga · 1,5 / Mycket lång fråga · 2 / Läs upp eller Säg i AirPods · 1 per 800 tecken / Upprepa samma text · 0 |
| Bladet, fotnot | Fylls på den 1 {december}. Prov som andra har delat eller publicerat kostar inget. |
| Spelaren, överst | ● Spelar i AirPods |
| Spelaren, rad | Varv {3} · {7:12} kvar av {10} min *(En gång: "Mening {2} av {5}")* |
| VoiceOver på fältet | Säg i AirPods, textfält |
| VoiceOver på + | Lägg till material |
| VoiceOver på Hur länge | Hur länge, {Upprepa 10 minuter} |

## 5. SwiftUI-förslag (till Angela Fable)
- Fältet: `TextField(..., axis: .vertical).lineLimit(3...8).font(.body.monospaced())` i en `RoundedRectangle(cornerRadius: 16)`
  med fast mörk fyllning och `.environment(\.colorScheme, .dark)` inuti, så att systemets kontroller blir mörka även i
  ljust läge. `.tint(Color(hex: 0x7F9BFF))` ger markören accentfärgen (systemmarkören, ingen egen animation behövs om
  den räcker; den egna blockmarkören bara för det tomma läget utan fokus).
- Knapparna: `Menu` med `Label` för `+`, Hur länge och tempo (`.buttonStyle(.bordered)`, `.controlSize(.small)`), Spela
  `.borderedProminent`.
- Kreditkapseln: `ToolbarItem(placement: .topBarLeading)` med en `Button` som öppnar `.sheet` med `presentationDetents([.medium])`.
