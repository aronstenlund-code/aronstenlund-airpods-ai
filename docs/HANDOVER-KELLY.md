# Överlämning: Kelly lokal → Kelly (moln), 2026-11-15

Den lokala sessionen (2026-11-13 – 15, Ke49–Ke62) lämnar över till "Kelly (moln)". Det här står inte i rapporterna
(`reports/*kelly*`). Föregående överlämning (Ke29–Ke48) finns i git-historiken för den här filen.

## Klart (allt på main)
- **Repetitionsläget:** design `docs/design/repetition.md`, texter `repetition-texter.md` (uppdaterade efter A85/A86,
  A90 Arons trycktext ordagrant, D162, D164, D175, D176, A100), Publicera prov `publicera-prov.md`, första starten
  `forsta-starten.md` (D170 godkänd), Gör med ChatGPT `gor-med-chatgpt.md`, hjälp-AI:n `hjalp.md`.
- **Apple-stil (D160):** `docs/design/SYSTEM.md` §0 (§0.3 har D174 om grå text), skisser `docs/design/bilder/apple/`.
- **Granskat och godkänt på bild:** A82, A83/A84 (P1 stängd), A85/A86, A87, A88–A90, A92, A93/A94, A95/A98, A99/A100,
  A102 (Ke61), största text (S1–S5). Rapporterna heter `reports/2026-11-1[3-4]-*-kelly-*`.
- **Ke60 (D179) EarMind med stort M** i designdokumenten, skisserna, utkastet och App Store-texten.

## Pågår
- Inget. **Ke62 är klar** (`reports/2026-11-15-0306-kelly-ke62-appstore-utkast.md`). Kvar därifrån: rubrikerna i App Store-bilderna med SF Pro på en Mac, och
  Angelas `VoiceChannel.names` ("Earmind") om namnet visas någonstans.

## Väntar på andra
- **Grenen `kelly/ke60-earmind-site`** (b646295): demosidan `site/` med EarMind och delningsbilden
  `og-earmind-v2.png`. **Inte publicerad.** Aron har inte svarat. Slå ihop med main först när Aron säger ja (Pages
  publicerar `site/**` vid push till main). Gör en `git rebase origin/main` på grenen innan, eftersom `site/index.html`
  kan ha ändrats.
- **Kevin:** F2 i Ke61 (servern ska inte börja en mening med en symbol, "A = π · r², där π är ungefär 3,14."),
  H-1–H-5 i `docs/HJALP.md` (knappnamnen) och avsnittet "Gör med ChatGPT" i HJALP.md.
- **Angela Fable:** A104 (tomma lägen och fellägen) ska granskas på bild när bilderna kommer.
- **Publicering** av demosidans utkast (`drafts/site-repetition/`) och App Store-texten: bara efter Arons ja och T18.

## Verktyg (lokalt, Windows; i molnet finns playwright och gh direkt)
- **Skisser:** `docs/design/_src/apple.html` (Apple-stil, Ke53–Ke58) och `_src/repetition.html` (Ke49–Ke52), en
  `<section class="pair" id="…">` per bild. Rendera med `node docs/design/_src/apple-render.js [id]` eller
  `repetition-render.js [id]`. Lokalt behövs `NODE_PATH=<playwright-core>` och `PW_CHROME=<chrome.exe>`.
- **App Store-bilder:** `python -I docs/appstore/_src/appstore.py <uppackad skärmbildsartefakt> [<fet ttf> <vanlig ttf>]`.
  Använd en körning på **iPhone 17 Pro Max** (1320 × 2868). Rubrikerna ska sättas med SF Pro Display på en Mac
  (Segoe UI används i Windows som ersättning).
- **Skärmbilder från CI:** "Simulator screenshots" (workflow 411255536) med `workflow_dispatch` och indata `device`,
  `screens` (`rep` = alla repetitionsscener, eller namn med mellanslag) och `text_size` (`default` eller
  `accessibility-extra-extra-extra-large`). Skärmbilderna bygger appen själva, så det behövs inget grönt iOS-bygge först.
- **Demosidans utkast:** `drafts/site-repetition/index.html` är fristående. Skärmbilder tas med `shots.js` och en
  http-server från repots rot (typsnitt blockeras under `file://`).

## Fallgropar (lärda den här gången)
- **Den delade arbetskopian:** andra sessioner har ocommittade filer. Använd aldrig `git pull --autostash`. Committa
  med pathspec (`git commit -- <filer>`). Om pull vägrar: `git reset --keep origin/main` och `git cherry-pick`.
  Ofta tar en annan sessions push med ens commit.
- **Ändra aldrig backtick-text med sed** (\` är buffertens början i GNU sed). Använd Python-skript i filer och kör
  `git diff --stat` före varje commit.
- **Heredoc utan citattecken kör backticks som kommandon.** Skriv rapporter med `<<'EOF'` eller via Write/Python.
- Tiden i rapportnamn ska komma från `date`, aldrig uppskattas.
- **`site/` publiceras vid push till main.** Allt som ska vänta på Aron läggs på en egen gren.
