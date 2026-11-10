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
| Kevin (backend) | Opus 5.5 (claude-opus-5-5) | high | – (kön tom; nästa session: stående uppgift K4-loopen) | slutat (PLAN 2e: två komprimeringar), överlämning `docs/HANDOVER-kevin.md` | K25–K27 klara och driftsatta (CI 42804686846, 42805093491, 42805896061): siffror O26 45/45, räknaren 0 fel, Rizz-nätet O27 25/25, känsliga minnen O28 27/27, självfrågor 20/20, eko 12/12, länkar 15/15. K23 (BLOCKER) klar: kris i Auto 44/44. API i dag 0,004 USD | 2026-11-10 12:27 | två komprimeringar: ny session behövs |
| Angela (app) | Opus 5.5 (claude-opus-5-5) | low (sessionens inställning) | A33 (CI), sedan A36, A38, A40, A43 | jobbar | I dag klara och gröna i CI: A21–A30, A16, A19, A35, A37, A39, A41, A42, A45, A34; ej på enhet | 2026-11-10 14:10 | 21 punkter, komprimerad, byt snart (överlämning `docs/HANDOVER-angela.md`) |
| Oscar (QA) | Opus 5.5 (claude-opus-5-5) | low (sessionens inställning) | – (omtest av K23–K27 klart) | väntar på Kevin: **BLOCKER K23 mindre men kvar: 7/40 nya krisfall tysta i Auto**; B5-minne sparar kris/hälsa (6/14) | O35: O17b 40/40, nytt O17c 31/40 (7 tysta, 0 falska). O36: K24 repot skyddat (nya privata 12/22 till granskning, artefakten publik), K25 0 fel, K26 B5 6/14, K27 4/9. API i dag 1,93 + 0,084 av 0,50 extra | 2026-11-10 12:58 | 26 punkter, komprimerad, byt snart (överlämning `docs/HANDOVER-OSCAR.md`) |
| Toby (apptest) | Opus 5.5 (claude-opus-5-5) | medium | T9 skärmrunda efter A18/A22 + T8b del 1 (Lyssnar efter mikrofonfrågan) | jobbar, byt snart | T9: turen följer A18/A22:s knappord (första körningen fastnade på 'Fortsätt', turens fel) | 2026-11-10 10:05 | komprimerad, byt snart (T7, T8 klara, T9 pågår) |
| Kelly (demosida) | Opus 5.5 (claude-opus-5-5) | low (sessionens inställning) | – (Ke22–Ke25 till nästa Kelly-session) | stoppad (PLAN 2e) | Ke21 klar (Rizz utan 18+), A30 godkänd, Ke18 klar (sidans tre steg i nya systemet). API 0 USD | 2026-11-10 12:50 | 15 punkter (Ke9–Ke21, Ke12b, Ke13b, Ke18), två komprimeringar, överlämning skriven i docs/HANDOVER-KELLY.md |
| Ryan (annonser) | – | – | R1 konton och spårning | ny | – | – | – |
