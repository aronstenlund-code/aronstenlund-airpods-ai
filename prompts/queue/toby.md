# Kö: Toby (apptestare)

Du testar appen oberoende av Angela och ändrar aldrig appkoden. Saknas en testkrok: skriv det under "Behöver av Angela" i din rapport.

- [x] klar 2026-11-08 18:50 → reports/apptest/2026-11-08-1850-toby-t1-audio-chain.md **T1 – Ljudkedjetest i simulatorn** (effort: high). Beror på: Angelas A1 (testkrokar). CI-test som matar WAV-filer genom appens riktiga ljudkedja → Silero-VAD → Scribe (riktig realtidsanslutning via /stt-token, samma parametrar per läge och keyterms från en provprofil) → yttrandesammanslagning → QuestionGate/Provläge → /answer. Kontrollera: ingen krasch, rätt antal yttranden; transkript och svar som artefakt. Ljud: Kevins D88-ljud när det finns, annars egna TTS-filer. Manuellt + nattligt, inte på varje push.

- [x] klar 2026-11-09 16:30 → reports/apptest/2026-11-09-1630-toby-t2-long-run.md **T2 – Långtest 60 minuter** (effort: medium). Beror på: T1. 60 minuter Provläge med upprepat ljud: minne över tid, att Scribe förnyas utan avbrott, att inget läge stängs av, att svarstiden inte växer. Kurvor i rapporten.

- [x] klar 2026-11-09 16:25 → reports/apptest/2026-11-09-1625-toby-t3-screens.md **T3 – Bildtester av alla skärmar** (effort: medium). Ögonblicksbilder i simulatorn av varje skärm i ljust och mörkt, stor textstorlek och liten iPhone. Jämför mot skisserna (https://claude.ai/artifact/UZeuuk1zxGMKVA6A9CQC1x, eller beskrivningen i D86) och lista avvikelser. Kör i CI så att designfel syns automatiskt.

- [x] klar 2026-11-08 16:10 → reports/apptest/2026-11-08-1610-toby-t4-device-quick.md **T4 – Testschema för Aron på telefon** (effort: low). Ett kort schema (högst 15 minuter) för det som bara går att testa på riktig iPhone + AirPods: eko, AirPods-knappen, nick, röstbyte av läge, låsskärm, Provläge 10 minuter. Varje steg: vad han gör, vad som ska hända, vad han skickar tillbaka. Lägg i `docs/DEVICE-TEST-QUICK.md`.

Simulatorn räknas aldrig som verifiering på enhet; skriv det i varje rapport.

- [~] pågår 2026-11-09 20:05 **T5 – Omtest efter Angelas A8 och A11** (effort: medium). Beror på: A8 och A11 klara. (1) Frågor: 10 vanliga frågor via WAV-kroken, varav 3 med en fortsättning efter en kort paus. Alla ska få svar som läses upp (räkna ställda/besvarade/upplästa). (2) Provläge: 3 frågor och en instruktion i rad ska bli 4 egna turer. (3) Ett prov med ett keyterm längre än 20 tecken: Scribe ska hålla. (4) Kör om T2 (60 min): inga döva perioder över 30 s, och "Lyssnar" bara när det stämmer. Skriv siffrorna i rapporten.

- [x] klar 2026-11-09 20:05 → `reports/apptest/2026-11-09-2000-toby-t6-commands.md` **T6 – Kommandon i simulatorn** (effort: medium). Beror på: Angelas A7. Läs `docs/COMMANDS.md`. Mata varje kommando (3 varianter) och 10 vanliga meningar som innehåller kommandoord via WAV-kroken i alla 5 lägen. Krav: rätt åtgärd och 0 falska träffar. Lägg till de 5 viktigaste kommandona i `docs/DEVICE-TEST-QUICK.md` så att Aron testar dem på telefon.

