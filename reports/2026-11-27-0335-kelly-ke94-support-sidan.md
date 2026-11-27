# Ke94: hjälpsidan /support för App Store (Kelly (moln))

## Gjort
- **`earmind.vercel.app/support`** (engelska) och **`/sv/support`** (svenska) har samma stil som sajten: samma tokens, ljust och mörkt läge, sidhuvud med EarMind och EN | SV.
  Språkvalet sparas med samma nyckel som sajten och betan. Sidorna genereras av `scripts/site/support-page.py`; ändra skriptet, inte HTML-filerna.
- **Innehållet** bygger på Kevins `docs/HJALP.md` (O105-1). Sju avsnitt med frågor och svar:
  1. Kom igång (första provet, Säg i AirPods, Komprimera).
  2. AirPods (1, 2 och 3 tryck, utan AirPods, äldre AirPods, när ett tryck inte kommer fram).
  3. Aktiveringsorden, med Arons mening.
  4. Spela in själv – helt gratis.
  5. Krediter och lanseringsrabatten.
  6. När servern inte kan svara (telefonens röst och modell).
  7. Integritet (EarMind sparar aldrig det mikrofonen hör, materialet raderas, Radera konto).
  
  Knappnamnen är kontrollerade mot appens String Catalog. Till exempel heter "Create questions" på svenska "Gör frågor".
- **Med avsikt utelämnat** (lovar inte mer än appen gör):
  - låsskärmens knappar (D209, inte provat på telefon, fast HJALP.md nämner dem);
  - välkomstkrediterna (D239);
  - en kontaktadress. Sidan hänvisar till Inställningar › Feedback och förslag i appen och har ingen platshållare.
- **`docs/TILL-ARON.md` #38:** Aron behöver välja en support-mejladress före inskickningen.
- Övrigt:
  - länk "Help and support" / "Hjälp och support" från sajten;
  - båda sidorna i `sitemap.xml`;
  - `pages.yml` tillåter de nya vägarna;
  - support-URL:en i `docs/appstore/README.md` och `granskning.md`;
  - svenska FAQ:ns gamla svar om att prova utan nedladdning pekar nu på betan.
- **kelly-site-check** provar nu också `/support` och `/sv/support`: 200, storlek, ingen platshållare eller mailto, och 393 px.

## Test
- **Lokalt (Chromium, Playwright):**
  - `/support` och `/sv/support` svarar 200;
  - ingen vågrät rullning vid 393 px, varken ljust eller mörkt läge, och inte heller vid 1280 px;
  - inga trasiga bilder.
- **Live:** se tillägget nedan. Vercel bygger produktionen från main ungefär en gång i timmen (Ke93). Mitt commit `a856b6d7` (02:34 UTC) kom precis efter bygget 02:31.

0 ElevenLabs. Inget i appen är ändrat.

## Tillägg: live (Ke95)
`/support` och `/sv/support` är live efter Vercels bygge 03:05 UTC (main `c6862ed0`, som innehåller `a856b6d7`). kelly-site-check 45932270267:
- båda svarar 200, med 13 205 och 13 227 byte;
- 0 platshållare och 0 mailto;
- ingen vågrät rullning vid 393 px;
- `/`, `/sv` och `/beta` svarar fortsatt 200.

Raden "MISSING 308 /support" är samma fel i kontrollskriptet som tidigare gav "//beta", inget fel på sajten. **Verifierat i Actions.**
