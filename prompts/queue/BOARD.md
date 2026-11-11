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
| Kevin (backend) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | K37 Mina svar (backend) | pågår | K38 klar 10:26: kandidaterna i privat tabell (live 401/403 utan nyckel), O25b 12/22 → 22/22, allmänna 12/12; 0 USD. Oscar: omtest K38; Aron: nyckeln efter Oscar | 2026-11-11 10:27 | 1 punkt |
| Angela (app) | Opus 5.5 (claude-opus-5-5) | low (sessionens inställning) | A50 ny Start (D124/D126) | pågår | Ny session i dag. Plan: A50 → A53 (när K37 är klar); A52/A54 om ingen Angela 2 finns; A51 hoppas över (D127) | 2026-11-11 10:13 | 0 punkter |
| Oscar (QA) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | O39 test av K37 Mina svar (falska träffar), offline först, sedan live | pågår | **O38: K38 GODKÄND 10:33** (tabellen nekar klienten 17/17 live, nya filterfall 24/26) — **Aron: lägg in SUPABASE_SERVICE_ROLE_KEY**. **O16 klar 10:34:** Scribe tillåter ≤20 kodpunkter/term, ≤50 termer; appen räknar grafem (NFD-lucka); **ElevenLabs loggar Scribe-sessionerna (ingen zero retention) men Om appen säger 'sparas inte'**. O13 del 3: cachat ljud bara på Arons dator. I dag 0 USD, 0 ElevenLabs, 62 Scribe-s | 2026-11-11 10:35 | 2 punkter |
| Toby (apptest) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | T5b, T7b, T8b och A50-rundan (förstagång + skärmtur) kör i CI på `toby/t5b-t7b-t8b-2` | pågår | Ny session 10:15. Nattens T1 grön: Scribe och /answer svarar igen (7/7 hörda, 5/5 besvarade). Testerna hittar nu A50:s Starta Lumen och Byt | 2026-11-11 10:36 | 0 punkter |
| Kelly (demosida) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | – (A54 och A52 granskas när de är byggda) | väntar på kö | Ke33 klar 10:39: A50 godkänd (CI 42993726421), 3 fynd kvar: länk till A52, grå ikoner i lägesbladet (låg), Ljud sparas inte före A53. I dag: Ke31 loggorna som vektor, Ke29 Start + Vad kan Lumen?, Ke30 Mina svar, Ke32 Earmind på sajten. API 0 USD, ElevenLabs 0 | 2026-11-11 10:39 | 5 punkter, byt snart (överlämning docs/HANDOVER-KELLY.md) |
| Ryan (annonser) | – | – | R1 konton och spårning | ny | – | – | – |
