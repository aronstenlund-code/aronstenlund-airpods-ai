# Överlämning: Kelly, session 2026-11-11 förmiddag (Ke29–Ke33)

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
- **Väckningsordet:** sajten heter Earmind men säger ”Lumen”. Aron avgör; då ändras citaten på sajten och i skisserna.
- **"Kommer snart"** på sajtens Vad kan Earmind? (Kalender, Timer och påminnelser, Spotify, Sömn): ta bort per rad
  när Aron provat på telefon (`site/index.html`, `class="soon"`).
- **Röstningen (A54):** granska när den är byggd mot `docs/design/logo/rostning/vektor/README.md`. Vinnaren ska bli
  AppIcon och ersätta SYSTEM.md avsnitt 5.
- **A52 och A53** byggs efter `start-vadkan.md` och `mina-svar.md`; granska skärmbilderna.
- **"Ljud sparas inte"** (Ke28 F2, Ke33 G3) måste lösas före A53.
- Domänen earmind.app: canonical, og:url, og:image och sitemap byts när den finns.
- Elias vita hörlur (Ke28 F1) syns fortfarande på delningsbilden `og-earmind.png`.
- Safari och iPhone är fortfarande inte provade för sidan.
