# Claude Code assignment (Angela) — MVP sprint: full core loop in the app

Approved by: CREED, 2026-11-03 17:50. **Deadline: working first version of the whole app by 2026-11-10.** This assignment has priority over `prompts/2026-11-03-trackD-spike.md` (Track D items not listed here come after the core loop works).
Start: as soon as your Phase 1a report is pushed. Then work continuously: when an item is done (CI green), start the next one immediately. Push after every completed item so CREED can follow progress.

## Goal
Core loop end to end: **AirPods mic → transcription → question understood → AI answer → spoken in AirPods**, plus the minimum UI to use it. Whole-flow first, polish later.

## Order of work
1. **Listening screen + consent** — onboarding consent screen, Start/Stop listening, always-visible listening indicator, live transcript, answer history. Simple, clean SwiftUI.
2. **STT (on-device first)** — `STTProvider` protocol; `AppleSpeechProvider` using SpeechAnalyzer: `SpeechTranscriber` if `sv-SE` is supported, else `DictationTranscriber`; feed `AnalysisContext.contextualStrings` from prep topics (≤100). Runtime locale check with clear UI if Swedish is unavailable. Language setting sv/en.
3. **Activation** — two modes: (a) **push-to-talk** (hold/tap button in app; this is the default MVP trigger — fewest false answers, best for low voice); (b) **auto** (local `QuestionGate`: Swedish/English question words, "?", maths patterns, short topic fragments, cooldown, self-playback suppression).
4. **AnswerClient** — streams from the backend `/answer` endpoint (SSE, contract in `prompts/2026-11-03-mvp-sprint-backend.md`); sends the fragment + context pack (last ~60 s transcript, last 3 Q/A, prep topics, language). Until the backend URL exists, a `MockAnswerProvider` behind the same protocol so the full loop runs in the app.
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
