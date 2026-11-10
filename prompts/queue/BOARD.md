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
| Kevin (backend) | Opus 5.5 (claude-opus-5-5) | high | K21 (BLOCKER) → K15 → K17 → K18 → K19 → K4 → K5 | jobbar: K21 (säkerhet), K15 pausad | K16, K12, K13 klara; K15 live: uppdelning 12/12 och 10/10, nav 11/11, rättning 14/16 | 2026-11-10 09:45 | 10 punkter, komprimerad, byt snart (överlämning `docs/HANDOVER-kevin.md`; fortsätter i självständigt läge) |
| Angela (app) | Opus 5.5 (claude-opus-5-5) | low (sessionens inställning) | A21, A18, A20 byggda → CI → rapporter; sedan stående uppgift | jobbar | A21: 2 av nya testerna föll på testfel (rättade); A18 (en blå knapp per skärm, 5 kommandon, Elias i introt) och A20 (taltempo, tyst förhör) pushade i 59a697f, CI pågår | 2026-11-10 07:52 | 0 klara i sessionen (3 i CI) |
| Oscar (QA) | Opus 5.5 (claude-opus-5-5) | high | O13 del 1 (K16: recept, följdfrågor utan motsägelser); O17 när K21 är klar; O16 del 2 när krediterna finns | jobbar; **ElevenLabs slut: /tts 503 och Scribe quota_exceeded (08:10)** | O18 klar: 82 fall, rätt 42/44, tyst 6/8 ('två r i jordgubbe', svarar på lärarens provfrågor). O15, O12, O14 klara | 2026-11-10 08:40 | 5 punkter (O14, O12, O15, O16 del 1, O18), byt snart (överlämning skriven, fortsätter enligt punkt 8) |
| Toby (apptest) | Opus 5.5 (claude-opus-5-5) | low | Kön: T5b väntar på A21, T7b och T8b på ElevenLabs-kvoten. Nu: stående uppgift | jobbar | T8 klar: ny användare når aldrig första svaret ('Startar …' efter mikrofonfrågan, 3/3), Provläge 1 tryck med prov, 6 utan; T7 klar: Mer-fönstret dövt | 2026-11-10 08:35 | 2 punkter klara (T7, T8) |
| Kelly (demosida) | Opus 5.5 (claude-opus-5-5) | low (sessionens inställning) | Ke17: granskning av A18, del 2 väntar på Angelas skärmbilder | jobbar (självständigt läge) | Granskning A18 del 1 (kod, mot c36830b): 5 av 6 rättade av Angela, kvar: röd punkt och röd Avsluta i lyssnarraden. API 0 USD | 2026-11-10 08:06 | 10 punkter, byt snart, fortsätter |
