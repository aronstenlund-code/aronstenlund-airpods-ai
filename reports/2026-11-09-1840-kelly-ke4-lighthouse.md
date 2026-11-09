# Kelly Ke4: Lighthouse och finputs

**Mätt:** Lighthouse 13.6.0, headless Chromium, mot lokal statisk server (utan komprimering och cache-rubriker, så siffrorna är lokala, inte live på GitHub Pages).

| | Performance | Accessibility | Best practices | SEO |
|---|---|---|---|---|
| Före Ke3 (eb0238f) mobil | 100 | 100 | 100 | 100 |
| Före Ke3 dator | 100 | 100 | 100 | 100 |
| Nu mobil | 99 | 100 | 100 | 100 |
| Nu dator | 100 | 100 | 100 | 100 |

Alla mål (minst 95) uppfyllda, inget behövde rättas. Mobil Performance tappade en poäng efter Ke3 (mer innehåll, fler bilder); kvarstående förslag gäller bara servern (cache, komprimering) och ligger utanför `site/`.
**Validering:** FAQ-JSON-LD tolkas som giltig JSON med 4 FAQPage-frågor och svar (Googles Rich Results Test mot live-URL är inte körd, **untested**; kräver publicerad sida). Open Graph: og:title/description/image/url och twitter:card finns, og.png är 1200×630.
**Påståenden:** inga nya funktionspåståenden; bilderna är simulatorbilder och märkta så.
