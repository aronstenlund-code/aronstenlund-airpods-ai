# Report: Track D — Discreet interaction (feasibility, test plan, priorities)

Date: 2026-11-03 18:00 · Session: CREED (project supervisor) · Type: research + plan (no code)

## 0. Goal (product owner, 2026-11-03)
The user can interact with the AI naturally and discreetly in everyday life, including public places (metro, office, café), without speaking loudly or disturbing others. Guardrails unchanged: visible listening indicator, consent, no concealment features.

Evidence labels used below: **VERIFIED-DOCS** (stated in official Apple/provider docs), **POSSIBLE-UNTESTED** (no doc says it works for our case; plausible, must be tested on device), **NOT POSSIBLE** (docs say it does not work for our case with current technology), **UNKNOWN** (no reliable source found).

## 1. Findings per capability

### 1.1 Low voice and whisper capture
| Claim | Status |
|---|---|
| Apple publishes no specification for AirPods mic performance on low/whispered speech | VERIFIED-DOCS (absence: nothing in AVAudioSession/AirPods docs) |
| In the EU the third-party AirPods mic path is HFP (high-quality recording not supported in the EU) | VERIFIED-DOCS (see `reports/2026-11-03-1615-architect-eu-hq-restriction.md`) |
| Whispered speech is much harder for ASR than voiced speech; main cause is missing glottal (voiced) information; augmentation gives 18–23 % *relative* WER reduction | VERIFIED-DOCS (research literature, sources 6–7) — absolute numbers for our STT providers: UNKNOWN |
| AirPods voice processing / wearer-voice detection reacts to whisper the same way as to voiced speech | UNKNOWN — must measure |
| Wearer's own low voice is captured far better than other people 1–4 m away | POSSIBLE-UNTESTED (AirPods mics are designed for the wearer's voice) |
| Silent-speech / lip-reading AirPods | NOT POSSIBLE today: only rumours/patents about future hardware; no shipped feature, no API (source 9) |

**Conclusion:** design the primary experience around **low normal voice** (quiet, voiced speech); treat **whisper** as a measured stretch goal. The difference between the two decides how quiet "quiet" can be — Phase 1 measures it.

### 1.2 Stem press as a command
| Path | Status | Notes |
|---|---|---|
| `AVAudioApplication.inputMuteStateChangeNotification` + `muteStateKey` (iOS 17+): system posts when the app's input mute state changes, including via an AirPods gesture; on iOS the system mutes input itself and notifies the app | VERIFIED-DOCS for API existence and iOS behaviour (sources 1–3) | Apple presents it for communication apps. Whether the stem gesture triggers it in a **non-call `.playAndRecord` session**, which AirPods models support it, background/locked behaviour, and App Review acceptance: **POSSIBLE-UNTESTED**. Apple's AirPods user guide only documents call mute for AirPods Max (source 4) → real risk it does not fire for stem models. |
| `MPRemoteCommandCenter` (play/pause, next, previous) — stem single/double/triple press sends these on AirPods 3/4/5/Pro (source 4) | Gesture mapping VERIFIED-DOCS; delivery to our app while it captures over HFP: **POSSIBLE-UNTESTED** | Requires our app to be the Now Playing app; conflicts with the user's music. |
| `AVCaptureEventInteraction` / `onCameraCaptureEvent` (iOS 26, H2 AirPods) | **NOT POSSIBLE** for our use: events go only to apps with an active camera session (source 5) | Running the camera to get stem clicks would be a privacy and battery problem — rejected. |
| Press-and-hold (Siri / noise control) | NOT POSSIBLE to intercept — system-owned (source 4) | |

