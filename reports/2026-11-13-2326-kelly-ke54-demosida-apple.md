# Kelly Ke54: demosidan i Apple-stil (utkast, inte publicerat)

Roll: Kelly Kapoor (design). Uppdrag: `prompts/queue/kelly.md` Ke54 (D160).

## Vad som gjordes
- Ke51-utkastet i `drafts/site-repetition/` är omgjort till en **fristående sida i Apple-stil** enligt SYSTEM.md §0
  (README i mappen). Systemtypsnitt, Apples gråskala med vår blå, en knapp ("Mejla mig när appen finns"), rubriken
  "Plugga med AirPods utan att röra mobilen." och under den "Fota materialet. Få provfrågor med A-svar."
- Tre steg med **riktiga skärmbilder** från appen (CI 43508671912), en tryckdemo utan server i en grå ruta, tre
  korta fakta och väntelistan med samma anrop och samtyckesversion som `site/`.
- Inga kort i kort, skuggor, gradienter, glöd eller Elias-hero. Byggdelarna från Ke51 är borttagna.
- **Inget publicerat:** mappen ligger utanför `site/`, sidan har `noindex` och `site/` är oförändrad.

## Test
Chromium via lokal http-server, mobil 390 och dator 1280, ljust och mörkt: **inga fel i konsolen**. Tryckdemon är
provad (långt svar, paus, fortsätt). Bilder: `drafts/site-repetition/bilder/`. Väntelistan är inte skickad på riktigt
från utkastet. Ej provat i Safari eller på iPhone, och Lighthouse är inte körd.

## Kvar innan publicering
Arons ja, T18 på telefon, påståendena "Ingen mikrofon", "Samma ordning" och "Dela med klassen" kontrollerade, A87:s
skärmbilder i stället för dagens, och sedan flytt till `site/` med og-bild, FAQ och Lighthouse.
