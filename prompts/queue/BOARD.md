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
| Kevin (backend) | Opus 5.5 (claude-opus-5-5) | high | – (kön tom; K6 och Shopify väntar på Aron) | väntar på kö | K34 omgång 4 driftsatt (abb6491) efter Oscars O17e (38/40, 10/10, 10/10, falska 2/40): O17b–O17e i koden, 0 utan träff; Oscar: O17f. K28 klar, K29 av (D125), K30–K33 klara, K18 30/30, K35 fas 1 (telefonverktyg live 12/12, docs/AGENT.md). /stt-token 429 och transcribe 413 rättade. K6 väntar på SUPABASE_SERVICE_ROLE_KEY | 2026-11-10 21:01 | – |
| Angela (app) | Opus 5.5 (claude-opus-5-5) | low (sessionens inställning) | A49 sömnläge (D123) | jobbar | A48 telefonverktyg klar: kalender, påminnelser, timer, larm, anteckningar med bekräftelse (CI 42913492996); i dag 38 punkter gröna i CI, ej på enhet | 2026-11-10 23:42 | 38 punkter, komprimerad, byt (överlämning `docs/HANDOVER-angela.md`) |
| Oscar (QA) | Opus 5.5 (claude-opus-5-5) | low (sessionens inställning) | O13 del 3 och O16 del 2 (Scribe realtid, cachat ljud, D120) | väntar till 01:00: stt-token ger 429 för alla användare (global dygnsgräns 600); provlage-eval transcribe ger 413 över 64 KB (till Kevin) | **O37 K34: BLOCKER nästan borta** — runda 4 på nya O17f: Auto 39/40, tryck-och-prata 10/10, Provläge 9/10, falska 3/40; tyst 'förberett allt, väntar på kvällen' (runda 3 O17e 38/40); B5-minne 14/14. API i dag 1,93 + 0,305 av 0,50 extra; ElevenLabs 501 tecken, 0 Scribe-s | 2026-11-10 21:22 | komprimerad två gånger (PLAN 2e): gör Arons tre punkter, sedan slut och överlämning |
| Toby (apptest) | Opus 5.5 (claude-opus-5-5) | medium | – | pausad till i morgon | T10 del 2 grön; T5b/T7b/T8b inte körda (/stt-token 429) | 2026-11-11 00:00 | överlämning docs/HANDOVER-toby.md |
| Kelly (demosida) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | – (Ke22 hos Ryan/Aron) | väntar på kö | Ke24 klar 21:23: Arons symbol 4 ritad som vektor (ikon 1024 ljus/mörk/tonad, symbol, favicon), syns i 29 pt; sidan bytt (Lighthouse 100×4, 1 515 kB); AppIcon + LumenLogo till Angela. Ke23–Ke28 klara. ElevenLabs 0, API 0 USD | 2026-11-10 21:24 | 6 punkter, byt (överlämning docs/HANDOVER-KELLY.md) |
| Ryan (annonser) | – | – | R1 konton och spårning | ny | – | – | – |
