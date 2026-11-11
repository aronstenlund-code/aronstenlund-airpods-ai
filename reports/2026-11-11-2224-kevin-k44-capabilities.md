# K44: Earmind vet vad den heter och vad den kan (Kevin, 2026-11-11 22:24), DELRAPPORT

**Status:** koden är klar och pushad (`1d5237a`, `e3fedc0`), men **den är inte driftsatt.**
- Alla GitHub Actions-körningar har stått i kö sedan 21:24: Deploy backend och iOS build.
- GitHubs statussida säger "All Systems Operational".
- Troligast är att kontots Actions-minuter eller utgiftsgräns är slut. Jag kan inte se faktureringen från sessionen.
- Livetestet mot den **gamla** koden (före K44) gav dessa svar, och det är grundmätningen:
  - "Kan du sätta en timer?": "Jag kan inte sätta timers".
  - "Kan du ringa folk?": "Jag är en studieassistent".
  - 18 av 30 "kan du …?" var fel.

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
- **GitHub Actions står stilla,** så ingen backend-driftsättning eller iOS-bygge sker. Se efter på github.com → ditt konto eller organisationen `aronstenlund-code` → Settings → Billing and plans → Actions: är minuterna eller utgiftsgränsen slut?
- När kön släpper driftsätts K44 automatiskt. Jag kör livetestet då.
