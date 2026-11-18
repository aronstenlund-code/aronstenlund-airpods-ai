# Ke82: demosidan som appen är nu (Kelly (moln), 2026-11-18, D218, D224)

## Vad som ändrades i `site/index.html` (live på earmind.vercel.app)
- **Hero:** Säg i AirPods först: "Skriv det du vill höra. EarMind läser upp det i dina AirPods, om och om igen." och
  under "Eller fota boken och få provfrågor med svar. Du styr med tryck på AirPods, utan mikrofon."
- **Så fungerar det**, fyra steg med Ke80-bilderna (iPhone 17 Pro Max, full storlek, nedskalade till 600 px webp):
  Skriv det du vill höra · **Hur ska det låta?** (AI väljer röst efter stilen, eller välj själv och lyssna först) ·
  Eller fota boken · Starta prov. Raden **"Sedan ligger telefonen i fickan." är struken** (antydde låst skärm, D209).
- **Nytt avsnitt "Gratis att börja"** (`#krediter`): 5 000 krediter när du börjar, 1 500 i månaden, 1 kredit = 1 tecken
  nytt ljud, upprepningar gratis; paketen 100/10 kr, 500/39 kr, 2 000/110 kr (Bäst värde), veckokort 79 kr/vecka
  (cirka 3 prov, förnyas tills du säger upp det); "Ett prov är ungefär 6 000 krediter"; **Bjud in** (2 000 krediter).
  Bild: kreditbladet ur appen. Tal med hårda mellanslag så att "1 500" inte bryts.
- **Vanliga frågor:** "Vad kostar det?" och "Kan jag välja röst?".
- Röster: bara de vanliga (bilden av bladet med "Att provlyssna" används inte).
- **Inga länkar till /integritet eller /villkor** (Ke78 inte godkänd). De gamla bilderna `rep-*.webp` är borttagna.
- `kelly-site-check.yml` räknar nu också "Gratis att börja" och kollar cache-huvudet på `img/app-sag.webp`.

## Kontroller
- **Lokalt (Chromium, iPhone 15, 393 px):** scrollWidth 393 i ljust och mörkt, ingen vågrät rullning. Bilder:
  `reports/2026-11-18-ke82-bilder/` (krediter mobil ljust/mörkt, Så fungerar det, krediter på dator).
- **Live (kelly-site-check 44362639889, 17:48 UTC):** 200, HTML 84 970 byte, allt sidan laddar inkl. lata bilder
  296 712 byte, inga saknade filer, steget finns, "Gratis att börja" finns, cache på bilderna, sitemap och robots 200.
  Väntelistan anropades inte. **Verifierat live** (sidan); mobilbredden är **verifierad lokalt**, inte på telefon.
- Vercels produktionsgren `kelly/ke66-earmind-site` snabbspolad till main (2a1de1f) – den bör bli main (Aron).
- 0 ElevenLabs: sidans demo anropades inte.

## Kvar
- Kreditbilden på sidan visar låtsasbutikens "10,00 kr"; texten säger "10 kr". Ändras priserna i App Store: uppdatera
  båda.
- Bilderna är bara ljusa (Ke80-flödet tar ljust); i mörkt läge står ljusa skärmbilder på mörk sida.
