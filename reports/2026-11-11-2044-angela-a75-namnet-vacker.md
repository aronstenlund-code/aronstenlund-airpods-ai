# A75 – "Lumen" ska alltid väcka och alltid få svar (Aron 20:41)

Angela, 2026-11-11. Kö: `prompts/queue/angela.md` A75 (Deangelo, högsta prioritet).

## Vad som är gjort
1. **Namnet hörs som det felhörs.**
   - `WakeWord.matches` godtar en känd variant: lumin, lummen, lomen, lymen, limen, loomen, lumens, lumén, luman med
     flera, och "lu men" som två ord.
   - Den godtar också varje ord med samma första bokstav som ligger högst en bokstav från namnet.
   - Riktiga ord en bokstav bort väcker aldrig: lumpen, luren, tumen, rummen med flera.
   - Namnet räknas som förut bara där det tilltalar Lumen: i början av ett yttrande, efter en mening eller efter en
     hälsning ("Jag berättade om Lumin …" väcker inte).
   - **Listan är per namn** (`variantsByName`). Raden för "earmind" finns redan, så ett byte av väckningsord är en rad.
2. **Namnet ger alltid svar.**
   - Det som sägs efter namnet skickas som en avsiktlig fråga (`mode: text`), utan frågespärren, som förut. Det som
     blev tyst var felhörningarna, som hamnade i spärren.
   - **Bara namnet** ("Lumin.") ger nu "Ja?" i örat. Nästa yttrande inom **8 s** (var 4 s) blir frågan.
   - Ett eko av "Ja?" räknas inte som frågan.
3. **Missar loggas:** ett första ord som ligger två bokstäver från namnet och inte godtogs loggas som "Name-like word
   not taken: … (A75)", så att listan kan växa.
4. **Nyckelorden:** namnet står först bland Scribes nyckelord och i iPhonens `contextualStrings`, alltså det som
   reservigenkänningen använder.

## Ändrat beteende
"Lumens …" i början av ett yttrande väcker nu, eftersom det är en felhörning (Deangelo). `VoiceChannelTests` är
ändrat. Mitt i en mening väcker det fortfarande inte.

## Testresultat
- **Enhetstester:** `LumenTests/A75Tests.swift` har 4 tester:
  - felhörningar väcker;
  - riktiga ord och mitt i en mening väcker inte;
  - en nära miss loggas;
  - listan per namn.
- `A14Tests` och `VoiceChannelTests` är uppdaterade.
- **iOS-bygge och enhetstester:** CI 43090031944 fick ingen Mac-runner (GitHubs kapacitet, inte kompilering); ombyggt med A76: CI 43093258037 grön (device-bygge, enhetstester med A75Tests, arkiv).
- **Ej verifierat:** Tobys T17 har kraven 48/50 "Lumen, <fråga>" och högst 1/50 falska väckningar. På telefon är inget
  provat.

## Risker
- Regeln om en bokstav kan väcka på ovanliga ord som börjar med "Lu…" i början av en mening. Därför finns listan
  `notTheName`, och den kan fyllas på.
