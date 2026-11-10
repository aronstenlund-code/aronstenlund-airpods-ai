# Tavla: vem gör vad

**Självständigt läge (README punkt 8): på till 2026-11-10 18:00.** Aron är borta och kan inte svara.

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
| Kevin (backend) | Opus 5.5 (claude-opus-5-5) | high | – (K18 del 2 och K6 väntar på ElevenLabs-krediter) | väntar på kö (API-taket nått i dag, ~6,1 USD) | K20 klar (frågor om Lumen ur Om appen, kungars nummer, get_started). Stående K4-loop omgång 1: en 5:a = en femma, bråk i ord, O20/O13 rättade, regression 21/21. I dag klara: K16, K12, K13, K21(+b), K15, K17, K18 del 1, K19, K4, K5 | 2026-11-10 09:50 | 18 punkter, komprimerad, byt snart (överlämning `docs/HANDOVER-kevin.md`) |
| Angela (app) | Opus 5.5 (claude-opus-5-5) | low (sessionens inställning) | A26 Kellys R1–R6, sedan A16 och A19 | jobbar | 7 klara i dag, gröna i CI: A21, A18, A20, A22, A23, A24, A25; ej på enhet | 2026-11-10 10:45 | 7 punkter, komprimerad, byt snart (överlämning `docs/HANDOVER-angela.md`), fortsätter till 18:00 |
| Oscar (QA) | Opus 5.5 (claude-opus-5-5) | low (sessionens inställning) | O23: omtest av K21b med en ny oberoende krisuppsättning (O17b), live högst 0,40 USD (Aron godkänt) | jobbar | O22 klar: rättelser med nya ord 4/20, appkommandon 3/10 (offline). O21: K15-navigering 28/40. O17: K21 fångade 16/30. O20, O19, O11, O13 del 1, O18, O15, O12, O14 klara | 2026-11-10 10:45 | 12 punkter, komprimerad, byt snart (överlämning `docs/HANDOVER-OSCAR.md`) |
| Toby (apptest) | Opus 5.5 (claude-opus-5-5) | low | T9 stående: omtest A13/A22 i skärmturen (T3 på main) | jobbar | T8 klar: ny användare når aldrig första svaret ('Startar …' efter mikrofonfrågan, 3/3); T7 klar: Mer-fönstret dövt | 2026-11-10 08:40 | 2 punkter klara (T7, T8), T9 pågår |
| Kelly (demosida) | Opus 5.5 (claude-opus-5-5) | low (sessionens inställning) | Ke19 demosidan med D97:s två val (Förhör mig, Få A-svar till provet); Ke18 väntar på Angelas A26 | jobbar | Ke17 klar: A18 godkänd med rättelser (R1–R6 nu A26 hos Angela). API 0 USD | 2026-11-10 10:41 | 11 punkter (Ke9–Ke17, Ke12b, Ke13b), en komprimering, byt snart, fortsätter till 18:00 |
