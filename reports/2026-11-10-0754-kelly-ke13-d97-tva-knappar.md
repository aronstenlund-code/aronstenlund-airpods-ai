# Ke13: D97, två knappar på provkortet (Kelly, 2026-11-10)

Kort: provkortet i det nya systemet har nu Arons två knappar (D97, slutgiltigt): **"Förhör mig"** (blå) och **"Få A-svar
till provet"** (sekundär). Under varje knapp står en rad som säger skillnaden. Namnen är oförändrade.
**Skiss, ingen appkod ändrad, inget provat på telefon.**

## Vad som gjorts
- `docs/design/_src/system.html` och `bilder/system/start.png` och `start-dark.png`: provkortet har två knappar med
  förklaring.
  - "Förhör mig": *Lumen frågar ut dig och svarar på dina frågor*.
  - "Få A-svar till provet": *Lumen svarar bara när du frågar*.
  - Båda knapparna är 64 pt höga och har texten på två rader.
- `docs/design/SYSTEM.md`: ny komponent "Knapp med förklaring", och provkortet och Start-raden beskriver D97.
  Huvudknappsregeln gäller fortfarande: bara "Förhör mig" är blå.
- `docs/design/enkel-start.md`: Ke9:s förslag om en enda knapp är markerat som ersatt av D97. Min tidigare Concern om
  namnet "Få A-svar" är besvarad av ägaren.
- Demosidan, steg 3: "Lumen ställer frågor om det du pluggar och svarar på dina. Vill du bara ha svar trycker du Få
  A-svar till provet." Samma ord som appen. Bild: `reports/2026-11-10-ke13-sida/d97-steg3.png`. Inget överflöd vid 390 px
  och inga JS-fel. Lighthouse kördes inte, för att inte skapa fler anonyma inloggningar (se Ke13b).

## Till Aron
Inget nytt. Logga A, B eller C väntar fortfarande (Ke12).

## Concerns
Inga.
