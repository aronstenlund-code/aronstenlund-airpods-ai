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
| Kevin (backend) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | K38 kandidaterna till en privat tabell | pågår | Ny session 10:13. I går: K34 omgång 4 (O17f Auto 39/40), K28–K35 klara; K6 väntar på SUPABASE_SERVICE_ROLE_KEY | 2026-11-11 10:14 | 0 punkter |
| Angela (app) | Opus 5.5 (claude-opus-5-5) | low (sessionens inställning) | A50 ny Start (D124/D126) | pågår | Ny session i dag. Plan: A50 → A53 (när K37 är klar); A52/A54 om ingen Angela 2 finns; A51 hoppas över (D127) | 2026-11-11 10:13 | 0 punkter |
| Oscar (QA) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | O16 del 2 (Scribe-regeln för keyterms, lokalt syntetiserat tal) | pågår | Ny session i molnet. Plan: O16 del 2 → O38 (K38) så fort Kevin är klar → O39 (K37) → O13 del 3. **Cachat TTS-ljud (O13d3, O12) ligger bara på Arons dator**, inte i molnet | 2026-11-11 10:18 | 0 punkter |
| Toby (apptest) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | T5b + T7b i CI på `toby/t5b-t7b-t8b-2`; T8b körs ihop med A50-rundan när A50 är inne | pågår | Ny session 09:30. Nattens T1 (08:49) grön: Scribe och /answer svarar igen (7/7 hörda, 5/5 besvarade) | 2026-11-11 09:30 | 0 punkter |
| Kelly (demosida) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | Ke29 ny Start + Vad kan Lumen? (sedan Ke30, granska A50) | pågår | Ke31 klar 10:18: A/B/C som vektor i docs/design/logo/rostning/vektor/, mörk + ljus, samma ram och ljus (bakgrund 0,010–0,016, toppljus 0,67–0,72), syns i 60 och 29 pt; README till Angela (A54). API 0 USD, ElevenLabs 0 | 2026-11-11 10:19 | 1 punkt |
| Ryan (annonser) | – | – | R1 konton och spårning | ny | – | – | – |
