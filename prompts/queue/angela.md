# Kö: Angela

Fokus (Aron 2026-11-08): Provläget ska fungera riktigt bra; svarskvalitet och ljuduppfattning testas.

- [x] klar 2026-11-08 16:38 → reports/2026-11-08-angela-a1-test-hooks-toby.md **A1 – Testkrokar åt Toby** (effort: medium). Toby (apptestare) tar över ljudkedjetestet och långtestet. Lägg till det han behöver för att mata WAV-filer i stället för mikrofonen i simulatorn (en testbar ljudkälla bakom ett protokoll, bara i Debug/test-byggen) och en testmålsplats `AppTests/E2E/` i project.yml som han får skriva i. Fråga honom i hans rapport om något saknas.

- [~] pågår 2026-11-08 16:38 **A2 – D86 resten** (effort: medium). Skärmarna som behöll listlayouten (Inställningar, Diagnostik, Anteckningar, lägenas startskärmar) får den nya designen. Samtycke: Architect godkänner ett kort samtyckeskort i introduktionen (Lumen lyssnar bara när du startat den, du ser alltid när den lyssnar, ljud sparas inte) med "Läs mer", så att första svaret kan komma inom 30 sekunder. Skicka skärmbilder från simulatorn i rapporten.

- [ ] **A4 – Hackig röst** (effort: high). Gör före A3. Aron (2026-11-08): "rösten låter ibland extremt hackig". Trolig orsak (Deangelo läste koden, ej verifierat på enhet): `ElevenLabsTTSProvider` skickar 100 ms-bitar (`bufferBytes = 4_800`, pcm_24000) och `PlaybackService.schedule` startar spelaren direkt på första biten, utan buffert. Kommer nätet ojämnt (4G, svag wifi, ElevenLabs skickar i skurar) tar ljudet slut mitt i ord → hack. Även glapp mellan meningar när varje mening är ett eget TTS-anrop.
  1. Jitterbuffert: starta uppspelning först när ~300 ms ljud ligger i kö (eller strömmen är slut); tar kön slut mitt i, pausa och buffra om i stället för att spela luckor. Mät och välj värdet; skriv det i DECISIONS.
  2. Räkna och logga underrun (antal, total tystnad i ms) per svar; visa i Diagnostik så att Arons telefontest ger siffror.
  3. Mellan meningar: hämta nästa menings TTS medan den förra spelas, så att det inte blir paus mellan dem.
  4. Kolla även att konverteraren 24 kHz → uppspelningsformat inte skapas om eller nollställs mellan bitar (klick), och att ljudvägen inte byts (A2DP ↔ HFP) mitt i ett svar när mikrofonen är på.
  5. Test: enhetstest med en fejkad ström som levererar ojämnt (skurar, 400 ms paus) → inga luckor efter startbufferten. Toby verifierar sedan i simulatorn; Aron på telefon (markera "ej verifierat på enhet" tills dess).

- [ ] **A3 – Välj röst** (effort: low). Beror på: Kevins K6. Inställningar › Röst: lista med Kevins vitlistade röster, ett tryck spelar ett kort prov, valet sparas och används i alla lägen. Även med rösten: "Lumen, byt röst till sportkommentatorn".
