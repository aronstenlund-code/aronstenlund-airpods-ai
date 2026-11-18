# A146: mikrofontexten och taligenkänningens text enligt D229

Angela Schrute (moln, Opus 5.5), 2026-11-18 11:20–12:21. Main, sammanslagning be0b66f3 (grenen
`claude/fervent-fermi-34hrer`, 6c849a6e).

## 1. Texterna (Info.plist och InfoPlist.xcstrings)
| Text | Svenska | Engelska |
|---|---|---|
| Mikrofon | EarMind lyssnar bara när du har startat ett läge som lyssnar. Ljudet skickas till en taligenkänningstjänst och blir text. EarMind sparar inte ljudet. **Sömnläget sparar klippen bara på din telefon.** | EarMind only listens after you start a listening mode. The audio is sent to a speech recognition service to become text. EarMind does not save the audio. **Sleep mode keeps its clips only on your phone.** |
| Taligenkänning | EarMind lyssnar bara när du har startat ett läge som lyssnar. iPhonens egen taligenkänning gör ljudet till text på telefonen: som reserv, när du har stängt av molnet i Inställningar, och för Sömnläget och Mina svar. Det ljudet lämnar inte telefonen. | EarMind only listens after you start a listening mode. The iPhone's own speech recognition turns the audio into text on the phone: as a fallback, when you switch off cloud recognition in Settings, and for Sleep mode and Mina svar. That audio does not leave the phone. |

## 2. Två avvikelser från D229, som Deangelo får bestämma om
1. **Mikrofontexten har kvar Sömnlägets mening.** D229 säger "EarMind sparar inte ljudet." Det stämmer inte för
   Sömnläget: det sparar klipp med prat i sömnen och snarkning på telefonen i 30 dagar (`SleepRecorder`, Sömnlägets
   egen text "Klippen sparas bara på telefonen och raderas efter 30 dagar"). Sömnläget går att starta från Start.
   D138 hade meningen just av det skälet, så jag lät den stå kvar. *Verifierat i koden.* Tas Sömnläget bort ur
   App Store-versionen kan meningen strykas.
2. **Taligenkänningens text säger inte att ljudet skickas.** D229 säger att den "följer samma ord", men det tillståndet
   gäller bara iPhonens egen igenkänning, och den körs alltid på telefonen (`requiresOnDeviceRecognition = true` i
   `LegacySpeechProvider` och `SleepRecorder`). Molnets igenkänning (Scribe) kräver inte det tillståndet. Samma ord
   skulle alltså säga något som inte stämmer. *Verifierat i koden.*

## 3. Kontrollerat mot koden
- "Lyssnar bara när du har startat ett läge som lyssnar": samtycket före första start (D21), indikatorn medan den
  lyssnar. Sömnläget och Mina svar startas också med ett tryck av användaren.
- "Ljudet skickas till en taligenkänningstjänst": Scribe (ElevenLabs) när molnet är på, vilket är standard. När molnet
  är av skickas inget; texten säger då mer än som händer, inte mindre.
- **I testarnas byggen** (Debug och Beta) skickar testläget ljudet till oss när testaren har slagit på det. Det säger
  testlägets eget blad, inte mikrofontexten. App Store-bygget har inget testläge (D227).

## 4. Testresultat
- **CI: iOS build 44284557970 grön** (samma bygge som A145). *Verifierat i CI.* Texterna har inget eget test.
- Inte sett på telefon. iOS visar texten första gången appen ber om mikrofonen eller taligenkänningen.

## 5. Till Kelly
App Privacy och Ke78 bör följa texterna ovan, också Sömnlägets mening. Rad i `kelly.md`.
