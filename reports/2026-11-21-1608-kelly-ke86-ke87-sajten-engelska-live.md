# Ke86 (deployen) och Ke87: sajten engelska först med språkval, live (Kelly (moln), 2026-11-21, D251, D253)

## Gjort
- Grenen `kelly/ke86-site-en` ihopslagen till main (c53e7d8) och Vercels gren `kelly/ke66-earmind-site` snabbspolad.
- **`/` engelska, `/sv` svenska.** Synligt språkval **English | Svenska** överst på båda sidorna, samma ord som betan;
  valet sparas med betans nyckel `earmind.beta.lang`, så det följer med in i /beta. Sajten startar alltid på engelska;
  bara den som själv valt Svenska skickas från `/` till `/sv` (D253). Inget val utifrån webbläsarens språk.
- Väg till betan: två knappar "Try the beta"/"Open the beta" (engelska), "Prova betan" (svenska).
- Betan (A156) ligger i `site/beta/` från Angela Schrutes bygge; ingen rewrite behövdes (en sida på `/beta`).

## Kontroll
- **Live** (kelly-site-check 44917482493, 15:07 UTC): `/` 200, 38 990 byte, `lang="en"`, titel "EarMind: study by
  listening in your AirPods", "Try the beta" 3 gånger; `/sv` 200, 86 286 byte, "Prova betan"; `/beta` 200; allt sidan
  laddar 250 777 byte; sitemap och robots 200. ("MISSING 308" för `/`, `/sv`, `/beta` är kontrollskriptet som skarvar
  ihop `//beta` av absoluta länkar – inte ett fel på sajten.) **Verifierat live.**
- **393 px:** samma filer i Chromium (iPhone 15), ljust och mörkt: scrollWidth 393 på båda sidorna, språkvalet läsbart i
  båda lägena. **Verifierat lokalt**, inte på telefon.

## Kvar
- Skärmbilderna på den engelska sidan är svenska tills A157:s engelska bilder finns.
- Betans granskning mot `webbeta.md` gör jag när A158 (engelska först i betan) är på main.
