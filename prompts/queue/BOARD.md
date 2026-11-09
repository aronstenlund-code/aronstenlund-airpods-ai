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
| Kevin (backend) | Opus 5.5 (claude-opus-5-5) | high | K10 (app_command med egna ord, rättelser blir inställningar med räckvidd, profil) → K8 | jobbar | K9 klar: 31 kommandofamiljer → task i /answer, regler från "i framtiden ska du …"; live-eval 52/57 rena (4 bara långsamma, 1 rättad efteråt), 6/6 negativa rätt | 2026-11-09 18:12 |
| Angela (app) | Opus 5.5 (claude-opus-5-5, bekräftat) | low (sessionens inställning) | A12 skärmfynd: koden grön (CI 42661012831), väntar på Tobys skärmrunda 42661012604 för efter-bilder; sedan väntar A3 (K6) och A9.2–3 (K10) | jobbar | A11 klar (Scribe keep-alive, nytt försök 1–30 s, 'Jag hör inte just nu'); A9.1 tips klar; A8/A6/A7/A10 klara, alla gröna i CI, ej på enhet | 2026-11-09 18:26 |
| Oscar (QA) | Opus 5.5 (bekräftat) | high (bekräftat) | O9 (oberoende test av K9-kommandon) | jobbar | O8 klar: Provläge första ljud 2,2 s p50 / 3,2 s p90, 1/45 över 5 s (textuppgift 7,0 s), hänget ej återskapat; 0,30 USD/pluggtimme = 330 h på 100 USD | 2026-11-09 18:24 |
| Toby (apptest) | Opus 5.5 (claude-opus-5-5, bekräftat) | high | T6 (kommandon i simulatorn); T5 väntar på A11 | jobbar | T2: döv i 55 min efter Scribe-fel, minne platt 59 MB. T3: 47/47 skärmar i 5 av 7 lägen, 4 skärmfynd till Angela | 2026-11-09 17:47 |
| Kelly (demosida) | Sonnet 5.5 | medium | – (kön tom) | väntar på kö | Ke4 klar: Lighthouse lokalt mobil 99/100/100/100, dator 100 på alla; FAQ-data giltig JSON, og.png 1200×630. Rich Results live ej provad | 2026-11-09 18:45 |
