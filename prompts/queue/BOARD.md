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
| Kevin (backend) | Opus 5.5 (claude-opus-5-5) | high | – (K18 del 2 och K6 väntar på ElevenLabs-krediter) | väntar på kö (API-taket nått i dag, ~6,1 USD) | Stående K4-loop omgång 1: en 5:a = en femma, bråk i ord, O20/O13 rättade, regression 21/21. I dag klara: K16, K12, K13, K21(+b), K15, K17, K18 del 1, K19, K4, K5 | 2026-11-10 09:50 | 18 punkter, komprimerad, byt snart (överlämning `docs/HANDOVER-kevin.md`) |
| Angela (app) | Opus 5.5 (claude-opus-5-5) | low (sessionens inställning) | stående uppgift (PLAN 2b), väntar på nya fynd | jobbar | 7 klara i dag, gröna i CI: A21, A18, A20, A22, A23, A24, A25 (T8: första starten); ej på enhet. Resten av kön väntar på Kevin | 2026-11-10 10:00 | 7 punkter, byt snart (överlämning `docs/HANDOVER-angela.md`) |
| Oscar (QA) | Opus 5.5 (claude-opus-5-5) | high | – (omtest av O17 när Kevin rättat K21; O16 del 2 och O13 del 3 när ElevenLabs har krediter) | väntar: API-budgeten för dagen använd (1,93 av 2 USD), ElevenLabs-krediter slut; **BLOCKER hos Kevin: K21 fångar 16/30** | O22 klar: rättelser med nya ord 4/20, appkommandon 3/10 (offline). O21: K15-navigering 28/40. O17: BLOCKER, K21 fångar 16/30. O20, O19, O11, O13 del 1, O18, O15, O12, O14 klara | 2026-11-10 08:55 | 12 punkter, byt snart (överlämning skriven) |
| Toby (apptest) | Opus 5.5 (claude-opus-5-5) | low | T9 stående: omtest A13/A22 i skärmturen (T3 på main) | jobbar | T8 klar: ny användare når aldrig första svaret ('Startar …' efter mikrofonfrågan, 3/3); T7 klar: Mer-fönstret dövt | 2026-11-10 08:40 | 2 punkter klara (T7, T8), T9 pågår |
| Kelly (demosida) | Opus 5.5 (claude-opus-5-5) | low (sessionens inställning) | Ke18 väntar på Angelas R1–R4 och nya bilder | väntar | Ke17 klar: A18 godkänd med rättelser (20 bilder granskade; Start godkänd; R1–R4 före nästa T3: ringarna i ansiktet, SE skymmer löftena, svart bakgrund i mörkt, "Startar …" vid paus). API 0 USD | 2026-11-10 08:49 | 11 punkter (Ke9–Ke17, Ke12b, Ke13b), byt snart, fortsätter |
