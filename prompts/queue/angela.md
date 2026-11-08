# Kö: Angela

Fokus (Aron 2026-11-08): Provläget ska fungera riktigt bra; svarskvalitet och ljuduppfattning testas.

- [ ] **A1 – Ljudkedjetest i simulatorn** (effort: high). Ett CI-test som matar WAV-filer genom appens riktiga ljudkedja i simulatorn: uppspelning av fil in i AVAudioEngine-grafen i stället för mikrofonen → Silero-VAD → Scribe (riktig realtidsanslutning via /stt-token, samma parametrar per läge och keyterms från en provprofil) → yttrandesammanslagning → QuestionGate/Provläge → /answer. Kontrollera: ingen krasch, rätt antal yttranden, transkript och svar loggas som artefakt. Ljudfiler: Kevins D88-ljud när det finns (K3 i hans kö), annars några egna TTS-filer. Kör det inte på varje push om det kostar mycket; manuellt + nattligt räcker. Simulatorn är ingen enhetsverifiering, skriv det i rapporten.

- [ ] **A2 – Långtest 60 minuter** (effort: medium). Samma uppsättning som A1 men 60 minuter Provläge med upprepat ljud: minnesanvändning över tid, att Scribe-sessionen förnyas utan avbrott, att inget läge stängs av, och att svarstiden inte växer. Rapportera kurvor (minne, svarstid) och allt som läcker eller faller.

- [ ] **A3 – D86 resten** (effort: medium). Skärmarna som behöll listlayouten (Inställningar, Diagnostik, Anteckningar, lägenas startskärmar) får den nya designen. Samtycke: Architect godkänner ett kort samtyckeskort i introduktionen (Lumen lyssnar bara när du startat den, du ser alltid när den lyssnar, ljud sparas inte) med "Läs mer", så att första svaret kan komma inom 30 sekunder. Skicka skärmbilder från simulatorn i rapporten.
