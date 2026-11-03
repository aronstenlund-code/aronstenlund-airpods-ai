# Claude Code assignment — Phase 1: Audio foundation

Paste everything below into a Claude Code session (Opus) running **on a Mac with Xcode 26**, inside a clone of the project repo.

---

## 1. Objective

Build the app's audio core and **measure how well the AirPods microphones capture another person speaking 1–4 m away** while the app plays high-quality audio into the same AirPods. Capture via AirPods is the product decision (D10); the iPhone mic (A-ref) is only a reference measurement. Apple documents that Bluetooth high-quality recording is **not currently supported in the EU**, so in Sweden the realistic AirPods path is **HFP**; this phase measures what HFP (and HQ, wherever it turns out to be available) actually delivers. Then measure **actual Swedish speech-recognition accuracy (WER)** on those recordings for Apple on-device STT and two cloud providers, across AirPods models, mic modes, distances and noise — so the Phase 2 technology choice is based on data. This is the foundation of the whole product; nothing else is built in this phase.

Deliverables: an Xcode project, a reusable audio module, a Diagnostics screen to run the tests on a real iPhone, and a report with measured results.

## 2. Existing project context

- Product: iPhone app that listens to the room, detects questions and speaks short answers into AirPods. Codename **Lumen**, bundle ID `com.rsolutions.lumen` (placeholders).
- Read first: `CLAUDE.md`, `docs/STATUS.md`, `docs/ARCHITECTURE.md` (§2, §4, §11), `docs/DECISIONS.md`, `reports/2026-11-03-1600-architect-initial-analysis.md`.
- The repo contains docs only. No code yet.
- Baseline: iOS 26.0 minimum, Swift 6 strict concurrency, SwiftUI + Observation, no third-party runtime dependencies. XcodeGen allowed as a dev tool (D9).

## 3. Exact functionality to implement

### 3.1 Project skeleton
- `project.yml` (XcodeGen) generating `Lumen.xcodeproj` with targets `Lumen` (app) and `LumenTests` (unit tests). If XcodeGen is not installed, run `brew install xcodegen`; if that is not possible, stop and tell the product owner.
- Folder layout per ARCHITECTURE §11 (create only what this phase needs: `App/`, `Core/Audio/`, `Core/Session/`, `Core/Telemetry/`, `Features/Diagnostics/`).
- `Info.plist`: `NSMicrophoneUsageDescription` (clear text, English + Swedish localization), `UIBackgroundModes` = `audio`.
- Signing: leave team empty in `project.yml` and document how to set it locally. Do not commit personal team IDs.

### 3.2 `AudioSessionManager` (`Core/Audio/`)
An `@MainActor` or actor-isolated type that configures `AVAudioSession` for a selected `CaptureConfig`:

| Config ID | Category | Mode | Options | Preferred input | Note |
|---|---|---|---|---|---|
| **B-HQ** | `.playAndRecord` | `.default` **only** | `[.bluetoothHighQualityRecording, .allowBluetoothHFP]` | AirPods | Apple: HQ can only be requested in `.default` mode; `allowBluetoothHFP` is the documented fallback. **Apple: not currently supported in the EU** → expected to fall back to HFP in Sweden. |
| **C-HFP-default** | `.playAndRecord` | `.default` | `[.allowBluetoothHFP]` | AirPods | Baseline AirPods capture available everywhere. |
| **C-HFP-measurement** | `.playAndRecord` | `.measurement` | `[.allowBluetoothHFP]` | AirPods | Separate test: does `.measurement` reduce iOS-side processing on the AirPods input? |
| **C-HFP-voiceChat** | `.playAndRecord` | `.voiceChat` | `[.allowBluetoothHFP]` | AirPods | Reference: full voice processing (expected to suppress other speakers most). |
| **A-ref** | `.playAndRecord` | `.default` and `.measurement` | `[.allowBluetoothA2DP]` only | built-in mic | Reference only (iPhone mic, AirPods A2DP output). |

