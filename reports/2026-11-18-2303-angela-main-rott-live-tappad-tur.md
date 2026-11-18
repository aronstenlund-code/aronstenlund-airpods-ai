# Main rött efter A151: ett yttrande tappades bort i live-lägena (inte A151)

Angela Schrute (moln, Fable 5.2), 2026-11-18 20:30–23:03. Main, sammanslagning eaa7279f. 0 ElevenLabs.

## 1. Vad som hände
iOS build 44374756678 på main (25b5551c) föll i ett test: `CalibrationFlowTests.askingForMoreShowsAndSpeaksAllThisTimeOnly`.
Testet säger "Lumen, ge mig tre pickup lines" i Socialt läge, väntar på de tre förslagen och låter sedan den andra
personen säga något. Då ska ett nytt förslag begäras. Det begärdes aldrig (`requests.count == 2` gick ut efter 3 s).

## 2. Orsaken
**Det är inte A151.** Söktonen och `searching` körs inte i live-lägena, och samma test var grönt på båda A151-byggena
(44358091800 avbröts, 44363314542 grönt på 0,09 s) och på grenen med Kellys småsaker (44369553887).

Felet är en kapplöpning i `LiveModeController`, som har funnits sedan D72:
1. "Ge mig tre" skickas som en instruktion. Servern svarar med de tre förslagen och strax därefter `done`.
2. Tar den andra personens yttrande slut **mellan förslagen och `done`**, får det vänta tills instruktionen är klar.
3. När `done` kom ströks allt som väntade, eftersom instruktionen själv hade gett förslag ("inget ersätter dem
   genast"). Regeln var tänkt för förslag som begärdes *före* instruktionen. Yttrandet som kom efter de tre
   förslagen ströks också, och den andra personens replik fick aldrig något förslag.

I testet kommer `done` nästan alltid före talet, och då syns inget. På en långsam byggmaskin kom `done` efter, och
testet föll. I appen är fönstret kort (tiden mellan förslagen och `done`), men felet är verkligt: en replik kan bli
utan förslag.

**Säkerhet i slutsatsen:** mekanismen följer av koden och visas av ett nytt test som håller kvar `done` tills testet
släpper den; med rättningen går det igenom (44381782850). **Att testet faller utan rättningen är inte visat i CI än:**
bygget på grenen med bara testet (`angela/live-tappad-tur-test`, 44381834053) fick ingen byggmaskin på 20 minuter
och avbröts av GitHub; det är omstartat och resultatet skrivs som tillägg här. Att just detta hände i 44374756678 är en slutsats av att felbilden är exakt densamma (allt före går igenom,
den andra begäran kommer aldrig); bygget har ingen applogg som visar det direkt.

## 3. Rättningen
`LiveModeController` skiljer nu på det som väntade *innan* instruktionens förslag kom (stryks som förut) och ett
yttrande som tog slut *efter* att de visades (begärs när instruktionen är klar). En ny flagga, `deferredIsNews`, och
tre rader. Inget annat beteende är ändrat.

## 4. Tester
- **Nytt, ska falla utan rättningen (inte visat i CI än, se §2):** `aTurnBetweenTheSuggestionsAndDoneGetsItsSuggestion`. Svaret är styrt av testet
  (`HeldProvider`): förslagen kommer, `done` hålls kvar, den andra personen talar, `done` släpps. Då ska en vanlig
  begäran om ett förslag gå iväg och de tre ersättas av ett.
- **Nytt, vakt för det oförändrade:** `aTurnBeforeTheThreeCameIsNotAskedForAfterThem`. Ett yttrande som tog slut
  innan de tre kom begärs inte efteråt.
- **Det gamla testet** är oförändrat och beror inte längre på vilken av `done` och talet som kommer först.
- **CI:** iOS build 44381782850 grön på grenen (3f8c7811): alla tre testerna i `CalibrationFlowTests` som rör detta gick igenom, liksom `A148AccessibilityTests` och `A151SearchToneTests`. Bygget på main efter sammanslagningen är 44407721919 och körde när rapporten skrevs. Main-bygget dessförinnan (44382692902, utan rättningen) var grönt, vilket visar att felet är tidsberoende. **Verifierat i CI, inte på enhet.**

## 5. Också i sammanslagningen: Kellys två småsaker (Ke79, omgång 5)
- VoiceOver säger klockans minuter: 7:07 är "7 minuter kvar", sista minuten "under en minut kvar".
- De två rader jag slog ihop till en VoiceOver-mening (tryckraden i spelarna, raden på kortet som spelar) är märkta
  som text. Granskningsomgång 6 (44369572808, grenarna `angela/a11y-a148-6-17pro` och `-se-ax5`): fyndet "för liten tryckyta" är borta i alla fem scenerna (5 → 0). **Verifierat i Simulatorns granskning.**

## 6. Kvar
- Tobys T54 för 7b och 7c, och Arons prov av lyssnarlägena (A149 är inte ihopslagen).
- A151 är otestad på enhet.
