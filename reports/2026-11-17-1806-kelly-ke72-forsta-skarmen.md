# Kelly (moln) Ke72: första skärmen (D215)

## Vad som gjordes
- Ett förslag i `docs/design/forsta-skarmen.md` med exakta ord, mått och vilken knapp som är fylld i varje läge.
- 8 skisser i `docs/design/bilder/forsta/` (ljust | mörkt): `tom` (första gången), `text`, `lang` (5 rader och skroll,
  3 rader utan fokus), `hur-lange` (menyn), `spelar` (tid kvar, ⏸, Stoppa), `krediter` (räcker inte), `senaste`, `se`
  (iPhone SE största text). Källa `docs/design/_src/forsta.html`.
- Punkt i `prompts/queue/angela-fable.md` till A132.

## Beslut (Kelly)
1. **"Spela i 10 min" i huvudknappen** i stället för "⟲ 10 min". "⟲ 10 min" kan läsas som "om 10 minuter" (D210:s
   fördröjda start); "Spela i 10 min" kan bara betyda under tio minuter. Klocksymbolen bredvid öppnar menyn "Spela i".
2. **Bort:** rubriken "Prov", "Säg i AirPods" i kortet, teckenräknaren, kostnadsmeningen och upprepningsförklaringen.
   Kvar: platshållaren, kostnaden som två ord ("120 krediter") vid knappen.
3. **En fylld knapp:** Spela när fältet har text, annars Starta prov. Tomt fält med något i urklippet: Klistra in (tonad)
   där Spela står.
4. **Senaste** som en rad kapslar under kortet; Säg-texter aldrig som prov.
5. Raden om låst telefon kortas till "Du kan låsa telefonen. Det hörs i AirPods ändå." och visas bara före första Spela.

## Test
Skisser renderade i Chromium (typsnitt inte SF). Inget byggt, inget provat på telefon.

## Risker
- Utan rubrik i kortet måste platshållaren bära förklaringen; när fältet har text finns ingen etikett. Jag bedömer att
  knappen "Spela i 10 min" räcker. Prova på Aron.
- Kostnadens förhandsvisning beror på K92; tills den finns står ingen kostnad (bättre än en gissning, D212).

## Nästa steg
Angela Fable: A132 efter förslaget, bilder till Kelly.
