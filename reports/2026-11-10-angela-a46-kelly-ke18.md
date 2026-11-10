# A46 – Kellys fynd i Ke18 efter A30 (Angela, 2026-11-10)

Det här är en stående uppgift enligt `docs/PLAN.md` 2b och har en egen punkt i kön. Underlaget är
`reports/2026-11-10-1249-kelly-granskning-a30-ke18.md`, avsnittet "Nya fynd", där alla fynd är mindre. **Ändringarna är kod och
simulatorbilder. Inget är provat på telefon.**

| # | Kellys fynd | Vad som gjordes |
|---|---|---|
| 1 | `addExamFirst` visar "Startar …" | Skärmbildsscenen visar nu "Säg till exempel" och lyssnande ringar. Det styrs av `screenshotShows` och gäller bara Debug. |
| 2 | Ämnena är rundade rutor | Ämnena (`Chip`) är nu helt runda (`Capsule`), enligt SYSTEM.md §3. Det gäller alla ämnesval i appen. |
| 3 | "Säg ”Lumen, förhör mig”" står längst ner på Lyssnar | Raden är borta, och bara länken "Kommandon" finns kvar (SYSTEM.md §4). Övningsprovet och det tysta förhöret säger vad man gör under brickan, som förut. |
| 4 | Demofrågorna blandar ämnen | Övningsprovets demofrågor handlar nu om biologi: fotosyntes, cellandning och kolets kretslopp. |
| 5 | Två iPhone-röster ser likadana ut | Röstsidan visar en enda iPhone-röst, "iPhonens röst – Fungerar utan nät". Saga och Max beskrivs när `/voices` får beskrivningar (Kevin, se A26). |
| 6 | "Lägg till prov" har fortfarande 19 val | **Inte ändrat.** Kelly tog bara med det gamla fyndet för att det inte skulle tappas bort. Det kan bli en egen punkt: "Lägg till prov" från Start kan använda samma snabbform som första starten (rösten först och "Skriv i stället"). |

## Bilder
Bilderna från iPhone 17 Pro ligger i `reports/2026-11-10-a46-skarmbilder/` (körning 42830169882). "Har du prov snart?" visar
"Säg till exempel", lyssnande ringar och "Skriv i stället" (A33).

## CI
Grönt i CI: iOS build 42830170108 (`ed4bbdb`). Bygget för enhet räknar varningar som fel, och alla LumenTests är gröna.
