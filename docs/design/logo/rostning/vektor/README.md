> **D139 (Aron 2026-11-11 18:51): de här vektorerna används inte i appen.** Röstningen och appikonen använder de exakta
> ChatGPT-bilderna i `../exakt/`. Vektorerna ligger kvar som underlag.

# Röstningens tre loggor som vektor (Kelly, Ke31, 2026-11-11)

Underlag till Angelas **A54** (D127). Förlagorna är Arons ChatGPT-bilder i `../` (A-klotet.png, B-grona-formen.png,
C-orange-ringen.png). Här är de omritade så att röstningen blir rättvis: bara motivet skiljer.

## Filer
| Kandidat | Mörk (röstningen) | Ljus |
|---|---|---|
| A · Klotet | `A-klotet-mork.svg`, `A-klotet-mork-1024.png` | `A-klotet-ljus.svg`, `A-klotet-ljus-1024.png` |
| B · Den gröna formen | `B-grona-formen-mork.svg`, `-mork-1024.png` | `B-grona-formen-ljus.svg`, `-ljus-1024.png` |
| C · Den orange ringen | `C-orange-ringen-mork.svg`, `-mork-1024.png` | `C-orange-ringen-ljus.svg`, `-ljus-1024.png` |

`kontroll-60pt.png`: förlaga mot vektor och alla tre i 60 pt och 29 pt, ljust och mörkt läge.
Källa: `../../_src/rostning.py` (SVG) och `../../_src/rostning-render.js` (PNG). Ändra bara där.

## Vad som är lika för alla tre
- 1024 × 1024, fyrkantig utan genomskinlighet (iOS rundar själv).
- Motivet är 500 px brett och centrerat (klotet och ringen har diametern 500, formen är 500 bred).
- Samma staplar: två per sida, 318 och 392 px från mitten, 236 och 148 hög, 26 bred, runda.
- Samma ljus: en ljuskälla uppe till vänster i samma koordinater, samma glöd bakom motivet (blur 34, 42 % mörk,
  22 % ljus), samma ljusa fläck i bakgrunden.
- Uppmätt (mörk ikon, relativ luminans): bakgrund 0,010 / 0,016 / 0,013, ljusaste punkt i motivet 0,68 / 0,67 / 0,72.

## Till Angela (A54)
1. **Visa den mörka versionen i röstningen, både i ljust och mörkt läge.** Det är den som Aron och användarna känner
   igen från förlagorna. De ljusa är till senare, när vinnaren blir AppIcon (Any/Dark).
2. Lägg in `*-mork-1024.png` som tre bilder i en asset catalog (en skala räcker, 1024 skalas ned). Rita dem med
   iOS-maskens hörn: `RoundedRectangle(cornerRadius: storlek × 0.2237, style: .continuous)`.
3. Storlek i arket: samma för alla tre, i en rad om den ryms (3 × 96 pt på iPhone SE), annars
   en kolumn. Ordningen A, B, C som i D127, men **slumpa ordningen per användare** om det går, så att läget inte
   påverkar rösten. Spara ordningen som visades tillsammans med rösten.
4. Namnet under varje ikon: "Klotet", "Den gröna formen", "Den orange ringen" (eller bara A, B, C). Inga andra
   texter som gynnar någon.
5. Skärmbilder ljust, mörkt och SE till Kellys granskning (PLAN 2c).

**Ej verifierat på enhet.** Ritat och kontrollerat i Chromium (Playwright) med iOS-masken.

---

# Ke40 (2026-11-11 kväll): sex kandidater och glasklotet som appikon (D129, D130)

## Alla sex till röstningen (A71: rutnät 2 × 3)
| Kandidat | Mörk (röstningen) | Ljus |
|---|---|---|
| A · Klotet | `A-klotet-mork-1024.png` | `A-klotet-ljus-1024.png` |
| B · Den gröna formen | `B-grona-formen-mork-1024.png` | `B-grona-formen-ljus-1024.png` |
| C · Den orange ringen | `C-orange-ringen-mork-1024.png` | `C-orange-ringen-ljus-1024.png` |
| D · Glasklotet | `D-glasklotet-mork-1024.png` | `D-glasklotet-ljus-1024.png` |
| E · Glasringen | `E-glasringen-mork-1024.png` | `E-glasringen-ljus-1024.png` |
| F · Glasvågen | `F-glasvagen-mork-1024.png` | `F-glasvagen-ljus-1024.png` |
A–C är oförändrade sedan Ke31 (byte för byte). D–F följer samma ram: motivet 500 px brett, samma staplar, ljusfält och
glöd. **F har inga staplar** (förlagan har inga); vågen fyller i stället samma bredd som staplarna hos de andra.
Uppmätt (mörk, relativ luminans): bakgrund 0,009–0,019 och ljusaste punkt 0,60–0,69 för alla sex.
Kontroll: `kontroll-sex.png` (förlaga, mörk, ljus; 60 och 29 pt på mörk och ljus bakgrund).

Röstningen: samma regler som förut (mörk version i båda lägena, iOS-maskens hörn, ordningen slumpad per användare och
sparad). I ett rutnät 2 × 3 på iPhone SE ryms 2 × 120 pt eller 3 × 96 pt; välj 3 × 96 i två rader så att alla sex
har samma storlek som i dag.

## Appikonen nu: D glasklotet (D129, tills röstningen avgjort)
| Fil | Till |
|---|---|
| `D-glasklotet-mork-1024.png` | **AppIcon, vanlig (Any).** Det är förlagans utseende (mörk bakgrund), som Aron valde |
| `D-glasklotet-svart-1024.png` | AppIcon, mörk variant (Dark, iOS 18+): motivet på nästan svart |
| `D-glasklotet-tonad-1024.png` | AppIcon, tonad variant (Tinted, iOS 18+): gråskala på svart, iOS färgar själv |
| `D-glasklotet-ljus-1024.png` | Reserv om Aron vill ha en ljus ikon; används inte nu |
| `D-glasklotet-symbol.svg` | Symbolen i appens rubrik och i introt: ring + S-band, `currentColor`, ruta 100 × 100 |

**Symbolen:** färg `LumenColor.blue` (som rubrikens symbol i dag), storlek som texten bredvid (`@ScaledMetric`,
SYSTEM.md 10.6), kvadratisk ram. I SwiftUI: en `Circle()` med `stroke(lineWidth: size × 0.09)` och radie
`size × 0.39`, plus S-bandet som `Path` (`M14 58 C30 30 46 34 54 52 S76 72 86 42` i rutan 100, linjebredd
`size × 0.11`, runda ändar). Eller som en vektor-bild i asset-katalogen (SVG, "Preserve Vector Data", Template).
Kontroll: `D-appikon-kontroll.png` (hemskärm ljus/mörk/tonad i 60 och 29 pt, symbolen bredvid "Earmind" i 17–34 pt).

**Ej verifierat på enhet.** Ritat och kontrollerat i Chromium (Playwright) med iOS-maskens hörn.
