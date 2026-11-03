# Report: MVP item 2 — On-device speech-to-text

Date: 2026-11-03 21:40 · Session: Angela (builder) · Assignment: `prompts/2026-11-03-mvp-sprint-app.md` item 2 (D18 chain, D22)

Evidence labels: **verified in CI** (compiles with zero warnings / tests pass on the GitHub macOS runner), **verified in docs**, **untested on device** (nothing in this report has run on an iPhone; the Simulator has no SpeechTranscriber).

## 1. Summary
- The Listening screen now transcribes live: an `STTProvider` chain picks the best on-device Apple engine for the chosen language (`SpeechTranscriber` → `DictationTranscriber` → `SFSpeechRecognizer` on-device only), downloads the speech model on first use, follows the session (pause/resume/stop) and writes partial and final results into the transcript list. A sv/en language picker and a status row ("Transcribing on this iPhone · SpeechTranscriber", model download, or a clear "Swedish is not available on this iPhone") sit on the Listening screen.
- Commit `ac64843` — **green on the first push**: [run 41712601522](https://github.com/aronstenlund-code/aronstenlund-airpods-ai/actions/runs/41712601522) (Xcode 26.6, iOS 26.5 SDK, zero compiler warnings, 36/36 SDK symbols found, 21 scoring tests + 96 app tests in 16 suites passed on the iPhone 17 Pro simulator). The new CI step dumped 458 lines of `SpeechAnalyzer`-family declarations from the SDK; every signature the code uses (`setContext`, `bestAvailableAudioFormat`, `finalizeAndFinishThroughEndOfInput`, `AnalyzerInput(buffer:)`, `AnalysisContext.contextualStrings`) is in that dump — **verified in CI**.
- **Untested on device.** Whether `SpeechTranscriber` offers sv-SE on the owner's iPhone 14 Pro, how fast partials arrive, and recognition quality over HFP are exactly what checklist §3j measures.

## 2. What was implemented
| Piece | Files | Notes |
|---|---|---|
| Provider protocol | `Lumen/Core/Transcription/STTProvider.swift` | `STTProvider` (prepare / start(audio:) / stop / setContextualStrings), `STTResult` (text, isFinal, audio time range), typed `STTError`, `TranscriptSink`. |
| SpeechAnalyzer provider | `AppleSpeechProvider.swift` | `SpeechAnalyzer` with `SpeechTranscriber` or `DictationTranscriber` (`.volatileResults`, `.audioTimeRange`); `AssetInventory.assetInstallationRequest` → `downloadAndInstall` in `prepare()`; our 16 kHz Int16 chunks → `PCMConverter` → `SpeechAnalyzer.bestAvailableAudioFormat` → `AnalyzerInput`; `finalizeAndFinishThroughEndOfInput` on stop with a 5 s watchdog; `AnalysisContext.contextualStrings[.general]` (≤100) when prep topics exist. |
| Legacy on-device provider | `LegacySpeechProvider.swift` | `SFSpeechRecognizer` with `requiresOnDeviceRecognition = true` and `supportsOnDeviceRecognition` checked first; authorization requested only on this path. Server-based recognition is never used (D22, consent text). |
| Engine selection | `SpeechEngineSelector.swift` | Pure chain over normalised BCP-47 ids (exact locale, else same language any region); `SpeechAvailabilityProbe.current` reads `SpeechTranscriber.isAvailable/supportedLocales`, `DictationTranscriber.supportedLocales`, `SFSpeechRecognizer.supportsOnDeviceRecognition`. |
| Coordinator | `TranscriptionCoordinator.swift` | Hooks `SessionController.onCaptureStarted/Stopped`, subscribes to the chunk fan-out, status `probing → preparing → running` / `unavailable(language)` / `failed(message)`; generation counter so stop/start races cannot leave a stale provider running; `setLanguage` persists and restarts live. |
| Language setting | `TranscriptionLanguage.swift` | sv-SE / en-US, default from the phone language, UserDefaults. |
| Session fan-out | `Lumen/Core/Session/SessionController.swift` | `subscribeToChunks()` / `unsubscribeFromChunks` (AsyncStream has one consumer); `onCaptureStarted` / `onCaptureStopped` hooks fire on start, resume, pause, stop and engine rebuild. |
| UI | `ListeningView.swift`, `ListeningModel.swift` | Status row per coordinator state, segmented language picker, `ListeningModel: TranscriptSink`. Swedish for all new strings. |
| Plist / CI | `Info.plist`, `InfoPlist.xcstrings`, `tools/ci/sdk-symbols.txt`, `tools/ci/dump-speech-api.sh`, workflow | `NSSpeechRecognitionUsageDescription` (en + sv). 12 more Speech symbols in the API-name check; a new CI step dumps the `SpeechAnalyzer` family declarations from the SDK's `.swiftinterface` into `build-logs/speech-api.txt` so signatures are verifiable in every run. |

Not in this item: prep topics (item 9 — only the plumbing exists), question detection (item 3), any cloud STT.

## 3. Test results
| Suite (iPhone 17 Pro simulator, iOS 26.5) | Tests | Result | Basis |
|---|---|---|---|
| `TranscriptionCoordinatorTests` — chain for sv (SpeechTranscriber), fallbacks to Dictation and legacy, unavailable language + recovery by switching language, results → sink, chunks → provider, stop on capture stop, pause/resume restarts, language change live and idle, prepare failure, start failure | 12 | pass | **verified in CI** |
| `SpeechEngineSelectorTests` — normalisation, exact/region matching, chain order, nothing supported | 5 | pass | **verified in CI** |
| `LanguageSettingsTests` — default by phone language, persistence, bad stored value, BCP-47 | 4 | pass | **verified in CI** |
| `ChunkFanOutTests` — two subscribers, unsubscribe ends the stream | 1 | pass | **verified in CI** |
| Item 1 + Phase 1 suites | 74 | pass | **verified in CI** |
| `LumenScoring` (macOS host) | 21 | pass | **verified in CI** |
| Real `SpeechAnalyzer` recognition, model download, Swedish availability, HFP audio quality | — | not run | checklist §3j |

The coordinator is tested with an in-memory `FakeSTTProvider` behind the same protocol; the Apple providers themselves are only compile-checked against the SDK (their API names are in the symbol check and the swiftinterface dump).

## 4. CI iterations
One push, one green run. No compiler warnings, no test failures, no missing SDK symbols. `SFSpeechRecognizer` carries no deprecation macro in the iOS 26.5 headers (checked by the dump step).

## 5. Known limitations, risks
- `SpeechTranscriber` Swedish support is unknown until the device run (R2). The chain and the UI message exist for the "no" case; `DictationTranscriber` is the expected fallback (**verified in docs**: dictation locales).
- Partial-result granularity and latency of `SpeechAnalyzer` on an iPhone 14 Pro: **untested**. Item 7 adds the instrumentation.
- Audio conversion for the analyzer runs on the main actor at ~25 chunks/s. Cheap, but move it off-main if the UI stutters on device.
- `AnalyzerInput` is fed without explicit `bufferStartTime`; the analyzer's own timeline is used for `audioStart/End`.
- The SFSpeechRecognizer path is kept per D18 but is probably redundant on iOS 26 (DictationTranscriber covers the dictation locales); drop it if it causes trouble on device.
- First-use model download needs internet; the status row says so. Without internet and without an installed model, transcription fails with the install error shown.

## 6. Concerns (per CLAUDE.md)
None new. Transcription stays on the phone; the consent text's promise ("transcribed on your iPhone, audio never uploaded") is enforced by D22 (no server-based recognizer).

## 7. Next
Item 3 — activation: push-to-talk (default) and auto mode with a local `QuestionGate` (Swedish/English question words, "?", maths patterns, short topic fragments, cooldown, self-playback suppression via `TranscriptSegment.overlapsPlayback`), unit-tested on an evaluation set.
