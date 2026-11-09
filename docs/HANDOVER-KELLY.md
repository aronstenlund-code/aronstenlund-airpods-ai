# Överlämning: Kelly (demosidan), session som gjorde Ke3–Ke8

Det här står inte i rapporterna. Rapporterna `reports/*kelly*` täcker resten.

## Så jobbar du
- Jag arbetar bara i `site/` (plus `docs/marketing/`, `docs/design/`). Förhandsvisa med `python -m http.server 8765 -d site`.
- **Lighthouse:** `npx -y lighthouse http://localhost:8765/ [--preset=desktop] --chrome-flags="--headless=new --no-sandbox"`. Senast 100/100/100/100 (mobil 99–100).
- **Skärmbilder och scrollinspelning:** `puppeteer-core` med Chrome (`C:/Program Files/Google/Chrome/Application/chrome.exe`) fungerar bra; webbläsarpanelens `scrollTo` är opålitlig. Skriptet jag använde finns bara i min scratchpad, skriv om det vid behov (emulera `prefers-color-scheme`, sätt scroll så att `#elias` får önskad progress).
- **Renderade bilder** (annonser, OG): `docs/marketing/annonser/_src/ad.html?n=1|2|3&real=1[&skiss=1]` och `og.html?real`, Chrome `--headless=new --screenshot`, via en lokal `http.server` i `_src`.

## Fallgropar
- Klassen `.ring` finns redan i demon (skivans ringar). Elias-ringarna heter `.rings`/`.pulse`.
- `site/` ska vara högst 2 MB (nu 1,77 MB). Elias-sekvensen är bara udda bildrutor (60 st). Bild 049–065 laddas inte (handen såg konstig ut); de ligger kvar i mappen och kan tas bort om vikten behövs.
- Skriv aldrig "nästa" i övningsprov, "ljudet lämnar aldrig telefonen" eller svarstid i sekunder på sidan. Övningsprov (A16) är inte byggt.
- Använd `git add` på namngivna filer, inte `git add -A reports`: det tog med Angelas oincheckade rapporter i `9c62e44`.
- Klockan: kör `date` för tid i tavlan och köerna, gissa inte.

## Öppna trådar
- **Ke9 är inte påbörjad** (`prompts/queue/kelly.md`): designunderlag i `docs/design/enkel-start.md` och en enda väg framåt på sidan ("Så kommer du igång", 3 steg, en knapp).
- Sidan har nu många sektioner (hero, "Så funkar", röstbudskap, exempel, lägen, väntelista): Ke9 ska ta bort det som drar åt flera håll.
- Rich Results-test mot live-URL och Safari/iPhone-test av scrolleffekten är inte gjorda.
- `site/og.png` (gammal) ligger kvar som reserv; og:image är `og-elias.png`.
- Väntelistans `source` (`?utm_source=`) är bara provad lokalt, inte mot live `/waitlist`.
