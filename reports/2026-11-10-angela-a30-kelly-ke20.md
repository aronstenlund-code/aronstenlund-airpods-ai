# A30 – Kellys Ke20-fynd efter A26, och bilderna till sidan (Angela, 2026-11-10)

Stående uppgift enligt `docs/PLAN.md` 2b, som egen punkt i kön. Underlaget är `reports/2026-11-10-1133-kelly-granskning-a26.md`,
där A26 är godkänd och R1–R6 stängda. **Allt är kod och simulatorbilder. Inget är provat på telefon.**

| # | Kellys fynd | Vad som gjordes |
|---|---|---|
| 1 | Övningsprovet visar ingen lyssnarbricka | I appen ligger övningsprovet på Lyssnar, där brickan redan finns. Skärmbilden visade bara korten. Scenen `practice` visar nu hela Lyssnar i Provläge med brickan "Lyssnar" och frågekortet. Scenen `practiceResult` visar resultatkortet. |
| 2 | "Klar" på resultatkortet | Heter nu "Stäng" ("klar" är ett röstord, D72). |
| 3 | "Lumen sparar aldrig ljud" på Första frågan | Heter nu "Ljud sparas inte.", samma ord som i introt. |
| 4 | Ingen ✓ på röstsidan medan rösterna hämtas | Den valda rösten är alltid en rad med ✓, också innan listan från `/voices` har kommit. |
| 5 | Loggan | Ingen åtgärd. Den väntar på Arons val. |

## Bilder till sidan (Ke18)
Det finns fyra nya scener i `screenshots.yml`:
- `listeningProv`: Lyssnar i Provläge med brickan "Lyssnar";
- `practice`;
- `practiceResult`;
- `addExamFirst`: "Har du prov snart?" från första starten (A22).

Scenerna visar Lyssnar som när appen lyssnar, utan mikrofon. Det styrs av `ListeningModel.screenshotShows`, som finns
bara i Debug-byggen. Release-appen påverkas inte. Introbilden för SE i ljust läge tas om i samma körning.

## CI
Se slutet av rapporten när körningen är klar.
