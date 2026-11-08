# Kö: Kevin

Fokus (Aron 2026-11-08): Provläget ska fungera riktigt bra. Svarskvalitet och ljuduppfattning först.

- [ ] **K1 – Oscars fynd från D81–D84** (effort: high). Underlag: `reports/qa/2026-11-08-1510-oscar-d81-d84.md` och dina egna "Known limits" i D86-rapporten. Push efter varje punkt.
  1. Muntlig rättning: svensk talparsning ("sexton komma fem" = 16,5, "en halv", bråk); ta det sista talet efter "så", "blir", "är"; godta algebraformer ("x är sju", "7 = x", "x = 7"). 30 nya rättningsfall i live-eval, krav 100 %.
  2. Provläget säger aldrig sitt resonemang högt: inget "X är nog Y", "i din lista", "jag tar det som", "inte ett kemiord". Filtrera på innebörd, inte bara första meningen och kända former. Med Kemi-profil tolkas "syntes" inom kemi (t.ex. syntesreaktion) eller är tyst, aldrig fotosyntes.
  3. Nivå i matte: åk 6–9 utan gränsvärden och kedjeregel; gymnasiet enligt kursen. Matematiska påståenden kontrolleras i kod där det går (derivator, ekvationer). Lägg derivata/ekvation för åk 8 och Matte 4 i D87-testbanken.
  4. Förhör mig: recent_qa/already_asked används så att ingen fråga upprepas; ett kort yttrande räknas bara som svar om det kommer inom rimlig tid och inte är en fråga.
  5. Intervjuläget: svara aldrig ja eller nej på något CV:t inte säger (körkort, ålder, alkohol, pendling); styr till det CV:t visar.
  6. Socialt/Rizz: ett förslag som klipps av etikettfiltret kastas, visas aldrig avhugget.
  7. Provpass: tabelluppgifter tolkas rätt; sammanfattningen påstår bara det som finns i rättningen; 429-text på svenska.

- [ ] **K2 – D87 till målet** (effort: high). Baslinjen är 72,6 % "första svaret räcker" med Haiku (`reports/eval/provlage-2026-11-08-haiku-baseline.json`); målet är ≥ 90 %. Läs Oscars granskning `reports/qa/2026-11-08-1610-oscar-d87-review.md` (bedömaren är för sträng på längd; 85 % enligt Oscar i hans urval). Jämför Haiku 5.5 och Sonnet 5.5 (kvalitet, tid till första ljud, kostnad med caching), driftsätt det bästa, och förbättra svarsstrukturen tills målet nås eller förklara exakt vad som stoppar. Skriv siffrorna i rapporten.

- [ ] **K3 – D88 ljuduppfattning utan telefon** (effort: high).
  1. Välj 60 fall ur D87-testbanken (ämnesord, korta nyckelord, halva meningar, följdfrågor). Läs igenom manusen innan något genereras (spara ElevenLabs-krediter); kör först en pilot med 15 fall.
  2. Tal med ElevenLabs TTS, 3–4 svenska röster. Tre förhållanden: tyst; bakgrundsprat (blandat av andra TTS-röster, inget licensierat ljud) på 10 och 5 dB SNR; nedsamplat till 16 kHz som en AirPods-mikrofon. Ljudet som Actions-artefakt eller i Supabase Storage, aldrig i git.
  3. Kör genom Scribe som appen gör (realtid, samma VAD-värden per läge, keyterms från en provprofil), med och utan keyterms, och batch som jämförelse. Mät ordfel (WER), andel rätt ämnesord, klippta/sammanslagna yttranden.
  4. Hela kedjan: transkript → /answer i Provläge med profil → D87-rubriken. Jämför med samma fall som ren text så att förlusten från felhörning syns.
  5. Arons egna inspelningar läggs till när han skickar dem i din chatt (hans röst aldrig i repot, det är publikt).
  6. Rapport: tabell per förhållande, de 10 värsta fallen ordagrant, rekommendationer (VAD-värden, keyterms, modell), krediter och kostnad.

- [ ] **K4 – Snabbare förbättringsloop** (effort: medium). Gör efter K2 om K2 inte redan täcker det.
  1. Varje ändring i backend som rör svar körs automatiskt mot ett urval på 40 fall ur D87-testbanken (i CI, några cent) och resultatet skrivs i PR/commit-kommentaren, så att en försämring syns direkt.
  2. 8–12 förebildssvar för Provläget (olika ämnen, årskurser, nyckelord, följdfråga) i den cachade systemprompten. Mät före och efter.
  3. Riktiga fel blir testfall automatiskt: "det där var fel"-rapporter och dåliga svar i shared_history läggs (anonymiserade) in i testbanken varje natt.
  4. Kunskapskrav som underlag: korta utdrag ur Skolverkets centrala innehåll och kunskapskrav för A per ämne och årskurs/kurs, skickade med profilen, så att "A-nivå" bygger på riktiga krav. Kolla att texten får användas så.
