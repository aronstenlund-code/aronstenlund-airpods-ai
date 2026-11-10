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
| Oscar (QA) | Opus 5.5 (claude-opus-5-5) | high | O12 → O15 → stående uppgift | jobbar (självständigt till 18:00), O12 pågår | O14 klar: Provläge 0/20 över 8 s (max 5,7 s), stump 0/6 i intervju men 1/5 efter bortfiltrerat citat, påhittade citat 0/5, 429 först på anrop 21 per minut; 0,36 USD | 2026-11-10 09:30 | 1 punkt (O14), komprimerad en gång, byt snart (fortsätter enligt punkt 8) |
| Toby (apptest) | Opus 5.5 (claude-opus-5-5) | low | T7 (Mer-fönstret): testet på `toby/t7-more`, skript och CI-flöde nu. Sedan T8, T5b när A21 är klar | jobbar | T5 klar: Frågor 9/10 upplästa, Provläge 1 av 4 turer, 60 min 0 döva perioder | 2026-11-10 09:00 | 0 punkter klara (ny session), T7 pågår |
| Kelly (demosida) | Opus 5.5 (claude-opus-5-5) | low (sessionens inställning) | stående uppgift (PLAN 2b) | jobbar (självständigt läge) | Ke11 klar: FAQ-datan synlig på sidan (4/4 ordagrant lika), demons rad i samma ord som väntelistan, Lighthouse 100/100/100/100 | 2026-11-10 07:41 | 3 punkter (Ke9–Ke11), ej komprimerad |
