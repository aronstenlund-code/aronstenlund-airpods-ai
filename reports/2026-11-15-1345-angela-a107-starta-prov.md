# A107: ljud vid Starta prov (logiken)

Angela Schrute (moln), 2026-11-15 13:08–13:45. Commit 30b99ae. Beslut: D190 (Aron), D191 (Kevins K71) och D193 (mitt).
Vyerna är Angela Fables.

## Vad som gjordes
- **Sparning gör aldrig ljud.** Varje `save` skickar `defer_audio: true`, för frågor och för texter. Före start kostar
  sparning och redigering inget. Efter start gör servern bara de ändrade filerna (D144), så redigering efter start gör
  bara den frågans ljud om.
- **`Drill.audioStarted`:** `false` betyder att servern inte har gjort något ljud (`audio_started: false`). `nil`
  betyder startat, eller en server från före K71. `Drill.awaitsAudioStart` är `true` i det första fallet.
- **`CloudDrillAudio.prepare`** slutar efter sparningen när ljudet inte är begärt. Det blir alltså ingen väntan i
  20 minuter och ingen "Ljudet dröjer"-rad (L6) för ljud som ingen har bett om.
- **`CloudDrillAudio.startAudio`:**
  1. sparar provet först om servern inte har sett det;
  2. anropar `/drill start` (kvoten räknas nu);
  3. markerar provet som startat och följer och laddar ner ljudet som `prepare` gör.

  Ett andra anrop gör inget. Är kvoten slut (402) eller nätet borta blir svaret `false`, och skälet står i
  `problem(for:)` (och `quotaExceeded`).
- **`RepetitionModel`:**
  - `start(drill)` begär först ljudet och öppnar sedan spelaren, som väntar på varje frågas ljud som förut (Kelly
    Ke49). Läsläget gör likadant. Går det inte att starta öppnas spelaren inte.
  - `canStart(drill)` är sann för ett prov som inte är startat.
  - Nya: `awaitsAudioStart(drill)`, `startAudio(drill)` (utan att spela) och `isStartingAudio(drill)`.
  - `shareLink` startar ett ostartat prov först.
  - Om `publish` svarar `audio_not_ready` för ett ostartat prov följer appen ljudet, eftersom servern startar det
    själv (D191).

### Till Angela Fable
Namnen står på A107-raden i kön och är skickade till dig:
- `awaitsAudioStart` betyder att ljudet inte är begärt. Visa då ingen "Ljud: 0 av N"-rad.
- `startAudio` och `isStartingAudio` startar ljudet och säger när det pågår. Förloppet är `progress`.
- `start` begär ljudet och spelar.
- För redigering räcker `save`.

### Till Toby
Starta prov gör nu ljudet. Ett flöde som efter en import väntar på "ljud klart" eller på att Starta prov blir aktiv
måste trycka Starta prov. Ljudet görs då, och spelaren väntar på första frågan.

## Testresultat
- 6 nya tester i `LumenTests/A107StartAudioTests.swift`, mot ett skenmoln som beter sig som K71:
  - sparningen begär inget ljud och väntar inte;
  - Starta prov begär ljudet och laddar ner det;
  - ett osparat prov sparas och startas;
  - kvoten slut sägs, och inget startar;
  - modellens Starta prov öppnar spelaren;
  - en äldre server räknas som startad.

  0 ElevenLabs (D180).
- **CI: iOS build 43712934484 grön** (77c80b3, med 30b99ae): device-bygget, varningar som fel och LumenTests, med `A107StartAudioTests` och de tidigare sviterna (A79A81, A105, T24). *Verifierat i CI.* (Bygget för 30b99ae ensamt ersattes i kön.)
- Ej provat på telefon eller mot den riktiga servern. Kevins `start` är *verified in docs* (backend/README), men
  appens anrop är inte provade live.

## Kända begränsningar och risker
- Om en äldre `status` hinner tillbaka efter `start` kan provet en kort stund märkas som ostartat igen. Ett nytt tryck
  på Starta prov kostar inget (D191), och nästa öppning rättar det.
- Prov som sparades före den här versionen räknas som startade (servern ger dem `audio_started` = sant).

## Kvar
- Angela Fables vyer för A107 (förloppet vid Starta prov, fotnoten i redigeraren).
- Toby: flödena efter import.
