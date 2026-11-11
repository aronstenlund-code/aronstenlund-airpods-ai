# Kelly Ke40: exakta ChatGPT-ikoner till röstningen och appikonen (2026-11-11 18:59)

D129/D130 (sex kandidater, D som appikon) och **D139** (Aron 18:51: "exakt som de som ChatGPT gjorde").
Deangelo ändrade Ke40 kl. 18:55 medan jag ritade.

## Vad som gjordes
- **`docs/design/logo/rostning/exakt/`: A.png–F.png och AppIcon-1024.png (= D)**, 1024 × 1024 utan genomskinlighet.
  Bara beskärning, hörnfyllnad utanför den rundade rutan och uppskalning (Lanczos), med `_src/exakt.py`. Färg, form,
  staplar och glöd är orörda.
- **Hörnen:** originalens rundade rutor har hörnradie 26–29 %, större än iOS-maskens 22,4 %. Utan åtgärd hade en vit
  (A–C) eller svart (D–F) flik och originalets kant synts i varje hörn under iOS-masken. Kvadraten beskärs därför
  2,6–3,1 % inåt per sida (uträknat per ikon, så lite som möjligt), och det som ändå ligger utanför originalets ruta
  fylls inifrån. Kontroll: `exakt/kontroll.png`, rena hörn med masken, läsbara i 60 och 29 pt.
- README i `exakt/` med filer, mått och begränsningar. SYSTEM.md avsnitt 5 pekar på `exakt/`.
- **Innan D139:** jag hade ritat D, E och F som vektorer (som A–C i Ke31) med en appikon i tre varianter och en
  symbol. De ligger kvar i `rostning/vektor/`, märkta "används inte (D139)".

## Till Angela (A71)
**Filerna är pushade:** `docs/design/logo/rostning/exakt/`. AppIcon (Any) = `AppIcon-1024.png`. Röstningen:
`A.png`–`F.png` i 2 × 3, samma storlek, iOS-maskens hörn. Symbolen i rubriken: förslag i README (den exakta ikonen
liten med maskens hörn), eftersom en enfärgad symbol inte kan vara exakt.

## Till Aron
- **Upplösningen:** originalen är små (A–C cirka 260 px, D–F cirka 380 px). Uppskalade till 1024 är de något mjuka i
  stor storlek, men skarpa i 60 och 29 pt. Vill du ha skarpa 1024: be ChatGPT göra om vinnaren i 1024 px.
- **Mörk och tonad ikon** (iOS 18) är inte gjorda, eftersom det vore ändringar av bilden. Utan dem tar iOS fram egna.

## Test
Chromium (Playwright) med iOS-maskens hörn. **Ej verifierat på enhet.** Kostnad: API 0 USD, ElevenLabs 0 tecken.
