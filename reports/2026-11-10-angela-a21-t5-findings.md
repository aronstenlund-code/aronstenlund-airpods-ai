# A21 – Tobys T5-fynd: tappade frågor och döv mikrofon (Angela, 2026-11-10)

Underlag: `reports/apptest/2026-11-09-2150-toby-t5-retest.md`, "Fynd (till Angela)" 1–4. Påbörjad 2026-11-09 22:50,
pausad över natten, klar 2026-11-10. **Inget är verifierat på enhet.** Toby ombeds köra om T5.

## Vad som gjordes
| Fynd | Orsak i koden | Rättning |
|---|---|---|
| 1. Provläge: fyra frågor i ett andetag blev en tur, tre tappades | Scribe levererade fyra segment på en gång. Det första avslutade turen (fas `.thinking`), och `StudyMachine.transcriptFinal` kastar allt som kommer när fasen inte är `.listening`. | I `ListeningModel.receiveFinalTranscript` blir ett segment som kommer medan en tur besvaras (Provläge/Frågor-handsfree, inte under prov eller minitest) egna turer i `studyQueue` (delas med `QuestionSplitter`, utfyllnad bort). De frågas en i taget när svaret före är slut, som A8:s delade turer. En sen final av den tur som just slutade (eller en del av dess ord, inom 15 s) räknas inte som ny tur. En ny tur lägger sina delar *före* det som redan väntar i stället för att skriva över kön. |
| 2. Svar i förväg på en halv fråga ("Vilka är de största?") | Scribe sätter "?" efter första halvan; svaret i förväg startar direkt och levereras vid pausen. Sedan stänger D82 igenkänningen, så fortsättningen hörs aldrig. A8:s sammanslagning krävde att förra frågan *inte* slutade på "?". | Ny regel `UnfinishedQuestion.looksUnfinished` (högst 8 ord; slutar på artikel/konjunktion, "mellan" utan "och", eller bestämningsord + superlativ utan substantiv: "de största", "den bästa"). Prepositioner räknas aldrig, eftersom svenska frågor ofta slutar på dem ("Vad handlar boken om?"). En sådan fråga (1) svaras aldrig i förväg, (2) väntar 3 s extra i Frågor och förlängs med 1,5 s efter varje ny partial, (3) i Provläge läggs 3 s till turens tystnadsgräns, (4) slås ihop med fortsättningen även när den slutade på "?". Gäller inte Socialt/Rizz/Intervju. |
| 3. Mikrofonen öppnades inte efter ett långt svar (106 s döv) | Grinden öppnas bara via `speaker.onFinished` → `reopenRecognizerAfterSpeech`. Den väntar högst 30 s på `playback.isSpeaking` och gör sedan `guard !speaker.isSpeaking else { return }`, så ett svar som spelas längre än 30 s (eller en röst som aldrig rapporterar slut) lämnar igenkänningen stängd för alltid. | Säkerhetsspärr `OwnSpeechDeadline`: varje mening Lumen börjar säga lägger till sin beräknade längd (13 tecken/s × talhastighet; meningar i kö summeras, efter en paus räknas från nu). Har rösten inte rapporterat slut vid beräknad längd + 2 s öppnas igenkänningen ändå, Provläge går tillbaka till att lyssna (eller tar nästa väntande tur), och det loggas: `STT input opened by the safety timer: no end of Lumen's speech after N s (playback speaking …, speaker speaking …) (A21)`. Antalet syns som `gateWatchdogOpens`. "Igen" (uppspelning från minnet) får samma spärr. |
| 4. 6–17 s väntan när svaret i förväg kastades | Frågan kom inte vidare förrän Scribe committade, och i T5 skedde det först när Scribe-sessionen stängdes. Appen hade bara en egen slut-på-tur när andra pratade (A10/A14). | I `TranscriptionCoordinator`: inga nya ord i en partial på pausen + 0,8 s (Frågor 1,8 s) och ingen pratar enligt Silero → `commit()` till Scribe. Kommer ingen final 1,5 s senare används den senaste partialen som final. Scribes senare resultat för samma ord tas bort (`UsedWords`), och bara nya ord efter dem går vidare, så det blir ingen dubbeltur. Bara Scribe; telefonens igenkänning avslutar själv. Medan Lumen pratar (grinden stängd) görs inget. Loggas, och antalet visas när lyssningen slutar (`Stale words: N finals asked for, M partials used as finals (A21)`). |
| 5. Svar på 7 meningar i Frågor | Backend (Kevins K13). | Inget i appen; fynd 3 gör att ett långt svar inte längre kan ge en döv mikrofon. |

