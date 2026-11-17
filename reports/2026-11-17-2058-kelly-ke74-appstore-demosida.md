# Kelly (moln) Ke74: App Store-bilder och demosidan efter nya första skärmen (D218, D215)

## Vad som gjordes
1. **5 App Store-förslag** i `docs/appstore/69-1…5.jpg` (1320 × 2868), tabell i `docs/appstore/README.md`:
   Skriv. Lyssna. · Om och om igen. · Fota boken. · Tryck för svaret. · Följ texten. Inget om låst skärm (D209 inte provat),
   inget som antyder dold användning. Skärmbilderna från iPhone 17 Pro Max (CI 44160416467, 5398a2b, grenen
   `kelly/screens-ke74-promax`), men bildflödet skalar ner till 644 × 1400, så de är **förslag** och lite mjuka.
   Rubrikerna i DejaVu Sans (molnet); slutliga bilder med full upplösning och SF Pro Display på en Mac.
2. **Demosidan:** nytt första steg "Skriv det du vill höra" med en bild av nya första skärmen (A132), "Eller fota
   boken" som steg 2, ingressen och heron kompletterade. Pushad till main (54f3dce).
3. **Vercel publicerar från grenen `kelly/ke66-earmind-site`, inte main** (sidans storlek på Vercel var oförändrad
   82 176 byte). Grenen är snabbspolad till main (991421a). `kelly-site-check.yml` visar nu om Ke74-steget finns.

## Test
- Sidan lokalt i Chromium: inga fel, ingen vågrät rullning på mobil (393 px), site/ 1 564 kB.
- Live (CI 44164178584, 20:57): fortfarande den gamla sidan direkt efter snabbspolningen; kontrolleras igen.
- App Store-bilderna: tittat på alla fem.

## Risker
- Bild 1 visar raden "Du kan låsa telefonen. Det hörs i AirPods ändå." (overifierad, D209).
- **Till Deangelo/Aron:** Vercels produktionsgren bör vara `main` (Vercel › earmind › Settings › Git › Production
  Branch), annars måste grenen snabbspolas efter varje ändring av sidan.
