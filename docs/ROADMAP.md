# Roadmap — Lumen (codename)

## ⏱ Deadline: first working version of the whole app by 2026-11-10 (set by product owner 2026-11-03)
Deadline, not a day plan: work continuously, start the next priority as soon as one is done.
- **Angela (app):** `prompts/2026-11-03-mvp-sprint-app.md` — core loop first (listening UI → on-device STT → push-to-talk/auto → answer stream → TTS in AirPods), then text mode, notes, prep mode, Track D.
- **Zero cost (D12):** everything on device — SpeechAnalyzer → Foundation Models → AVSpeechSynthesizer. Backend assignment paused.
- **Architect:** `prompts/2026-11-03-architect-trackD-verification.md`.
- **Critical path / bottlenecks:** (1) on-device testing needs the owner's Mac with Xcode + free Apple ID (next week); until then CI is the only verification; (2) the iPhone must support Apple Intelligence for the on-device LLM.
- Phase 2–4 below are now built in parallel inside the sprint; Phase 1 device measurements run in the same device session as the first end-to-end test.

Last updated: 2026-11-03 by the Architect session.

Rule: a phase is **done** only when its acceptance criteria are met on a real iPhone + AirPods and its report is saved in `/reports/`.

---

## Phase 0 — Project setup (Architect) ✅ in progress
- Architecture, risks, roadmap, first assignment (this commit).
- Repo conventions: `CLAUDE.md`, `/docs`, `/reports`, `/prompts`.

## Phase 1 — Audio foundation  *(Milestone M1, Priority 1)*
Goal: prove which capture strategy works and build the reusable audio core.
- Xcode project skeleton (iOS 26, Swift 6) and module layout.
- `AudioSessionManager` with configs B-HQ / C-HFP (default, measurement, voiceChat) / A-ref (see ARCHITECTURE §4.1), HQ capability detection and per-test logging.
- `CaptureService` → 16 kHz mono Int16 stream + 60 s ring buffer.
- `PlaybackService` (TTS-ready) playing through AirPods while capturing.
- Background capture, interruptions, route changes.
- Diagnostics screen + **speaker-distance test** + measurements report.
- **STT accuracy benchmark** (WER/CER, short-prompt exact match) for Apple on-device, ElevenLabs Scribe v2, Deepgram Nova-3, across AirPods models × mic modes × distance × noise.
- Recommendation of default AirPods mode + Swedish STT provider before Phase 2.
**Exit criteria:** measured AirPods pickup (SNR) and Swedish STT accuracy (WER) for a speaker at 1/2/4 m, quiet and noisy, per AirPods model and mode, plus a written recommendation.

## Phase 2 — Transcription  *(M2, Priority 2)*
- `STTProvider` protocol; `AppleSpeechProvider` (SpeechTranscriber + DictationTranscriber fallback).
- Supabase project + `/stt-token` edge function; one cloud provider (ElevenLabs Scribe v2 Realtime or Deepgram Nova-3).
- Bake-off harness: replay recorded test set (sv + en, near/far, noise) through each provider; report WER + latency.
- Live transcript view.

## Phase 3 — Question detection  *(M3, Priority 3)*
- `ContextBuffer`, local `QuestionGate` (sv/en rules, math patterns, short topic phrases), self-playback suppression.
- `/answer` classifier mode with strict JSON output; sensitivity setting.
- Labeled evaluation set (questions vs. non-questions); report precision/recall.

## Phase 4 — Answer + voice loop = **MVP**  *(M4, Priorities 4–5)*
- `/answer` streaming answers (SSE), TTS-normalized text.
- ElevenLabs Flash v2.5 streaming TTS + `AVSpeechSynthesizer` fallback.
- Sentence-level streaming into AirPods; latency instrumentation end-to-end.
- "Answer last" button + text (silent) mode.

## Phase 5 — Premium UI & settings  *(M5, Priority 6)*
- Onboarding + consent, listening screen, voice picker (2–4 voices), speed slider, sensitivity, language, history.

## Phase 6 — Notes & preparation mode  *(M6, Priority 7)*
- "Take notes" explicit command → structured notes + summary, saved and synced.
- Prep mode: upload documents/study material → context + STT vocabulary.

## Phase 7 — Beta & launch  *(M7)*
- TestFlight, cost controls, analytics (privacy-preserving), App Store review prep, privacy policy, pricing.

---

## MVP definition (end of Phase 4)

