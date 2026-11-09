# Tavla: vem gör vad

**Nattläge: på till 2026-11-10 07:30.** Aron sover. Se README punkt 8.

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
| Kevin (backend) | Opus 5.5 (claude-opus-5-5) | high | K16 → K12 → K13 → K15 → K17 → K18 → K19 → K4 → K5 | K16 pågår (nattläge) | K14 klar: v4 Turbo standard i app och demo, Flash reserv, samma krediter (42/209 tecken), första ljud p50 268 ms. K11: 0/10 över 8 s | 2026-11-09 23:55 | 7 punkter, komprimerad, byt snart (överlämning `docs/HANDOVER-kevin.md`; fortsätter i nattläge) |
| Angela (app) | Opus 5.5 (claude-opus-5-5) | low (sessionens inställning) | A21 → A18 → A20 (nattläge) | A21 pågår | Ny session. Förra: 11 punkter (A8–A17), alla gröna i CI, ej på enhet | 2026-11-09 22:50 | 0 punkter (ny session) |
| Oscar (QA) | Opus 5.5 (claude-opus-5-5) | high | O14 → O12 → O15 → verklighetsbanken (nattläge, högst 2 USD) | O14 pågår | – (ny session) | 2026-11-10 00:20 | 0 punkter, ny session |
| Toby (apptest) | Opus 5.5 (claude-opus-5-5, bekräftat) | high | Tar ingen ny punkt: T7, T8 och T5b till nästa session, överlämning i `docs/HANDOVER-toby.md` | byt snart | T5 klar: Frågor 9/10 upplästa, Provläge 1 av 4 turer, långa keyterms håller, 60 min 117/117 hörda och 0 döva perioder, 4 fynd till Angela | 2026-11-09 23:50 | 6 punkter, komprimerad, byt snart |
| Kelly (demosida) | Opus 5.5 (claude-opus-5-5) | low (ej bekräftat) | Ke9 → stående uppgift (PLAN 2b) | Ke9 pågår (nattläge) | Ny session. Förra: Ke3–Ke8 klara, sidan 1 767 kB | 2026-11-09 22:47 | 0 punkter (ny session) |