### 1.3 Head movements
| Claim | Status |
|---|---|
| `CMHeadphoneMotionManager` (iOS 14+) gives attitude, rotation rate, acceleration from supported AirPods; needs `NSMotionUsageDescription`; check `isDeviceMotionAvailable` | VERIFIED-DOCS (source 8) |
| Apple's own nod/shake gestures (AirPods 4, 5, Pro 2, Pro 3, Max 2) for calls/notifications | VERIFIED-DOCS (source 4) — **not exposed to third-party apps**; we must classify nod/shake ourselves from raw motion |
| Exact list of models that deliver motion data to apps | UNKNOWN in current docs → log `isDeviceMotionAvailable` per model |
| Reliable nod/shake detection while walking or on a moving train | POSSIBLE-UNTESTED — expect false positives from vehicle motion; needs measurement |
| Motion updates in background | UNKNOWN → test |

### 1.4 Custom keywords from prep material
| Claim | Status |
|---|---|
| `AnalysisContext.contextualStrings` (iOS 26): short phrases (1–2 words), max ~100 total, used by **DictationTranscriber**; a custom language model with pronunciations via `customizedLanguage(modelConfiguration:)` | VERIFIED-DOCS (sources 10–11) |
| Same boost for `SpeechTranscriber` | UNKNOWN (docs only name DictationTranscriber) |
| Deepgram Nova-3 streaming supports Swedish (`sv`, `sv-SE`) | VERIFIED-DOCS (source 12) |
| Deepgram keyterm prompting works for Swedish; ElevenLabs Scribe keyterms in Swedish | UNKNOWN → verify in provider docs + bake-off |

### 1.5 Fragments / half sentences — method (proposal)
1. **Explicit turn boundary** (push-to-talk or stem) tells us *this* is addressed to the assistant → no need to guess intent from ambient speech.
2. **Context pack** sent with each fragment: last ~60 s transcript, active prep topics, last 3 Q/A turns, user language.
3. **Reconstruct-then-answer** in one LLM call returning JSON: `{reconstructed_question, confidence, answer}`. Low confidence → speak a 2–3 word confirmation ("Menar du …?") instead of guessing.
4. **Prep-mode index**: key terms from uploaded material feed both STT boosting (§1.4) and LLM context.
5. Measured on a labelled fragment set (see §2).

### 1.6 Silent interaction
| Claim | Status |
|---|---|
| Controls (iOS 18+) run an App Intent or open the app from Control Center, Lock Screen and the **Action button**; can require device authentication | VERIFIED-DOCS (source 13) |
| Interactive Live Activity buttons via App Intents for "listening on/off" and "answer last" | Known iOS feature; not re-checked in this report → POSSIBLE-UNTESTED for our flow |
| Text input with suggestions (Phase 4) | Standard UIKit/SwiftUI — no platform risk |

## 2. Test plan (makes Track D measurable)

**Matrix:** environment × voice level × material × AirPods model × mic config × activation mode.

| Dimension | Values |
|---|---|
| Environment | Quiet room · Office (recorded office ambience) · Public transport (recorded metro/bus noise, played from a speaker at fixed distance and level) |
| Voice level (wearer) | Normal · Low normal · Whisper |
| Material | 30 short prompts (`testdata/scripts/sv-short-prompts.md`) · new **fragment set** (40 keyword fragments with intended question + expected answer) |
| AirPods | Every model available to the product owner (log model + firmware) |
| Mic config | C-HFP-default · C-HFP-measurement · C-HFP-voiceChat · B-HQ (logs fallback) · A-ref |
| Activation | Always-on VAD · Push-to-talk (in-app/Lock Screen button) · Stem press (if a path works) |

**Metrics**
| Metric | Definition | Provisional target |
|---|---|---|
| Keyword accuracy (KWA) | share of content keywords transcribed correctly | ≥ 90 % low voice, office · report whisper as measured |
| WER / CER | standard, Swedish normalisation (`Packages/LumenScoring`) | report |
| Intent accuracy | fragment → correct reconstructed question (human-labelled) | ≥ 90 % |
| False activations | triggers per hour while nobody addresses the assistant (30 min metro noise + nearby conversation) | ≤ 1/h always-on · 0 with explicit activation |
| Activation latency | stem/button press → app state change | < 300 ms |
| Response latency | end of speech → first answer audio, p50 / p95 | < 1.5 s / < 2.5 s |
| Bystander level | user's voice SPL at 1 m (phone sound-level app, same app every time) | report; aim ≈ quiet conversation or lower |