**In:**
- iPhone (iOS 26+) + AirPods, Swedish and English.
- Start/stop listening session (foreground start, continues with screen locked).
- Room capture via the strategy chosen in Phase 1.
- Live transcript.
- Automatic question detection with a sensitivity setting + manual "answer last" + text input.
- Short, accurate answer spoken in AirPods in < 1.5 s p50; 2–3 voices; speed slider.
- Consent screen, visible listening indicator, no audio stored.
- Backend with anonymous auth, token broker, rate limits.

**Out (later):** notes, prep mode, accounts/sync, payments, more languages, iPad/Watch.

---

## Issue backlog (to be created as GitHub issues once the repo is connected)

| # | Milestone | Title |
|---|---|---|
| 1 | M1 | Xcode project skeleton (iOS 26, Swift 6, module layout, XcodeGen) |
| 2 | M1 | AudioSessionManager with capture configs + HQ capability detection/logging |
| 3 | M1 | CaptureService: 16 kHz mono PCM stream + ring buffer |
| 4 | M1 | PlaybackService through AirPods during capture |
| 5 | M1 | Background capture, interruptions, route changes |
| 6 | M1 | Diagnostics screen + speaker-distance test + Phase 1 report |
| 7 | M2 | STTProvider protocol + Apple SpeechTranscriber/DictationTranscriber |
| 8 | M2 | Supabase project + /stt-token edge function |
| 9 | M2 | Cloud STT provider client (WebSocket) |
| 10 | M2 | STT bake-off harness + report |
| 11 | M3 | ContextBuffer + QuestionGate + evaluation set |
| 12 | M3 | Classifier endpoint + sensitivity |
| 13 | M4 | Streaming answer endpoint + AnswerClient |
| 14 | M4 | TTS providers + sentence streaming + latency report |

---

## Quality bar Q1 — whispered keywords (set by product owner, 2026-11-03)

The product is good enough when the **wearer whispers 1–5 keywords** (e.g. "roten ur hundra", "fotosyntes formel") in a quiet room and gets a correct, short spoken answer in AirPods.

Measurable targets (to be confirmed with data in Phases 1–4):
- Whisper capture: wearer's whisper via AirPods mic transcribed with keyword accuracy ≥ 90 % (sv) — measured in Phase 1/2 with a whispered version of `testdata/scripts/sv-short-prompts.md`.
- Intent from fragments: ≥ 90 % of keyword-only prompts produce the answer a human would expect (labelled set, Phase 3).
- Answer correctness ≥ 95 % on the same set; answer length ≤ 2 sentences.
- Latency: end of whisper → first audio < 1.5 s p50, < 2.5 s p95.
- Public-transport case (product owner, 2026-11-03): user can talk quietly on the metro without disturbing others. Test with recorded metro/street noise (~70–80 dB) as an extra noise condition; report keyword accuracy for whisper vs. low normal voice. Fallback when speech can't work: text mode (Phase 4).

Framing: this is a quality benchmark for low-volume, fragmentary input (library, meetings, studying next to others). Marketing, onboarding and test material do not reference exams or covert use (R6, D8).

## Track D — Discreet interaction (product owner, 2026-11-03)
Goal: natural, quiet use in public without disturbing others. Each item is a measurement or prototype, labelled by evidence status.
- D1 Low-voice capture: whisper vs. low voice vs. normal voice, quiet / office / metro noise, per AirPods model and mic mode (Phase 1).
- D2 Personal vocabulary: keyterm boosting from prep-mode topics to lift accuracy on quiet, fragmentary input (Phase 2 bake-off).
- D3 Fragment understanding: keyword-only prompts with conversation context (Phase 3 eval set).
- D4 Non-voice triggers: AirPods stem press via `MPRemoteCommandCenter` (possible with limitations — app must own Now Playing; untested), head nod/shake via `CMHeadphoneMotionManager` (API exists; gesture reliability untested), Lock Screen / Live Activity quick actions.
- D5 Silent fallback: text input with fast suggestions (Phase 4).
- D6 Output comfort: short answers, adjustable voice volume and speed, answer interrupted instantly by a new question.
Guardrails unchanged: visible listening indicator, consent, no concealment features.
Full analysis, test matrix and priorities: `reports/2026-11-03-1800-creed-track-d-discreet-interaction.md`. Priority 1 (explicit activation = push-to-talk) is built into the MVP sprint.
