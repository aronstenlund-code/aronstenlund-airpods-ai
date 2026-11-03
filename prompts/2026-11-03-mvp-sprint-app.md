# Claude Code assignment (Angela) — MVP sprint: full core loop in the app

Approved by: CREED, 2026-11-03 17:50. **Deadline: working first version of the whole app by 2026-11-10.** This assignment has priority over `prompts/2026-11-03-trackD-spike.md` (Track D items not listed here come after the core loop works).
**Zero-cost rule (product owner, 18:00): nothing may cost money.** No paid APIs, no Apple Developer Program, no paid services. MVP runs fully on device: SpeechAnalyzer (STT) → Foundation Models (on-device LLM, Apple Intelligence; Swedish supported since iOS 26.1 per Apple) → AVSpeechSynthesizer (TTS). No backend in the MVP (decision D12).

**Step 0 (now, ~15 min):** CI on `main` is red: `Packages/LumenScoring` tests fail (`cerHandComputed` expects 0.1 but gets 0.125; `NormalizerTests.normalizedString`). Fix (check whether the test or the code is wrong), get CI green, then push your Phase 1a report + STATUS update. Then start item 1 immediately.

After step 0: Then work continuously: when an item is done (CI green), start the next one immediately. Push after every completed item so CREED can follow progress.

## Goal
Core loop end to end: **AirPods mic → transcription → question understood → AI answer → spoken in AirPods**, plus the minimum UI to use it. Whole-flow first, polish later.

## Order of work
1. **Listening screen + consent** — onboarding consent screen, Start/Stop listening, always-visible listening indicator, live transcript, answer history. Simple, clean SwiftUI.
2. **STT (on-device first)** — `STTProvider` protocol; `AppleSpeechProvider` using SpeechAnalyzer: `SpeechTranscriber` if `sv-SE` is supported, else `DictationTranscriber`; feed `AnalysisContext.contextualStrings` from prep topics (≤100). Runtime locale check with clear UI if Swedish is unavailable. Language setting sv/en.
3. **Activation** — two modes: (a) **push-to-talk** (hold/tap button in app; this is the default MVP trigger — fewest false answers, best for low voice); (b) **auto** (local `QuestionGate`: Swedish/English question words, "?", maths patterns, short topic fragments, cooldown, self-playback suppression).
4. **Answer engine (on device)** — `AnswerProvider` protocol. Default `FoundationModelsAnswerProvider`: `LanguageModelSession` with instructions for short spoken answers (max 2 sentences, same language, numbers written for TTS), reconstruct-then-answer for fragments using a `@Generable` struct `{reconstructedQuestion, confidence, isQuestion, answer}` (or streaming text if structured output is too slow — measure), context pack (last ~60 s transcript, last 3 Q/A, prep terms). Check `SystemLanguageModel.default.availability` and `supportsLocale(_:)`; show a clear message if Apple Intelligence is off/unsupported (device must be Apple Intelligence capable). Keep a `MockAnswerProvider` for CI tests. A cloud provider is out of scope (cost) — keep the protocol so one can be added later.
5. **Voice output** — `TTSProvider` protocol; `AppleTTSProvider` (`AVSpeechSynthesizer.write` → `PlaybackService`, Swedish + English voices, voice picker, speed slider); speak sentence by sentence as tokens arrive; new question interrupts current answer.
6. **Text mode** — type a question, get the answer spoken or shown silently.
7. **Latency instrumentation** — end of user speech → first audio, logged per answer, shown in a debug overlay.
8. **Notes (minimal)** — "Save transcript + answers" as a note, local only.
9. **Prep mode (minimal)** — paste text or import a PDF/text file → extract key terms (on device, simple frequency + capitalised terms) → contextual strings + context pack.
10. Then Track D items: Lock Screen/Action-button Control for push-to-talk, activation probes (stem press), head-gesture experiment.

## Rules
- Everything in CLAUDE.md applies (Swift 6, no secrets, no concealment features, indicator always visible).
- CI must stay green with zero warnings after every push. Unit tests for QuestionGate, context pack, sentence splitter, activation state machine.
- Status labels in reports: verified in CI / untested on device. Never mark a feature "done" in STATUS until it has run on a real iPhone + AirPods.
- Keep `docs/DEVICE-TEST-CHECKLIST.md` (Swedish) current so the first device session tests the whole loop, not only Phase 1 measurements.

## Report
One short progress report per finished item group is fine (`reports/YYYY-MM-DD-HHMM-angela-mvp-<item>.md`), always with STATUS update.
