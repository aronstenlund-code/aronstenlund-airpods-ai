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

## Del 2, efter Tobys T15 (`reports/apptest/2026-11-11-1930-toby-t15-vantande-fragan.md`)
- **Orsaken** (verifierat i T15-loggen och koden):
  - En hållen halv fråga, och en sammanslagen fortsättning som fortfarande ser ofärdig ut, sköts fram med 1,5 s varje
    gång Scribe skickade obekräftade ord (`speechContinues`). Det fanns inget tak.
  - Med den lokala VAD:n och bärarfokus framför Scribe kom sådana ord hela tiden, så frågan förföll aldrig. Frågetimern
    planerade om utan att logga, och därför kom A70-raden aldrig.
  - Frågan gick först när Scribe stängde sessionen, efter 14–26 s.
- **Rättat:** en hållen fråga skickas senast **6 s** efter att den hördes. Efter en sammanslagen fortsättning skickas
  den senast **1,5 s** efter fortsättningens final, som Toby föreslog. `PendingQuestion.latestDue` gäller både vid
  sammanslagningen och i `speechContinues`.
- **Mikrofonen** (krav 2): T15 mätte 0,6–0,8 s från att rösten tystnat till att igenkänningen öppnas, 9 av 9 gånger.
  Det är ekosvansen. T14:s 12–15 s var rösten som fortfarande talade, så del 2 av kravet är uppfyllt i simulatorn
  utan ändring. **Ej verifierat på enhet.**
- **Tester:** `LumenTests/A72Tests.swift` har 2 tester: ord som aldrig tar slut, och en fortsättning som skickas
  strax efter.
- **iOS-bygge och enhetstester:** CI RESULT72B.
- **Toby:** kör T15b. Kravet är att 0 av 10 frågor väntar över 4 s.
