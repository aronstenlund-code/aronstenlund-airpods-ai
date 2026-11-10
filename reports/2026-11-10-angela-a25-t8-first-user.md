# A25 – Tobys T8-fynd: förstagångsanvändaren (Angela, 2026-11-10)

Underlag: `reports/apptest/2026-11-10-0830-toby-t8-forstagangsanvandaren.md`. Fynd från test går först (PLAN 2). T8
kördes på koden före A18 och A22, så flera fynd var redan rättade. **Inget provat på telefon.**

| Fynd | Läge |
|---|---|
| 1. "Startar …" i 60 s efter mikrofonfrågan (3/3) | **Rättat (untested assumption om orsaken).** Gissningen är att sessionen startades medan iOS-dialogen fortfarande höll appen inaktiv, så att aktiveringen misslyckades och ingen försökte igen. Nu väntar `FirstStartView.startListening` på förgrunden (`waitForForeground`) innan lyssningen startar. Lyssnar den inte efter 3 s startas den en gång till, och det loggas ("First start: not listening 3 s after …"). Verifieras med T8b och Arons nyinstallation. |
| 2. "Fortsätt" gjorde ingenting en gång (1/3) | Inte återskapat. Före svaret heter knappen nu "Hoppa över" (A18). T8b får visa om det står kvar. |
| 3. NO och Biologi förvalda i provsteget | **Rättat i A22.** Första starten har inget förval, och "Spara prov" är grå tills ett ämne är valt. |
| 4. "Spara prov" täcker datumraden | **Rättat i A22.** Datum och årskurs är två rader högt upp, ovanför knappen. |
| 5. Provläge utan prov frågar 5 saker | **Inte ändrat.** Det är beslutet D83 ("frågorna kommer först, en gång"). Toby har skickat det till Kelly som design. Ändras D83 (till exempel så att Provläge startar direkt och Lumen frågar en sak åt gången med rösten), är det en ny punkt. |
| 6. Två vägar till Provläge på Start | **Rättat i A18/A23.** Den runda Provläge-knappen är borta. "Förhör mig" och "Få A-svar till provet" har var sin förklarande rad (D97). |
| 7. Delningsfrågan direkt efter första starten | **Ägarbeslut** (D57 säger "i onboarding"). Det står i A18:s Till Aron. |
| 8. Tre instruktioner samtidigt i Provläge | **Rättat i A18.** Lyssnar har en kommandorad, ingen fast instruktionstext, och "Förhör mig" som enda blå knapp. Ämnesorden står kvar, som i Kellys skiss. |
| 9. Olika rubriker på Start ("Andra lägen" / "Eller börja direkt") | **Rättat i A18.** Rubriken är borta, och raden "Bara fråga" + "Fler lägen" är densamma med och utan prov. |

## Till Toby
- T8b: kör om `apptest-firstuser` när ElevenLabs-kvoten är påfylld. Nya knappord: "Hoppa över" (före svaret),
  "Har du prov snart?", "Inte nu", "Förhör mig", "Få A-svar till provet", "Bara fråga", "Fler lägen".

## Till Aron
- Radera Lumen, installera igen, tryck "Testa nu" och "Tillåt". Blir det "Lyssnar" inom några sekunder?

## CI
Grönt i CI: iOS build 42779504798 (`090acca`). Bygget för enhet räknar varningar som fel, och alla LumenTests är gröna.
