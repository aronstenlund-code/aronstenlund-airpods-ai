# Tavla: vem gör vad

**Självständigt läge (README punkt 8): på till 2026-11-11 18:00.** Plan för dagen: `docs/PLAN-2026-11-11.md`.

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
| Kevin (backend) | Opus 5.5 (claude-opus-5-5) | high | – (kön tom; K6 och Shopify väntar på Aron) | väntar på kö | K34 omgång 4 driftsatt (abb6491) efter Oscars O17e (38/40, 10/10, 10/10, falska 2/40): O17b–O17e i koden, 0 utan träff; Oscar: O17f. K28 klar, K29 av (D125), K30–K33 klara, K18 30/30, K35 fas 1 (telefonverktyg live 12/12, docs/AGENT.md). /stt-token 429 och transcribe 413 rättade. K6 väntar på SUPABASE_SERVICE_ROLE_KEY | 2026-11-10 21:01 | – |
| Angela (app) | Opus 5.5 (claude-opus-5-5) | low (sessionens inställning) | – (A3 väntar på K6:s hemlighet) | pausad till i morgon | I kväll A46 vändkort, A48 qa_log, A38 streak, A43 % redo, A44 widget, A47 D121, A48 telefonverktyg, A49 sömnläge, alla gröna i CI (sist 42917153228); i dag 39 punkter, ej på enhet | 2026-11-11 00:05 | 39 punkter, komprimerad, byt (överlämning `docs/HANDOVER-angela.md`) |
| Oscar (QA) | Opus 5.5 (claude-opus-5-5) | low (sessionens inställning) | – | **pausad till i morgon** (Aron 00:03). Kvar: O13 del 3 och O16 del 2 med Scribe realtid och cachat ljud (stt-token gav 429 för alla till 01:00; provlage-eval transcribe ger 413 över 64 KB, till Kevin) | **O37 K34: BLOCKER nästan borta** — runda 4 på nya O17f: Auto 39/40, tryck-och-prata 10/10, Provläge 9/10, falska 3/40; tyst 'förberett allt, väntar på kvällen'. B5-minne 14/14. API 2026-11-10: 1,93 + 0,305 av 0,50 extra; ElevenLabs 501 tecken, 0 Scribe-s | 2026-11-11 00:04 | komprimerad två gånger (PLAN 2e): ny session behövs, överlämning `docs/HANDOVER-OSCAR.md` |
| Toby (apptest) | Opus 5.5 (claude-opus-5-5) | medium | – | pausad till i morgon | T10 del 2 grön; T5b/T7b/T8b inte körda (/stt-token 429) | 2026-11-11 00:00 | överlämning docs/HANDOVER-toby.md |
| Kelly (demosida) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | Ke31 tre loggkandidater som vektor (sedan Ke29, Ke30) | pågår | Ny session 10:12. Förra: Ke24 klar 21:23 (symbol 4 som vektor, Lighthouse 100×4) | 2026-11-11 10:13 | 0 punkter |
| Ryan (annonser) | – | – | R1 konton och spårning | ny | – | – | – |
