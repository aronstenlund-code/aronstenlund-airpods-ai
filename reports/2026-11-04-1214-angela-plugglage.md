# Report: Pluggläge — hands-free tutor session (D36, D38)

Date: 2026-11-04 12:14 · Session: Angela (builder) · Assignment: top of `prompts/2026-11-03-mvp-sprint-app.md` (Deangelo 2026-11-04 11:35)

Evidence labels: **verified in CI** (compiles with zero warnings / tests pass on the GitHub macOS runner against fakes), **untested on device** (no microphone, AirPods or real recogniser has run this), **untested against the live backend**.

## 1. Summary
- One tap on **Pluggläge** starts a hands-free session (starting the microphone if needed); one tap ends it. Loop: listen → the user speaks → 0.8 s of silence ends the turn → `mode: "tutor"` with the whole session's `recent_qa` to `/answer` → the answer streams to TTS → back to listening without touching the phone. Talking while the assistant speaks (≥ 0.4 s) stops it and starts a new turn. While the assistant speaks, the recogniser gets no input. After 10 minutes without speech the session ends **and the microphone is released** (my reading of "sparläge": nothing runs or costs anything while nobody studies). Indicator and Live Activity show the ordinary listening state throughout.
- Commits `95626ee` (Pluggläge), `5dbc908` (floor fix) and `b0d0ec6` (D37) — **green in [run 41817986402](https://github.com/aronstenlund-code/aronstenlund-airpods-ai/actions/runs/41817986402)** (Xcode 26.6, iOS 26.5 SDK, zero compiler warnings, 36/36 SDK symbols, 21 scoring tests + 249 app tests in 54 suites on the iPhone 17 Pro simulator).
- **Untested on device.** The VAD thresholds, the 0.8 s endpoint against the real recogniser's final-result delay, barge-in over HFP (does the AirPods mic hear the user over our own playback?), and the `.voiceChat` echo-cancellation option are exactly what checklist §3r measures. The backend does not accept `mode: "tutor"` yet (Kevin's `validate.ts` whitelists auto / push_to_talk / text); until it does, the app retries once as `push_to_talk`, so the session works but answers are not yet in tutor style (D35 study style comes from Kevin's side).

## 2. What was implemented
| Piece | Files | Notes |
|---|---|---|
| State machine | `Lumen/Core/Study/StudyMachine.swift` | Pure, time injected. Noise floor follows quieter input at once and rises 1 dB/s; speech = floor + 12 dB and above −50 dBFS held 120 ms; end of turn = 0.8 s silence with a final result, else up to +0.7 s for the recogniser; a final arriving after the silence closes the turn at once; noise without words is dropped; barge-in = 0.4 s sustained speech during `.speaking`; auto-end after 10 min without speech. `StudySettings` (endpoint 0.5–1.5 s, auto-end minutes, voiceChat option) persisted in UserDefaults. |
| Controller | `StudySessionController.swift` | Subscribes to the capture fan-out and feeds one level reading per 40 ms chunk (silence included, so no timers); forwards transcript partial/final and the answer/speech lifecycle. |
| Tutor requests | `ActivationSettings.swift`, `CloudAnswerProvider.swift`, `ListeningModel.swift` | `ActivationTrigger.tutor` → `mode: "tutor"`; context carries the whole session's Q/A (backend cap 6 pairs); a 400 for `tutor` is retried once as `push_to_talk` (logged). |
| Own-voice suppression | `TranscriptionCoordinator.swift` | `setInputGated(true)` drops capture chunks before the STT provider while the assistant speaks; level readings keep flowing for barge-in. `.voiceChat` capture config (AEC) is an opt-in setting applied when Pluggläge starts the microphone. |
| Wiring | `ListeningModel.swift`, `Speaker.swift` | Start/end, turn → request, speech started → gate + `.speaking`, speech finished (`Speaker.onFinished`) or silent answer → back to listening, barge-in → cancel answer + stop TTS + open gate, auto-end → stop listening + notice; pause/stop/error end the session; the question gate is off during it. |
| UI | `ListeningView.swift`, `SettingsView.swift` | Purple Pluggläge button, phase line ("din tur – prata bara" / "jag hör dig …" / "tänker …" / "talar – prata för att avbryta"), notice after auto-end; Settings section with endpoint slider, auto-end stepper, echo-cancellation toggle. Swedish strings. |
| Docs | `docs/DECISIONS.md` D38, `docs/DEVICE-TEST-CHECKLIST.md` §3r | |

Not done: a dedicated Pluggläge button in the Live Activity / Control (the existing Pause/Resume control is unchanged; the activity shows listening/paused), and the backend side of `tutor` (Kevin).

## 3. Test results
| Suite (iPhone 17 Pro simulator, iOS 26.5) | Tests | Result | Basis |
|---|---|---|---|
| `StudyMachineTests` — onset hold, endpoint with final, partial + grace, late final closes at once, noise without words, barge-in needs 0.4 s, thinking ignores levels, auto-end at 600 s, speech postpones auto-end, floor adaptation, absolute minimum | 10 | pass | **verified in CI** |
| `StudySettingsTests` | 1 | pass | **verified in CI** |
| `StudyModeTests` — start starts the mic, a turn becomes a `tutor` request with 5 Q/A and returns to listening, own speech gates STT until finished, barge-in stops speech and opens a new turn, silence auto-ends and releases the mic, user end keeps listening / pause ends it, question gate off | 7 | pass | **verified in CI** |
| `InputGatingTests`, `TutorModeFallbackTests` | 2 | pass | **verified in CI** |
| Everything before this task | 216 | pass | **verified in CI** |
| Real speech, AirPods, recogniser timing, echo over HFP | — | not run | checklist §3r |

## 4. CI iterations
1. Run 41816464542 (`95626ee`): everything compiled with zero warnings, 228 tests passed, **one failed** — `speechPostponesTheAutoEnd`. The test exposed a real flaw: the noise floor rose 1 dB/s even during speech and jumped after a gap in readings, so a long question (> ~12 s) or a resumed capture would stop counting as speech. Fixed in `5dbc908`: the floor rises only on clearly quiet frames (below floor + 6 dB) and by at most one second per update.
2. Run 41817986402 (with D37) green.

## 5. Known limitations, risks
- Turn end relies on the level-based VAD plus the recogniser's final; if `SpeechTranscriber` finalises later than 1.5 s after silence on device, the partial text is sent (may miss the last word). The endpoint and grace are settings/constants to tune in §3r.
- Barge-in detection runs on the AirPods mic level while our audio plays in the ears; leakage into the mic is unknown (ARCHITECTURE §4.3 assumption) — a too-low threshold would make the assistant interrupt itself. The 0.4 s hold and the +12 dB margin are starting points.
- Gating drops ~0.4 s of the user's barge-in speech before the gate opens; the first word may be missing from the transcript.
- No tutor-style answers until Kevin's backend accepts `mode: "tutor"` (and D35/D37 prompt work lands there).
- Live Activity shows the generic listening state; no Pluggläge toggle outside the app yet.
- Notices are English only (string catalog not yet used for engine texts).

## 6. Concerns (per CLAUDE.md)
None new. The session is explicit (one tap), the indicator stays on, the microphone is released after the silence timeout, and only transcribed text leaves the phone.

## 7. Next
D37 (queued by Deangelo): *Målbeskrivning* (course goals in prep mode → compact `goals`) and *Egna kommandon* (command list editor + voice "spara kommando …", STT-tolerant keyword match → matched `commands`), persisted on device, unit-tested.
