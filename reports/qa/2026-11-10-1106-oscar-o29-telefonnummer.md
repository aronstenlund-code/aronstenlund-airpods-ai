# Oscar O29: Skyddet mot telefonnummer i svar (D65/K13), offline

Datum: 2026-11-10, 11:04–11:06
Uppgift: stående uppgift (PLAN 2b).
- **Regeln:** modellen får aldrig säga ett telefonnummer ur minnet. Bara 112, 1177 och 114 14 (polisen) går igenom, och de sägs som folk säger dem.
- **Skript:** `scripts/qa/o29_phone_guard_offline.mjs`. Det kör `toSpeech` och `guardPhoneNumbers` i den driftsatta `speechsym.ts`. Kostnad: 0 USD.
- **Rådata:** `reports/qa/data/2026-11-10-1105-o29-phone.json`

**Verified in code.**

## Resultat: 17/22
**Rätt:**
- 0771-, 08-, 070-, +46- och 010-nummer byts mot "numret som står på deras webbplats".
- 112, 1177 och 114 14 sägs rätt.
- "sidan 112", "Telefonen uppfanns 1876", "12 999 kr", "Atomnummer 26", "10 siffror" och "Ring din mormor, hon fyller 85" står kvar som vanliga tal.

**Fel:**
| Modellens text | Uppläst | Problem |
|---|---|---|
| "Bris nås på 116 111." | "hundrasextontusen hundraelva" | "nås på" räknas inte som telefonord, så numret blir ett stort tal. Barnet hör ett nummer som inte går att ringa. |
| "Självmordslinjen nås på 90101." | "nittiotusen hundraett" | samma sak |
| "Skicka sms till 72456 för att skänka." | "sjuttiotvåtusen fyrahundrafemtiosex" | Ett kortnummer utan mellanslag fångas inte, trots att "sms" finns som telefonord. |
| "Swisha till 123 456 78 90." | "hundratjugotretusen fyrahundrafemtiosex sjuttioåtta nittio" | "swisha" räknas inte som telefonord. Ett Swish-nummer ur minnet sägs alltså, om än obegripligt. |
| "Nummer 112 i listan är Kina." | "Nummer ett ett två i listan" | "nummer" ses som telefonord (liten sak) |

**Noterat, räknat som rätt:** "1177.se" blir "elvahundrasjuttiosju.se". En webbadress bör läsas "elva sjuttiosju punkt se".

## Koppling till krisfiltret (O17/O23)
- Kodens krissvar säger "nittio ett noll ett" och "ett ett sex ett ett ett" rätt. Där har Kevin verifierat numren mot källan (K21).
- När modellen själv svarar på en kris, till exempel de 18 fall i O23 som koden missade, får den bara använda 112 och 1177. Prompten tillåter inga fler nummer.
- Skriver modellen ändå Självmordslinjen eller Bris med siffror blir det ett obegripligt stort tal.

## Till Kevin
- Lägg till de verifierade stödnumren i listan över tillåtna nummer:
  - 90101, sägs "nittio ett noll ett";
  - 116 111, sägs "ett ett sex ett ett ett".

  Prompten bör få tillåta dem i krissammanhang (samma källa som `crisis.ts`).
- Lägg till "nås på", "nå", "swish/swisha", "sms:a", "messa" och "skriv till" bland telefonorden (`PHONE_CUE`). Fånga också 5–6 siffror utan mellanslag direkt efter ett telefonord.
- Läs ett tal med domän (".se", ".nu", ".com") som siffror och "punkt".
- Lägg de 22 fallen i testerna: `node --experimental-transform-types scripts/qa/o29_phone_guard_offline.mjs`.

## Kostnad
0 USD.
