# Kelly Ke52: design och texter för Publicera prov och Prov från din skola (D149, D150)

Datum: 2026-11-13 21:17. Roll: Kelly Kapoor (design). Uppdrag: `prompts/queue/kelly.md` Ke52.

## Vad som gjordes
- `docs/design/publicera-prov.md`: underlag till Angela (A83) med tre regler (aldrig "övningsprov", inget namn utan
  att man väljer det, uppmuntra en gång utan att tjata), 11 skärmar, alla texter att kopiera (provet, bladet Publicera
  prov, Välj skola, listan, ett publicerat prov, Rapportera, Ta bort, fel och VoiceOver) och en ämneslista.
- 11 skisser i ljust och mörkt: `docs/design/bilder/repetition/pub-*.png`. Källan är Ke52-blocket i
  `docs/design/_src/repetition.html`.
- Texterna följer K49-kontraktet i `backend/README.md`: `missing` blir "Saknas: …", rapportskälen motsvarar `reason`,
  `my_school` och `display_name` bara med `show_name`.

## Designbeslut (mina, inom D149/D150)
1. Publicera prov är en rad bredvid Dela, inte en knapp till. Starta prov är fortfarande den enda blå knappen.
2. Brytaren heter "Visa ett användarnamn", är av från början och säger "Skriv inte ditt riktiga namn".
3. **Din skola sparas bara på telefonen** och skickas som `my_school`. Den sparas inte i kontot och publiceras inte.
4. Den som publicerat ser bara ett antal ("12 har lagt till provet"), aldrig vem. Ingen konfetti och ingen
   räknare som tjatar.
5. Rapportera har fyra skäl och ingen fritext, och ligger tyst längst ner på ett publicerat prov.
6. Hem utan egna prov får textlänken "Hitta prov från din skola" (att hämta är gratis, D151).

## Fynd
- **"Övningsprov" finns kvar i appen** i A16:s röstförhör: knappen "Kör övningsprovet", raden "Övningsprov, …" och
  det som sägs ("Övningsprov, {n} frågor"). Förslag till Angela står i `publicera-prov.md` §3.
- **Till Kevin:** kontraktet säger inte vad en andra rapport från samma konto ger. Förslag: 409 `already_reported`.

## Test
Bara skisser. De är renderade och kontrollerade i Chromium, men inget är byggt och inget är provat på telefon
(untested assumption). Att Skolverkets register har ort för alla skolor är ej verifierat.

## Kvar
Granskning av A82 på bild när iOS-bygget och skärmbilderna är gröna. Bevakningen i bakgrunden står kvar.
