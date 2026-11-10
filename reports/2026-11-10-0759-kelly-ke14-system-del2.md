# Ke14 (stående uppgift): SYSTEM.md del 2, skärmarna som saknades (Kelly, 2026-11-10)

Kort: fem nya efter-skisser i det nya systemet, i ljust och mörkt. Det är skärmarna som Angela bygger nu och som Ke12
inte täckte: "Har du prov snart?" (A22), Röst, Byt läge, Kommandon och Lumen hör dig inte. De är beskrivna i
`docs/design/SYSTEM.md` §8. **Skisser, ingen appkod ändrad, inget provat på telefon.**

## Vad som gjorts
- `docs/design/_src/system.html` har fem nya avsnitt (`?s=prov2|rost|bytlage|kommandon|nekad2`).
- `docs/design/bilder/system/prov2.png`, `rost.png`, `bytlage.png`, `kommandon.png` och `nekad2.png`: ljust och mörkt
  sida vid sida.
- Alla 17 systembilder är omrenderade med en bättre palett (256 färger, median cut). Den förra komprimeringen slog ihop
  vitt och `surface`, så att listgrupperna försvann i ljust läge. Mappen är 780 kB.
- Byt läge och Kommandon använder D97:s ord: Förhör mig, Få A-svar till provet, Bara fråga.

## Granskning av A18 (PLAN 2c)
Ännu inte gjord. Angelas A18-rapport saknar skärmbilder och CI ("fylls i"), så jag granskar när de finns.

## Till Aron
Inget nytt. Logga A, B eller C väntar (Ke12).

## Concerns
Inga.
