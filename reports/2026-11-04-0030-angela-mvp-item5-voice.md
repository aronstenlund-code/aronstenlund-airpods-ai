# Report: MVP item 5 — Voice output (sentence-by-sentence TTS, voice picker)

Date: REPORT_DATE · Session: Angela (builder) · Assignment: `prompts/2026-11-03-mvp-sprint-app.md` item 5 + D23 (three ElevenLabs voices, preview) · D26

Evidence labels: **verified in CI** (compiles with zero warnings / tests pass on the GitHub macOS runner against fakes), **verified in docs** (`backend/README.md`), **untested against the live backend**, **untested on device** (no audio has been heard by anyone yet).

## 1. Summary
- Answers are now spoken in the AirPods as they stream: each completed sentence from the answer engine goes to a `Speaker` queue and is played through our own engine (`PlaybackService`), so speech starts after the first sentence, not after the whole answer. A new question interrupts speech immediately. The chosen voice is tried first (ElevenLabs via Kevin's `/tts`, streamed as 24 kHz PCM straight into the playback graph); any network/quota problem falls back to Apple's voice for that sentence. Settings sheet: language, activation, voice picker (Apple voices on the phone + the three premium voices from `GET /voices`), preview, speed slider, "Speak answers" (off = silent mode, item 6's half).
- CI_RESULT_LINE
- **Nothing heard on device.** Voice quality over HFP, time-to-first-word and whether `.dataPlayedBack` completions behave as expected are exactly what checklist §3m measures. `GET /voices` does not exist in the backend yet (Kevin's item from D23), so the premium picker is empty until then — the app shows "Premium voices appear here when the voice service is live".

## 2. What was implemented
| Piece | Files | Notes |
|---|---|---|
| Provider contract | `Lumen/Core/Voice/TTSProvider.swift` | `TTSProvider.speak(text, language, voice)`, `VoiceChoice` (apple / elevenLabs, id, name), `TTSError` with `wantsFallback` for network problems. |
| Apple voice | `AppleTTSProvider.swift` | Wraps `PlaybackService.speak` (now with an optional `AVSpeechSynthesisVoice` identifier); lists installed voices per language, enhanced/premium first. |
| Premium voice | `ElevenLabsTTSProvider.swift` | `POST /tts` `{text, language, output_format: "pcm_24000", voice_id?}` with the anonymous JWT; bytes → `PCM16Assembler` (samples may straddle chunks) → `PlaybackService.play(samples:)` in 100 ms buffers; 401 invalidates the session; texts > 500 chars split at word boundaries. |
| Speaker | `Speaker.swift` | Ordered queue, one sentence at a time, fallback to Apple on `wantsFallback`, notice text, `interrupt()` (new question / stop) with a generation guard so a cancelled drain cannot clobber its successor; `preview(voice)`. |
| Settings | `VoiceSettings.swift`, `Lumen/Features/Settings/SettingsView.swift` | Voice, speed (0.5–2.0, applied to `AVAudioUnitTimePitch`), speak-answers; `VoiceCatalog` loads `GET /voices` once per run with a tolerant decoder. The Listening screen's inline pickers moved into the sheet (gear icon); the main screen keeps status, transcript, answers and the two buttons. |
| Playback | `Lumen/Core/Audio/PlaybackService.swift` | `speak(_:language:voiceIdentifier:)`, `play(samples:sampleRate:)`, and `isSpeaking` now stays true until scheduled buffers have actually played (`scheduleBuffer(..., completionCallbackType: .dataPlayedBack)` + a generation to ignore callbacks after `stop()`). This is what tags transcript segments as "spoken over our playback" (§4.3). |
| HTTP seam | `HTTPStreaming.swift` | `bytes(for:)` for binary streams (4800-byte chunks). |
| Wiring | `ListeningModel.swift`, `AppContainer.swift` | `answerSentence` → `speaker.enqueue`; `activated` / `stopListening` / `clearHistory` → `speaker.interrupt()`. |

## 3. Test results
| Suite (iPhone 17 Pro simulator, iOS 26.5) | Tests | Result | Basis |
|---|---|---|---|
| `SpeakerTests` — order + chosen voice, Apple voice direct, fallback on quota, non-network failure without fallback, interrupt clears queue/stops playback/recovers, silent mode, preview, rate | 8 | TEST_RESULT | **verified in CI** |
| `VoiceSettingsTests`, `PCM16AssemblerTests` | 3 | TEST_RESULT | **verified in CI** |
| `ElevenLabsTTSProviderTests` — request headers/body, PCM across chunk boundaries into playback, quota → fallback, 401 invalidates session, >500-char split, body shape | 5 | TEST_RESULT | **verified in CI** (fakes) |
| `VoiceCatalogTests` — both JSON shapes, auth + once-per-run, failure status | 2 | TEST_RESULT | **verified in CI** (fakes) |
| Items 1–4 + Phase 1 suites | 215 | TEST_RESULT | **verified in CI** |
| `LumenScoring` (macOS host) | 21 | TEST_RESULT | **verified in CI** |
| Hearing anything; HFP voice quality; time-to-first-word; `.dataPlayedBack` timing | — | not run | checklist §3m |

## 4. CI iterations
CI_ITERATIONS

## 5. Known limitations, risks
- `GET /voices` is not deployed yet; the decoder accepts `{voices:[{name,id}]}`, `{voices:[{name,voice_id}]}` and a bare list — adjust when Kevin documents it (**untested assumption**).
- The `/tts` ElevenLabs parameters are themselves marked "untested assumptions" in Kevin's README; a quota/parameter error surfaces as the fallback notice and Apple speaks instead.
- Apple's `AVSpeechSynthesizer.write` delivers audio in a few large buffers, so "sentence-level" latency for the Apple voice is bounded by synthesis of one sentence; measure on device.
- Speed applies to both voices through the time-pitch node (quality of 1.5–2.0× is **untested on device**).
- Interrupting mid-sentence stops at buffer granularity (≤ 100 ms for PCM, larger for Apple's buffers).
- Notices from the speaker and errors are English only (not in the string catalog yet).

## 6. Concerns (per CLAUDE.md)
None new. Speech plays only in the user's own AirPods while the indicator is on; the premium voice sends only the answer text (never audio or transcript) to the backend.

## 7. Next
Item 6 — text mode UI (type a question; `submitText` and silent mode already exist), then item 7 latency overlay (end of speech → first audio, per answer), items 8–9, then Track D.
