# AppTests/E2E: Toby's end-to-end tests

**Owner:** Toby (app tester) owns everything in this folder. Angela set it up (A1).

**What it is for:** feeding known audio through the app's real chain after the microphone, in the Simulator:
- the gate and Silero VAD;
- Scribe (live, through `/stt-token`) with the mode's parameters and keyterms;
- utterance joining;
- QuestionGate or Provläge turns;
- `/answer`.

**Limits:**
- The Simulator is **no device verification**: no AirPods, no Bluetooth route, no real echo.
- These tests reach the live backend and cost money. They are a separate target and scheme (`LumenE2ETests` /
  `LumenE2E`), so the push workflow never runs them. Run them by hand or nightly.

## The hook: `FileCaptureService`
`Lumen/Core/Audio/FileCaptureService.swift` (Debug and test builds only) implements `CaptureServicing`, the same
protocol as the microphone.

- **Input:** any WAV, CAF or M4A file, decoded to 16 kHz mono Int16.
- **Output:** 40 ms chunks, in real time (`.realTime`) or as fast as the consumer reads (`.asFastAsPossible`).
- **Between and after files:** a silent gap between files (`gapSeconds`); afterwards silence (`silenceAfter`) or a
  loop (`loop`).
- **For your log:** `onFinishedFiles`, `currentFile` and `chunksSent`.

**Two ways to use it:**
1. **In a test:** build the chain yourself, as `AppContainer` does, with
   `FileCaptureService(files: [...], pace: .realTime)` passed to `SessionController(capture:)`. `AppTests/E2E/
   FileCaptureE2ETests.swift` is a starting point.
2. **The whole app in the Simulator:** set the environment variable
   `LUMEN_AUDIO_FILES=/abs/path/a.wav:/abs/path/b.wav` (or the launch argument `-LumenAudioFiles …`).
   - `LUMEN_AUDIO_LOOP=1` repeats the files (A2's 60-minute test).
   - `LUMEN_AUDIO_GAP=2.5` sets the silence between files in seconds.
   - The app then listens to the files instead of the microphone. Settings → Diagnostik shows
     "WAV files (n) · 16000 Hz".

**Running:**

```bash
xcodebuild test -project Lumen.xcodeproj -scheme LumenE2E -destination 'platform=iOS Simulator,name=iPhone 17'
```

**Audio:**
- Put test audio in `AppTests/E2E/Audio/`. It is excluded from the target's sources.
- Kevin's D88 recordings are his K3; until then, TTS files.

## What Angela can add
Tell me in your report what is missing, for example a hook for the answer engine, timings in a file, or a launch
argument for the mode.

## Screens/: screen tour (T3, Toby)

`Screens/ScreenTourTests.swift` is an XCUITest that walks the app the way a user does. It uses labels only and no hooks inside the app.

- **Path:** first start → share prompt → Start without and with an exam → every page under Inställningar → Lyssnar in Frågor → Byt läge → the first screens of Intervju, Socialt and Rizz 18+ → Provläge's first start.
- **Output:** a screenshot of every screen. A screen the tour cannot reach fails the test, and the tour goes on. `APP:` in a failure marks a finding about the app.
- **Target:** `LumenScreenTour` (UI tests) lives in `project-e2e.yml`, which includes `project.yml` unchanged.
- **Compile flag:** the file compiles only with `LUMEN_SCREEN_TOUR`, so in `LumenE2ETests` (a unit-test bundle that takes all of `AppTests/E2E`) it is empty.
- **Runner:** `scripts/apptest/screens.sh [config ...]`. Configs: `pro-light`, `pro-dark`, `pro-light-storsta-text`, `pro-dark-storsta-text`, `liten-light`, `liten-dark`, `pro-light-mikrofon-nekad`.
- **CI:** `.github/workflows/apptest-screens.yml` runs on app pushes to main, nightly, by hand, and on two configs on `toby/**` branches. The artifact `apptest-screens` holds `index.html` with one row per screen and one column per config.
- **Run settings:** the app runs in Swedish with Apple's recogniser (`-stt.useCloud NO`), so no paid Scribe session is opened.

**Simulator only.** A screenshot is never a verification on a device.
