# Kö: Kelly

Aron (2026-11-08): demosidan måste bli väldigt bra.

- [x] klar 2026-11-08 16:14 → reports/2026-11-08-1640-kelly-ke1-demo.md **Ke1 – Demosidan från bra till mycket bra** (effort: medium).
  1. Mobil först: läs sidan på 390 px bredd och rätta allt som känns trångt, glappt eller långsamt. Inga layoutskift när typsnitt laddas.
  2. Visa 2–3 riktiga exempel från Provläget (fråga i handstil, svaret som text och uppläst), hämtade från verkliga svar i D87-testbankens körning, inget påhittat.
  3. En tydlig väg till väntelistan efter att man testat demon (en rad, ett fält).
  4. Delningsbild (Open Graph, 1200×630) och favicon med Lumen-loggan (ringarna), så att länken ser bra ut i Messenger, Snapchat och iMessage.
  5. Sidvikt och laddtid: mät och skriv siffrorna; inga tunga bibliotek.
  6. Inga påståenden om svarstid i sekunder och inget om att ljud aldrig lämnar telefonen.
  Skärmbild mobil + dator, ljust + mörkt i rapporten.

- [x] klar 2026-11-08 18:12 → reports/2026-11-08-1815-kelly-ke2-oscar-fynd.md **Ke2 – Oscars fynd på demosidan** (effort: low). Underlag: `reports/qa/2026-11-08-1630-oscar-demosida.md`. (1) Efter ett svar flyttas fokus till svaret eller "Ställ en ny fråga". (2) Samtyckesrutan och mejllänken får träffytor på minst 44×44 px. (4) Skriv i rapporten exakt hur taket för tal provats; kan det inte provas utan riktig telefon, säg det. Skärmbild mobil.

- [x] klar 2026-11-09 18:10 → reports/2026-11-09-0930-kelly-ke3-delvis.md (Lighthouse ej körd) **Ke3 – "Så funkar Provläget" och hitta sidan** (effort: medium). Aron: demosidan måste bli väldigt bra.
  1. En sektion med tre steg (lägg in provet, starta, fråga i örat) med riktiga skärmbilder från Tobys T3 (`reports/apptest/`). Inga påhittade skärmar och inga påståenden om svarstid i sekunder.
  2. En kort animation (CSS/SVG, under 50 kB, respekterar "reducera rörelse") som visar en fråga i handstil bli ett uppläst svar, som i appens design.
  3. Hittbarhet: titel, beskrivning och rubriker för det elever söker ("plugga inför prov", "förhör mig", "A-nivå", "nationella provet"), strukturerad data (FAQ) och en sitemap. Inget som sidan inte kan hålla.
  4. Mät sidvikt och Lighthouse före och efter. Skärmbilder mobil och dator, ljust och mörkt.

- [x] klar 2026-11-09 18:45 → reports/2026-11-09-1840-kelly-ke4-lighthouse.md **Ke4 – Lighthouse och finputs** (effort: medium). Kör Lighthouse (mobil och dator) med Playwright/Chromium i CI eller lokalt. Mål: minst 95 i Performance, Accessibility, Best Practices och SEO. Rätta det som drar ner. Kontrollera att delningsbilden och FAQ-datan validerar (Googles Rich Results-format, Open Graph). Inga nya påståenden om funktioner som inte är testade på telefon. Skriv siffrorna före och efter.

- [x] klar 2026-11-09 19:15 → reports/2026-11-09-1910-kelly-ke5-kalla.md **Ke5 – Mät var användarna kommer ifrån** (effort: low). Aron räknar med 10–40 kr per användare och behöver veta vilken kanal som ger mest. `/waitlist` tar redan emot `source` (`[a-z0-9_-]{1,32}`). Sidan ska läsa `?utm_source=` eller `?ref=` (till exempel `tiktok`, `snap`, `insta`, `skola`), spara värdet i sessionStorage och skicka det med anmälan. Utan värde skickas `direkt`. Inga cookies och ingen tredjepartsanalys. Skriv en tabell med färdiga länkar per kanal i `docs/marketing/lankar.md`.

- [ ] **Ke6 – Tre annonsbilder för korta videoflöden** (effort: medium). Gör 3 stillbilder, 1080×1920 (TikTok, Snapchat, Reels), i `docs/marketing/annonser/`, i sidans stil (rutpapper, handstil). Använd riktiga skärmbilder från T3 och en riktig fråga och ett riktigt svar från D87-körningen. Svensk text till högstadie- och gymnasieelever, med en vinkel per bild: "Bli förhörd inför provet", "Fråga i örat, få A-nivåsvaret", "Plugga utan att titta på skärmen". Regler: inga påståenden om svarstid i sekunder, inget om funktioner som inte är testade på telefon, inget om fusk på prov, och ingen verklig person. Bilderna ska vara PNG på högst 500 kB och ha en skiss för textrutorna. Aron väljer själv vilka som används.

