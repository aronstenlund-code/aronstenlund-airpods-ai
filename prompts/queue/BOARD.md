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
| Kevin (backend) | Opus 5.5 (claude-opus-5-5) | high | K8 (färre onödiga begränsningar enligt Oscars O7) → K4 → K5 → K6 | jobbar | K10 klar: appkommandon med egna ord live 28/28, 0 falska av 29; rätta en gång räcker 20/20. K9 klar: 31 kommandofamiljer | 2026-11-09 19:02 |
| Angela (app) | Opus 5.5 (claude-opus-5-5, bekräftat) | low (sessionens inställning) | A12 skärmfynd: koden grön (CI 42661012831), väntar på Tobys skärmrunda 42661012604 för efter-bilder; sedan väntar A3 (K6) och A9.2–3 (K10) | jobbar | A11 klar (Scribe keep-alive, nytt försök 1–30 s, 'Jag hör inte just nu'); A9.1 tips klar; A8/A6/A7/A10 klara, alla gröna i CI, ej på enhet | 2026-11-09 18:26 |
| Oscar (QA) | Opus 5.5 (bekräftat) | high (bekräftat) | – | väntar på kö | O9 klar: K9-kommandon rätt task 90/93, 0/15 falska träffar, 3 matchningsfel till Kevin. O8 klar: Provläge första ljud 2,2 s p50 / 3,2 s p90, 330 pluggtimmar på 100 USD | 2026-11-09 18:29 |
| Toby (apptest) | Opus 5.5 (claude-opus-5-5, bekräftat) | high | T6 (kommandon i simulatorn); T5 väntar på A11 | jobbar | T2: döv i 55 min efter Scribe-fel, minne platt 59 MB. T3: 47/47 skärmar i 5 av 7 lägen, 4 skärmfynd till Angela | 2026-11-09 17:47 |
| Kelly (demosida) | Sonnet 5.5 | medium | – (kön tom) | väntar på kö | Ke6 klar: 3 annonsbilder 1080×1920 (160–200 kB) + skisser, riktiga svar och T3-bilder; Aron väljer | 2026-11-09 19:45 |
