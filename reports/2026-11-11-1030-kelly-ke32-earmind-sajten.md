# Kelly Ke32: Earmind på sajten (2026-11-11 10:30)

D128: appen heter Earmind. Väckningsordet "Lumen" behålls tills Aron säger något annat.

## Vad som gjordes
- `APP_NAME = "Earmind"` (sidhuvudet, rubriken "Vad kan Earmind?", fotnoten och alla `data-app`).
- Fasta texter som var produktnamnet är bytta: titeln ("Earmind: fråga högt, få svaret i örat. AI i dina AirPods"),
  beskrivningen, `og:site_name`, bildtexten till delningsbilden, FAQ-datan (JSON-LD) och den synliga FAQ:n, heron
  ("Starta Earmind en gång, sen finns den i örat. Säg ”Lumen” så svarar den."), demorutans rader, steg 3.
- "Hör Lumens svar" heter nu "Hör svaret" (inget genitiv-s på Earmind).
- **Väckningsordet står kvar** i alla citat: ”Lumen, förhör mig”, ”Lumen, vad har jag i dag?” osv., och ”Lumen” i heron.
- **Ny delningsbild `site/og-earmind.png`** (1200×630, 111 kB) med ordmärket Earmind; nytt filnamn så att Messenger
  och iMessage inte visar den gamla från cachen. `og-lumen.png` borttagen. Källan
  `docs/marketing/annonser/_src/og-system.html` säger Earmind.

## Mätt
- Lighthouse mobil: **99 / 100 / 100 / 100**. `site/`: **1 504 kB**.
- 390 ljust/mörkt och 1280: inga JS-fel, ingen horisontell scroll, titeln, sidhuvudet, rubriken och demorutans båda
  rader säger Earmind. Bilder: `reports/2026-11-11-ke32-bilder/`.

## Kvar
- Kommentarer i koden säger fortfarande Lumen; det syns inte och ändras när väckningsordet bestäms.
- Delningsbilden visar fortfarande Elias vita hörlur (Ke28 F1).
- Adressen är fortfarande github.io. När earmind.app finns: canonical, `og:url`, `og:image` och sitemap (en rad var).

## Till Aron
- "Starta Earmind … Säg ”Lumen” så svarar den" är sant men kan förvirra. Ska väckningsordet bli "Earmind"?

## Test
Chromium (Playwright). **Ej provat i Safari eller på iPhone.** Kostnad: API 0 USD, ElevenLabs 0 tecken.
