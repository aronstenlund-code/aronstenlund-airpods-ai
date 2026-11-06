**QUEUED (Deangelo 18:05, D60): nod to expand.** Head-nod detection on AirPods motion (classifier from Track D spike, nod vs shake, ~4 s window after a short answer that ends with the offer) → request the A-level answer for the same turn; 'mer' as voice fallback; setting to turn off. Unit-test the classifier on synthetic motion data; device behaviour untested.

**QUEUED (Deangelo 17:30, D58): hands-free start + music hand-off.** App Intents/App Shortcuts with Swedish phrases (Starta Lumen, Fråga Lumen, Starta provläge med Lumen, Pausa Lumen), Control Center/Lock Screen control, spoken 'pausa'/'spela musik' → stop + deactivate with notifyOthersOnDeactivation. Unit-test intents where possible; device behaviour untested.

**QUEUED (Deangelo 17:25, D57): feedback.** 'Rapportera' on every answer + voice command in hands-free modes (backend returns `report: true`) → send previous turn verbatim to `/feedback`, speak 'Skickat'. Settings → 'Feedback & förslag' (free text). Onboarding + Settings opt-in 'Dela historik för att förbättra appen' (off by default; off → delete shared rows). Never include other people's speech.

**QUEUED (Deangelo 2026-11-06, D55): microphone source setting** — AirPods vs iPhone mic (A2DP output to AirPods), per-mode defaults, route logged, Diagnostics comparison run (same 5 sentences, own voice + other person at 1.5 m, record Scribe transcript for WER). Unit-test the session-config builder. Sparläge not required (budget reset), but keep commits small.

**QUEUED (D49):** Settings → Historik (list, delete one, 'Radera all historik' with in-app confirm, 2-year auto-delete) and Settings → Minne (list/edit/delete, 'Radera allt minne', save from `memory_add`, send `memories` with each request, 2-year expiry). Privacy text update. Sparläge.

**QUEUED (Deangelo 08:45, D48): summaries only.** Transcripts and answers live only in memory for the session and are wiped at session end. History/notes store the backend's `summary` per Q/A (or a local fallback summary for on-device answers) — remove saving of verbatim transcripts/answers. Unit-test that nothing verbatim reaches disk. Sparläge.

**QUEUED (Deangelo 17:55, D43, replaces the Rizzläge part of D42): live wingman.** Session on the StudyMachine loop with: rolling 2-min transcript in memory with speaker tag (wearer vs other by input level — make the threshold a setting and log it), triggers `other_spoke` (other person's turn ended) and `stall` (~4 s silence), style picker (5 styles), interests/profile field, speak only the best suggestion at low volume and only during a pause, never over speech, all 2–3 options on the Live Activity, stem/'nästa' to hear the next, on-device counts of used styles (no content stored), transcript wiped at session end, indicator always visible, onboarding text recommending telling others. Unit-test triggers, speaker tagging heuristic on synthetic levels, and the 'never talk over speech' rule. Sparläge.

**QUEUED (Deangelo 16:30, D42 revised):** mode picker for the hands-free loop: Provläge / Intervjuläge / Rizzläge. Intervjuläge: setup = role or pasted job ad; in-session the app listens for the question and plays a suggested answer outline, then feedback after the user's answer; prep screen with likely questions + model answers. Rizzläge: setup = scenario; start screen 'Testa med en kompis – berätta att appen lyssnar' with one-tap confirm; listens to the friend and plays a short suggestion of what to say next. Send `persona` + `persona_setup`. Reuse StudyMachine, no new audio code. Unit tests, CI green, short report. Sparläge.

**ALSO QUEUED (Deangelo 11:50, D37, after Pluggläge):** *Målbeskrivning* (paste/import course goals into prep mode; send compact `goals`) and *Egna kommandon* (list editor + voice "spara kommando <ord>: <instruktion>"; persistent on device; STT-tolerant keyword match; send matched `commands`). Unit-test matching and storage. Sparläge.

**NEXT TASK (Deangelo 2026-11-04 11:35, D36): Pluggläge — hands-free tutor session.** Toggle button on the listening screen (+ Live Activity/Control) starts/ends a session. Loop: listen → VAD end-of-turn (~800 ms, setting) → send `mode: "tutor"` + full session `recent_qa` to /answer → stream TTS → resume listening automatically. Barge-in: user speech during TTS stops playback and starts a new turn. Suppress own playback from STT (gate input while speaking; evaluate `.voiceChat` AEC config). Auto-end after 10 min silence. Indicator always visible. State machine fully unit-tested; device behaviour untested. Coordinate with Kevin: backend must accept `mode: "tutor"` (pedagogical D35 study style, may end with one short check question). Sparläge, CI green, short report.

# Claude Code assignment (Angela) — MVP sprint: full core loop in the app

Approved by: CREED, 2026-11-03 17:50. **Deadline: working first version of the whole app by 2026-11-10.** This assignment has priority over `prompts/2026-11-03-trackD-spike.md` (Track D items not listed here come after the core loop works).
**Update 2026-11-04 10:10 (D33, priority after the core flow): easy switch to music.** Pause/Resume button that fully releases the audio session (`notifyOthersOnDeactivation`), interruption from other apps → paused state with one-tap resume, never steal audio back. Lock Screen/Control Center control in the same item. Unit-test the state machine; device behaviour is untested until a device run.
**Update 21:40 (D23): voice picker with three Swedish ElevenLabs voices** (names from backend `GET /voices`, preview button, saved choice) + Apple voice as fallback/option — part of item 5.
**Test device (product owner, 18:30):** iPhone 14 Pro, iOS 26.5 — **no Apple Intelligence**, so the Foundation Models path cannot be tested on our device. Priority: the cloud path (Kevin's backend) is the critical path for the first device test; build Foundation Models as a guarded optional provider only after the core loop works. Without network the app must say clearly that answers need internet.
**Update 18:25 (D19):** when the backend is reachable, `CloudAnswerProvider` (Claude via backend) is the default on **all** devices for best answer quality; Foundation Models is the offline/fallback path on Apple Intelligence devices.
**Update 18:20 (D18): must run on iPhone 12 and later.** Answer engine is tiered: Foundation Models when `SystemLanguageModel.default.availability == .available`, otherwise `CloudAnswerProvider` calling the free backend (`prompts/2026-11-03-mvp-sprint-backend.md`, built in parallel by Kevin Malone; use its SSE contract, mock until the URL exists). STT fallback chain: `SpeechTranscriber.isAvailable` → `DictationTranscriber` → `SFSpeechRecognizer`. TTS: `ElevenLabsTTSProvider` via backend when available, else Apple TTS. Deployment target stays iOS 26 (iPhone 11+ supported by iOS 26).

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
