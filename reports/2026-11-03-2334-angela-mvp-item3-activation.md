# Report: MVP item 3 — Activation (hold to ask, auto mode, ask about the last sentence)

Date: 2026-11-03 23:34 · Session: Angela (builder) · Assignment: `prompts/2026-11-03-mvp-sprint-app.md` item 3 (D24)

Evidence labels: **verified in CI** (compiles with zero warnings / tests pass on the GitHub macOS runner), **verified in docs**, **untested on device** (nothing in this report has run on an iPhone).

## 1. Summary
- The app now decides *when* a question goes to the answer engine. **Hold to ask** (push-to-talk) is the default: the words recognised while the button is held become the question; on release the app waits up to 2 s for the recogniser's final result. **Auto** mode runs a local, scored `QuestionGate` on every final transcript segment with a low/medium/high sensitivity, an 8 s cooldown and suppression of anything spoken over our own playback. **Ask about the last sentence** is the manual path. The detected question is shown on the Listening screen as a card ("Detected question … answer engine not connected yet") and handed to `ActivationController.onActivate`, where item 4 plugs in.
- Commit `79b58a5` (+ test fix `7416569`) — **green in [run 41729913430](https://github.com/aronstenlund-code/aronstenlund-airpods-ai/actions/runs/41729913430)** (Xcode 26.6, iOS 26.5 SDK, zero compiler warnings, 36/36 SDK symbols, 21 scoring tests + 193 app tests in 37 suites on the iPhone 17 Pro simulator) — the run that built items 3–9 together.
- **Untested on device.** The gate's weights were tuned on the 30-prompt set and 15 classroom statements in unit tests, not on real speech; checklist §3k measures false triggers and misses.

## 2. What was implemented
| Piece | Files | Notes |
|---|---|---|
| Question gate (ARCHITECTURE §6 stage 1) | `Lumen/Core/Understanding/QuestionGate.swift` | Scored cues over `LumenScoring`-normalised tokens (number words → digits): question mark +0.6, interrogative start (sv/en words + phrases like "kan någon", "can you") +0.55, interrogative inside +0.2, imperative cue ("förklara", "explain", "tell me") +0.5, maths pattern (operator word + number/x/pi) +0.6, short fragment ≤3 tokens +0.35, statement start ("jag", "vi", "idag", "I", "let's"…) −0.3, >14 tokens −0.25; overlap with our playback or empty text never fires. Thresholds: low 0.7, medium 0.5, high 0.3. |
| Settings | `ActivationSettings.swift` | `ActivationMode` (pushToTalk default / auto), `GateSensitivity`, cooldown 8 s, release grace 2 s; persisted in UserDefaults. `ActivationRequest` carries query, trigger, language, gate decision; `trigger.backendMode` maps to the backend's `mode` (`push_to_talk` / `auto` / `text`). |
| Controller | `ActivationController.swift` | Pure state machine over the `Conversation` value with injected time: begin/end push-to-talk (fires immediately when the last words are final, else waits for the next final within the grace, else `flushPushToTalk` uses the open partial), `segmentFinalized` (auto gate + cooldown + playback suppression, ignored while holding), `answerLast`, `submitText` (item 6 entry point), history of 20. |
| UI | `ListeningView.swift`, `ListeningModel.swift` | Activation picker (Hold to ask / Auto) and sensitivity picker with a one-line explanation; a press-and-hold button that turns orange while listening to you; "Ask about the last sentence"; "Detected question" card with trigger and time. All strings in Swedish too. `ListeningModel` routes every final segment through the controller and schedules the grace flush. |
| Docs | `docs/DECISIONS.md` D24, `docs/DEVICE-TEST-CHECKLIST.md` §3k | |

## 3. Test results
| Suite (iPhone 17 Pro simulator, iOS 26.5) | Tests | Result | Basis |
|---|---|---|---|
| `QuestionGateTests` — 27 prompts that must fire at medium (questions, maths, imperatives), 3 bare fragments that fire only at high, 15 classroom statements that never fire at any sensitivity, 8 English questions, question mark alone, digits = number words, low-sensitivity evidence, playback overlap, empty, long rambling question | 6 functions (59 parameterised cases) | pass | **verified in CI** |
| `ActivationControllerTests` — push-to-talk collect/release, wait-for-final, grace flush with partial, late final ignored, nothing said, auto fires + cooldown, playback suppression, PTT mode never auto-fires, sensitivity, answer-last skips playback echo and has no cooldown, text entry, history cap, settings persistence | 13 | pass | **verified in CI** |
| `ListeningActivationTests` — hold produces a pending question, hold ignored when not listening, release waits then flushes (0.2 s grace), auto detection end to end from transcript, ask-about-last + clear | 5 | pass | **verified in CI** |
| Items 1–2 + Phase 1 suites | 96 | pass | **verified in CI** |
| `LumenScoring` (macOS host) | 21 | pass | **verified in CI** |
| Hold-to-ask with real recogniser timing, false triggers on real classroom speech | — | not run | checklist §3k |

## 4. CI iterations
1. Run 41716445406 for `79b58a5` failed to **compile the tests**: `#expect(…, text)` passed a `String` where Swift Testing wants a `Comment` — fixed in `7416569` (two expectations). The app target built with zero warnings.
2. The next run (`16feaf6`, with item 4) was **cancelled by GitHub** before any step ran (macOS pool); re-pushed together with items 5–7.
3. Run 41721203407 (`556d457`) failed in item 7's `LatencyLog` (an OSLog interpolation captured an `inout` parameter) — fixed in `5789b99`.
4. Run 41722435935 (`0313b8f`, items 3–9) was cancelled by GitHub before any step; its re-run failed to compile one more test comment (same `Comment` vs `String` mistake, `f244792`).
5. Run 41726373023 (`858e54f`): everything compiled, 185/187 tests passed; two test fixes (`e163e9b`: sentence splitter closes sentences ending in a quote; PrepStore test compares ids because ISO 8601 drops sub-seconds).
6. Run 41729913430 (`e163e9b`) green.

## 5. Known limitations, risks
- The gate is rule-based and tuned on a tiny set (30 + 15 sentences). Expect misses on indirect questions ("jag undrar om …" is penalised as a statement) and false triggers on rhetorical questions by the lecturer; stage 2 (the backend's `is_question` in auto mode, D20) catches part of that. The weights are explicit constants so they can be tuned after §3k.
- Push-to-talk depends on the recogniser finalising within 2 s of release; if `SpeechTranscriber` is slower on device, the open partial is used (may miss the last word). The grace is a setting (`releaseGrace`).
- Hold-to-ask is a long-press gesture on a `Label`; VoiceOver users get a button trait but no alternative tap-to-toggle yet.
- Auto mode and hold both use the same transcript; while holding, auto never fires (by design).
- No Lock Screen / Action-button control yet (Track D item 10).

## 6. Concerns (per CLAUDE.md)
None new. Both modes work only while the visible indicator is on; auto mode is opt-in and explained in the UI.

## 7. Next
Item 4 — answer engine: `AnswerProvider` protocol; `CloudAnswerProvider` (default, D19) against Kevin's deployed `/answer` SSE contract (anonymous Supabase sign-in, `meta → delta* → done`), `MockAnswerProvider` for CI, guarded `FoundationModelsAnswerProvider` fallback later; clear "answers need internet" message; answers appear in the history and are passed to TTS (item 5).
