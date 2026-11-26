# K120 (A163, D259): `compress` i /exam för Komprimera, och T50

Kevin (moln), 2026-11-26.

- **Inga riktiga modellanrop** (krediterna är slut till nästa månad, D258) och **0 ElevenLabs**.
- **Tester:** **857/857**.
- **Commit:** bccbe632, deployad av deploy-backend 372.

## Åtgärden
- **Anrop:** `POST /exam {"action":"compress","text":"<≤12 000 tecken>","lang":"sv"|"en"}` ger `{"text":"<kortare>"}`. Det är Angela Fables fältnamn, så appen behöver inte ändras.
- **Prompten** (`SYSTEM_PROMPT_COMPRESS`) ber om ungefär halva längden, med alla fakta, namn, tal och steg kvar och inget tillagt. Ordningen är densamma, och texten skrivs på **textens eget språk**, aldrig översatt. Den ska vara vanliga meningar att lyssna på, utan rubriker, listor eller markdown.
  - `lang` behövs inte för språket, men den tas emot som i övriga anrop och styr felmeddelandena.
- **Svaret städas** (`cleanCompressed`): en inledning som "Här är den kortare texten:", markdown och omslutande citattecken tas bort.
- **Fel:**
  - Tom text, eller längre än 12 000 tecken: 400 `invalid_request`, utan modellanrop.
  - Tomt svar från modellen: 502 `provider_error`.
  - Modellens fel: `provider_*` med `fallback: true`, som övriga åtgärder (O97).
  - Appen låter telefonens modell ta över vid `provider_*`.
- **Kostnad som för de andra modellåtgärderna:**
  - Samma gräns som /exam, med vikten 2.
  - Modellkostnaden loggas som `exam-compress` i användningen.
  - Inga användarkrediter dras, eftersom de gäller ljud och dras när det sparas.
  - Max tokens är cirka en tredjedel av textens tecken plus 200, högst 4 000.
- **Verifierat i test** (`exam/k120_compress_test.ts`, låtsasmodell): kortare text, en prompt som behåller språket, städningen, 400 utan anrop, 503 `provider_quota`, och 502 för tomt svar. LIVE

## T50 (rad 331)
- **Gäller inte längre.** Jag svarade Toby den 18 november, och han har kvitterat i sin kö: "T50 klar sedan 18/11".
- **K100** gjorde Säg till ett anrop (median 1,4 s live).
- **Angela Fable** rättade raden så att den inte skyller på nätet när servern är långsam (`reports/2026-11-18-0735-angela-fable-t50-langsam-server.md`).
- Bara bocken i min kö saknades, och nu är den satt.

## Kvar
- Prompten har inte provats mot en riktig modell, eftersom krediterna är slut. Det görs när de fylls på, med en svensk och en engelsk text och en koll av längd och språk.
