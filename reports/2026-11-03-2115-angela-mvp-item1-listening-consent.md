# Report: MVP item 1 — Listening screen + consent

Date: 2026-11-03 21:15 · Session: Angela (builder) · Assignment: `prompts/2026-11-03-mvp-sprint-app.md` item 1

Evidence labels: **verified in CI** (compiles with zero warnings / tests pass on the GitHub macOS runner), **verified in docs**, **untested on device** (nothing in this report has run on an iPhone).

## 1. Summary
- The app now opens on a **consent screen**, then a **Listening screen** with Start/Stop, status, live-transcript and answer-history lists, and an **indicator bar** that stays above every screen while the microphone is live or paused (one-tap Stop/Resume). Diagnostics (Phase 1) is reachable from the toolbar and shares the same microphone state.
- Commit `d65c9cf` — **green on the first push**: [run 41708665338](https://github.com/aronstenlund-code/aronstenlund-airpods-ai/actions/runs/41708665338) (Xcode 26.6, iOS 26.5 SDK, zero compiler warnings, 21 scoring tests + 74 app tests in 12 suites passed on the iPhone 17 Pro simulator).
- **Untested on device.** The transcript and answer lists are empty until item 2 (STT) and item 4 (answer engine) feed them; their data model and feed API exist and are unit-tested.

## 2. What was implemented
| Piece | Files | Notes |
|---|---|---|
| Consent (ARCHITECTURE §12, D21) | `Lumen/Core/Consent/ConsentStore.swift`, `Lumen/Features/Onboarding/ConsentView.swift` | Versioned local record (`version`, `grantedAt`) in UserDefaults; `ConsentPolicy.currentVersion` bump re-shows the screen. Five points: listens only during a session + indicator; audio not stored; answers via Lumen's server → Claude (D19), no answers offline; tell the people around you, not where recording is not allowed (e.g. exams); one-tap stop + withdrawal. "Privacy & consent" sheet shows the same text, the grant date and a confirmed **Withdraw consent** (stops mic, clears transcript, back to the consent screen). |
| Shared session owner | `Lumen/Core/Session/SessionController.swift` | The Phase 1 state machine + audio side effects moved out of `DiagnosticsModel` so Listening and Diagnostics are two views of one object (one owner of `AVAudioEngine`). Foreground check is injected (testable). |
| Transcript + answers model | `Lumen/Core/Session/Conversation.swift` | `TranscriptSegment` (partial replaced in place, final appended with the same identity → no row flicker), `AnswerTurn` (question, answer, latency, source), caps 200/50, `recentText(seconds:)` for the context pack excluding words spoken over our own playback (§4.3). |
| Listening screen | `Lumen/Features/Listening/ListeningModel.swift`, `ListeningView.swift` | Start/Stop (red while active), Resume when paused, status title + reason text, which mic is live ("AirPods Pro · HFP"), level meter, live transcript (partials italic/grey), answer history newest first with time · source · latency, Clear. `startListening` refuses without a current consent record even if the UI were bypassed. |
| Indicator | `Lumen/Features/Listening/ListeningIndicatorBar.swift`, `Lumen/App/RootView.swift` | Top safe-area bar above the whole `NavigationStack`: red pulsing dot + "Listening" + Stop; orange + "Paused — …" + Resume/Stop. Hidden when idle or in error (mic not live). |
| Localisation | `Lumen/Resources/Localizable.xcstrings` | Swedish for all 48 new strings (English source). Checked by script that every literal in the new views has an entry. |
| Device checklist | `docs/DEVICE-TEST-CHECKLIST.md` | Step 10 rewritten for the new first-launch flow; new §3i tests indicator, pause/resume, withdrawal, persistence across relaunch, Swedish texts. |

Not in this item on purpose: a language setting (item 2), text input (item 6), notes (item 8), settings screen. The Phase 1 Diagnostics screen is unchanged in function.

## 3. Test results
| Suite (iPhone 17 Pro simulator, iOS 26.5) | Tests | Result | Basis |
|---|---|---|---|
| `SessionControllerTests` — start (permission → activate → capture), permission denied, background refused, activation/capture failures, stop, interruption with/without resume hint, AirPods removed never auto-resumes, stop while paused, restart after error, event log | 12 | pass | **verified in CI** |
| `ListeningModelTests` — refuses without consent, toggle, toggle while paused, withdraw consent (stop + clear + revoke + refuse), transcript feed, playback-overlap tagging, answers/clear | 7 | pass | **verified in CI** |
| `ConsentStoreTests` — fresh install, persistence across instances, policy version bump, revoke, corrupt data | 5 | pass | **verified in CI** |
| `ConversationTests` — partial replace, finalize identity, empty dropped, caps, recentText, overlap flag, clear | 9 | pass | **verified in CI** |
| Phase 1 suites (unchanged) | 41 | pass | **verified in CI** |
| `LumenScoring` (macOS host) | 21 | pass | **verified in CI** |
| Consent screen, indicator, Start/Stop on a real iPhone + AirPods | — | not run | `docs/DEVICE-TEST-CHECKLIST.md` §3i |

The fakes (`LumenTests/Fakes.swift`) implement the three audio protocols in memory and count calls, so the state machine is tested end to end without a microphone.

## 4. CI iterations
One push, one green run. No compiler warnings or test failures (the only `warning:` lines in the log are Node deprecation notices from `actions/upload-artifact`).

## 5. Known limitations, risks
- Transcript/answer lists are empty in this build (no STT/answer engine yet) — the empty-state texts say so.
- The consent text promises "transcribed on your iPhone" and "answers via Lumen's server → Claude". If item 2 ends up using a cloud STT or item 4 changes the data flow, bump `ConsentPolicy.currentVersion` and edit the text — the screen then re-appears. Don't change the promise silently.
- The indicator bar is a `safeAreaInset` on the root; whether it overlaps the large navigation title nicely on device is **untested on device**.
- Consent lives in UserDefaults: reinstalling the app asks again (intended); restoring from a backup keeps it.
- Diagnostics and Listening share one `config`; Diagnostics' picker therefore changes what "Start listening" uses too (shown in the route line).

## 6. Concerns (per CLAUDE.md)
None new. The consent text names exams explicitly as a place not to use Lumen and tells the user to inform people whose speech is transcribed (R6/R9).

## 7. Next
Item 2 — STT: `STTProvider` protocol, `AppleSpeechProvider` (SpeechAnalyzer: `SpeechTranscriber` if sv-SE supported else `DictationTranscriber`, then `SFSpeechRecognizer` per D18), fed from `CaptureService.chunks`, writing into `ListeningModel.receivePartialTranscript/receiveFinalTranscript`; runtime locale check with clear UI; language setting sv/en.
