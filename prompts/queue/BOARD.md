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
| Kevin (backend) | Opus 5.5 (claude-opus-5-5) | high | K16 → K12 → K13 → K15 → K17 → K18 → K19 → K4 → K5 | jobbar: K16 live-mätning | K16 kod driftsatt (deploy 42706487639), mätning pågår. K14 klar: v4 Turbo standard | 2026-11-10 | 7 punkter, komprimerad, byt snart (överlämning `docs/HANDOVER-kevin.md`; fortsätter i självständigt läge) |
| Angela (app) | Opus 5.5 (claude-opus-5-5) | low (sessionens inställning) | A21, A18, A20 byggda → CI → rapporter; sedan stående uppgift | jobbar | A21: 2 av nya testerna föll på testfel (rättade); A18 (en blå knapp per skärm, 5 kommandon, Elias i introt) och A20 (taltempo, tyst förhör) pushade i 59a697f, CI pågår | 2026-11-10 07:52 | 0 klara i sessionen (3 i CI) |
| Oscar (QA) | Opus 5.5 (claude-opus-5-5) | high | O18 (stående uppgift: verklighetsbanken växer, 82 fall); O17 (K21) direkt när K21 är klar; O16 del 2 när krediterna finns | jobbar; **ElevenLabs slut: /tts 503 och Scribe quota_exceeded (08:10)** | O16 del 1: Deangelos 22 stängda strömmar = en term på 25 tecken, appens filter täcker regeln. O15 klar: 215 fall, svarade rätt 156/168, tyst 33/37 | 2026-11-10 08:25 | 3 punkter + O16 del 1 |
| Toby (apptest) | Opus 5.5 (claude-opus-5-5) | low | T8 förstagångsanvändaren (T7 klar) | jobbar | T7 klar: Mer-fönstret dövt, mikrofonen öppnar 2,8–13,3 s efter tonen (fönstret 5 s), 0/7 ja hörda; fynd till Angela; ElevenLabs-kvoten slut stoppar omtest | 2026-11-10 08:20 | 1 punkt klar (T7) |
| Kelly (demosida) | Opus 5.5 (claude-opus-5-5) | low (sessionens inställning) | Ke17: granskning av A18, del 2 väntar på Angelas skärmbilder | jobbar (självständigt läge) | Granskning A18 del 1 (kod, mot c36830b): 5 av 6 rättade av Angela, kvar: röd punkt och röd Avsluta i lyssnarraden. API 0 USD | 2026-11-10 08:06 | 10 punkter, byt snart, fortsätter |
