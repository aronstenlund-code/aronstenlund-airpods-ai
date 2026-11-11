# Stående uppgift, omgång 10: följdfrågan som citerar förra svaret blev tyst (Kevin, 2026-11-11 13:05)

Fynd: nattens live-eval (`reports/eval/2026-11-11.md`), klocka-01 tur 2: "tyst på en riktig fråga".
- Lumen svarade "Klockan tjugo och tjugo är tjugo över åtta på kvällen."
- Eleven frågade "är det samma som tjugo över åtta på kvällen", och Provläge var tyst.

**Orsak:** ekofiltret (D82) tog bort de fyra ord som upprepade förra svaret. Kvar blev "är det samma som", och det gav tystnad.

**Rättning (`answer/echo.ts`):**
- En ja/nej-ram före det citerade ("är det …", "blir det …", "stämmer det …", "samma som …", "så det är …?") räknas som en följdfråga om citatet. Hela fragmentet behålls, som K27:s "vad menar du med …".
- Ett rent eko ("tjugo över åtta på kvällen") och eko med brus tas fortfarande bort.

**Live (Provläge, driftsatt `4b96ab8`):** 2/2 "Ja, det är samma sak. Klockan tjugo och tjugo … är tjugo över åtta på kvällen …"

**Kostnad:** cirka 0,02 USD. **Tester:** alla gröna (ny i `answer/k_standing7_test.ts`).
