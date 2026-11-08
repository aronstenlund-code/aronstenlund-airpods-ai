# Kö: Oscar

- [x] **O1 – Omtest av dina D81–D84-fynd** (effort: low). _klar 2026-11-08 (Oscar): `reports/qa/2026-11-08-1830-oscar-o1-omtest.md`; ny bugg: Provläge säger nivån högt (8 av 10 derivata-svar)_ Beror på: Kevins K1 klar (`prompts/queue/kevin.md`). Testa exakt dina fall igen (rättning med talade tal och algebra, resonemang som läcker, Kemi-"syntes", matte-nivå åk 8 vs Matte 4, förhör mig utan upprepning, intervju utan påhittade fakta, avklippta förslag, provpass-tabell). Notera answer vN per test. Budget 0,25 USD.

- [x] **O2 – Demosidan live** (effort: low). _klar 2026-11-08 (Oscar): `reports/qa/2026-11-08-1630-oscar-demosida.md`; WebKit ej testad (kräver nedladdning, väntar på ja)_ https://aronstenlund-code.github.io/aronstenlund-airpods-ai/ i Playwright med Chromium och WebKit, mobil (iPhone-storlek) och dator: att demon svarar, att alla tak visar serverns svenska text, väntelistan (giltig e-post, samtycke, dubbletter), ljust och mörkt, tangentbordsnavigering och kontrast, laddtid och sidvikt. Skärmbilder ≤ 500 kB i rapporten. Budget 0,10 USD.

- [x] **O3 – utgår** (D88 görs nu av dig själv som O6).

- [x] **O4 – Demosidan i Safari-motorn** (effort: low). _klar 2026-11-08 (Oscar): `reports/qa/2026-11-08-1835-oscar-o4-webkit.md`_ Ja från Deangelo: installera Playwrights WebKit (gratis nedladdning) och kör O2 igen i WebKit, mobil och dator. Budget 0,05 USD.

- [ ] **O5 – Förhör mig utan upprepning, och omtest av K7** (effort: low). Beror på: Kevins K7. Kör ditt eget test med 6 frågor i rad och `already_asked` (ja från Deangelo). Testa sedan om fynd A–E, med samma fall och samma antal körningar som i O1. Budget 0,15 USD.

- [ ] **O6 – D88 ljuduppfattning utan telefon** (effort: high). Flyttad från Kevins K3. Du skriver bara i `scripts/qa/` och `reports/qa/`; ändra inte backend. Hittar du något som backend behöver ändra, skriv det under "Till Kevin" i rapporten. Budget: pilot högst 2 USD; fråga Deangelo i rapporten innan hela körningen. Gör O6 före O5.
  1. Välj 60 fall ur D87-testbanken (ämnesord, korta nyckelord, halva meningar, följdfrågor). Läs igenom manusen innan något genereras (spara ElevenLabs-krediter); kör först en pilot med 15 fall.
  2. Tal med ElevenLabs TTS, 3–4 svenska röster. Tre förhållanden: tyst; bakgrundsprat (blandat av andra TTS-röster, inget licensierat ljud) på 10 och 5 dB SNR; nedsamplat till 16 kHz som en AirPods-mikrofon. Ljudet som Actions-artefakt eller i Supabase Storage, aldrig i git.
  3. Kör genom Scribe som appen gör (realtid, samma VAD-värden per läge, keyterms från en provprofil), med och utan keyterms, och batch som jämförelse. Mät ordfel (WER), andel rätt ämnesord, klippta/sammanslagna yttranden.
  4. Hela kedjan: transkript → /answer i Provläge med profil → D87-rubriken. Jämför med samma fall som ren text så att förlusten från felhörning syns.
  5. Arons egna inspelningar läggs till när han skickar dem i din chatt (hans röst aldrig i repot, det är publikt).
  6. Rapport: tabell per förhållande, de 10 värsta fallen ordagrant, rekommendationer (VAD-värden, keyterms, modell), krediter och kostnad.
