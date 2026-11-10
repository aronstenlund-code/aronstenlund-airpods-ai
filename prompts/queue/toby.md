# Kö: Toby (apptestare)

Du testar appen oberoende av Angela och ändrar aldrig appkoden. Saknas en testkrok: skriv det under "Behöver av Angela" i din rapport.

- [x] klar 2026-11-08 18:50 → reports/apptest/2026-11-08-1850-toby-t1-audio-chain.md **T1 – Ljudkedjetest i simulatorn** (effort: high). Beror på: Angelas A1 (testkrokar). CI-test som matar WAV-filer genom appens riktiga ljudkedja → Silero-VAD → Scribe (riktig realtidsanslutning via /stt-token, samma parametrar per läge och keyterms från en provprofil) → yttrandesammanslagning → QuestionGate/Provläge → /answer. Kontrollera: ingen krasch, rätt antal yttranden; transkript och svar som artefakt. Ljud: Kevins D88-ljud när det finns, annars egna TTS-filer. Manuellt + nattligt, inte på varje push.

- [x] klar 2026-11-09 16:30 → reports/apptest/2026-11-09-1630-toby-t2-long-run.md **T2 – Långtest 60 minuter** (effort: medium). Beror på: T1. 60 minuter Provläge med upprepat ljud: minne över tid, att Scribe förnyas utan avbrott, att inget läge stängs av, att svarstiden inte växer. Kurvor i rapporten.

- [x] klar 2026-11-09 16:25 → reports/apptest/2026-11-09-1625-toby-t3-screens.md **T3 – Bildtester av alla skärmar** (effort: medium). Ögonblicksbilder i simulatorn av varje skärm i ljust och mörkt, stor textstorlek och liten iPhone. Jämför mot skisserna (https://claude.ai/artifact/UZeuuk1zxGMKVA6A9CQC1x, eller beskrivningen i D86) och lista avvikelser. Kör i CI så att designfel syns automatiskt.

- [x] klar 2026-11-08 16:10 → reports/apptest/2026-11-08-1610-toby-t4-device-quick.md **T4 – Testschema för Aron på telefon** (effort: low). Ett kort schema (högst 15 minuter) för det som bara går att testa på riktig iPhone + AirPods: eko, AirPods-knappen, nick, röstbyte av läge, låsskärm, Provläge 10 minuter. Varje steg: vad han gör, vad som ska hända, vad han skickar tillbaka. Lägg i `docs/DEVICE-TEST-QUICK.md`.

Simulatorn räknas aldrig som verifiering på enhet; skriv det i varje rapport.

- [x] klar 2026-11-09 21:55 → `reports/apptest/2026-11-09-2150-toby-t5-retest.md` **T5 – Omtest efter Angelas A8 och A11** (effort: medium). Beror på: A8 och A11 klara. (1) Frågor: 10 vanliga frågor via WAV-kroken, varav 3 med en fortsättning efter en kort paus. Alla ska få svar som läses upp (räkna ställda/besvarade/upplästa). (2) Provläge: 3 frågor och en instruktion i rad ska bli 4 egna turer. (3) Ett prov med ett keyterm längre än 20 tecken: Scribe ska hålla. (4) Kör om T2 (60 min): inga döva perioder över 30 s, och "Lyssnar" bara när det stämmer. Skriv siffrorna i rapporten.

- [x] klar 2026-11-09 20:05 → `reports/apptest/2026-11-09-2000-toby-t6-commands.md` **T6 – Kommandon i simulatorn** (effort: medium). Beror på: Angelas A7. Läs `docs/COMMANDS.md`. Mata varje kommando (3 varianter) och 10 vanliga meningar som innehåller kommandoord via WAV-kroken i alla 5 lägen. Krav: rätt åtgärd och 0 falska träffar. Lägg till de 5 viktigaste kommandona i `docs/DEVICE-TEST-QUICK.md` så att Aron testar dem på telefon.

- [x] klar 2026-11-10 08:15 → `reports/apptest/2026-11-10-0815-toby-t7-more.md` **T7 – Mer-fönstret i simulatorn** (effort: medium). Beror på: Angelas A15. Kör via WAV-kroken: "ja", "mer", "gärna" inom 5 s, ett "ja" efter 6 s, "ja" mitt i en mening, ett ja från en annan röst och en ny fråga i fönstret. Krav: rätt i alla fall, och långt svar under 1 s efter ja. Lägg till steget i `docs/DEVICE-TEST-QUICK.md` (nick och tryck testas på telefonen av Aron).

- [x] klar 2026-11-10 08:30 → `reports/apptest/2026-11-10-0830-toby-t8-forstagangsanvandaren.md` **T8 – Förstagångsanvändaren** (effort: medium). Gör efter T7. Aron 2026-11-09: lätt att komma igång och aldrig överväldigande. I simulatorn, från helt ny installation till första upplästa svaret i Frågor och i Provläge: räkna tryck, skärmar och sekunder, och skriv ner varje text eller knapp som är oklar eller onödig. Skärmbilder av varje steg till `reports/apptest/`. Fynd till Angela och Kelly (Ke9). Ändra ingen appkod.

- [~] pågår 2026-11-10 19:38 (krediterna påfyllda, Frågor + block enligt D120) **T5b – Omtest av T5 efter Angelas A21** (effort: medium). Beror på: A21 (klar 2026-11-10) och påfylld ElevenLabs-kvot (Scribe `quota_exceeded` sedan 07:45). Samma fall som T5.

- [x] klar 2026-11-10 17:10 → `reports/apptest/2026-11-10-1710-toby-t9-skarmrunda.md` **T9 – Skärmrunda efter A22 och A18** (effort: medium). Beror på: A23 (sedan igen efter A18). Samma sju lägen som T3. Lägg bilderna sida vid sida med Kellys Ke12-skisser och skriv avvikelserna till Angela och Kelly.

- [~] pågår 2026-11-10 19:38 **T7b – Omtest av Mer-fönstret** (effort: medium). Beror på: Angelas rättning av T7-fynd 1 (fönstret öppnas innan mikrofonen hör) och påfylld ElevenLabs-kvot. Kör `apptest-more` på `toby/t7-more` (eller main): ordlogiken (ja, mer, gärna, ja mitt i mening, annan röst, ny fråga) och tid till långt svar under 1 s (K13).

- [~] pågår 2026-11-10 19:38 (vägen Hoppa över enligt D120) **T8b – Omtest av förstagångsanvändaren** (effort: medium). Beror på: påfylld ElevenLabs-kvot, och Angela har tittat på T8-fynd 1 ("Startar …" efter mikrofonfrågan). Kör `apptest-firstuser`: tid och tryck till första svaret i Frågor och Provläge.

- [~] pågår 2026-11-10 19:38, del 1 klar → `reports/apptest/2026-11-10-1710-toby-t10-elevenlabs-nere-del1.md`, del 2 (503-stub i testet) körs **T10 – När ElevenLabs ligger nere (N3)** (effort: medium). Simulera att Scribe och ElevenLabs-rösten svarar fel (kvoten slut, 503) och kontrollera att appen fortsätter med iPhonens taligenkänning och röst, inte blir döv eller tyst, och att A45:s rad visas en gång. Skärmbilder.
