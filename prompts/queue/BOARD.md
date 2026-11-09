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
| Kevin (backend) | Opus 5.5 (claude-opus-5-5) | high | K11 (anrop som hänger, stump, citat) → K12 → K14 → K13 → K4 → K5 → K6 | tar K11 | K8 klar: onödiga avslag 2/60 → 1/64 (pris i Auto kvar), 10/10 begränsade höll | 2026-11-09 21:50 |
| Angela (app) | Opus 5.5 (claude-opus-5-5, bekräftat) | low (sessionens inställning) | A17 'igen' upprepar exakt med tidsregler → A15 → A13 (skärmbilder tas) → A16 (väntar på K15), A3 (K6) | jobbar | A9 och A14 klara (grönt i CI 42690189387); A13-koden grön (42693453845), efter-bilder i arbete | 2026-11-09 21:59 |
| Oscar (QA) | Opus 5.5 (bekräftat) | high (bekräftat) | – | väntar: O12 på Kevins K14.1 (/tts-vitlista), O11 på K13 | O10 klar: K10 appkommandon egna ord 13/20, rättelser egna ord 3/20, andra rättelsen behövs inte 15/20; K8 14/15 | 2026-11-09 21:40 |
| Toby (apptest) | Opus 5.5 (claude-opus-5-5, bekräftat) | high | Väntar på kö: T7 väntar på Angelas A15 | väntar | T5 klar: Frågor 9/10 upplästa, Provläge 1 av 4 turer, långa keyterms håller, 60 min 117/117 hörda och 0 döva perioder, 4 fynd till Angela | 2026-11-09 21:55 |
| Kelly (demosida) | Sonnet 5.5 | medium | Ke8 (hero i kort, tydligare budskap) | jobbar | Ke7 klar: scrollstyrd Elias-hero (120 bilder, lerp, vilobilder, ringar), 3 annonser + OG med riktiga bilden. Lighthouse 100 på alla lokalt. Safari/iPhone ej provad | 2026-11-09 22:15 |
