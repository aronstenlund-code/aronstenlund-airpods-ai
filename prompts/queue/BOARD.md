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
| Kevin (backend) | Opus 5.5 (claude-opus-5-5) | high | K9: regeltabell för "Lumen, …" → task (30 uttrycksfamiljer klara i kod, kopplas in i /answer; regler från "i framtiden ska du …") → K10 → K8 | jobbar | K7 klar: nivån sägs aldrig (0/8), åk 8 = gymnasiet (10/10 mot 10/10), logik 6/6 med tänkande. K2 klar: Provläge på Sonnet, 91,6 % av 191 räcker | 2026-11-09 17:46 |
| Angela (app) | Opus 5.5 (claude-opus-5-5, bekräftat) | low (sessionens inställning) | A11 blocker: Scribe keep-alive + nytt försök 1–30 s + 'Jag hör inte just nu' i stället för Lyssnar, i CI nu → A12 → A9 | jobbar | A10 klar (grön i CI 42657618728). A11-orsak hittad: när VAD:n håller tystnad får Scribe inget ljud och stänger efter ~20 s; inget nytt försök efter att reserven föll | 2026-11-09 18:02 |
| Oscar (QA) | Opus 5.5 (bekräftat) | high (bekräftat) | – | väntar på kö | O5 klar: förhör mig 6/6 utan upprepning, nivån sägs aldrig (0/4), C/D delvis kvar, 1 Provläge-anrop hängde > 90 s; 0,30 USD (budget 0,15) | 2026-11-09 17:54 |
| Toby (apptest) | Opus 5.5 (claude-opus-5-5, bekräftat) | high | T6 (kommandon i simulatorn); T5 väntar på A11 | jobbar | T2: döv i 55 min efter Scribe-fel, minne platt 59 MB. T3: 47/47 skärmar i 5 av 7 lägen, 4 skärmfynd till Angela | 2026-11-09 17:47 |
| Kelly (demosida) | Sonnet 5.5 | medium | – (kön tom) | väntar på kö | Ke3 klar: 3 steg med riktiga T3-skärmbilder (ljust/mörkt), CSS-animation, FAQ-data, sitemap. index.html 68 kB + bilder 57 kB, Lighthouse ej körd | 2026-11-09 18:10 |
