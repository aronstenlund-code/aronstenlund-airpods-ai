# Överlämning: Kelly, session 2026-11-11 (Ke29–Ke48)

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
- **Loggan (D139):** ikonerna är EXAKT ChatGPT-bilderna, aldrig omritade. `_src/exakt.py` beskär 2,6–3,1 % inåt så
  att iOS-maskens hörn hamnar innanför originalens. Mina vektorer (`rostning/vektor/`) används inte.
- A71 godkänd (Ke43). Kvar: hemskärmsikonen efter steg 2 (Tobys natttur) och testlägets skärmar på bild (A76, Ke46/Ke48).
- **Väckningsordet:** appen och sajten heter Earmind men säger ”Lumen”. Aron avgör. Annonserna (Ke22) undviker ordet.
- **Ke22:** bildplan och bilder i `docs/marketing/annonser/ke22/`. Cookiebanner + pixlar (Ryans B1) blockerar
  annonserna; ingen punkt hos mig än (behöver pixel-ID från Ryan och Arons ja till kakor).
- **"Kommer snart"** på sajten: ta bort per rad när Aron provat på telefon (`class="soon"`).
- A73 godkänd; kvar L1: licensraden säger att ElevenLabs inte sparar ljud (motsäger D135).
- Delningsbilden `og-earmind.png` byts när röstningen avgjort loggan. Domänen earmind.app: canonical m.m.
- Safari och iPhone är fortfarande inte provade för sidan.
