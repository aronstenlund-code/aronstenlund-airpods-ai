# Report: Phase 1a — Phase 1 audio core built against CI (no Mac yet)

Date: 2026-11-03 19:05 · Session: Angela (builder) · Assignment: `prompts/2026-11-03-phase1a-ci-build.md` (supersedes the Mac requirement in `prompts/2026-11-03-phase1-audio-foundation.md` §3.1 until the owner has a Mac)

Evidence labels: **verified in CI** (compiles with zero warnings / tests pass on the GitHub macOS runner), **verified in docs**, **untested assumption**, **verified on device** (none in this report — nothing has run on an iPhone).

## 1. Summary
- Phase 1 §3.1–3.7 is implemented and **`main` is green**: [run 41688186030](https://github.com/aronstenlund-code/aronstenlund-airpods-ai/actions/runs/41688186030) — device build with `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES` in Swift 6 language mode, 21 scoring tests + 41 app unit tests passed.
- Every AVFoundation/Speech API name the code uses was checked against the real iOS 26.5 SDK headers and `.swiftinterface` files in CI (24/24 found, declarations printed in the log).
- **Nothing is verified on device.** All audio behaviour (capture, HQ/HFP routing, playback through AirPods, background, interruptions, SNR numbers) waits for the owner's Mac next week; `docs/DEVICE-TEST-CHECKLIST.md` (Swedish) scripts that session.
- Two CI-infrastructure facts learned the hard way: GitHub's macOS arm64 pool is capacity-constrained (one run was dropped with "not acquired by Runner"), and every push by other sessions cancelled my queued run until I excluded `docs/`, `reports/`, `prompts/`, `testdata/`, `backend/` and `*.md` from the workflow triggers.

## 2. What was implemented

### CI as compiler (`.github/workflows/ios-build.yml`, D13)
| Step | What it does | Result in run 41688186030 |
|---|---|---|
| Select Xcode | newest `/Applications/Xcode_26*.app` on the `macos-26` image via `xcode-select`; prints `sw_vers`, `xcodebuild -version`, `-showsdks`, `swift --version` | macOS 26.6.2, Xcode 26.6 (17F113), Swift 6.3.3, iOS 26.5 SDK — **verified in CI** |
| API-name check | `tools/ci/check-sdk-symbols.sh` greps the iOS SDK for every symbol in `tools/ci/sdk-symbols.txt` (24 symbols) and dumps the declarations we depend on | 24/24 found — **verified in CI** |
| XcodeGen | `brew install xcodegen`, `xcodegen generate`; `Lumen.xcodeproj` uploaded as artifact (D14) | OK |
| Scoring tests | `swift test` on the macOS host for `Packages/LumenScoring` | 21 tests / 4 suites passed |
| Device build | `xcodebuild build -destination generic/platform=iOS`, unsigned, warnings as errors | **green** |
| Unit tests | `xcodebuild test` on the newest iOS 26 iPhone simulator on the image (picked with `simctl` + `jq`) | iPhone 17 Pro, iOS 26.5: 41 tests / 8 suites passed |

The only "warning" strings in the log are Node deprecation notices from `actions/upload-artifact`, not compiler output.

### App (`project.yml` + `Lumen/`), Phase 1 §3.1–3.7
| § | Component | Notes |
|---|---|---|
| 3.1 | `project.yml`, targets `Lumen` + `LumenTests`, iOS 26.0, Swift 6, strict concurrency; `Info.plist` with `NSMicrophoneUsageDescription` (en + sv via `InfoPlist.xcstrings`) and `UIBackgroundModes=audio`; `UIFileSharingEnabled` only in Debug (`INFOPLIST_KEY_` setting per config); team empty, set locally in Xcode | **verified in CI** (builds); plist merge of `INFOPLIST_KEY_*` into the custom plist: **untested assumption** until seen in Xcode |
| 3.2 | `AudioSessionManager` + `CaptureConfig` (B-HQ, C-HFP-default/measurement/voiceChat, A-ref-default/measurement) with exact iOS 26 option names (`allowBluetoothHFP`, `bluetoothHighQualityRecording`, `allowBluetoothA2DP`); `setPreferredInput` to Bluetooth or built-in mic; permission via `AVAudioApplication.requestRecordPermission()`; interruption / route-change / media-services-reset observers; route re-read 1 s after activation | compiles; behaviour **untested on device** |
| 3.3 | `CaptureService`: `AVAudioEngine` input tap → `AVAudioConverter` → 16 kHz mono Int16; voice processing off; `AsyncStream<AudioChunk>` (~40 ms, host time); `Int16RingBuffer` (60 s, lock-based, `Sendable` without `@unchecked`); level ~20×/s; Debug-only WAV export to Documents; converter rebuilt on `AVAudioEngineConfigurationChange` | ring buffer, converter, WAV, levels **verified in CI** by unit tests; live capture **untested on device** |
| 3.4 | `PlaybackService`: `AVAudioPlayerNode` → `AVAudioUnitTimePitch` (0.5–2.0×) → mixer at a fixed 24 kHz mono graph format (D16); test tone; TTS through our engine via `AVSpeechSynthesizer.write(_:toBufferCallback:)` with per-buffer conversion; "play requested → first non-silent buffer rendered" probe on a tap, plus session `outputLatency` logged | compiles; **untested on device** |
| 3.5 | Capture starts only from a UI tap while `applicationState == .active`; `SessionReducer` handles interruption (`shouldResume` → resume, else "tap to resume"), AirPods removed (pause + haptic, never auto-resume), media services reset (engine rebuilt) | reducer **verified in CI** (7 tests); real interruptions **untested on device** |
| 3.6 | `DiagnosticsView`/`DiagnosticsModel`: config picker, Start/Stop, "Active capture" banner, route table (§3.11 fields), level meter, chunk counter, test tone, Speak sv/en + rate slider, latency median, speaker-distance test (1/2/4 m × quiet/noisy/metro × other person/wearer/wearer whisper/wearer low voice — the last three per Track D1) with SNR estimate + WAV per run, mic-source sanity check (tap impulses), `SpeechTranscriber`/`DictationTranscriber` locale check, event log, "Copy results as Markdown" | logic (SNR estimator, impulse detector, banner, Markdown) **verified in CI**; UI **untested on device** |
| 3.7 | `Log`: `Logger` categories `audio.session`, `audio.capture`, `audio.playback`, `diagnostics`; `OSSignposter` events `capture.started/stopped`, `play.requested`, `play.firstAudio` | compiles |
| 3.11 | `SessionSnapshot.read(from:)` logs input/output ports (type, name, uid, channels), category, mode, options, sample rate, IO buffer, channels, latencies, `bluetoothMicrophoneExtension?.highQualityRecording.isSupported/.isEnabled`, `setPreferredInput` outcome, engine input format, `Locale.current.region`, OS version | API names **verified in CI** against `AVAudioSessionRoute.h`; values **untested on device** |

### Scoring core for §3.9 (`Packages/LumenScoring`, D15)
`TextNormalizer` (Swedish lowercase, punctuation → word boundary, decimals kept, `%` → "procent", number words → digits incl. compounds like "nittonhundratrettionio" and adjacent merges like "tjugo fem"), `EditDistance` with S/D/I counts, `Scorer` (WER, CER, exact match, corpus aggregate), `STTResultRow` (the CSV row for `reports/data/phase1-stt-results.csv` with all §3.11 fields). One module for the app and the later Mac CLI; no Python copy. **verified in CI** (21 tests, hand-computed cases incl. items from `testdata/scripts/`).

### Docs
- `docs/DEVICE-TEST-CHECKLIST.md` (Swedish): install Xcode + free Apple ID + Homebrew/XcodeGen (artifact fallback), run on iPhone, then the exact button order for mic-source check, playback quality, distance test (incl. whisper/low voice), 10-min locked-screen test (explicitly checks whether background audio works with free provisioning), interruption, AirPods removal, locale check, Apple's own studio-quality feature (§3.12, separate), what to send back and where WAVs go.
- `docs/DECISIONS.md` D13–D17 (CI as compiler, xcodeproj not committed, scoring module rules, playback graph format, Swift Testing).

## 3. Test results
| Suite (where) | Tests | Result | Basis |
|---|---|---|---|
| LumenScoring: Normalizer, SwedishNumbers, EditDistance, Scoring (macOS host) | 21 | pass | **verified in CI** |
| LumenTests: RingBuffer (incl. concurrent write/read), PCMConverter (48 kHz stereo Float32 → 16 kHz Int16 mono, 24 kHz mono, 16 kHz passthrough, flush/reuse), AudioLevel + SNREstimator, WAVWriter, SessionReducer, MicSourceTest, SessionSnapshot/banner, CaptureConfig (iPhone 17 Pro simulator, iOS 26.5) | 41 | pass | **verified in CI** |
| Anything with a microphone, AirPods, Bluetooth route, background, interruption | — | not run | needs the Mac + iPhone |

## 4. CI iterations (what failed and why)
1. Two LumenScoring expectations were wrong, not the code ("Fem" normalises to "5"; CER denominator 8).
2. `AVAudioConverterInputBlock` is `@Sendable` in the iOS 26 SDK → the input block could not capture the buffer or a local flag; fixed with a single-owner hand-off object (`OneShotInputFeed`, documented `@unchecked Sendable`).
3. `PCMConverterTests` assumed the sample-rate converter emits nearly everything per call; it holds back ~240 frames of 1600 until the next call or `flush` (observed in CI). Tests now assert convert + flush totals. Consequence for live capture: ~15 ms of audio is always one buffer behind — not lost — **verified in CI**, latency impact on device **untested**.
4. Infrastructure: one run lost to macOS runner capacity; four runs cancelled by concurrent pushes from CREED/Kevin → path filters added to the workflow triggers.

## 5. Known bugs, limitations, risks
- `@unchecked Sendable` is used twice with justification: `CaptureTapContext` (render-thread-only state) and `OneShotInputFeed` (synchronous converter callback).
- The tap allocates one `[Int16]` per ~40 ms chunk to hand samples off the render thread; acceptable for Phase 1, a buffer pool is the fix if `conversionErrorCount`/glitches show up on device.
- Playback latency probe measures to the first rendered buffer at the time-pitch tap (granularity ≈ tap buffer); add `outputLatency` (logged) for time-to-ear.
- `AVSpeechSynthesizer.write` must deliver a final zero-length buffer for `speak` to finish; if a voice never does, the method waits (stop() still works). **untested assumption**.
- `INFOPLIST_KEY_UIFileSharingEnabled` per configuration with a custom `Info.plist`: merging **untested** until opened in Xcode.
- Mic-source check is a heuristic (impulse count); it reports levels so a human can judge.
- No `LumenScoring` CLI yet (`tools/stt-bench/` is Phase 1 §3.9 cloud work, deferred with the device measurements).

## 6. Concerns (per CLAUDE.md)
None. Track D's roadmap addition keeps the guardrails (indicator, consent, no concealment); the whisper/low-voice runs added to the distance test are measurements of the wearer's own voice.

## 7. Remaining work / what the next session should do
- **Device session (owner's Mac):** follow `docs/DEVICE-TEST-CHECKLIST.md`; send back the copied Markdown per AirPods model. Then fill `reports/data/phase1-stt-results.csv` and the Phase 1 report with measured numbers.
- **MVP sprint (`prompts/2026-11-03-mvp-sprint-app.md`, step 0 done):** item 1 listening screen + consent, then STT provider (SpeechAnalyzer; locale check is already in Diagnostics), activation, `CloudAnswerProvider` against Kevin's SSE contract (`backend/README.md`, mock until deployed; D19 makes it the default, Foundation Models the offline fallback and unavailable on the owner's iPhone 14 Pro), TTS, text mode, latency overlay, notes, prep mode, then Track D.
- OSS-1 / OSS-3 still gated on a device run.
