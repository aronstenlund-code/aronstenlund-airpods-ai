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
| Kevin (backend) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | K37 Mina svar (backend) | pågår | K38 klar 10:50: kandidaterna i privat tabell (live 401/403 utan nyckel), O25b 12/22 → 22/22, allmänna 12/12; 0 USD. Oscar: omtest K38; Aron: nyckeln efter Oscar | 2026-11-11 10:26 | 1 punkt |
| Angela (app) | Opus 5.5 (claude-opus-5-5) | low (sessionens inställning) | A50 ny Start (D124/D126) | pågår | Ny session i dag. Plan: A50 → A53 (när K37 är klar); A52/A54 om ingen Angela 2 finns; A51 hoppas över (D127) | 2026-11-11 10:13 | 0 punkter |
| Oscar (QA) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | O16 del 2 (Scribe-regeln för keyterms, lokalt syntetiserat tal) | pågår | Ny session i molnet. Plan: O16 del 2 → O38 (K38) så fort Kevin är klar → O39 (K37) → O13 del 3. **Cachat TTS-ljud (O13d3, O12) ligger bara på Arons dator**, inte i molnet | 2026-11-11 10:18 | 0 punkter |
| Toby (apptest) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | T5b + T7b i CI på `toby/t5b-t7b-t8b-2`; T8b körs ihop med A50-rundan när A50 är inne | pågår | Ny session 09:30. Nattens T1 (08:49) grön: Scribe och /answer svarar igen (7/7 hörda, 5/5 besvarade) | 2026-11-11 09:30 | 0 punkter |
| Kelly (demosida) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | Ke30 Mina svar + Lumen kan allt (sedan Ke32, granska A50/A54) | pågår | Ke29 klar 10:28: docs/design/start-vadkan.md, 7 skisser; A50 granskad i koden (S1 länk till A52, S2 inget Spotify-exempel än), A52 ritad (13 rader); sajten: Vad kan Lumen? + Standardläge i demon, Lighthouse 99/100/100/100, 1 504 kB. Ke31 klar 10:18. API 0 USD | 2026-11-11 10:29 | 2 punkter |
| Ryan (annonser) | – | – | R1 konton och spårning | ny | – | – | – |
