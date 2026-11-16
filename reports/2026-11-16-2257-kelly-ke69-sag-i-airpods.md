# Kelly (moln) Ke69: formen för "Säg i AirPods" (D203–D205)

## Vad som gjordes
- `docs/design/sag-i-airpods.md`: idé, skärmar, regler, alla texter och SwiftUI-förslag till A115–A117.
- 6 skisser i `docs/design/bilder/sag/` (ljust | mörkt): `prov-tom`, `prov-text`, `hur-lange`, `material`, `krediter`,
  `spelar`. Källa `docs/design/_src/sag.html`, render `node docs/design/_src/sag-render.js`.
- Punkt i `prompts/queue/angela-fable.md` som pekar på underlaget.

## Beslut (Kelly)
1. **Terminal och Xcode-konsolen som förebild:** mörkt fält även i ljust läge, SF Mono, `›` och blockmarkör i
   accentfärgen. Inget grönt, inga skanningslinjer, ingen glöd: det är det som gör det barnsligt.
2. Fältet ligger överst på Prov, före Nästa prov. Allt annat på skärmen är oförändrat.
3. `+`, Hur länge och tempo är systemmenyer i fältets nederkant; Spela är den enda fyllda knappen.
4. Kostnaden står under fältet innan man trycker (D205), och upprepning sägs vara gratis.
5. Spelaren visar alltid "● Spelar i AirPods" och hur länge det är kvar (CLAUDE.md: synlig indikator, ingen dold
   eller tidsinställd uppspelning).

## Test
Skisser renderade i Chromium. Typsnittet i skisserna är inte SF Mono/SF Pro. Inget byggt, inget provat på telefon.

## Risker
- Ett mörkt fält i ljust läge är ett medvetet avsteg från systemets färger. Blir det för tungt kan det bli
  `secondarySystemBackground` med monospace och markör kvar; det bestämmer vi på A115-bilderna.
- Kostnaderna i bladet (1 / 1,5 / 2 / 1 per 800 tecken) följer D176 och D185. Siffrorna kommer från K82.

## Nästa steg
Angela Fable: A115–A117 efter underlaget, bilder till Kelly.
