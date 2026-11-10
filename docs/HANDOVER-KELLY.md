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
- Ke13b klar: sidan följer SYSTEM.md. Ke13 (D97, två knappar på provkortet) klar. Loggan byts när Aron valt A, B eller C (sidhuvudet, `og-lumen.png` via `docs/marketing/annonser/_src/og-system.html`, appen).
- Kör Lighthouse med `--blocked-url-patterns="*supabase.co*"`. Annars skapar varje körning en anonym inloggning, och spärren
  ger 429 (Best Practices 96). Med blockering: 99/100/100/100 (Ke19).
- Skärmbilderna i sidans tre steg (Ke18) byts när Angelas A26 har skärmbilder i repot. Granska dem först (PLAN 2c).
- Ke19: demorutan har D97:s två val. "Förhör mig" är tre Provlägesfrågor med de inspelade svaren i `site/audio/`,
  helt utan anrop, för att servern inte låter demon förhöra (D62). `QUIZ` i skriptet har texterna ordagrant. Byt
  aldrig svarstext utan att byta ljudfil. Oscars `scripts/qa/demo_site*.py` förutsätter att `#txt` syns vid start, så
  "Få A-svar till provet" måste vara förvalt.
- Safari och iPhone är inte provade för någonting på sidan. Rich Results-testet mot live-URL är inte gjort.
