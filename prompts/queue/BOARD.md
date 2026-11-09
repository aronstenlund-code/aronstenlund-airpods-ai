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
| Angela (app) | Opus 5.5 (ej bekräftat) | high | A8 klar? → A11 blocker (döv men "Lyssnar") → A6/A7 | jobbar | A8: Frågor svarar, Provläge delar upp turer, keyterms ≤ 20 tecken. A6/A7 under arbete (CI) | 2026-11-09 17:23 |
| Oscar (QA) | Opus 5.5 | high | O5 (förhör mig 6 i rad + omtest av O1-fynd A–E mot K7) | jobbar | O6 klar: tyst rum 84 % räcker, prat bryter slut-på-tur. O7 klar: 53/60 hjälpte, 10/10 skydd höll | 2026-11-09 17:45 |
| Toby (apptest) | Opus 5.5 | medium | T5 väntar på A8 (pågår) och A11; T6 väntar på A7 | väntar på kö | T2: döv i 55 min efter Scribe-fel, minne platt 59 MB. T3: 47/47 skärmar i 5 av 7 lägen, 4 skärmfynd till Angela | 2026-11-09 17:35 |
| Kelly (demosida) | Sonnet 5.5 | medium | – (kön tom) | väntar på kö | Ke3 klar: 3 steg med riktiga T3-skärmbilder (ljust/mörkt), CSS-animation, FAQ-data, sitemap. index.html 68 kB + bilder 57 kB, Lighthouse ej körd | 2026-11-09 18:10 |
