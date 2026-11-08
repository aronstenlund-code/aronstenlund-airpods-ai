# T1 – Ljudkedjetest i simulatorn (Toby, 2026-11-08 18:50)

**Simulatorn räknas aldrig som verifiering på enhet.** Allt nedan är simulator (iPhone 17 Pro, iOS 26.5-runtime,
GitHub `macos-26`, Xcode 26). Inga AirPods, ingen Bluetooth-väg, inget riktigt eko.

## Vad som byggdes
| Del | Fil |
|---|---|
| Test i Angelas `LumenE2ETests` (A1) | `AppTests/E2E/Chain/AudioChainE2ETests.swift` |
| Manus (12 meningar i tre set) | `AppTests/E2E/Audio/cases.tsv` |
| Körning: tal med macOS `say` (svensk röst, 16 kHz WAV) + 4 s tystnad, test, sammanfattning | `scripts/apptest/chain.sh`, `scripts/apptest/chain_summary.py` |
| CI: nattligt 03:00, manuellt, och på `toby/**` vid ändring av testet. **Aldrig på push till main.** | `.github/workflows/apptest-chain.yml` |

**Hur kedjan körs:**
- Testet bygger appens riktiga `AppContainer` med `LUMEN_AUDIO_FILES` satt, så att filerna ersätter mikrofonen
  (`FileCaptureService`, realtid).
- Allt efter mikrofonen är appen som den är byggd:
  - grind och Silero-VAD,
  - Scribe live via `/stt-token` med lägets parametrar och provprofilens keyterms (Provläge startas med ett
    biologiprov: "fotosyntes, klorofyll, cellandning, mitokondrier"),
  - yttrandesammanslagning,
  - QuestionGate eller Provläge,
  - `/answer`.
- Testet läser appens `sessionObserver` (hört, svarat) och sessionsloggen.
- För varje set skrivs `apptest-out/chain/<set>.json`. Artefakten `apptest-chain` innehåller också WAV-filerna och
  `summary.md`.
- Svaren läses **inte** upp (`voice.speakAnswers` av). Det sparar TTS-kostnad, men grinden medan Lumen pratar testas
  därför inte.
- Kevins D88-ljud (K3) finns inte än. Byt filerna i `chain.sh` när det gör det.

## Testresultat (CI-körning 42505228884, `fa3ba28`)
| Set | Sagt | Hört | Svar | Första text | Resultat |
|---|---|---|---|---|---|
| Frågor (4 s tyst först) | 7 (5 frågor, 2 påståenden) | 7, ett yttrande per mening | 5, alla frågor, inga påståenden | 1,0–1,5 s | ✔ |
| Provläge (4 s tyst först) | 4 | 4 | 4, på svenska, alla ämnesord rätt | 0,73–0,81 s | ✔ |
| Fråga direkt vid start | 1 | "Tack." | 0 | – | ✘ **fynd 1** |

Allt i tabellen är **verifierat i simulator**.

Ingen krasch, och ingen session slutade av sig själv. En mening hördes fel: "Vad bildas när glukos bryts ner …"
blev "För att bilda snar glukos bryts ner …", och Provläge svarade då "Det stämmer inte riktigt …" (`say`-rösten är
inte mänskligt tal). Hela tidslinjen per händelse finns i artefaktens `summary.md`.

## Fynd (till Angela)
1. **Det som sägs direkt när lyssnandet startar försvinner.**
   - **Vad som hände:** en fråga som börjar i samma ögonblick som sessionen startar hördes inte. Scribe gav bara
     "Tack." (en typisk hallucination på avklippt ljud), och inget svar kom.
   - **Utan tyst inledning:** i körning 42502966284 försvann också första meningen i både Frågor och Provläge.
   - **Med tyst inledning:** med 4 s tystnad först hörs allt.
   - **Trolig orsak:** ljudet före Scribe-anslutningen (token + websocket) buffras inte. **Untested assumption.**
   - **Varför det spelar roll:** på telefon gäller det den som trycker Start, eller säger "Hej Siri, starta Lumen",
     och genast frågar. **Inte verifierat på enhet.**
   - **Testet:** `theFirstWordsRightAfterStartAreHeard` är rött tills det är löst.
