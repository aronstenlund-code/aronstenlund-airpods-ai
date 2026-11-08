# Angela — A1: test hooks for Toby (WAV instead of the microphone, an E2E test target)

Date: 2026-11-08 · Assignment: `prompts/queue/angela.md` A1 · Device: **none** (Simulator hooks only)

**Result:** the hooks are built. Toby can feed WAV files through the app's real chain in the Simulator, and he has
his own test target. **The Simulator is no device verification.** CI: see the end of this report.

## What was built
| # | Change | Status |
|---|---|---|
| 1 | **`FileCaptureService`**, details below the table. | verified in CI |
| 2 | **The app in the Simulator on files**, details below the table. | untested (no Simulator run with the app) |
| 3 | **Toby's place: `AppTests/E2E/`**, details below the table. | target untested in CI (by design) |

**1. `FileCaptureService`** (`Lumen/Core/Audio/FileCaptureService.swift`, `#if DEBUG`)
- **The same `CaptureServicing` protocol as the microphone:** chunks, ring buffer, level, start/stop, export.
- **Input:** reads WAV/CAF/M4A at any rate and channel count, mixed to mono and linearly resampled to 16 kHz Int16.
- **Output:** 40 ms chunks in real time, or as fast as possible for offline checks.
- **Between and after files:** a silent gap between files; afterwards silence (so pause detection goes on) or a loop.
- **For the test log:** `currentFile`, `chunksSent`, `onFinishedFiles`.

**2. The app in the Simulator on files**
- **Turning it on:** in Debug, `AppContainer` uses the files when `LUMEN_AUDIO_FILES` is set (or the launch argument
  `-LumenAudioFiles`), otherwise the microphone as before. `LUMEN_AUDIO_LOOP=1` repeats the files (for A2's 60
  minutes) and `LUMEN_AUDIO_GAP` sets the gap.
- **Everything after the microphone is the real chain:** the gate and Silero, Scribe through `/stt-token` with the
  mode's parameters and keyterms, utterance joining, QuestionGate or Provläge, `/answer`.
- **Release:** the microphone only, and the file source is not compiled in.

**3. Toby's place: `AppTests/E2E/`**
- **What is there:**
  - A new test target `LumenE2ETests` with its own scheme `LumenE2E` (`project.yml`).
  - A README with how to use the hook and how to run it.
  - A starting test (`FileCaptureE2ETests.swift`).
  - An `Audio/` folder that is not compiled.
- **Not on every push:** the push workflow builds and tests only the `Lumen` scheme, because E2E reaches the live
  Scribe and `/answer`. It is for manual and nightly runs.

## Tests
`LumenTests/FileCaptureTests.swift` runs on every push:
- **Chunks:** two files plus their gaps come through as 40 ms chunks, the second file plays, and the ring buffer
  fills.
- **Resampling:** 48 kHz is resampled to 16 kHz with the level kept.
- **Default:** without the variable the app uses the microphone.

## For Toby
**What is open:**
- **Building `LumenE2ETests`:** no CI job builds it yet, so a compile error in `AppTests/E2E/` shows up only when you
  run it. Add a nightly `xcodebuild test -scheme LumenE2E` (or ask me).
- **Missing hooks:** tell me in your report, for example a launch argument for the mode or exam, timings written to a
  file (the D87 recording already writes them), or a fake answer engine for offline runs.

## Known limits
- **Resampling:** linear resampling is enough for speech recognition tests, not for audio quality measurements.
- **Route:** the Simulator has no AirPods route: HFP, voice processing and echo cancellation are not exercised.

## Next session
A2 (D86 rest) in the queue.
