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
| Kevin (backend) | Opus 5.5 (claude-opus-5-5) | high | – (kön tom; nästa session: stående uppgift K4-loopen) | slutat (PLAN 2e: två komprimeringar), överlämning `docs/HANDOVER-kevin.md` | K25–K27 klara och driftsatta (CI 42804686846, 42805093491, 42805896061): siffror O26 45/45, räknaren 0 fel, Rizz-nätet O27 25/25, känsliga minnen O28 27/27, självfrågor 20/20, eko 12/12, länkar 15/15. K23 (BLOCKER) klar: kris i Auto 44/44. API i dag 0,004 USD | 2026-11-10 12:27 | två komprimeringar: ny session behövs |
| Angela (app) | Opus 5.5 (claude-opus-5-5) | low (sessionens inställning) | A46 vändkort i tyst läge; sedan A38/A43 när K31/K33 är klara | jobbar | I dag 31 punkter klara och gröna i CI (A16–A30, A33–A37, A39–A42, A45–A47); ej på enhet | 2026-11-10 19:27 | 31 punkter, komprimerad, byt (överlämning `docs/HANDOVER-angela.md`) |
| Oscar (QA) | Opus 5.5 (claude-opus-5-5) | low (sessionens inställning) | – (omtest av K23–K27 klart) | väntar på Kevin: **BLOCKER K23 mindre men kvar: 7/40 nya krisfall tysta i Auto**; B5-minne sparar kris/hälsa (6/14) | O35: O17b 40/40, nytt O17c 31/40 (7 tysta, 0 falska). O36: K24 repot skyddat (nya privata 12/22 till granskning, artefakten publik), K25 0 fel, K26 B5 6/14, K27 4/9. API i dag 1,93 + 0,084 av 0,50 extra | 2026-11-10 12:58 | 26 punkter, komprimerad, byt snart (överlämning `docs/HANDOVER-OSCAR.md`) |
| Toby (apptest) | Opus 5.5 (claude-opus-5-5) | medium | – | slutade 18:00, väntar på kö | T9 klar, T10 del 1; T5b/T7b/T8b väntar på ElevenLabs | 2026-11-10 17:57 | komprimerad, överlämning docs/HANDOVER-toby.md |
| Kelly (demosida) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | Ke23 namn och logga | pågår | Ny session. Ke23 → Ke24 (väntar på Arons nummer) → Ke25. ElevenLabs 0 tecken | 2026-11-10 19:30 | 0 punkter |
| Ryan (annonser) | – | – | R1 konton och spårning | ny | – | – | – |
