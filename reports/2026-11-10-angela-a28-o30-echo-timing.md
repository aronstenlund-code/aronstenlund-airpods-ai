# A28 – Oscars O30 i appen: eko räknas efter tiden (Angela, 2026-11-10)

Det här är en stående uppgift enligt `docs/PLAN.md` 2b och har en egen punkt i kön. Underlaget är
`reports/qa/2026-11-10-1108-oscar-o30-ekofilter.md`, avsnittet "Bättre på sikt (Angela)". **Ändringen är kod och
enhetstester. Inget är provat på telefon.**

## Problemet
Appens ekofilter (`EchoFilter`, D82) bedömer bara orden. En tur räknas som Lumens eget eko om minst 60 % av orden finns i
det Lumen har sagt de senaste 30 sekunderna. Då försvinner hela turen.

Det slår mot elever som upprepar svaret för att kontrollera det. Ett exempel är "så fotosyntesen omvandlar ljusenergi
till kemisk energi?". Där kommer 6 av 7 ord från svaret, så frågan försvann helt i appen redan innan servern fick den.
Oscar visade samma risk på servern (`stripEcho`).

## Vad som gjordes
Nu måste två saker gälla för att en tur ska räknas som eko:
- orden överlappar som förut;
- turen eller segmentet började medan Lumen talade, överlappade uppläsningen eller började senast 1,5 s efter att
  Lumen slutade.

Det som börjar senare är eleven, och det loggas som "Not echo: … said after Lumen stopped (A28)". Tiden "Lumen slutade"
sätts när mikrofonen öppnas igen, alltså efter `echoTail` på 0,7 s.

**Ändrade delar:**
- `EchoFilter.mayBeEcho` är ny och ren (pure);
- `ListeningModel.isOwnEcho` får turens eller segmentets starttid;
- `ownSpeechEndedAt` och `turnStartedAt` är nya fält i `ListeningModel`.

## Tester
- `LumenTests/A28Tests.swift`:
  - eko är möjligt under uppläsningen och inom 1,5 s efter;
  - 3 s efter är det eleven;
  - har Lumen aldrig talat är det inget eko;
  - Oscars kontrollfråga räknas som eko på orden ensamma, och det är skälet till att tiden behövs.
- `EchoFlowTests` finns kvar: igenkänningen som hör Lumens svar medan svaret pågår filtreras fortfarande bort.

## Till Kevin
Kevins K27 (`8e7ced4`) rättade samma sak på servern samtidigt: frågan behålls och det citerade märks (O30 12/12). Appen och
servern släpper nu båda igenom en följdfråga som citerar svaret.

## Kända begränsningar
- **Untested assumption:** att 1,5 s efter att mikrofonen öppnats räcker för rummets efterklang när ljudet går ut ur
  iPhonens högtalare. Med AirPods hörs Lumen aldrig i mikrofonen (D82).

## CI
Grönt i CI: iOS build 42807652449 (`2115a3d`, med A28, A29 och A30). Bygget för enhet räknar varningar som fel, och alla LumenTests är gröna. Körningen 42803935391 (`2ad2e36`) föll bara på A29:s första test. A28:s tester var gröna redan där.
