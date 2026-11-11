# Kelly Ke29: ny Start och "Vad kan Lumen?" (2026-11-11 10:28)

D124, D125, D126. Angela hade redan byggt A50 (commit 0d2346e) när jag började, så Ke29 blev tre saker:
granskning av A50 i koden, underlag till A52 (inte byggd) och samma budskap på sajten.

## Vad som gjordes
- **Underlag:** `docs/design/start-vadkan.md` med sju skisser i `docs/design/bilder/start2/`, ljust och mörkt
  (källa `docs/design/_src/start2.html`, rendering `_src/start2-render.js`):
  Start, Start med Provläge, Start på SE, Välj läge, Vad kan Lumen? (överst och hela listan), och bladet efter
  första svaret.
- **A50 granskad i koden** (`HomeView.swift`, `Theme.swift`), inte på skärmbilder. Den följer D124/D126. Tre rättelser:
  **S1** "Allt Lumen kan ›" saknas i rutan Lumen kan allt (vägen till A52). **S2** exemplet med Spotify lovar något
  som inte är byggt: byt mot förhör tills Spotify fungerar. **S3** (valfri) knappen 72 i stället för 64 pt.
- **A52 ritad:** 13 rader i fyra grupper. Varje rad säger vad man säger och om något behöver ställas in, med verklig
  status från behörigheterna. Bara det som behövs får en knapp (Tillåt, Koppla). Det som inte är byggt står som
  "Kommer snart". Bladet "Lumen kan mer än svara" kommer en gång efter första svaret.
- **Sajten:**
  - Ny sektion "Vad kan Lumen?" med D125:s Siri-rad och åtta rader. Kalender, Timer och påminnelser, Spotify och
    Sömn är märkta "Kommer snart" tills de är provade på telefon. Fotnot om Siri som Apples varumärke.
  - Demorutan heter nu **Standardläge** och **Förhör mig** i stället för "Få A-svar till provet", och Standardläge
    står först (D124). Raden säger "Lumen svarar när någon frågar.", samma ord som appens Byt läge.
  - I steg 3 står "Vill du bara ha svar, starta Lumen och fråga." i stället för "trycker du Få A-svar".

## Mätt
- Lighthouse mobil (Chromium, supabase blockerad): **99 / 100 / 100 / 100**.
- `site/`: **1 504 kB** (gräns 2 MB).
- 390 px ljust och mörkt och 1280 px: ingen horisontell scroll, inga JS-fel.
- Bilder: `reports/2026-11-11-ke29-bilder/` (sektionen mobil ljus/mörk och dator, demorutan mobil).

## Till Angela
- A50: S1 och S2 (och S3 om Toby eller Aron tycker att knappen inte syns). Se `docs/design/start-vadkan.md`.
- A52: bygg efter samma fil. Statusen ska komma från behörigheterna, inte vara hårdkodad.

## Till Aron
- **Väckningsordet:** appen heter Earmind (D128) men man säger "Lumen". Efter A55 står "Earmind kan allt" ovanför
  "Säg ”Lumen” och vad du vill". Ska väckningsordet också bli Earmind? Jag rekommenderar att bestämma det före
  annonserna, eftersom annonserna säger ordet högt.
- **Siri i appen:** kan ge en fråga i App Store-granskningen (**ej verifierat**). Sajten har en fotnot. Jag har ett
  reservförslag utan ordet Siri.
- **"Kommer snart" på sajten:** ta bort brickan för Kalender och Timer när du har provat dem i kväll (säg till, så
  gör jag det).

## Inte gjort
- Sajten byter inte namn till Earmind här; det är Ke32 (nästa i kön efter Ke30).
- Inga skärmbilder från A50 fanns att granska. Granskningen på bilder görs när Toby eller Angela har tagit dem.

## Test
Chromium (Playwright). **Ej provat i Safari eller på iPhone.** Kostnad: API 0 USD, ElevenLabs 0 tecken.
