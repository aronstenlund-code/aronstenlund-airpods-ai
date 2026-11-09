# A11 – BLOCKER: Lumen blir döv men visar "Lyssnar" (Angela, 2026-11-09)

Kort: orsaken hittades i Tobys logg. Scribe fick inget ljud i tystnaden och stängde sessionen, reserven misslyckades
och inget nytt försök gjordes. Tre rättningar:
1. Ett kort tyst ljud håller sessionen vid liv.
2. Scribe provas alltid igen med 1–30 s väntan.
3. Skärmen och örat säger "Jag hör inte just nu, försöker igen" i stället för "Lyssnar".

Grönt i CI (körning 42661012831). **Ej verifierat på enhet.** Toby kör om T2.

## Orsak (punkt 1)
**Före minut 2,69** höll första sessionen i mer än 2,5 minuter. Loggen visar varför: "Local VAD not ready: all audio
goes to Scribe". Allt ljud, även tystnad, gick alltså till Scribe.

**Vid minut 2,69 bytte keytermerna**, och sessionen öppnades om. Nu var Silero redo (D78), så bara tal skickades.
- T2 har cirka 20 s mellan frågorna, så Scribe fick inget ljud i 20 s åt gången.
- Sessionerna slutade då efter 21, 23 och 32 s.

**Slutsats:** Scribe stänger en session som inte får ljud på cirka 20 s.
- **Untested assumption** om exakt gräns. Den stämmer med alla tre stängningarna och med att den första sessionen
  höll.
- Keytermerna orsakade det inte direkt. De utlöste bara återanslutningen. A8.5 klarade redan längden: nu loggas
  antalet och den längsta termen när sessionen öppnas, som Toby bad om.

**Sedan:**
- En session slutade på under 20 s och räknades som fel.
- Reserven (iPhonens igenkänning) misslyckades i simulatorn ("no analyzer audio format for DictationTranscriber").
- `status = .failed` och ingen timer. Döv i 55 minuter, med "Lyssnar" på skärmen.

## Rättat
1. **Keep-alive (`ScribeProvider`).**
   - Har inget ljud skickats på 8 s, skickas 0,25 s tystnad. Det är cirka 3 % av den tysta tiden som faktureras.
   - Stängningskoden och orsaken (`ScribeClosed`, A8.5) står nu i raden "Scribe session ended after N s (orsak)".
2. **Nytt försök alltid (`TranscriptionCoordinator`).** Väntan är 1, 2, 4, 8, 16 och sedan 30 s så länge
   inspelningen pågår. Ett nytt försök planeras när:
   - Scribe faller tillbaka till telefonen, även om telefonen fungerar, för den är en nödlösning;
   - telefonens igenkänning saknas, inte startar eller slutar;
   - token eller start misslyckas.
   - Räknaren nollställs när en Scribe-session har hållit ≥ 20 s.
   - Inget försök efter att användaren stoppat.
   - Loggen visar "Scribe retry N in M s (orsak)".
3. **Aldrig "Lyssnar" när inget hörs.**
   - Går ingen igenkänning på 3 s visar lyssnarskärmen "Hör inte, försöker igen".
   - Kortet "Jag hör inte just nu" visas, och Lumen säger en gång "Jag hör inte just nu, försöker igen." (som A5).
   - När igenkänningen går igen försvinner kortet. Nästa avbrott sägs igen.
   - Korta glapp vid återanslutning säger ingenting.

## Tester (`LumenTests/A11Tests.swift`)
- Väntan 1, 2, 4, 8, 16, 30, 30.
- Scribe och telefonen faller båda → nytt försök efter 1 s → Scribe kör igen, och skärmen får veta det.
- Inget nytt försök efter stopp.
- Keyterm-raden ("Scribe keyterms: 3, longest 16 characters (Elektromagnetisk)").
- Problemkortets text och vad som sägs.
- Gröna i CI 42661012831.
- Keep-alive har inget enhetstest: 8 s väntan.

## Till Toby
Kör om T2. Förväntat:
- Sessionen håller genom tystnaden. Inga "ended after 2x s" i rad.
- Faller den ändå kommer "Scribe retry …" och sedan "STT running: Scribe".
- Skärmen säger "Hör inte, försöker igen" medan det pågår.

**Ändrade texter för rundan:**
- Lyssnar-rubriken visar "Hör inte, försöker igen" när ingen igenkänning går.
- Kortet "Jag hör inte just nu".

## Kvar
- Varför `DictationTranscriber` inte startar i simulatorn. Troligen saknas en analysformat-modell i simulatorn.
  **Untested assumption.**

## Concerns
Inga.

## Nästa
A12 (skärmfynden), sedan A9.