Do **not** combine `.bluetoothHighQualityRecording` with `.measurement` — Apple documents that HQ can only be requested in `.default`.

Requirements:
- Expose current route (inputs/outputs with `portType`, `portName`, `uid`), sample rate, IO buffer duration, input channel count, and the HQ capability state (§3.11).
- Microphone permission via `AVAudioApplication.requestRecordPermission`.
- Observe and publish: interruptions (`interruptionNotification`, incl. `shouldResume`), route changes (`routeChangeNotification` with reason), media services reset. Route change "AirPods removed" → pause capture and playback, surface state to UI.
- Use the exact API names that exist in the iOS 26 SDK (e.g. `allowBluetoothHFP` vs the older `allowBluetooth`); check the SDK headers, do not guess.

### 3.3 `CaptureService` (`Core/Audio/`)
- `AVAudioEngine` input tap in the hardware format → `AVAudioConverter` → **16 kHz, mono, Int16 PCM**.
- Voice processing **off** (`inputNode.isVoiceProcessingEnabled == false`).
- Outputs: `AsyncStream<AudioChunk>` (chunk = ~40 ms, with host-time timestamp) and a thread-safe **ring buffer holding the last 60 s**, with `snapshot(lastSeconds:) -> [Int16]`.
- Live input level (RMS dBFS + peak) published ~20×/s for the UI.
- Debug-only: `exportLast(seconds:) -> URL` writing a WAV file to the app's Documents folder (enable `UIFileSharingEnabled` only in Debug config).