2. **Provläge svarar på engelska när iPhonens språk är engelska.**
   - **Vad som hände:** körning 42502966284 kördes med simulatorns standardspråk (en_US). Där svarade Provläge på
     engelska på svenska frågor ("The main difference is direction. Photosynthesis …"), medan Frågor svarade på
     svenska i samma körning.
   - **På svenska:** med `-testLanguage sv` blev svaren svenska.
   - **Varför det spelar roll:** en elev med engelsk iPhone som pluggar på svenska får engelska svar. **Verifierat i
     simulator, inte på enhet.**
   - **Testet:** kontrollen `englishAnswers == 0` ligger kvar i Provläge-testet. Testet körs nu på svenska, så den
     fångar bara regressioner på svensk iPhone.
3. **`asked` rapporteras inte på svar-i-förväg-vägen (D80).**
   - **Vad som hände:** `sessionObserver` fick `heard` och `answered` men aldrig `asked` (0 av 9 svar).
   - **Varför det spelar roll:** D87-inspelningens JSON saknar därför sannolikt "asked"-raderna. **Untested
     assumption** för inspelningen.

4. **Scribe tappar anslutningen, och då blir lyssnandet dött i simulatorn medan det står "Lyssnar".**
   - **T1-omkörningen (42506898206, samma kod):** Provläge hörde 0 av 4 meningar.
   - **Loggen:**
     ```
     2,27 STT running: Scribe · sv-SE
     12,44 Scribe unavailable (connection lost): using the iPhone's speech recognition
     ```
     Efter det hördes ingenting.
   - **T2-röktestet:** Scribe-sessionen slutade efter 22–33 s gång på gång (`Scribe session ended after 23 s:
     reconnecting`) och kopplade upp igen. Vid minut 4,9 kom `STT start failed: Audio format problem: no analyzer
     audio format for DictationTranscriber`, och efter minut 3,8 kom inga fler svar.
   - **Varför reserven inte hjälper i simulatorn:** iPhonens igenkänning startar inte där. På telefon fungerar den
     troligen (**untested assumption**).
   - **Tre frågor till Angela:**
     1. Varför tappas Scribe så ofta? Klipps den av tystnaden (20 s mellan frågorna) eller när keytermerna byts
        (`Scribe keyterms changed: reconnecting in a pause`)?
     2. Försöker appen återvända till Scribe efter att ha bytt till iPhonens igenkänning?
     3. Ska ett misslyckat byte till reserven synas som ett fel, i stället för att det står "Lyssnar"?
   - **Status:** **verifierat i simulator, inte på enhet.**

## Behöver av Angela
- **Pushar som startar iOS-bygget:** `ios-build.yml` ignorerar inte `AppTests/**` eller
  `.github/workflows/apptest-*.yml`. Mina pushar startar därför iOS-bygget och kan avbryta ett pågående bygge på main.
  Jag itererar på grenen `toby/*` och avbryter mina egna dubbletter, men lägg gärna till de två sökvägarna i
  `paths-ignore`.
- **Mitt UI-test i `LumenE2ETests`:** `LumenE2ETests` tar med hela `AppTests/E2E`, och mitt UI-test
  (`Screens/ScreenTourTests.swift`) är därför skyddat med `#if LUMEN_SCREEN_TOUR`. Vill du hellre utesluta
  `Screens/**` i `project.yml` går det också bra.
- **Krok för `asked`:** en `sessionObserver`-händelse `asked` även på svar-i-förväg-vägen (se fynd 3).

## Kända begränsningar
- **Rösten:** `say` är en syntetisk röst utan brus. Kevins D88 (brus, flera röster) blir det riktiga måttet.
- **Lägen:** Intervju, Socialt och Rizz finns inte i setet än.
- **Kostnad:** varje körning kostar Scribe (cirka 3 minuter ljud) och 9–10 `/answer`-anrop, och den loggar in anonymt
  en gång.

## Kvar
- T2 (60 minuter) bygger på detta: samma test med `LUMEN_AUDIO_LOOP=1` och kurvor.
- Fler lägen i setet.

## Nästa session
Avsluta T3 (full körning i sju lägen pågår), sedan T2.
