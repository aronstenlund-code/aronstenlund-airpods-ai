# A72 – Frågan som väntar 13–29 s, och mikrofonen stängd efter svar (Tobys T14 fynd 1–3), del 1

Angela, 2026-11-11. Kö: `prompts/queue/angela.md` A72 (Deangelo).

## Vad som är gjort
1. **Övre gräns (krav 1).**
   - En fråga som väntar i frågetimern skickas senast **3 s efter att Lumens röst tystnat**, oavsett om ett svar
     fortfarande strömmar (`lumenIsBusyAnswering`).
   - "Tyst" betyder att spelaren inte spelar och att inget tal väntar på att läsas upp.
   - Loggraden är "A question waited 3 s after Lumen went quiet: asked now (A72) · <orsak>". Orsaken kommer från A70.
   - Strömmade ett svar fortfarande avbryts det, och den nya frågan får sitt svar.
2. **Mätning av mikrofonens stängning (krav 2).** Varje gång igenkänningen öppnas efter Lumens tal loggas det här:
   - hur långt efter sista meningens början rösten sa att den var klar;
   - hur länge spelaren därefter fortfarande spelade;
   - ekosvansen (0,7 s).

   Loggraden är "Recogniser reopens: voice done X ms after its last sentence began, player quiet Y ms later, + 700 ms
   tail (A72)".

## Varför del 2 inte är ändrad än
- `onFinished` kommer när rösten har lämnat ifrån sig kön, men `speak()` kan returnera innan ljudet har spelats klart.
  Därför väntar appen på spelarens flagga, i högst 30 s.
- Att korta den väntan utan mätdata kan ge eko, alltså att Lumen hör sig själv. Kravet är noll eko.
- Tobys T15 visar med A72-raden om sekunderna går åt till att spelaren spelar på, till ett sent `onFinished` eller till
  säkerhetsspärren. Då rättas villkoret i del 2.

## Testresultat
- **iOS-bygge och enhetstester:** CI 43076491531 (9791ce0, A72 och A74) är **grön**: device-bygget, alla enhetstester och `Lumen-unsigned.ipa`.
- **Ej verifierat:** Toby mäter i T15 och T15b. Kravet är att 0 av 10 frågor väntar över 4 s och att inget eko blir
  en fråga.

## Nästa
- Läs A70- och A72-raderna i T15 och rätta villkoren i del 2.
