# Angela — crash when the microphone starts, callbacks off the main actor, D71

Date: 2026-11-07 · Assignment: Aron (chat), priority 1 before D69 · Device: **none this session**. Aron's crash logs
came from an iPhone 14 Pro on iOS 26.5, installed with Sideloadly. AirPods model not stated.

**Result:** the cause of the crash is fixed in code and covered by a test that runs in CI. **Unverified on device**
until Aron installs the new `Lumen-unsigned.ipa`. Provläge no longer ends after 10 minutes of silence (D71).

## Cause
Aron reported 9 crashes between 16:11 and 16:19, as soon as the microphone started, in every mode: EXC_BREAKPOINT on
`RealtimeMessenger.mServiceQueue`, in `_dispatch_assert_queue_fail` ← `_swift_task_checkIsolatedSwift` ←
closure #1 in `CaptureService.installTap(on:continuation:)`. The tap closure was written inline in a `@MainActor`
class, so it inherited main-actor isolation. `AVAudioNodeTapBlock` is not `@Sendable`, so Swift 6 inserts a run-time
isolation check, and that check traps when Core Audio calls the block on its real-time queue. CI never called a real
tap, which is why it stayed green. **Verified in docs** (the stack trace matches Swift 6's dynamic isolation check).

## What changed
Every block or closure that iOS calls on its own queue, and that was created inside a `@MainActor` type, is now made
in a `nonisolated static func` and typed `@Sendable`:

| Where | Callback | Change |
|---|---|---|
| `CaptureService.swift` | input tap (the crash) | `tapBlock(for: CaptureTapContext)` |
| `PlaybackService.swift` | latency probe tap on `timePitch` | `probeTapBlock(_:)` |
| `PlaybackService.swift` | `AVSpeechSynthesizer.write` buffer callback (Apple voice) | `ttsBufferCallback(_:)` |
| `PlaybackService.swift` | `scheduleBuffer` completion (`.dataPlayedBack`) | `playedBackHandler(_:)`, which hops to the main actor with a `Task` |
| `LegacySpeechProvider.swift` | `recognitionTask` result handler | `resultHandler(_:)` |
| `LegacySpeechProvider.swift` | `SFSpeechRecognizer.requestAuthorization` | `requestAuthorization()` |

**Checked and left as they were:**
- `AVAudioSession` and `AVAudioEngineConfigurationChange` notifications are delivered on `queue: .main`, which is the
  main actor.
- The level timer runs on the main run loop.
- Every `AsyncStream` `onTermination` closure is already `@Sendable`.
- `PCMConverter` runs its input block synchronously on the caller's thread and is not actor isolated.
- Scribe's WebSocket uses async `receive()`, `/answer` and `/tts` use `bytes(for:)`, and permissions use the async
  API.
- The Live Activity and the Control are only reached through async ActivityKit and App Intents calls.
- No URLSession delegate, CMHeadphoneMotionManager or SpeechAnalyzer callback closure exists in the code.

**Test:** `LumenTests/AudioCallbackIsolationTests.swift` calls each of the six blocks from a background
`DispatchQueue`, the way the system does. If one of them becomes main-actor isolated again, the run-time check traps
and the CI test run fails. The capture test also checks that buffers are converted into chunks off the main thread.

**D71 (owner decision): Provläge never ends by itself.** `StudyTuning.autoEndSilence` is now optional and nil by
default, `study.autoEndMinutes` defaults to 0 ("never"), and the setting still takes 1–60 minutes. Settings shows
*Auto-end after silence: never*. An earlier stored choice of 1–60 minutes is kept, but the old default of 10 was never
stored, so it does not come back. The tests that cover a chosen auto-end now set it themselves, and a new test checks
that one hour of silence does not end the session.

## Test results
- Commit `4a50887` (crash fix + D71): the app built, but the test step failed twice. The first time,
  `nonisolated(unsafe)` on a `Sendable` `AVAudioTime` was a warning, and warnings are errors (fixed in `e9d85d4`).
  The second time, an old Provläge flow test assumed the 10-minute default (fixed in `de2e362`, which also adds a test
  that silence never ends Provläge by default).
- **Green:** run 42389418030 on `876cb69` (it includes the fixes above). Build, unit tests and the unsigned archive
  passed. New ipa: artifact `Lumen-unsigned`,
  https://github.com/aronstenlund-code/aronstenlund-airpods-ai/actions/runs/42389418030/artifacts/13581660226
  (available until 2026-11-21).
- **Not tested on device.**

## Known limits and risks
- Other crashes may only show up once the microphone runs: Scribe, playback in AirPods, the Live Activity. The
  callbacks I could find are fixed. The first device run after this tells.
- The Apple voice fallback and `SFSpeechRecognizer` used the same pattern and would have crashed too. They are fixed
  but have never run on a device.

## Other
- The push contains only my commit, made on top of `origin/main` in a temporary worktree. Kevin's commit `ee4d7b8`
  sits unpushed in the shared checkout, and pushing it would have started a backend deploy he had not started
  himself.
- D69 (calibration, mode switch) is built locally but not pushed, as asked. It will get its own decision number when
  it is committed, since D71 is now the owner's Provläge decision.

## Next session
Aron: install the new `Lumen-unsigned.ipa` (steps in `docs/INSTALL-SIDELOADLY.md`) and start the microphone. If it
crashes again, send the new crash log. After that: finish D69.