### 3.4 `PlaybackService` (`Core/Audio/`)
- `AVAudioPlayerNode` attached to the same engine, with `AVAudioUnitTimePitch` for rate (0.5×–2.0×) without pitch change.
- `play(buffer:)` for PCM buffers and a helper that speaks a phrase with `AVSpeechSynthesizer.write(_:toBufferCallback:)` and schedules the buffers on the player node (so TTS goes through our engine, not the system's).
- Playback must work **while capture keeps running**, and output must stay on AirPods.
- Measure and log "play requested → first buffer rendered" latency.

### 3.5 Background & lifecycle
- Capture continues with the screen locked and the app backgrounded.
- Capture is started only by an explicit user tap in the foreground.
- After a phone call / Siri interruption ends, resume if `shouldResume`, otherwise show a "tap to resume" state.

### 3.6 Diagnostics screen (`Features/Diagnostics/`)
A single SwiftUI screen (functional, not pretty) with:
- Config picker (B-HQ, C-HFP-default, C-HFP-measurement, C-HFP-voiceChat, A-ref-default, A-ref-measurement), Start/Stop capture, and the "Active capture" banner (§3.11).
- Live route info, sample rate, input level meter.
- Buttons: "Play test tone", "Speak test phrase" (Swedish and English), rate slider.
- **Speaker-distance test** (guided, main measurement of this phase):
  1. User wears AirPods. Another person reads a fixed Swedish test paragraph (ship it in the app, ~20 s) at 1 m, 2 m and 4 m, in a quiet room and with background noise (e.g. a fan or room chatter).
  2. For each run: record, store WAV + speech RMS, noise-floor RMS and estimated SNR (speech segments vs. pauses).
  3. Run for every config in §3.2. B-HQ is run even in Sweden: if HQ is not enabled, the log must show the fallback (that is itself a result).
  4. Show a results table in the app and include it in "Copy results as Markdown".
  5. Also record the wearer reading the same paragraph, to quantify how much the AirPods favour the wearer's own voice.
- **Mic-source sanity check:** confirm the active input really is the AirPods mic (e.g. tap the iPhone body during capture: the built-in mic picks up the vibration, AirPods do not). Do not rely on `currentRoute` alone.
- "Check SpeechTranscriber locales" button: prints `SpeechTranscriber.isAvailable`, `SpeechTranscriber.supportedLocales` and `DictationTranscriber.supportedLocales` and highlights `sv-SE` and `en-US`.

### 3.8 Test material (`testdata/`)
- `testdata/scripts/sv-paragraphs.md`: 3 Swedish paragraphs (~20 s each when read aloud) in a teaching register (science, maths, history), with the exact reference text.
- `testdata/scripts/sv-short-prompts.md`: 30 short items of the kind the product must handle: incomplete phrases and short questions, e.g. "roten ur hundra", "fem plus två", "fotosyntes", "vad är ljusvågor", "när började andra världskriget". Exact reference text per item.
- Noise: one fixed background-noise file (room chatter / ventilation, royalty-free, document its source and licence) played from a speaker at a fixed position and volume; record the measured level in dB with any SPL meter app.
- WAV recordings are **not committed** (size + voices of real people). Store them locally/in a shared drive and list paths in the report.

### 3.9 Speech-recognition accuracy benchmark
Measure real STT precision on the Phase 1 recordings, so the Phase 2 decision is based on data.
- **On device (in the app, Diagnostics → "Run STT benchmark"):** transcribe each stored WAV with `SpeechTranscriber` (if `sv-SE` is supported) and `DictationTranscriber` (`sv-SE`) via `SpeechAnalyzer` file input. Compute **WER** and **CER** against the reference text.
- **Cloud (dev tool on the Mac, not in the app):** `tools/stt-bench/` — a small CLI (Swift package or Python, your choice; justify it) that sends the same WAVs to **ElevenLabs Scribe v2 Realtime** (streamed at real-time speed, `language_code=sv`) and **Deepgram Nova-3** (streaming, `language=sv`), records first-partial latency and final transcript, and computes WER/CER. API keys come from environment variables only (`ELEVENLABS_API_KEY`, `DEEPGRAM_API_KEY`), are never written to files, logs or the repo. If no key is available, skip that provider and say so in the report.
- Shared normalization before scoring (same code for all providers): lowercase, strip punctuation, collapse whitespace, normalise numbers ("100" ↔ "hundra") with a documented rule set. Put the scoring code in one place and unit-test it.
- For the short-prompt set, also record **exact-match rate** (the whole item correct after normalisation), since short items are what question detection depends on.
- Output: `reports/data/phase1-stt-results.csv` (provider, AirPods model, strategy, mode, distance, noise, item, WER, CER, latency) — CSV is small text and may be committed.

### 3.10 AirPods model matrix
Run the distance tests and the STT benchmark on **every AirPods model available** to the product owner. Per press coverage of WWDC25, studio-quality recording covers AirPods 4, AirPods 4 with ANC and AirPods Pro 2 (H2 chip); other models are **not verified**. Record firmware version (Settings → Bluetooth → AirPods → About) for each. The EU restriction does **not** remove AirPods from the test plan: HFP capture of other people's voices is measured on every model regardless.

### 3.11 HQ capability detection and per-test logging (mandatory)
Apple documents a capability API for this. For every test run, read and log:
- `currentRoute.inputs.first` → `portType`, `portName`, `uid`.
- `inputPort.bluetoothMicrophoneExtension` (nil or present) → `highQualityRecording.isSupported` (**can** the port do it) and `highQualityRecording.isEnabled` (**is** it active in this session). Log both; they answer different questions.
- Active session category, **mode**, options, `sampleRate`, `ioBufferDuration`, `inputNumberOfChannels`, and the engine input node's actual format.
- Device region (`Locale.current.region`) and OS version, because the EU restriction's trigger (device region, Apple account country, location, or something else) is **not documented** — this log is how we find out.
- Whether `setPreferredInput` succeeded and what the route looked like 1 s after activation (routes can change after activation).
Show a single "Active capture" banner in Diagnostics: e.g. `AirPods Pro 2 · HFP · mode=measurement · 16 kHz · HQ supported=false enabled=false`.
Every row in `phase1-stt-results.csv` must carry these fields, so no result is ever attributed to the wrong mic or mode.

Apple also notes HQ recording **may increase input latency and is not recommended for real-time communication** — if HQ is available anywhere, measure its input latency against HFP.

### 3.12 System feature vs. developer API (document separately)
Apple's own recording feature (e.g. AirPods studio-quality recording in Voice Memos/Camera) and the third-party API (`bluetoothHighQualityRecording`) are different things. In the report, record separately:
1. Does the system feature appear/work in Sweden on each model (check AirPods settings and record a short Voice Memo)? — manual check, label as such.
2. Does the developer API report `isSupported` / `isEnabled` in our app?
Never infer one from the other.
- Event log list (route changes, interruptions, errors) with timestamps, and "Copy results as Markdown" for the report.

### 3.7 Telemetry
- `os_signpost` / `Logger` categories: `audio.session`, `audio.capture`, `audio.playback`. These will be extended in later phases for the end-to-end latency budget.

## 4. Technical implementation requirements
- Swift 6 language mode, strict concurrency complete; no `@unchecked Sendable` unless justified in a comment.
- Real-time audio thread: no allocations, locks held briefly, no `async` work inside the tap callback — copy samples out and hand off.
- Dependency injection through protocols (`AudioSessionManaging`, `CaptureServicing`, `PlaybackServicing`) so later phases can mock them.
- Errors are typed (`AudioError`) and surfaced to the UI; no `try?` that silently swallows audio-session errors.
- No secrets and no network calls **from the app** in this phase. Only the Mac dev tool `tools/stt-bench/` calls cloud STT, with keys from environment variables.

## 5. Files and components likely to be affected
- `project.yml`, `Lumen/App/LumenApp.swift`, `Lumen/App/AppContainer.swift`
- `Lumen/Core/Audio/AudioSessionManager.swift`, `CaptureConfig.swift`, `CaptureDiagnostics.swift`, `CaptureService.swift`, `AudioFormat.swift`, `RingBuffer.swift`, `PlaybackService.swift`, `AudioError.swift`
- `Lumen/Core/Session/SessionState.swift` (minimal: idle/listening/paused/error)
- `Lumen/Core/Telemetry/Log.swift`
- `Lumen/Features/Diagnostics/DiagnosticsView.swift`, `DiagnosticsModel.swift`, `MicSourceTest.swift`
- `Lumen/Resources/Info.plist`, `Localizable.xcstrings`
- `LumenTests/…`
- `Lumen/Features/Diagnostics/STTBenchmark.swift`, `Lumen/Core/Transcription/Scoring.swift` (WER/CER + normalisation)
- `tools/stt-bench/…` (Mac-only dev CLI)
- `testdata/scripts/sv-paragraphs.md`, `testdata/scripts/sv-short-prompts.md`, `testdata/noise/README.md`
- `reports/…`, `reports/data/phase1-stt-results.csv`, `docs/STATUS.md`, `docs/DECISIONS.md`

## 6. Edge cases
- AirPods not connected when starting (each strategy must degrade gracefully and say what happened).
- AirPods connected/disconnected mid-session; one AirPod removed; AirPods switching to another Apple device.
- Microphone permission denied or revoked in Settings.
- Phone call, Siri, alarm, another app starting audio (music app) during capture.
- Sample-rate change on route change (e.g. 48 kHz → 24 kHz/16 kHz) — converter must be rebuilt.
- Media services reset.
- Screen locked for 10+ minutes; low-power mode.
- AirPods models without high-quality recording support (B must fall back and report it).

## 7. Testing requirements
**Unit tests (CI-able):**
- Format conversion 48 kHz float stereo → 16 kHz Int16 mono (length, amplitude sanity).
- Ring buffer: wraparound, snapshot sizes, concurrent write/read.
- Session state transitions on simulated interruption/route events (via mocks).

**On-device tests (mandatory — record device model, iOS version, AirPods model):**
1. For each strategy × mode: run the speaker-distance test (1/2/4 m, quiet + noisy) and the mic-source sanity check; keep the WAV files (they become the Phase 2 STT test set — do not commit them, list where they are stored).
2. For each strategy: does output stay on AirPods during capture? Subjective audio quality of the test phrase (good / degraded / phone-call quality).
3. Background: lock screen for 10 min while capturing; confirm the ring buffer kept filling (export WAV and check duration).
4. Interruption: receive a call (or trigger Siri) during capture; record resume behaviour.
5. Route: remove AirPods mid-session; reconnect.
6. Playback latency: median of 10 "play requested → first audio" measurements.
7. SpeechTranscriber/DictationTranscriber locale check output (copy the lists).
8. STT benchmark (§3.9) over the full matrix: AirPods model × config (B-HQ, C-HFP-default, C-HFP-measurement, C-HFP-voiceChat, A-ref) × distance (1/2/4 m) × noise (quiet/noisy) × material (paragraphs + short prompts) × provider (Apple on-device, ElevenLabs, Deepgram).
9. Unit tests for WER/CER scoring and Swedish number normalisation.

## 8. Acceptance criteria
- [ ] Project builds with zero warnings in Swift 6 mode and runs on a physical iPhone (iOS 26).
- [ ] All three strategies can be selected and started; failures are explained in the UI, not silent.
- [ ] Capture produces a continuous 16 kHz mono Int16 stream; ring buffer exports a valid 60 s WAV.
- [ ] Test phrase plays in the AirPods **while** capture is running.
- [ ] Capture continues ≥ 10 min with screen locked.
- [ ] Interruption and AirPods-removal are handled as specified.
- [ ] Speaker-distance results (SNR per distance, per strategy/mode) are measured and in the report, and every run's log (§3.11) confirms which mic, mode and HQ state (`isSupported`/`isEnabled`) was actually active.
- [ ] WER/CER and short-prompt exact-match rates exist for every tested combination, in `reports/data/phase1-stt-results.csv` and summarised in the report.
- [ ] Every available AirPods model is tested, with "high-quality capture engaged: yes/no" measured per model.
- [ ] No API key appears anywhere in the repo, logs or reports (grep before pushing).
- [ ] Unit tests pass.
- [ ] Report pushed to `reports/` with a filled-in results table; `docs/STATUS.md` updated; `docs/DECISIONS.md` updated with the recommended default AirPods config for Sweden (and whether D10 holds).

## 9. What to report when finished
Write `reports/YYYY-MM-DD-HHMM-phase1-audio-foundation.md` containing:
1. Summary (5 lines max): how well the AirPods capture a speaker at 1/2/4 m, which config is best in Sweden, whether HQ was ever `isEnabled`, and how confident we are.
2. Results table: AirPods model × config × distance × noise → SNR, speech RMS, verified input, mode, HQ isSupported/isEnabled, sample rate, output quality (HFP output is expected to be narrowband — rate it), notes.
2b. System feature vs. developer API (§3.12), reported separately.
3. Background, interruption, route-change results.
4. Playback latency numbers.
5. `SpeechTranscriber` / `DictationTranscriber` supported locales — explicitly: is `sv-SE` supported by each?
6. Device model, iOS version, AirPods model(s) used.
7. What is verified on device vs. untested.
8. Known bugs, limitations, risks discovered.
9. STT accuracy summary: best provider/mode per distance and noise condition, WER/CER/exact-match, latency.
10. **Recommendation before Phase 2:** default AirPods mode, default Swedish STT provider (and fallback), the maximum practical speaker distance, and which assumptions remain unverified. Use these labels throughout: **tested on device** / **possible with limitations** / **not possible with current technology** / **not yet verified**.

Then reply to the product owner in chat with a **short** summary (what was done, did it work, problems, next step) and the report path only.
