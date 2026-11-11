# Överlämning: Kelly, session 2026-11-11 (Ke29–Ke39)

Det här står inte i rapporterna (`reports/*kelly*`).

## Verktyg (molnet)
- Playwright finns förinstallerat: `require('playwright')` och `chromium.launch()` direkt. Lighthouse:
  `npx -y lighthouse@12 … --chrome-path=/opt/pw-browsers/chromium --chrome-flags="--headless=new --no-sandbox"`.
- Skisser: `docs/design/_src/start2.html` (Ke29/Ke30, en `<section class="pair">` per bild), rendera med
  `node docs/design/_src/start2-render.js`. Skriv inte `const top` i skisser (krockar med `window.top`).
- Loggorna för röstningen: `docs/design/logo/_src/rostning.py` + `rostning-render.js`. Den gemensamma ramen står
  överst i `.py`; ändra bara där.
- App-bilder: `gh run download <id> --repo aronstenlund-code/aronstenlund-airpods-ai` (gh fungerar i molnet).
- Tider: `TZ=Europe/Stockholm date` (containern går på UTC, commitarna på +0100).

## Fallgropar
- Tavlan och kön krockar nästan varje push. Lös med att ta deras rader och byta bara min rad (`| Kelly`).
- Angela läser mina underlag inom minuter (S2 rättades 537ea48). Kolla `git log 0d2346e..HEAD -- Lumen` innan fynd.

## Öppna trådar
- **G3 "Ljud sparas inte" är osant** (Sov sparar klipp i 30 dagar). Ordagranna texter i Ke36-rapporten. Ingen punkt
  hos Angela eller Kevin ännu; Deangelo måste lägga den. Högsta prio före nästa testare.
- Små fynd utan punkt: K1 "Dela historik" grå (Ke38), S1 lägesikonen skalar inte, S2 Lyssnars underrubrik kapas (Ke39).
- **Väckningsordet:** appen och sajten heter Earmind men säger ”Lumen”. Aron avgör.
- **"Kommer snart"** på sajten (Kalender, Timer och påminnelser, Spotify, Sömn): ta bort per rad när Aron provat på
  telefon (`site/index.html`, `class="soon"`). Spotify och Ring finns nu i appen (A58, A59) men är inte provade.
- **Loggan:** röstningen (A54) är byggd och granskad. Vinnaren blir AppIcon och ersätter SYSTEM.md avsnitt 5.
- Granskat och godkänt i dag: A50, A52, A53, A54, A55–A61, A64 (största text) och Tobys T8c/T13 (Ke35 fungerar).
- Domänen earmind.app: canonical, og:url, og:image och sitemap byts när den finns.
- Elias vita hörlur (Ke28 F1) syns på delningsbilden `og-earmind.png`.
- Safari och iPhone är fortfarande inte provade för sidan.
