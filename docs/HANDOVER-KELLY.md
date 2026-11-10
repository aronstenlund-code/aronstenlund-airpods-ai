# Överlämning: Kelly (demosidan och design), session som gjorde Ke9–Ke12 och Ke12b (2026-11-10)

Det här står inte i rapporterna. Rapporterna `reports/*kelly*` täcker resten.

## Så jobbar du
- Jag jobbar i `site/`, `docs/design/` och `docs/marketing/`. Förhandsvisa med `python -m http.server 8765 -d site`.
- **Skisser:** `docs/design/_src/system.html` (det nya systemet) och `enkel-start.html` (Ke9/Ke10, gammal stil). Starta
  `python -m http.server 8790` från repots rot och kör sedan Chrome `--headless=new --screenshot --window-size=880,1010
  "…?s=<skärm>[&dark=1]"`. Loggbladet behöver bredden 1210.
- **Helsidesbilder, klick och mätning:** `puppeteer-core@23` i scratchpad (`npm i puppeteer-core@23`), med Chrome i
  `C:/Program Files/Google/Chrome/Application/chrome.exe`.
  - Sätt `document.documentElement.style.scrollBehavior='auto'` innan du scrollar, annars hamnar bilden fel.
  - Kvantisera bilderna med PIL (`quantize(128)`), så att rapporterna håller sig små.
- **Lighthouse:** `npx -y lighthouse http://localhost:8765/ [--preset=desktop] --chrome-flags="--headless=new --no-sandbox"`.
  Senast 100/100/100/100.
- **Deploy:** kontrollera med GitHub API via `git credential fill` (gh finns inte). Pages-deployen tar ungefär 1 min.

## Fallgropar
- **Delat index:** en annan session kan committa dina stagade filer. Gör `git add F && git commit -- F` i ett kommando.
  En tom `.git/rebase-merge` som blir kvar tas bort med `rmdir`. Kontrollera autostash innan du gör något annat.
- Kör `date` innan du skriver en tid. Jag gissade 07:50 när klockan var 07:38 och fick rätta det.
- Raden i demon efter svaret har en egen samtyckesversion (`CONSENT_VERSION_ROW`, högst 16 tecken). Höj den när radens
  text ändras.
- FAQ-datan (JSON-LD) och "Vanliga frågor" på sidan måste ha samma text. Ändra båda från en lista (se Ke11).
- Samtyckesmeningen under Testa nu och tummen ned (D57) får aldrig försvinna ur en skiss.

## Öppna trådar
- **Ke13 pågår:** demosidan i SYSTEM.md, utan handstil och nästan utan rutpapper. Loggan byts först när Aron valt A, B eller C.
- Skärmbilderna i sidans tre steg ska bytas när A18 är byggd (Toby tar nya).
- Safari och iPhone är inte provade för någonting på sidan. Rich Results-testet mot live-URL är inte gjort.
