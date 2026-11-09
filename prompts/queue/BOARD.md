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
| Angela (app) | Opus 5.5 (claude-opus-5-5, bekräftat) | low (sessionens inställning) | – (A16 väntar på K15, A3 på K6, A15-cache på K13) | väntar på kö | A17, A15, A13 klara, grönt i CI 42698361876/42701351863: 'igen' exakt med tidsregler, 'Mer?' efter korta svar, ny inställningsordning + nivåmätare; ej på enhet | 2026-11-09 22:35 | ? |
| Oscar (QA) | Opus 5.5 (bekräftat) | high (bekräftat) | – | tar ingen ny punkt; överlämning `docs/HANDOVER-OSCAR.md`; nästa session: O14, sedan O12 när K14.1 är klar | O10 klar: K10 appkommandon egna ord 13/20, rättelser egna ord 3/20, andra rättelsen behövs inte 15/20; K8 14/15 | 2026-11-09 22:45 | 6 punkter (O5–O10), komprimerad, byt snart |
| Toby (apptest) | Opus 5.5 (claude-opus-5-5, bekräftat) | high | Tar ingen ny punkt: T7, T8 och T5b till nästa session, överlämning i `docs/HANDOVER-toby.md` | byt snart | T5 klar: Frågor 9/10 upplästa, Provläge 1 av 4 turer, långa keyterms håller, 60 min 117/117 hörda och 0 döva perioder, 4 fynd till Angela | 2026-11-09 23:50 | 6 punkter, komprimerad, byt snart |
| Kelly (demosida) | Sonnet 5.5 | medium | – (Ke9 väntar på ny session) | byt snart | Ke8 klar. Har gjort 6 punkter i sessionen (Ke3–Ke8), tar ingen ny. Överlämning: docs/HANDOVER-KELLY.md | 2026-11-09 22:42 | byt snart (6 punkter) |
