# Kelly Ke33: granskning av A50, ny Start (2026-11-11 10:39)

Underlag: CI "Simulator screenshots" 42993726421 på main 0d2346e (A50), iPhone 17 Pro (1206×2622), ljust och mörkt.
Jämfört mot SYSTEM.md, D124/D126 och `docs/design/start-vadkan.md` (Ke29). Efter bilderna har Angela gjort 537ea48
(Ke29 S2 och Välj läge); den är kontrollerad i koden, inte på bild. Bilder: `reports/2026-11-11-a50-granskning/`.

## Omdöme: **godkänd**
Start är begriplig på en gång: en blå knapp "Starta Lumen" överst, "Standardläge · Byt" under, "Lumen kan allt" med
tre exempel, sedan provkortet med "% redo", dagens pass och Förhör mig som grå knapp. Ingen "Få A-svar", ingen
instruktionsrad, ingen röd färg. Utan prov: "Har du prov snart?" med "+ Lägg till prov" och ett exempel att säga.
Mörkt läge: ljusblå knapp med mörk text, korten i `raised`, inga skuggor. Provläget säger "För dina prov".

## Fynd
| # | Var | Fynd | Förslag | Prio |
|---|---|---|---|---|
| G1 | Start, Lumen kan allt | Ingen väg till "Vad kan Lumen?" (Ke29 S1) | Lägg "Allt Lumen kan ›" när A52 byggs; inte före, eftersom den inte har något att öppna | Med A52 |
| G2 | Välj läge / Byt läge | Varje läge har en blå ikon i en mjuk cirkel och ett eget kort. SYSTEM.md avsnitt 8: grå ikoner, inga färgade cirklar; bara det valda är blått med ✓ | Ovalda: grå ikon utan cirkel. Valt: blå ikon, ✓ och `soft`-bakgrund som nu | Låg |
| G3 | Första frågan | "Ljud sparas inte." står kvar. Med sömnläget (A49) och Mina svar-inspelningen (A53) är det inte sant | Deangelo avgör texten före A53 (samma som Ke28 F2) | Före A53 |

**Redan rättat efter bilderna (537ea48, koden):** inget Spotify- eller ringexempel förrän det fungerar (Ke29 S2),
"Välj läge" från Start med Standardläge och Provläge överst, sedan FLER LÄGEN och Sov sist, och fotnoten "Valet
gäller Starta-knappen …".

## Inte granskat
- iPhone SE och största text: inte med i den här körningen. Tobys A50-runda (`toby/t5b-t7b-t8b-2`) tar dem.
- Loggan i rubriken är fortfarande radiovågorna; det är väntat (A51 är pausad tills röstningen D127).
- **Ej verifierat på enhet.** Kostnad: API 0 USD, ElevenLabs 0 tecken.
