# K53: många foton utan för stora anrop (Kevin, 2026-11-13 23:01)

## Kort
Appen laddar upp varje foto för sig till en privat bucket och skickar sedan bara sökvägarna till `drill`. **Verifierat live:** 30 foton till frågor på **22,5 s**, målet var 60 s. Svaren tog 12,3 s till, och bilderna var raderade efteråt.

## Hur det fungerar
1. **`/exam` `upload_urls` (count, högst 40):** ger signerade `PUT`-URL:er under `<konto-id>/<uuid>.jpg` i den privata bucketen `drill_material`. Bara JPEG, PNG och WebP, högst 5 MB per bild, giltiga i 2 timmar.
2. **Uppladdning:** appen laddar upp varje bild direkt till Storage. Funktionen ser aldrig de stora anropen. Det var 13,9 MB i ett anrop som stoppade Arons försök 22:13.
3. **`drill` med `page_paths`:**
   - Servern kontrollerar att varje sökväg ligger i kontots egen mapp (annars 403) och hämtar bilderna. Det riktiga formatet läses ur bildens första byte.
   - Saknas en bild blir svaret 422 `material_missing`, med hur många som saknas.
   - **Bilderna raderas direkt efter analysen, även när den misslyckas (B4).**
4. **Fler än 10 bilder:** Haiku skriver först ut bilderna som text, i satser om 10 som körs parallellt. Frågorna görs sedan på texten. Det håller tiden nere och anropen till Claude små.
5. **`drill-purge`:** körs av pg_cron var 15:e minut och raderar uppladdningar som aldrig analyserades och är äldre än en timme. Den behöver ingen inloggning och kan bara radera gammalt, aldrig läsa. **Verifierat live:** svarar `{"deleted":0}`, och GET ger 405.

## Mätning (live, `scripts/k53-live.py`, `reports/eval/k53-live-2026-11-13.json`)
Underlaget var 30 foton ur Oscars påhittade bank, 17 olika bilder upprepade till 30, totalt 1,7 MB.

| Steg | Tid |
|---|---|
| `upload_urls` | 1,7 s |
| Uppladdning, 6 parallellt | 1,0 s |
| `drill`: utskrift i 3 satser, plan och granskning, 20 frågor | 19,7 s |
| **Totalt till frågor** | **22,5 s** |
| `drill_answers` (20 svar) | 12,3 s |

- **Claude:** 0,01 USD för frågorna och 0,07 USD för svaren.
- **Efteråt:** samma sökväg gav 422 `material_missing`, alltså raderad.
- **Antagande, ej testat:** riktiga mobilfoton är större, cirka 300–500 kB efter förminskning till 1 600 px, alltså 9–15 MB för 30 foton. På 5G med 20 Mbit/s uppåt tar uppladdningen cirka 4–6 s. Utskriften kan ta något längre med mer text per bild. Det bör ändå hålla under 60 s. Toby mäter på telefonen.

## Tester
`deno task test`: 548 gröna och `check` ren. Nya tester täcker:
- uppladdnings-URL:er i egen mapp
- främmande sökväg (403)
- radering efter lyckad och misslyckad analys
- saknad bild (422)
- 23 bilder som skrivs ut i satserna 10/10/3 innan planen görs
- rensning av bara gamla filer

## Kontrakt
Kontraktet står i `backend/README.md` under "Many photos (K53)", med en kort anteckning till Angela under A85. Base64-`pages` fungerar fortfarande för några få bilder.

## Kostnad
- **Claude:** cirka 0,08 USD.
- **ElevenLabs:** 0.
