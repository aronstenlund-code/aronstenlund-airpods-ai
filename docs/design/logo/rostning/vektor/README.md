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
