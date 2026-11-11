# Kelly Ke31: tre loggkandidater som vektor för röstningen (2026-11-11 10:18)

D127: användarna röstar om loggan i appen (A54). Förlagorna var tre ChatGPT-bilder i olika storlek, ljus och
skärpa. Jag har ritat om dem som rena vektorer med gemensam ram, så att bara motivet skiljer.

## Vad som gjordes
- `docs/design/logo/_src/rostning.py` skriver sex SVG (A, B, C × mörk, ljus) i `docs/design/logo/rostning/vektor/`.
  `_src/rostning-render.js` (Playwright) gör PNG 1024 och kontrollbilden `kontroll-60pt.png`.
- **A · Klotet:** klot med sex S-formade band från persika till lila, staplar persika till vänster och lila till höger.
- **B · Den gröna formen:** konturen mätt på förlagan (klocka uppåt till −0,97 R, spegelvänd klocka nedåt till
  +0,97 R, trubbiga ändar med små spetsar, halvbredd 0,42 R / 0,37 R vid halva höjden) och en mörkare inre klocka.
  Första försöket blev en fyruddig stjärna med gaussiska spetsar; nu är det kupoler som i förlagan.
- **C · Den orange ringen:** ring 30 px bred, ytterdiameter 500, varm toning från gult uppe till vänster till
  rödorange nere till höger, svart inre skiva i den mörka versionen.
- `vektor/README.md`: filerna, vad som är lika och sex punkter till Angela för A54.

## Rättvisa (mätt)
Allt utom motivet är gemensamt och står bara på ett ställe i `rostning.py`: motivbredd 500 px, samma fyra staplar,
samma ljusfält uppe till vänster (i rutans koordinater, inte formens), samma glöd och samma ljusa fläck.
| Mörk ikon | Bakgrund (luminans) | Ljusaste i motivet | Motivets yta |
|---|---|---|---|
| A | 0,010 | 0,68 | 35 % |
| B | 0,016 | 0,67 | 27 % |
| C | 0,013 | 0,72 | 11 % |
Ytan skiljer eftersom en ring är en ring; det är designen, inte ljuset. Ljusaste punkt jämnades ut från 0,63–0,74.
Bakgrunderna har förlagornas färgton (lila-svart, grön-svart, brun-svart) men samma ljushet.

## Kontroll i 60 pt
`docs/design/logo/rostning/vektor/kontroll-60pt.png`: förlaga mot vektor, och alla tre i 60 pt och 29 pt på mörk och
ljus bakgrund, med mörk och ljus ikon. Alla tre känns igen i 60 pt. I 29 pt syns klotets band, formens kupol och
ringen; B:s inre skugga försvinner i 29 pt (som i förlagan).

## Avvikelser från förlagorna
- Ingen ljusglöd utöver den gemensamma: C:s förlaga glödde starkare än A och B, vilket hade gynnat den.
- Klotets S-kurva är uppdelad i jämna band i stället för förlagans ena stora S, för att den ska hålla i 29 pt.
- De ljusa versionerna är mina egna härledningar (ljus tonad bakgrund, samma motiv). Förlagorna fanns bara mörka.

## Till Angela (A54)
Se `docs/design/logo/rostning/vektor/README.md`. Kort: visa de mörka i röstningen i båda lägena, samma storlek,
iOS-maskens hörn (0,2237 × storleken, continuous), slumpa ordningen per användare och spara ordningen med rösten.

## Till Aron
- Ska röstningsordningen slumpas? Jag rekommenderar ja (läget påverkar annars rösten). Deangelo/Angela kan låta bli
  om K39 inte kan spara ordningen.

## Test
Chromium (Playwright, deviceScaleFactor 3) med iOS-masken. **Ej verifierat på enhet.**
Kostnad: API 0 USD, ElevenLabs 0 tecken.

## Nästa
Ke29 (ny Start och "Vad kan Lumen?"), sedan Ke30. Granska A50 och A54 när Angelas bilder är pushade.
