# Tavla: vem gör vad

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
| Kevin (backend) | Opus 5.5 (claude-opus-5-5) | high | K16 → K12 → K13 → K15 → K17 → K18 → K19 → K4 → K5 → K6 | klar med K14, tar K16 | K14 klar: v4 Turbo standard i app och demo, Flash reserv, samma krediter (42/209 tecken), första ljud p50 268 ms. K11: 0/10 över 8 s | 2026-11-09 23:40 |
| Angela (app) | Opus 5.5 (claude-opus-5-5, bekräftat) | low (sessionens inställning) | – (A16 väntar på K15, A3 på K6, A15-cache på K13) | väntar på kö | A17, A15, A13 klara, grönt i CI 42698361876/42701351863: 'igen' exakt med tidsregler, 'Mer?' efter korta svar, ny inställningsordning + nivåmätare; ej på enhet | 2026-11-09 22:35 | ? |
| Oscar (QA) | Opus 5.5 (bekräftat) | high (bekräftat) | – | väntar: O12 på Kevins K14.1 (/tts-vitlista), O11 på K13 | O10 klar: K10 appkommandon egna ord 13/20, rättelser egna ord 3/20, andra rättelsen behövs inte 15/20; K8 14/15 | 2026-11-09 21:40 | ? |
| Toby (apptest) | Opus 5.5 (claude-opus-5-5, bekräftat) | high | Väntar på kö: T7 väntar på Angelas A15 | väntar | T5 klar: Frågor 9/10 upplästa, Provläge 1 av 4 turer, långa keyterms håller, 60 min 117/117 hörda och 0 döva perioder, 4 fynd till Angela | 2026-11-09 21:55 | ? |
| Kelly (demosida) | Sonnet 5.5 | medium | – (kön tom) | väntar på kö | Ke8 klar: Elias i kort (bild 49–65 överhoppade, toning 47→67), ny sektion med tre röstbudskap + T3-bilder. site 1,77 MB, Lighthouse 100 lokalt. 'nästa' i övningsprov utelämnat (A16 ej byggt) | 2026-11-09 22:17 | ? |
