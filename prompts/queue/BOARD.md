# Tavla: vem gör vad

Deangelo läser tavlan före varje statusrapport till Aron. **Varje session uppdaterar bara sin egen rad**:
- när den tar en punkt,
- när den blir klar (resultatet i en mening med siffror),
- när den fastnar eller väntar.

Kolumnerna:
- **Modell** och **Effort**: det sessionen faktiskt kör på, enligt skärmen eller `/model`.
- **Senast**: tid för senaste uppdatering (ÅÅÅÅ-MM-DD HH:MM).

| Session | Modell | Effort | Gör nu | Status | Senaste resultat | Senast |
|---|---|---|---|---|---|---|
| Kevin (backend) | Opus 5.5 (claude-opus-5-5) | high | K4 (snabbare förbättringsloop) → K5 → K6 | klar med K8, tar K4 | K8 klar: onödiga avslag 2/60 → 1/64 (pris i Auto kvar), 10/10 begränsade höll, D1–D3/dos/låtrad/vers rättade. K10 klar: appkommandon 28/28, rätta en gång 20/20 | 2026-11-09 19:46 |
| Angela (app) | Opus 5.5 (claude-opus-5-5, bekräftat) | low (sessionens inställning) | A13 designgranskning: koden grön (CI 42693453845), väntar på Tobys skärmrunda 42693453684 för före/efter-bilder | jobbar | A9 och A14 klara (grönt i CI 42690189387). A13: Inställningar Vanliga/Avancerat/Om appen, nivåmätare, Provläge-chips + Förhör mig, Fler lägen, IntroHeroView | 2026-11-09 21:43 |
| Oscar (QA) | Opus 5.5 (bekräftat) | high (bekräftat) | – | väntar på kö | O10 klar: K10 appkommandon egna ord 13/20 (0/15 falska), rättelser egna ord 3/20, andra rättelsen behövs inte 15/20, vidgning mellan lägen trasig; K8 14/15; telefonfiltret byter 'omkring 800 000' | 2026-11-09 21:10 |
| Toby (apptest) | Opus 5.5 (claude-opus-5-5, bekräftat) | high | T5 (omtest efter A8 och A11: Frågor, Provläge, långt keyterm, T2 60 min igen) | jobbar | T6 klar: 485/541 kommandon rätt i 5 lägen, 5 falska träffar av 68 ("Lumen" mitt i en mening), 6 fynd till Angela | 2026-11-09 20:05 |
| Kelly (demosida) | Sonnet 5.5 | medium | – (kön tom) | väntar på kö | Ke7 klar: scrollstyrd Elias-hero (120 bilder, lerp, vilobilder, ringar), 3 annonser + OG med riktiga bilden. Lighthouse 100 på alla lokalt. Safari/iPhone ej provad | 2026-11-10 00:10 |
