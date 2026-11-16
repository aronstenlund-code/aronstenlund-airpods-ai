# Kevin (moln): K80 – väntelistan från Vercel (D202) – 2026-11-16 23:10

- `https://earmind.vercel.app` får anropa funktionerna från webbläsaren (`_shared/cors.ts`, `DEFAULT_ORIGINS`), bredvid GitHub Pages som ligger kvar tills Vercel är verifierad. Driftsatt i `7dee7e0`.
- **Avvikelse från uppdraget:** adressen ligger i koden, inte i hemligheten `CORS_ORIGINS`. Verktyget för hemligheter låter bara Aron skriva in värdet i Supabase, och hemlighetens nuvarande värde går inte att läsa, så "behåll befintliga värden" gick inte att garantera. Adressen är publik, så den behöver inte vara hemlig. `CORS_ORIGINS` gäller som förut för andra adresser.
- Test: `_shared/cors_test.ts` (Vercel och GitHub Pages ja, `earmind-evil.vercel.app` och `example.com` nej).
- **verified live** (`scripts/k80-cors.py` i `kevin-live.yml`, run 43966198148): förfrågan från `https://earmind.vercel.app` gav 204 med `Access-Control-Allow-Origin: https://earmind.vercel.app`. `https://example.com` gav 403 utan huvudet, och GitHub Pages fungerar fortfarande.
