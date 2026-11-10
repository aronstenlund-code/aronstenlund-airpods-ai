# Ke20 – Granskning av A26 (Kellys R1–R6) och första stegbilden på sidan (Kelly, 2026-11-10 11:33)

Underlag: `reports/2026-11-10-angela-a26-kelly-r1-r6.md` och 17 bilder i `reports/2026-11-10-a26-a16-skarmbilder/`
(simulator, iPhone 17 Pro och SE, ljust och mörkt). Granskat mot `docs/design/SYSTEM.md` och `GRANSKNING.md`.
**Bara skärmbilder från simulatorn, inget på telefon.** Kontaktark: `reports/2026-11-10-ke20-granskning-a26/`.

## Dom: **A26 godkänd.** R1–R6 är stängda.
| # | Fynd från A18 | I bilderna |
|---|---|---|
| R1 | Ringarna i ansiktet, Elias liten | **Rättat.** Elias fyller kortet och ringarna sitter på hörluren, på Pro och SE och i ljust och mörkt. |
| R2 | SE: Testa nu täcker löftena | **Rättat i mörkt läge.** Alla tre löftena och "Ljud sparas inte · Läs mer" syns ovanför Testa nu. SE ljust saknas, eftersom bilden blev hemskärmen; ta om den i nästa körning. |
| R3 | Svart bakgrund i mörkt | **Rättat.** Intro och Första frågan har samma bakgrund över hela skärmen. |
| R4 | "Startar …" när den är pausad | **Rättat.** Brickan säger "Pausad" och knappen "Lyssna igen", både på Första frågan och på Lyssnar. |
| R5 | "Adam" och raden Provlyssna | **Rättat.** Röstsidan har beskrivningar, ▶ på varje rad, ✓ på den valda och talhastighet i tre steg. "Apple ·" är borta efter bilderna (Angelas egen commit, inte sett i bild). |
| R6 | Röd Avsluta | **Rättat.** Avsluta är i bläck och Lyssna igen är blå. |

Talhastighetens segmentkontroll på röstsidan är samma komponent som demosidans lägesväljare (Ke19). Appen och sidan
ser alltså likadana ut där.

## Nya fynd (till Angela via Deangelo)
1. **Viktigt (skyddsräcke): Övningsprovet (A16, scenen `practice`) visar ingen lyssnarbricka.** Om skärmen visas
   medan Lumen lyssnar måste brickan synas ("Lyssnar" eller "Pausad", som på Lyssnar). Är scenen bara korten
   utan ram, så lägg till ramen i skärmbilden så att det går att granska.
2. Resultatkortet har knappen **"Klar"**. Enligt SYSTEM.md är "klar" ett röstord (D72), och knappar som avslutar heter
   "Avsluta" eller "Stäng". Förslag: "Stäng". Mindre.
3. Första frågan säger "Lumen sparar **aldrig** ljud", medan introt säger "Ljud sparas inte". Använd samma ord på båda
   ("Ljud sparas inte."). "Aldrig" är också starkare än skyddsräcket ("inget ljud sparas som standard"). Mindre.
4. Röstsidan i mörkt läge medan rösterna hämtas: ingen rad har ✓, eftersom den valda rösten inte har laddats än. Visa
   den valda rösten med ✓ direkt, eller en rad med "Hämtar …" och ✓. Mindre.
5. Symbolen i introt är fortfarande radiovågorna. Den byts när Aron har valt logga (A, B eller C, Ke12). Ingen åtgärd
   nu.

## Bilder som behövs till sidan (Ke18)
Sidans steg 2 och 3 är fortfarande i gamla stilen, med handstil, rutpapper och röd Avsluta. Bilder som saknas:
- `addExam`, alltså "Har du prov snart?" (A22), Pro ljust och mörkt.
- Lyssnar i **Provläget** med brickan "Lyssnar" (inte Pausad), Pro ljust och mörkt. A26:s `listening` är läget
  Frågor och pausat.
- SE ljust `intro` (för R2).

## Gjort på sidan (Ke18, del 1)
- **Steg 1** ("Tryck Testa nu och fråga högt") har nu A26:s Första frågan i det nya systemet, i ljust och mörkt
  (`site/img/fraga-*.webp`, 300 × 652, 14 och 13 kB). Alt-texten beskriver det som syns: frågan, svaret i ett kort och
  Fortsätt. Bilden visar "Pausad", eftersom simulatorn saknar mikrofon. Det är sant mot appen.
- Steg 2 och 3 väntar på bilderna ovan.
- Kontrollerat i Chromium på 1280 px, mörkt läge (bild 5 i mappen).

## Till Aron
- Välj logga A, B eller C (`docs/design/SYSTEM.md` §5). Den behövs på sidan, i appen och i delningsbilden.
