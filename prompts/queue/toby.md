# Kö: Toby (apptestare)

Du testar appen oberoende av Angela och ändrar aldrig appkoden. Saknas en testkrok: skriv det under "Behöver av Angela" i din rapport.

- [ ] **T1 – Ljudkedjetest i simulatorn** (effort: high). Beror på: Angelas A1 (testkrokar). CI-test som matar WAV-filer genom appens riktiga ljudkedja → Silero-VAD → Scribe (riktig realtidsanslutning via /stt-token, samma parametrar per läge och keyterms från en provprofil) → yttrandesammanslagning → QuestionGate/Provläge → /answer. Kontrollera: ingen krasch, rätt antal yttranden; transkript och svar som artefakt. Ljud: Kevins D88-ljud när det finns, annars egna TTS-filer. Manuellt + nattligt, inte på varje push.

- [ ] **T2 – Långtest 60 minuter** (effort: medium). Beror på: T1. 60 minuter Provläge med upprepat ljud: minne över tid, att Scribe förnyas utan avbrott, att inget läge stängs av, att svarstiden inte växer. Kurvor i rapporten.

- [~] pågår 2026-11-08 20:10 **T3 – Bildtester av alla skärmar** (effort: medium). Ögonblicksbilder i simulatorn av varje skärm i ljust och mörkt, stor textstorlek och liten iPhone. Jämför mot skisserna (https://claude.ai/artifact/UZeuuk1zxGMKVA6A9CQC1x, eller beskrivningen i D86) och lista avvikelser. Kör i CI så att designfel syns automatiskt.

- [ ] **T4 – Testschema för Aron på telefon** (effort: low). Ett kort schema (högst 15 minuter) för det som bara går att testa på riktig iPhone + AirPods: eko, AirPods-knappen, nick, röstbyte av läge, låsskärm, Provläge 10 minuter. Varje steg: vad han gör, vad som ska hända, vad han skickar tillbaka. Lägg i `docs/DEVICE-TEST-QUICK.md`.

Simulatorn räknas aldrig som verifiering på enhet; skriv det i varje rapport.
