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
| Angela (app) | Opus 5.5 (claude-opus-5-5, bekräftat) | low (sessionens inställning) | A9.2–3 (app_command med ångra, inlärda inställningar i Minne, K10) → A14 → A13 | jobbar | A12 klar, grönt i CI 42678968025. I dag: A8, A6, A7, A10, A11, A9.1, A12; ej på enhet | 2026-11-09 20:52 |
| Oscar (QA) | Opus 5.5 (bekräftat) | high (bekräftat) | – | väntar på kö | O10 klar: K10 appkommandon egna ord 13/20 (0/15 falska), rättelser egna ord 3/20, andra rättelsen behövs inte 15/20, vidgning mellan lägen trasig; K8 14/15; telefonfiltret byter 'omkring 800 000' | 2026-11-09 21:10 |
| Toby (apptest) | Opus 5.5 (claude-opus-5-5, bekräftat) | high | T5 (omtest efter A8 och A11: Frågor, Provläge, långt keyterm, T2 60 min igen) | jobbar | T6 klar: 485/541 kommandon rätt i 5 lägen, 5 falska träffar av 68 ("Lumen" mitt i en mening), 6 fynd till Angela | 2026-11-09 20:05 |
| Kelly (demosida) | Sonnet 5.5 | medium | Ke7 klar med platshållare, väntar på elias-frilagd.png | väntar på bild | Ke7: Elias i hero med ringar, 3 annonser omgjorda, ny OG (alla med platshållare). Lighthouse mobil 99, dator 100 | 2026-11-09 21:20 |
