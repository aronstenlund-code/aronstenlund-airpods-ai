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
| Kevin (backend) | Opus 5.5 (claude-opus-5-5) | high | K16 → K12 → K13 → K15 → K17 → K18 → K19 → K4 → K5 | pausad till i morgon | K16 kod driftsatt (deploy 42706487639: recept/instruktioner/regler söker, [[SÖK]] när modellen inte vet, följdfrågor håller källan), 263 tester gröna; live-mätningen `scripts/k16-eval.py` är inte körd, ingen rapport än. K14 klar: v4 Turbo standard | 2026-11-10 00:35 | 7 punkter, komprimerad, byt snart (överlämning `docs/HANDOVER-kevin.md`) |
| Angela (app) | Opus 5.5 (claude-opus-5-5) | low (sessionens inställning) | – | pausad till i morgon | A21 påbörjad: orsak till fynd 1–4 hittad, plan i `docs/HANDOVER-angela.md`, bara `UnfinishedQuestion.swift` pushad (oanvänd) | 2026-11-09 23:05 | 0 punkter klara, A21 pågår |
| Oscar (QA) | Opus 5.5 (claude-opus-5-5) | high | – | pausad till i morgon | O14 halvvägs: Provläge 20/20 under 8 s till första text (max 5,7 s, p50 2,3 s), stump 4/6 körda, citat och 429 kvar; 0,25 USD | 2026-11-10 00:45 | 0 punkter klara, O14 pågår |
| Toby (apptest) | Opus 5.5 (claude-opus-5-5) | low | T7 påbörjad: testet `AppTests/E2E/More/MoreE2ETests.swift` (egen ljudkälla som spelar ja när fönstret öppnas) på grenen `toby/t7-more`; kvar: `scripts/apptest/more.sh`, `more_summary.py`, `apptest-more.yml`, körning och rapport. Sedan T8, T5b | pausad till i morgon | T5 klar: Frågor 9/10 upplästa, Provläge 1 av 4 turer, 60 min 0 döva perioder | 2026-11-10 00:20 | 0 punkter klara (ny session), T7 halvvägs |
| Kelly (demosida) | Opus 5.5 (claude-opus-5-5) | low (ej bekräftat) | Ke9 del 2 (demosidan) i morgon | pausad till i morgon | Ke9 del 1 klar: designunderlag docs/design/enkel-start.md med 8 före/efter-bilder; första svaret 2 tryck, fram till Start 5 → 4 tryck utan formulär | 2026-11-09 23:00 | 0 punkter klara (Ke9 halvvägs) |
