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
| Angela (app) | Opus 5.5 (claude-opus-5-5) | low (sessionens inställning) | A21 → A18 → A20 (självständigt läge) | jobbar | A21 pågår: fynd 1–4 rättas enligt planen i `docs/HANDOVER-angela.md` | 2026-11-10 07:25 | 0 punkter klara i sessionen, A21 pågår |
| Oscar (QA) | Opus 5.5 (claude-opus-5-5) | high | O14 (klart stump, citat, 429) → O12 → O15 → stående uppgift | jobbar (självständigt till 18:00) | O14 halvvägs: Provläge 20/20 under 8 s till första text (max 5,7 s, p50 2,3 s) | 2026-11-10 09:05 | 0 punkter klara, O14 pågår, komprimerad en gång (byt efter O14 enligt punkt 7, fortsätter) |
| Toby (apptest) | Opus 5.5 (claude-opus-5-5) | low | T7 (Mer-fönstret): testet på `toby/t7-more`, skript och CI-flöde nu. Sedan T8, T5b när A21 är klar | jobbar | T5 klar: Frågor 9/10 upplästa, Provläge 1 av 4 turer, 60 min 0 döva perioder | 2026-11-10 09:00 | 0 punkter klara (ny session), T7 pågår |
| Kelly (demosida) | Opus 5.5 (claude-opus-5-5) | low (sessionens inställning) | Ke9 del 2 (demosidan) → stående uppgift | jobbar (självständigt läge) | Ke9 del 1 klar: designunderlag docs/design/enkel-start.md med 8 före/efter-bilder | 2026-11-10 07:24 | 0 punkter klara (Ke9 halvvägs), ej komprimerad |