## Även rättat: Tobys T7 fynd 1–2 (samma grind)
`reports/apptest/2026-11-10-0815-toby-t7-more.md`: "Mer?"-fönstret öppnades i `speechFinished()`, alltså när
texten hade lämnats till rösten. Mikrofonen öppnade 2,8–13,3 s senare, när ljudet var slut, och därför hördes 0 av 7
"ja", och en ny fråga i fönstret tappades. Nu startar allt som väntar på eleven när igenkänningen faktiskt öppnar
(`recognizerOpenAfterSpeech`, även via säkerhetsspärren):
- "Mer?"-fönstret och tonen;
- tipset;
- D83:s nick/skakning och tyst förhör (A20);
- antecknings-pausen (A20);
- en väntande fråga i Frågor.

Toby kör om T7 (T7b).

## Tekniska detaljer
- Nya filer: `Lumen/Core/Understanding/UnfinishedQuestion.swift`, `Lumen/Core/Voice/OwnSpeechDeadline.swift`,
  `LumenTests/A21Tests.swift`. `UsedWords` ligger sist i `TranscriptionCoordinator.swift`.
- `ActivationController`: `PendingQuestion.unfinished`, `speechContinues(now:)`, `continuesHold = 1.5`,
  `pendingIsUnfinished`.
- `StudyMachine`: `tuning.unfinishedHold` (0 = av), `endpointSilenceNeeded`, `isPartOfLastTurn(_:at:within:)`.
  `ListeningModel.startHandsFree` sätter 3 s för Provläge och Frågor, 0 för de andra lägena.
- Tre äldre tester byggde på att "vilka är de största" skickades direkt (A8.2). De använder nu Tobys c2
  ("hur många invånare har" … "Sverige ungefär"), som fortfarande går direkt och slås ihop som förut.
- `FakeSTTProvider` räknar `commit()`.

## Testresultat
- **CI:** grönt, run 42773767993. Två av de nya testerna föll i första körningen (42769178219), båda på testfel: talets slut och fejkuppspelningens `stop()`. De rättades, och sedan var allt grönt. Nya enhetstester (`A21Tests.swift`): halva och hela frågor (7 + 14 fall, bland dem
  "Vad handlar boken om?", "Var kommer du från?", "Vad är det?"), Frågor håller, slår ihop och förlänger, Provläge
  väntar och blir hel, säkerhetsspärrens matematik, `UsedWords`, koordinatorn (commit → partial som final → Scribes
  sena final bort; final i tid → ingen commit), och två helflödestester i Provläge mot fejkar: fyra segment i ett
  andetag → 4 anrop i rätt ordning, och en röst som aldrig rapporterar slut → igenkänningen öppnas av spärren.
- **Enhet:** inget. Simulator: Toby kör om T5 (`apptest-retest.yml`).

## Kända begränsningar och risker
- **Halva frågor är en ordlista, inte förståelse.** "Hur många invånare har" fångas inte (A8:s väg tar den,
  backend säger `not_question` och hela frågan ställs). En hel fråga som träffar regeln ("Vilken är den största?")
  får 3 s extra väntan. **Untested assumption** att det är sällsynt i riktigt tal.
- **Säkerhetsspärren gissar längden.** Hänger hämtningen av rösten (dåligt nät) längre än marginalen kan
  igenkänningen öppnas medan Lumen fortfarande talar. Då tar ekofiltret (D82) Lumens egna ord, och nästa mening
  stänger grinden igen. Hellre det än en döv mikrofon.
- **Partial som final** kan kapa sista ordet om Scribe har en partial som ligger efter. Regeln slår bara till efter
  1,8 s utan nya ord och efter ett misslyckat `commit()`. Toby: håll utkik efter kapade frågor i T5.

## Till Toby (be honom i nästa runda)
- Kör om T5 (del 1 och 2). Förväntat: c1 och c3 besvaras hela, Provläge 4 turer av 4, q7 hörs, ingen väntan över
  ~4 s mellan "heard" och anrop. Nya loggrader att söka på: `(A21)`.
- `ScreenTourTests` behöver nya knappord efter A18 (se A18-rapporten).

## Kvar
- Verifiering på telefon (Aron): Frågor med paus mitt i en fråga, Provläge med flera frågor i ett andetag, ett långt
  svar följt av en ny fråga.

## Nästa session
- A18 (pågår i samma session), sedan A20.

## CI
Grönt i CI: iOS build run 42773767993 (commit bda589a): bygget för enhet (varningar = fel) och alla LumenTests gröna (147 sviter, de nya A21-sviterna inräknade). T7-rättelsen kom efter, i `6133e6c`; dess CI-körning står i STATUS.
