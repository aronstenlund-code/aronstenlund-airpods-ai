# A65 – "Ja" i Mer?-fönstret utan att vänta på Scribes final (egen punkt, README 8)

Angela, 2026-11-11. Underlag: Tobys T7b och T12. Från "Ja." till anropet tog det 3,0 s, och efter "Mer." 14,7 s.
Väntan är appens egen: anropet går direkt när finalen kommer, men Scribe ger finalen först efter pausen. Ibland, som i
T12 fynd 1, kommer den först när sessionen stängs.

## Vad som är gjort
- När Mer?-fönstret är öppet och de obekräftade orden är ett ja ("ja", "mer", "gärna" och så vidare, `MoreOffer.verdict`)
  tas det långa svaret direkt, om orden har stått still i 0,7 s och kommer från eleven, inte från en annan röst.
- Med A56 sägs då `done.more` utan nytt anrop. Annars skickas "utveckla" direkt.
- Fortsätter orden ("Ja men vad är fotosyntes?") avbryts det. Det blir en vanlig tur, som förut (Tobys fall "ja mitt i
  mening").
- Kommer Scribes final "Ja." inom 6 s efteråt används den inte igen, varken som tur eller som "igen".
- Loggraden är "More? window closed (yes, voice, before the final (A65))".

## Testresultat
- **iOS-bygge och enhetstester:** CI RESULT65.
- **Ej verifierat:** tiden från ja till svar. Toby kör T7b igen. Målet är under 1 s med `done.more`.

## Risk
- Ett "ja" som är början på en längre mening, med en paus på mer än 0,7 s efter "ja", tas som ja. Fönstret är 5 s och
  öppnas bara efter ett kort svar.