Noise files: free-licensed recordings (e.g. CC0) or own ambient recordings without identifiable conversations; documented in `testdata/noise/README.md`.

## 3. Priorities (largest UX gain first)
1. **Explicit activation + low voice** (highest value). Push-to-talk removes guessing *when* the user speaks to the assistant → near-zero false activations, allows more sensitive capture thresholds, and makes fragments safe to interpret. Build order: in-app button → Control (Lock Screen / Action button) → stem press if a path proves reliable.
2. **Low-voice capture measurement** (decides how quiet is realistic; already part of Phase 1).
3. **Keyword boosting from prep material** (cheap, measurable gain on fragmentary input).
4. **Fragment understanding** (reconstruct-then-answer with confidence + confirmation).
5. **Text mode** as the fully silent fallback.
6. **Head gestures** for confirm/repeat/stop — nice to have; only after measuring false positives in motion.

## 4. Risks
- Stem press may not be available to non-call apps → fallback is Control / Action button / Lock Screen (verified paths).
- Whisper accuracy may be too low over HFP → product promise becomes "low voice", whisper only where measured good.
- Using the mute notification for something other than muting may raise App Review questions → keep semantics honest: press = start/stop talking to the assistant (input really is muted when "off").
- Head-gesture false positives in vehicles.

## 5. Team coordination (written in this commit)
- Architect: `prompts/2026-11-03-architect-trackD-verification.md` — verify open API questions, design `ActivationManager` + fragment pipeline, update ARCHITECTURE/DECISIONS.
- Angela: `prompts/2026-11-03-trackD-spike.md` — probes + push-to-talk prototype. **Starts only after** Angela's Phase 1a report is pushed and the Architect's Track D report is pushed. Device measurements happen in the product owner's first Mac session.
- No GitHub issues created (the backlog in ROADMAP is still a table).

## Sources
1. [Apple: inputMuteStateChangeNotification](https://developer.apple.com/documentation/avfaudio/avaudioapplication/inputmutestatechangenotification)
2. [Apple: setInputMuteStateChangeHandler (macOS only; iOS handles muting internally)](https://developer.apple.com/documentation/avfaudio/avaudioapplication/setinputmutestatechangehandler(_:))
3. [WWDC23 10233 notes — AirPods mute for apps](https://wwdcnotes.com/documentation/wwdc23-10233-enhance-your-apps-audio-experience-with-airpods/)
4. [Apple Support: AirPods controls and gestures](https://support.apple.com/guide/airpods/use-controls-and-gestures-with-your-airpods-devb2c431317/web)
5. [WWDC25 253 — capture controls, AirPods stem clicks require active camera](https://developer.apple.com/videos/play/wwdc2025/253/)
6. [Pseudo-whisper augmentation, arXiv 2311.05179](https://arxiv.org/abs/2311.05179v1)
7. [Interspeech 2020, whispered speech ASR](https://www.isca-archive.org/interspeech_2020/gudepu20_interspeech.html)
8. [Apple: CMHeadphoneMotionManager](https://developer.apple.com/documentation/coremotion/cmheadphonemotionmanager)
9. [Report on rumoured silent-speech AirPods (no API)](https://letsdatascience.com/news/apple-integrates-silent-speech-tech-into-airpods-pro-3-a4b371c1)
10. [Apple: AnalysisContext](https://developer.apple.com/documentation/speech/analysiscontext)
11. [Apple: AnalysisContext.contextualStrings](https://developer.apple.com/documentation/speech/analysiscontext/contextualstrings)
12. [Deepgram changelog 2026-08-27 — Swedish Nova-3 streaming](https://developers.deepgram.com/changelog/2026/8/27)
13. [Apple: Creating controls to perform actions across the system](https://developer.apple.com/documentation/widgetkit/creating-controls-to-perform-actions-across-the-system)
