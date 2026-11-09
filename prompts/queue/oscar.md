# Kö: Oscar

- [x] **O1 – Omtest av dina D81–D84-fynd** (effort: low). _klar 2026-11-08 (Oscar): `reports/qa/2026-11-08-1830-oscar-o1-omtest.md`; ny bugg: Provläge säger nivån högt (8 av 10 derivata-svar)_ Beror på: Kevins K1 klar (`prompts/queue/kevin.md`). Testa exakt dina fall igen (rättning med talade tal och algebra, resonemang som läcker, Kemi-"syntes", matte-nivå åk 8 vs Matte 4, förhör mig utan upprepning, intervju utan påhittade fakta, avklippta förslag, provpass-tabell). Notera answer vN per test. Budget 0,25 USD.

- [x] **O2 – Demosidan live** (effort: low). _klar 2026-11-08 (Oscar): `reports/qa/2026-11-08-1630-oscar-demosida.md`; WebKit ej testad (kräver nedladdning, väntar på ja)_ https://aronstenlund-code.github.io/aronstenlund-airpods-ai/ i Playwright med Chromium och WebKit, mobil (iPhone-storlek) och dator: att demon svarar, att alla tak visar serverns svenska text, väntelistan (giltig e-post, samtycke, dubbletter), ljust och mörkt, tangentbordsnavigering och kontrast, laddtid och sidvikt. Skärmbilder ≤ 500 kB i rapporten. Budget 0,10 USD.

- [x] **O3 – utgår** (D88 görs nu av dig själv som O6).

- [x] **O4 – Demosidan i Safari-motorn** (effort: low). _klar 2026-11-08 (Oscar): `reports/qa/2026-11-08-1835-oscar-o4-webkit.md`_ Ja från Deangelo: installera Playwrights WebKit (gratis nedladdning) och kör O2 igen i WebKit, mobil och dator. Budget 0,05 USD.

- [~] pågår 2026-11-09 17:45 **O5 – Förhör mig utan upprepning, och omtest av K7** (effort: low). Beror på: Kevins K7. Kör ditt eget test med 6 frågor i rad och `already_asked` (ja från Deangelo). Testa sedan om fynd A–E, med samma fall och samma antal körningar som i O1. Budget 0,15 USD.

**Ja från Deangelo 2026-11-09 16:15: kör hela O6 enligt ditt förslag under "Nästa" (budget 3 USD). Lägg också till ett fall per prov med en term längre än 20 tecken som kortas, så att det syns att Scribe överlever.**
- [x] klar 2026-11-09 17:30 → `reports/qa/2026-11-09-1730-oscar-o6-hela.md` (pilot: `reports/qa/2026-11-08-2050-oscar-o6-pilot.md`); Arons inspelningar läggs till när de kommer **O6 – D88 ljuduppfattning utan telefon** (effort: high). Flyttad från Kevins K3. Du skriver bara i `scripts/qa/` och `reports/qa/`; ändra inte backend. Hittar du något som backend behöver ändra, skriv det under "Till Kevin" i rapporten. Budget: pilot högst 2 USD; fråga Deangelo i rapporten innan hela körningen. Gör O6 före O5.
  1. Välj 60 fall ur D87-testbanken (ämnesord, korta nyckelord, halva meningar, följdfrågor). Läs igenom manusen innan något genereras (spara ElevenLabs-krediter); kör först en pilot med 15 fall.
  2. Tal med ElevenLabs TTS, 3–4 svenska röster. Tre förhållanden: tyst; bakgrundsprat (blandat av andra TTS-röster, inget licensierat ljud) på 10 och 5 dB SNR; nedsamplat till 16 kHz som en AirPods-mikrofon. Ljudet som Actions-artefakt eller i Supabase Storage, aldrig i git.
  3. Kör genom Scribe som appen gör (realtid, samma VAD-värden per läge, keyterms från en provprofil), med och utan keyterms, och batch som jämförelse. Mät ordfel (WER), andel rätt ämnesord, klippta/sammanslagna yttranden.
  4. Hela kedjan: transkript → /answer i Provläge med profil → D87-rubriken. Jämför med samma fall som ren text så att förlusten från felhörning syns.
  5. Arons egna inspelningar läggs till när han skickar dem i din chatt (hans röst aldrig i repot, det är publikt).
  6. Rapport: tabell per förhållande, de 10 värsta fallen ordagrant, rekommendationer (VAD-värden, keyterms, modell), krediter och kostnad.

- [x] **O7 – Granskning av onödiga begränsningar (D89)** (effort: high). Läs `docs/PRINCIPLES.md` (P1). Ändra ingenting i backend eller appen; det här är bara granskning och mätning.
  1. Inventera alla begränsningar: systemprompter per läge, regler i `answer/` (texter och citat i `web.ts`, filter för resonemang/etiketter/påståenden, 18+-spärren, ämnesspärrar), tak och avslag i koden, och appens egna spärrar. Lista dem i en tabell: var, vad den gör, varför (DECISIONS), behövs (krav/leverantör/upphovsrätt/integritet) eller onödig/för bred.
  2. Bygg en testbank med 60 fall över alla lägen: vanliga frågor som en överförsiktig AI ofta vägrar eller gömmer bakom förbehåll (låtar och texter, vad en låt betyder, historia med våld, kroppen och sex i skolbiologi, droger i ANT-undervisningen, medicin på faktanivå, politik på faktanivå, svordomar i citat, Rizz-repliker, tuffa intervjufrågor), plus 10 fall som ska fortsätta begränsas (hela skyddade låttexter, sådant som Anthropics policy förbjuder). Mät: onödigt avslag, onödigt förbehåll/varning, onödig följdfråga, svaret hjälpte.
  3. Rapport: tabellen, siffror per läge, de 10 värsta fallen ordagrant, och en konkret lista "ändra så här" till Kevin. Budget 0,30 USD. _klar 2026-11-09 17:00 (Oscar): `reports/qa/2026-11-09-1700-oscar-o7-begransningar.md`; 53/60 hjälpte, 10/10 begränsningar höll, 10 ändringar till Kevin (K8)_

