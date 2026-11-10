# Tavla: vem gör vad

**Självständigt läge (README punkt 8): på till 2026-11-11 07:30.** Aron sover och kan inte svara.

Deangelo läser tavlan före varje statusrapport till Aron. **Varje session uppdaterar bara sin egen rad**:
- när den tar en punkt,
- när den blir klar (resultatet i en mening med siffror),
- när den fastnar eller väntar.

Kolumnerna:
- **Modell** och **Effort**: det sessionen faktiskt kör på, enligt skärmen eller `/model`.
- **Kontext**: punkter klara i sessionen, "komprimerad" eller "byt snart" (README punkt 7).
- **Senast**: tid för senaste uppdatering (ÅÅÅÅ-MM-DD HH:MM).

| Session | Modell | Effort | Gör nu | Status | Senaste resultat | Senast | Kontext |
|---|---|---|---|---|---|---|---|
| Kevin (backend) | Opus 5.5 (claude-opus-5-5) | high | Tobys /stt-token 429, sedan K30 | jobbar (självständigt till 07:30) | K34 (BLOCKER) klar i tre omgångar, driftsatt 1c14046: O17d 37/40 live före omgång 3, kodlagret nu 0 utan träff, B5 14/14; väntar på Oscars O17e. K28 klar (D113 A1–A3). K29 byggd men av (D125, Haiku 75 % korrekt). API i kväll cirka 2,0 USD (mest CI-regression och K29-mätning) | 2026-11-10 20:11 | – |
| Angela (app) | Opus 5.5 (claude-opus-5-5) | low (sessionens inställning) | – (A38/K31, A43/K33, A44/A38, A3/K6 väntar på Kevin) | väntar på kö | A46 vändkort klar: kort att trycka igenom utan ljud, räknas som förhörssvar (CI 42876606748, 4 tester, bilder på SE); i dag 32 punkter gröna i CI, ej på enhet | 2026-11-10 20:19 | 32 punkter, komprimerad, byt (överlämning `docs/HANDOVER-angela.md`) |
| Oscar (QA) | Opus 5.5 (claude-opus-5-5) | low (sessionens inställning) | O13 del 3 och O16 del 2 (Scribe realtid, cachat ljud, D120) | väntar till 01:00: stt-token ger 429 för alla användare (global dygnsgräns 600); provlage-eval transcribe ger 413 över 64 KB (till Kevin) | **O37 K34: BLOCKER nästan borta** — runda 3 på nya O17e: Auto 38/40, tryck-och-prata 10/10, Provläge 10/10, falska 2/40; tysta 'köra av vägen med mopeden', 'aldrig bli gammal'; B5-minne 14/14. API i dag 1,93 + 0,245 av 0,50 extra; ElevenLabs 501 tecken, 0 Scribe-s | 2026-11-10 20:21 | komprimerad två gånger (PLAN 2e): gör Arons tre punkter, sedan slut och överlämning |
| Toby (apptest) | Opus 5.5 (claude-opus-5-5) | medium | T5b, T7b, T8b efter 01:00 | pågår | T10 del 2 grön; /stt-token 429 (dagstaket), till Kevin | 2026-11-10 20:15 | självständigt till 07:30, överlämning 20:15 |
| Kelly (demosida) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | stående uppgift (PLAN 2b) | pågår | Ke27 klar 20:28: sömnläget ritat (Sov i Byt läge, eget samtycke, svart natt, morgonrapport) i docs/design/sovlage.md; "Ljud sparas inte" blir osant med A49. Ke26 klar 20:24 (D121 på sidan, Lighthouse 100). Ke23 klar 20:20 (rekommenderar Earmind). Ke25 klar 20:12. Ke24 väntar på Arons nummer. ElevenLabs 0, API 0 USD | 2026-11-10 20:29 | 4 punkter |
| Ryan (annonser) | – | – | R1 konton och spårning | ny | – | – | – |
