# K44: Earmind vet vad den heter och vad den kan (Kevin, 2026-11-11 22:24), slutrapport 23:20

**Status: klar och driftsatt** (`b1e9305` 23:16, `8d91f5a`). GitHub Actions stod i kö 21:24–23:15 och släppte sedan av sig själv. Två gamla körningar (`1d5237a` och `e3fedc0`) listas fortfarande som "queued", men API:et säger att de är avslutade och inte kan avbrytas.

## Live (`scripts/k44-live.py`, Standardläge, rådata `reports/eval/2026-11-11-2317-k44-live.json`)
| Grupp | Före K44 (gammal kod) | Efter K44 |
|---|---|---|
| 30 "kan du …?" för funktioner som finns | 12/30 ("Jag kan inte sätta timers", "Jag är en studieassistent") | **30/30** |
| 10 för funktioner som inte finns | – | 8/10. Efter `8d91f5a` (mönster med "ett/en") är "kan du skicka ett mejl" och "kan du ta en bild" ett ärligt nej live |
| Identitet ("Vad är Earmind?", "Vad kan du göra?" …) | "en studieassistent" | **6/6** |
| Hjälp ("Hur stänger jag av dig?" …) | tyst | **5/5** |
| "studieassistent" i något svar | ja | **0** |
| "Lumen, kan du sätta en timer på tio minuter" med `tools_available` | – | **verktygsanrop** (`timer_start`), live |

- **Regression:** 90,5 % (`b1e9305`).
- **Kostnad:** cirka 0,2 USD.

## Gjort i koden
1. **`Shared/capabilities.json`** är den enda listan.
   - **Innehåll:**
     - Varje funktion har id (samma som i appens `CapabilitiesView`), grupp, namn, exempelfras (`say`), status (`finns`/`kommer`), vilken tillåtelse som krävs, verktyg, och ord för "kan du …?".
     - `not_yet` listar ärliga nej: sms, mejl, betala, bilder, lampor …
     - `help` innehåller hjälptexter för stänga av, pausa, byta läge, byta röst, starta och volym.
   - **Servern läser en kopia,** `backend/supabase/functions/_shared/capabilities.json`, eftersom funktionerna driftsätts från `backend/`. `_shared/capabilities_test.ts` slår fel om kopian skiljer sig från originalet. **Ändra i `Shared/` och kopiera sedan filen.**
2. **`context.capabilities`:** appen skickar de tillåtelser som är givna på telefonen: `calendar`, `reminders`, `alarms`, `contacts`.
3. **I kod, utan modellanrop:**
   - **"kan du …?" om en funktion som finns:** "Ja. Säg till exempel: Lumen, sätt en timer på 10 minuter."
   - **Om tillåtelsen saknas:** "Ja, men du behöver tillåta larm och timer i appen först. Sedan säger du …"
   - **Om funktionen kommer snart:** "Det kommer snart."
   - **Om något på listan över ärliga nej:** "Nej, det kan jag inte än. Jag kan …"
   - **"Vad kan du göra?":** en översikt från listan.
   - **"Vad är Earmind?":** "Earmind är en AI-agent i dina AirPods för vardag, skola och jobb …"
   - **"Hur stänger jag av dig?" och andra hjälpfrågor:** hjälptexten.
   - **Självsvaren** säger nu "AI-agent" i stället för "AI-assistent".
4. **Systemprompten:**
   - Säger att Earmind är en AI-agent för vardag, skola och jobb och aldrig ska kalla sig "studieassistent".
   - Innehåller listan över funktioner som finns, med en markering där tillåtelse behövs, och vad som kommer.
   - Earmind ska aldrig säga "jag kan inte" om något som står på listan.
5. **En konkret begäran** blir ett verktygsanrop, inte ett textsvar. Det gäller begäran med väckningsordet (eller i tryck-och-prata) när verktyget finns på telefonen, till exempel "Lumen, kan du sätta en timer på tio minuter".
6. **Riktiga frågor och begäran** går fortfarande till modellen: "kan du förklara fotosyntes", "kan du översätta fjäril …", "kan du ge mig ett träningspass".

## Tester
- `deno task test`: **502 gröna** (`_shared/capabilities_test.ts`, `k42_test.ts` K44). `check` är ren.
- **Live:** inte möjligt förrän koden är driftsatt.
- **Skript:** `scripts/k44-live.py` testar 30 "kan du …?" för funktioner som finns, 10 för sådant som inte finns, 6 identitetsfrågor och 5 hjälpfrågor. Det räknar också hur ofta "studieassistent" förekommer.

## Till Angela (A77)
- `CapabilitiesView` kan läsa `Shared/capabilities.json`. Id:na är desamma som i dag.
- Skicka `context.capabilities` med `/answer`.

## Till Aron
- GitHub Actions stod stilla 21:24–23:15 och har nu släppt av sig själv. Om det händer igen: se efter på github.com → ditt konto eller organisationen `aronstenlund-code` → Settings → Billing and plans → Actions.
