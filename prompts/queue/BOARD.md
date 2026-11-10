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
| Kevin (backend) | Opus 5.5 (claude-opus-5-5) | high | K15 → K17 → K18 → K19 → K4 → K5 | jobbar: tillbaka på K15 | K21 klar (BLOCKER): krissvar i alla lägen 20/20, falska larm 0/20. K16, K12, K13 klara | 2026-11-10 10:15 | 11 punkter, komprimerad, byt snart (överlämning `docs/HANDOVER-kevin.md`; fortsätter i självständigt läge) |
| Angela (app) | Opus 5.5 (claude-opus-5-5) | low (sessionens inställning) | A18: skärmbilder (Pro, SE) → rapport; sedan stående uppgift | jobbar | Grönt i CI 42773767993: A21 (T5-fynd + T7 fynd 1–2), A20 (taltempo, tyst förhör), A22 (Har du prov snart?), A23 (proffsfixar, D97); A18 designsystemet grönt, bilder körs | 2026-11-10 08:37 | 4 punkter klara i sessionen (A18 snart 5) |
| Oscar (QA) | Opus 5.5 (claude-opus-5-5) | high | offline-test av K12 (gratis, Node); O17 när K21 är klar; O16 del 2 och O13 del 3 när ElevenLabs har krediter | jobbar; API i dag 1,92 av 2 USD, bara gratis tester resten av dagen; **ElevenLabs slut (/tts 503, Scribe quota_exceeded)** | O11 klar: K13 kort 18/18 korrekt, långt klart innan ja, inlärning och räckvidd rätt, 4/18 korta över 35 ord. O13 del 1, O18, O15, O12, O14 klara | 2026-11-10 08:45 | 7 punkter, byt snart (överlämning skriven, fortsätter enligt punkt 8) |
| Toby (apptest) | Opus 5.5 (claude-opus-5-5) | low | T9 stående: omtest A13/A22 i skärmturen (T3 på main) | jobbar | T8 klar: ny användare når aldrig första svaret ('Startar …' efter mikrofonfrågan, 3/3); T7 klar: Mer-fönstret dövt | 2026-11-10 08:40 | 2 punkter klara (T7, T8), T9 pågår |
| Kelly (demosida) | Opus 5.5 (claude-opus-5-5) | low (sessionens inställning) | Ke17: granskning av A18, del 2 väntar på Angelas skärmbilder | jobbar (självständigt läge) | Granskning A18 del 1 (kod, mot c36830b): 5 av 6 rättade av Angela, kvar: röd punkt och röd Avsluta i lyssnarraden. API 0 USD | 2026-11-10 08:06 | 10 punkter, byt snart, fortsätter |
