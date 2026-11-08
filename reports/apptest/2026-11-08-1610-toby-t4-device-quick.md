# T4 – Snabbtest på telefon för Aron (Toby, 2026-11-08 16:10)

## Vad som gjordes
`docs/DEVICE-TEST-QUICK.md`: ett schema på högst 15 minuter för det som bara går att testa på riktig iPhone +
AirPods: eko i högtalaren (2 min), röstbyte av läge (1 min) och Provläge i 10 minuter (12 min med start och
avslut). Nick, skakning, AirPods-knappen och låsskärmen testas **under** Provläget, så att de ryms i 15 minuter.
Varje steg har vad Aron gör, vad som ska hända och vad han skickar tillbaka (J/N per rad, en skärmbild från
låsskärmen och de tre filerna från *Spela in plugg-session*, D87).

## Tekniska detaljer
- Stegen följer etiketterna i koden på `main` 2026-11-08 (`HomeView`, `ListeningScreen`, `StudyOnboardingView`,
  `StudyRecording`, `DiagnosticsView`): **verified in docs** (läst i källkoden), inte i appen.
- Plugg-sessionen kräver att mikrofonen redan lyssnar (`StudyRecordingModel.start` kräver `listening.isListening`),
  därför startas Provläget först och inspelningen sedan via Inställningar → Diagnostik.
- Nick kräver att *Kontrollfrågor* = *Ja–nej-frågor* i Provlägets första start (D83); steget säger det.
- AirPods-knappen styr Lumen bara när Lumen är "Spelas nu" (D74); därför ingen musik under testet.

## Testresultat
Inga. Schemat är inte kört. Ingenting här är verifierat på enhet. **Simulatorn räknas aldrig som verifiering på enhet.**

## Kända risker
- Etiketten på låsskärmens fortsätt-knapp efter Pausa är inte läst i koden (**untested assumption**: "Fortsätt").
- Har AirPods inte huvudspårning blir 3b/3c N av det skälet; Aron skriver då modellen.

## Kvar
Inget i T4. Resultaten från Arons körning läggs i nästa rapport.

## Nästa session
T3 (bildtester) pågår; T1/T2 väntar på Angelas A1.
