# Report: MVP items 5–9 — Voice output, text mode, latency log, notes, prep material

Date: REPORT_DATE · Session: Angela (builder) · Assignment: `prompts/2026-11-03-mvp-sprint-app.md` items 5–9 + D23 (three ElevenLabs voices, preview) · Decisions D26, D27

Evidence labels: **verified in CI** (compiles with zero warnings / tests pass on the GitHub macOS runner against fakes), **verified in docs** (`backend/README.md`), **untested against the live backend**, **untested on device** (no audio has been heard by anyone yet).

## 1. Summary
- **Item 5 — voice.** Answers are spoken in the AirPods as they stream: each completed sentence goes to a `Speaker` queue and plays through our own engine, so speech starts after the first sentence. A new question interrupts speech. The chosen voice is tried first (ElevenLabs via Kevin's `/tts`, streamed as 24 kHz PCM straight into the playback graph); any network/quota problem falls back to Apple's voice for that sentence. Settings sheet (gear): language, activation, voice picker (Apple voices on the phone + the three premium voices from `GET /voices`), preview, speed, "Speak answers".
- **Item 6 — text mode.** A question field on the Listening screen; works without the microphone; with "Speak answers" off the answer is only shown (silent mode).
- **Item 7 — latency.** Per answer: activation (≈ end of speech) → first streamed text → first speech scheduled, with p50/p95, in a Debug overlay and the log.
- **Item 8 — notes.** "Save note" stores transcript + answers locally (Application Support, file-protected) and exports Markdown through the share sheet.
- **Item 9 — prep material.** Paste text or import PDF/text; key terms are extracted on the phone and fed to the recogniser (`contextualStrings`, ≤100) and to `/answer` (`prep_terms`, ≤30).
- CI_RESULT_LINE
- **Nothing heard or seen on device.** Voice quality over HFP, time-to-first-word, `.dataPlayedBack` timing, PDF import and the file-importer flow are what checklist §3m–3p measure. `GET /voices` does not exist in the backend yet (Kevin's item from D23), so the premium picker is empty until then — the app says so.

## 2. What was implemented
| Item | Piece | Files | Notes |
|---|---|---|---|
| 5 | Provider contract | `Lumen/Core/Voice/TTSProvider.swift` | `TTSProvider.speak(text, language, voice)`, `VoiceChoice` (apple / elevenLabs), `TTSError` with `wantsFallback`. |
| 5 | Apple voice | `AppleTTSProvider.swift` | `PlaybackService.speak` with an optional `AVSpeechSynthesisVoice` identifier; installed voices per language, enhanced first. |
| 5 | Premium voice | `ElevenLabsTTSProvider.swift` | `POST /tts` `{text, language, output_format: "pcm_24000", voice_id?}`; bytes → `PCM16Assembler` → `PlaybackService.play(samples:)` in 100 ms buffers; 401 invalidates the session; > 500 chars split at word boundaries. |
| 5 | Speaker | `Speaker.swift` | Ordered queue, Apple fallback on `wantsFallback`, notice, `interrupt()` with a generation guard, `preview(voice)`, `onSentenceStarted` for latency. |
| 5 | Settings | `VoiceSettings.swift`, `Lumen/Features/Settings/SettingsView.swift` | Voice, speed (time-pitch), speak-answers; `VoiceCatalog` loads `GET /voices` once per run (tolerant decoder). Inline pickers moved from the Listening screen into the sheet. |
| 5 | Playback | `Lumen/Core/Audio/PlaybackService.swift` | `speak(_:language:voiceIdentifier:)`, `play(samples:sampleRate:)`, `isSpeaking` true until buffers have played (`.dataPlayedBack` + generation after `stop()`) — what tags transcript as "spoken over our playback" (§4.3). |
| 6 | Text mode | `ListeningView.swift`, `ListeningModel.swift` | `draftQuestion` / `sendDraft()` → `ActivationController.submitText` → backend `mode: text`. |
| 7 | Latency | `Lumen/Core/Telemetry/LatencyLog.swift` | `LatencyRecord` per answer (first text, first speech, providers), nearest-rank p50/p95, Debug overlay (Settings → Debug → Latency overlay). |
| 8 | Notes | `Lumen/Core/Notes/NotesStore.swift`, `Lumen/Features/Notes/NotesView.swift` | JSON in Application Support (complete file protection), newest first, Markdown export via `ShareLink`, delete. Playback echo lines excluded. |
| 9 | Prep | `Lumen/Core/Prep/KeyTermExtractor.swift`, `PrepStore.swift`, `DocumentText.swift`, `Lumen/Features/Prep/PrepView.swift` | Frequency + capitalised names + two-word names, sv/en stopwords; materials with enable toggle; PDFKit / UTF-8 import; terms applied to the current STT provider and every later one (`TranscriptionCoordinator.contextualStrings`). |
| — | Navigation | `ListeningView.swift` | "More" menu: Notes, Prep material, Diagnostics, Privacy & consent; gear = Settings. Checklist paths updated. |

## 3. Test results
| Suite (iPhone 17 Pro simulator, iOS 26.5) | Tests | Result | Basis |
|---|---|---|---|
| `SpeakerTests` — order + chosen voice, Apple direct, fallback on quota, non-network failure, interrupt/recover, silent mode, preview, rate | 8 | TEST_RESULT | **verified in CI** |
| `VoiceSettingsTests`, `PCM16AssemblerTests` | 3 | TEST_RESULT | **verified in CI** |
| `ElevenLabsTTSProviderTests` — headers/body, PCM across chunk boundaries, quota → fallback, 401 invalidates, split, body shape | 5 | TEST_RESULT | **verified in CI** (fakes) |
| `VoiceCatalogTests` | 2 | TEST_RESULT | **verified in CI** (fakes) |
| Text mode (`ListeningAnswerTests.typedQuestionWorksWithoutTheMicrophone`) | 1 | TEST_RESULT | **verified in CI** |
| `LatencyLogTests` — marks once, end/cap/clear, percentiles | 3 | TEST_RESULT | **verified in CI** |
| `NotesStoreTests`, `KeyTermExtractorTests`, `PrepStoreTests`, `ListeningNotesAndPrepTests` | 10 | TEST_RESULT | **verified in CI** |
| Items 1–4 + Phase 1 suites | 173 | TEST_RESULT | **verified in CI** |
| `LumenScoring` (macOS host) | 21 | TEST_RESULT | **verified in CI** |
| Hearing anything; HFP voice quality; PDF import; file importer; share sheet | — | not run | checklist §3m–3p |

## 4. CI iterations
CI_ITERATIONS

## 5. Known limitations, risks
- `GET /voices` is not deployed yet; the decoder accepts `{voices:[{name,id}]}`, `{voices:[{name,voice_id}]}` and a bare list — adjust when Kevin documents it (**untested assumption**). The `/tts` ElevenLabs parameters are themselves "untested assumptions" in Kevin's README; failures surface as the fallback notice and Apple speaks.
- Apple's `AVSpeechSynthesizer.write` delivers audio in a few large buffers, so Apple-voice latency is bounded by synthesis of one sentence; measure on device.
- Speed applies through the time-pitch node to both voices (1.5–2.0× quality **untested on device**).
- Interrupting stops at buffer granularity (≤ 100 ms for PCM, larger for Apple buffers).
- Key-term extraction is heuristic (no stemming: "fotosyntes" and "fotosyntesen" are two terms); good enough for boosting, tune after §3p.
- `PDFDocument.string` loses layout; scanned PDFs without a text layer yield nothing (reported as "no usable terms").
- Notices and errors are English only (not in the string catalog yet).

## 6. Concerns (per CLAUDE.md)
None new. Speech plays only in the user's own AirPods while the indicator is on; the premium voice sends only answer text to the backend; notes and prep text never leave the phone (only ≤30 terms accompany a question, as the Prep screen says).

## 7. Next
Item 10 / Track D: Lock Screen / Action-button Control for push-to-talk (App Intent + `ControlWidget`), activation probes (stem press via `inputMuteStateChangeNotification`), head-gesture experiment — after `prompts/2026-11-03-trackD-spike.md` and the Architect's Track D report are read. Then the first device session on the owner's Mac.
