# Kö: Oscar

- [x] **O1 – Omtest av dina D81–D84-fynd** (effort: low). _klar 2026-11-08 (Oscar): `reports/qa/2026-11-08-1830-oscar-o1-omtest.md`; ny bugg: Provläge säger nivån högt (8 av 10 derivata-svar)_ Beror på: Kevins K1 klar (`prompts/queue/kevin.md`). Testa exakt dina fall igen (rättning med talade tal och algebra, resonemang som läcker, Kemi-"syntes", matte-nivå åk 8 vs Matte 4, förhör mig utan upprepning, intervju utan påhittade fakta, avklippta förslag, provpass-tabell). Notera answer vN per test. Budget 0,25 USD.

- [x] **O2 – Demosidan live** (effort: low). _klar 2026-11-08 (Oscar): `reports/qa/2026-11-08-1630-oscar-demosida.md`; WebKit ej testad (kräver nedladdning, väntar på ja)_ https://aronstenlund-code.github.io/aronstenlund-airpods-ai/ i Playwright med Chromium och WebKit, mobil (iPhone-storlek) och dator: att demon svarar, att alla tak visar serverns svenska text, väntelistan (giltig e-post, samtycke, dubbletter), ljust och mörkt, tangentbordsnavigering och kontrast, laddtid och sidvikt. Skärmbilder ≤ 500 kB i rapporten. Budget 0,10 USD.

- [x] **O3 – utgår** (D88 görs nu av dig själv som O6).

- [x] **O4 – Demosidan i Safari-motorn** (effort: low). _klar 2026-11-08 (Oscar): `reports/qa/2026-11-08-1835-oscar-o4-webkit.md`_ Ja från Deangelo: installera Playwrights WebKit (gratis nedladdning) och kör O2 igen i WebKit, mobil och dator. Budget 0,05 USD.

- [x] **O5 – Förhör mig utan upprepning, och omtest av K7** (effort: low). Beror på: Kevins K7. Kör ditt eget test med 6 frågor i rad och `already_asked` (ja från Deangelo). Testa sedan om fynd A–E, med samma fall och samma antal körningar som i O1. Budget 0,15 USD. _klar 2026-11-09 17:54 (Oscar): `reports/qa/2026-11-09-1800-oscar-o5-forhor-k7.md`; förhör 6/6 utan upprepning, A/B/E lösta, C och D delvis kvar; 0,30 USD (Provläge på Sonnet + mitt importfel)_

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

- [x] **O8 – Svarstid och kostnad efter bytet till Sonnet** (effort: high). Kevin flyttade Provläge till Sonnet 5.5 (D90), med tänkande för textuppgifter (K7.6), och i O5 hängde ett anrop i över 90 s. Aron kräver max 5 s från fråga till svar, helst under 3 s. Mät live: _klar 2026-11-09 18:24 (Oscar): `reports/qa/2026-11-09-1830-oscar-o8-svarstid-kostnad.md`; Provläge första ljud 2,2 s p50 / 3,2 s p90 (44/45 under 5 s), hänget ej återskapat, 0,30 USD per pluggtimme = cirka 330 h på 100 USD_
  1. Tid till första text och tid till första ljud (/answer plus /tts för första meningen), p50/p90/max, för 40 Provläge-fall: vanliga frågor, textuppgifter med tänkande och följdfrågor. Gör samma sak för Frågor (Haiku).
  2. Antal anrop som tar över 5 s och över 30 s. Försök återskapa hänget från O5 och skriv exakt anrop och tid.
  3. Kostnad per fråga och per timmes plugg (cirka 30 frågor), jämfört med Max-krediten på 100 USD per månad: hur många pluggtimmar räcker den till?
  4. Rapport med tabell och konkreta förslag till Kevin. Budget 0,50 USD.

- [x] **O9 – Oberoende test av kommandona i backend (K9)** (effort: medium). Läs `docs/COMMANDS.md`. Kör 3 nya formuleringar per uppgift som Kevin inte har testat, plus 15 vanliga meningar med kommandoord. Krav: rätt `task`, 0 falska träffar. Budget 0,15 USD. _klar 2026-11-09 18:29 (Oscar): `reports/qa/2026-11-09-1835-oscar-o9-kommandon.md`; rätt task 90/93, falska träffar 0/15; 3 matchningsfel till Kevin ('hur går det för mig' ger påhittad lägesbild)_

- [x] **O10 – Oberoende test av K10 (Lumen lär sig användaren) och K8 (färre begränsningar)** (effort: high). Kevin rapporterar appkommandon 28/28 och "rätta en gång" 20/20 på sina egna fall. Gör 20 nya fall per del, som Kevin inte har sett:
  - (a) Appkommandon med egna ord, i alla lägen, plus 15 vanliga meningar som inte får tolkas som kommandon.
  - (b) Rättelse följd av en liknande fråga, i samma ämne och i ett annat ämne: används inställningen, och i rätt räckvidd?
  - (c) 15 nya fall från O7-typen (låttexter, historia med våld, sexualkunskap, ANT, medicin på faktanivå).
  Budget 0,40 USD. Rapport med siffror och till Kevin. _klar 2026-11-09 21:10 (Oscar): `reports/qa/2026-11-09-2110-oscar-o10-k10-k8.md`; appkommandon 13/20, 0/15 falska; rättelser med egna ord 3/20; andra rättelsen behövs inte 15/20 (vidgning mellan lägen trasig); K8 14/15; nya fel: telefonfiltret byter 'omkring 800 000', Frågor klipper mitt i ord; 0,33 USD_

- [ ] **O11 – Oberoende test av K13 (kort först, mer på ja, inlärd längd)** (effort: high). Beror på: K13. 30 nya fall:
  1. Är det korta svaret korrekt och användbart på egen hand?
  2. Är det långa svaret på A-nivå och fritt från upprepning?
  3. Tid till första ljud efter ett "ja".
  4. Inlärningen: att två ja av tre ger långt direkt och att "kortare" tar tillbaka det, i rätt räckvidd.
  5. Att ett nej eller tystnad inte gör den långrandig.
  Budget 0,40 USD.

- [ ] **O12 – Jämför röstmodellerna** (effort: medium). Beror på: Kevins K14 punkt 1. Gör före O11.
  1. Välj 20 riktiga Lumen-svar på svenska ur D87-körningen (fakta, tal och årtal, namn, en lång förklaring). Läs igenom texterna innan något genereras, för att spara ElevenLabs-krediter.
  2. Generera via `/tts` med `eleven_flash_v2_5`, `eleven_v4_turbo` och `eleven_multilingual_v2`, med samma röst. Jämför också dagens röst "Adam" med de svenska kandidatröster Kevin valt i K14, på den modell som vinner. Aron tycker att demoljudet låter riktigt dåligt, så det här är bråttom.
  3. Mät per modell:
     - tid till första ljud (p50/p90),
     - kostnad,
     - **tydlighet**: kör ljudet genom Scribe och räkna ordfel mot texten, där ett lågt värde betyder att det låter tydligt,
     - **artefakter**: tystnader över 400 ms mitt i en mening, upprepade stavelser, avklippta slut.
  4. Lägg 3 korta A/B-par (samma mening) som Actions-artefakt eller i Supabase Storage, aldrig i git, så att Aron kan lyssna och välja själv.
  5. Rapport med tabell och rekommendation. Budget: högst 1 USD i API och 20 000 ElevenLabs-tecken.

