# Open-source code audit — reusable components for Lumen

Date: 2026-11-03 · Session: Architect · Type: research (no code integrated)

Method: every repository below was **cloned and its source read** (not only the README). Licences were taken from the actual `LICENSE` file and the git history of that file. Commit SHAs are the versions reviewed. "Read" = we read the code; "Docs" = provider/model card only; "Not verified" = still open.

---

## 1. Summary

- **No repository is a good base to fork.** The closest (MeetingMindAI, MIT per README — owner-approved) is a one-day prototype with a record-only audio session; the most capable (Parrot) is macOS-only and now GPL-3.0.
- **Best reusable building blocks:**
  1. **FluidAudio** (Apache-2.0) — Silero VAD, on-device Swedish-capable ASR (Parakeet TDT v3 / Ultra), neural noise suppression (LocalVQE). iOS 17+.
  2. **swift-speech-transcriber** (MIT) — clean Swift 6 wrapper around Apple `SpeechAnalyzer` streaming, locale management, custom vocabulary.
  3. **WhisperKit** (MIT) + **KB-Whisper** (KBLab, Apache-2.0) — the strongest on-device *Swedish* accuracy candidate (KBLab reports roughly half the WER of OpenAI Whisper on Swedish benchmarks).
  4. **Volocal** (MIT) — iOS streaming STT→LLM→TTS reference: sentence buffer and interruptible pipeline.
- **Ideas, not code:** Parrot's event-driven "question → fast trigger" scheduling (from its last MIT release v0.11.3) and MeetingMindAI's provider/fallback layout.
- **Swedish question detection:** no open-source implementation found. We build it (small).
- **Licence actions:** add `THIRD_PARTY_NOTICES.md` + in-app acknowledgements (MIT/Apache texts; CC-BY-4.0 attribution for Parakeet weights).

---

## 2. Repositories reviewed

### 2.1 MeetingMindAI — richlira/MeetingMindAI @ `0cef092`
https://github.com/richlira/MeetingMindAI

| | |
|---|---|
| What it is | iOS 26 / Swift 6 meeting assistant: live transcription (Whisper API or `SpeechAnalyzer`), Claude or Apple Foundation Models for questions/summary |
| Platform | **iOS** (`IPHONEOS_DEPLOYMENT_TARGET = 26.2`, `SDKROOT = iphoneos`) — Read |
| Size / maturity | 27 Swift files, 10 commits over ~1 day (Feb 2026) — prototype |
| Audio | `AVAudioSession` `.record` only (no playback path, no Bluetooth options, no interruption/route handling) — [AudioManager.swift](https://github.com/richlira/MeetingMindAI/blob/0cef092/MeetingMind/Core/Audio/AudioManager.swift) |
| STT | [SpeechAnalyzerProvider.swift](https://github.com/richlira/MeetingMindAI/blob/0cef092/MeetingMind/Core/Transcription/SpeechAnalyzerProvider.swift): `SpeechTranscriber` + `bestAvailableAudioFormat` + converter; locale auto-detect among es/en/pt/fr/de/ja/zh (**no Swedish**); `@unchecked Sendable`, `print` logging |
| AI | [AIProvider.swift](https://github.com/richlira/MeetingMindAI/blob/0cef092/MeetingMind/Core/AI/AIProvider.swift) / [ClaudeProvider.swift](https://github.com/richlira/MeetingMindAI/blob/0cef092/MeetingMind/Core/AI/ClaudeProvider.swift): API key on device (Keychain); questions generated every ~50 words |
| **Licence** | No LICENSE file exists in the history (re-checked `origin/main` @ `0cef092` on 2026-11-03). README states twice that the project is MIT-licensed. **Product owner decision 2026-11-03 (D11): use under MIT as declared in the README.** Attribution: "Copyright (c) 2026 Rich (richlira)". Residual risk: low — no formal licence text/copyright line; recommended to ask the author to add a LICENSE file (GitHub issue). |
| Reuse | Now allowed with attribution. Worth taking: provider-fallback logic in [SessionManager.swift](https://github.com/richlira/MeetingMindAI/blob/0cef092/MeetingMind/Core/Pipeline/SessionManager.swift) (on-device → cloud on error) and the `bestAvailableAudioFormat` conversion in SpeechAnalyzerProvider as a second reference. **Do not copy** its `.record` audio session, its key-on-device Claude client, its every-50-words question trigger, or [DeviceCapability.swift](https://github.com/richlira/MeetingMindAI/blob/0cef092/MeetingMind/Utilities/DeviceCapability.swift)'s rule that SpeechAnalyzer needs A17 Pro+ (a developer-forum report shows SpeechTranscriber working on iPhone 12 — use `SpeechTranscriber.isAvailable` instead). For the Apple STT layer, swift-speech-transcriber remains the better base (tests, typed errors). |

### 2.2 Parrot — turantekin/Parrot @ `f9f2e2b` (and `v0.11.3` = `91b6f92`)
https://github.com/turantekin/Parrot

| | |
|---|---|
| What it is | macOS meeting recorder with a live Claude copilot that suggests answers to the other side's questions |
| Platform | **macOS 14 only** (`platforms: [.macOS(.v14)]`); uses ScreenCaptureKit + CoreAudio + Sparkle — Read |
| Licence | **GPL-3.0 on current main.** Commit `a40ef75` (2026-08-01) "Relicense from MIT to GPL-3.0"; commit message states releases **up to v0.11.3 remain MIT** (verified: `git show v0.11.3:LICENSE` = MIT) |
| Valuable parts (v0.11.3, MIT) | [CallAnalysisEngine.swift](https://github.com/turantekin/Parrot/blob/v0.11.3/Parrot/Services/CallAnalysisEngine.swift): event-driven trigger — question → ~1 s debounce, otherwise 8 s idle debounce, 5 s minimum interval, 15 s max staleness; `looksLikeQuestion` is an English keyword list. [AnalysisProvider.swift](https://github.com/turantekin/Parrot/blob/v0.11.3/Parrot/Services/AnalysisProvider.swift): provider protocol, Claude Messages API with JSON-schema output, model-invented-source validation. [CloudTranscription.swift](https://github.com/turantekin/Parrot/blob/v0.11.3/Parrot/Services/CloudTranscription.swift): ~60-line Deepgram WebSocket streamer (no reconnect, API key on device) |
| Reuse | **Never copy from current main (GPL-3.0 is incompatible with a proprietary App Store app).** From v0.11.3: reuse the *design* of the trigger scheduler; copying code is legally allowed under MIT with attribution, but the files are macOS-coupled and small — reimplementing is cleaner. |

### 2.3 Deepgram Examples — deepgram/examples @ `0dbe949`
https://github.com/deepgram/examples

| | |
|---|---|
| Relevant part | [370-swift-ios-live-transcription](https://github.com/deepgram/examples/tree/0dbe949/examples/370-swift-ios-live-transcription): 453 lines; `AVAudioEngine` → 16 kHz mono → `URLSessionWebSocketTask`, interim/final results, `utterance_end_ms`, `CloseStream` |
| Platform | iOS 17, no dependencies — Read |
| Quality | Example-level: `.record` session (no playback), API key from env on device, no reconnect/KeepAlive, no interruption handling |
| **Licence** | **No LICENSE file in the repository** (root or example folder) and no licence statement in README/CONTRIBUTING. → **Unclear; do not copy.** |
| Reuse | Protocol reference only (query parameters, CloseStream). Also shows a token-proxy pattern in [520-node-deepgram-proxy](https://github.com/deepgram/examples/tree/0dbe949/examples/520-node-deepgram-proxy) — reference for our backend. |

### 2.4 Swift Speech Transcriber — arraypress/swift-speech-transcriber @ `e194f56`
https://github.com/arraypress/swift-speech-transcriber

| | |
|---|---|
| What it is | Swift package around Apple `SpeechAnalyzer` (+ optional WhisperKit, Parakeet, diarization products) |
| Platform | **iOS 26 / macOS 26**, Swift 6.2, `MemberImportVisibility` — Read |
| Quality | Good: typed errors, progress, tests (582-line test file), `AsyncStream` live API, finalize-on-stop handled correctly ([Streaming.swift](https://github.com/arraypress/swift-speech-transcriber/blob/e194f56/Sources/SpeechTranscriber/Streaming.swift), [LocaleSupport.swift](https://github.com/arraypress/swift-speech-transcriber/blob/e194f56/Sources/SpeechTranscriber/LocaleSupport.swift), [TranscriptionOptions.swift](https://github.com/arraypress/swift-speech-transcriber/blob/e194f56/Sources/SpeechTranscriber/Enums/TranscriptionOptions.swift)) |
| Gaps | [MicrophoneCapture.swift](https://github.com/arraypress/swift-speech-transcriber/blob/e194f56/Sources/SpeechTranscriber/MicrophoneCapture.swift) does not configure `AVAudioSession` (fine — we own that). README says "zero dependencies" but the `SpeechTranscriber` target depends on `swift-subtitle-kit` (MIT), and SwiftPM resolves **all** package dependencies (WhisperKit, FluidAudio) even if we only use one product |
| Licence | **MIT** (LICENSE unchanged since first commit `36d7808`). Dependency swift-subtitle-kit: MIT |
| Reuse | **Vendor and adapt** the streaming + locale + vocabulary code (~300 lines) into `Core/Transcription/AppleSpeechProvider` with the MIT notice kept in the file header. Don't add the package itself (pulls heavy transitive deps). |

### 2.5 Additional projects found

| Project | Licence (LICENSE file) | Platform | What's valuable |
|---|---|---|---|
| **FluidAudio** — [FluidInference/FluidAudio](https://github.com/FluidInference/FluidAudio) @ `ee78635` | **Apache-2.0** (+ `ThirdPartyLicenses/`) | iOS 17+, macOS 14+ | Silero VAD (CoreML); Parakeet TDT v3 / Ultra — 25 European languages incl. Swedish (batch/sliding-window); Nemotron Unified multilingual **streaming** ASR (25 European languages); LocalVQE noise suppression + dereverberation, 16 kHz, 16 ms latency (beta). SwiftPM traits allow ASR+VAD only. Used in many shipping iOS apps (README). |
| **WhisperKit** — [argmaxinc/argmax-oss-swift](https://github.com/argmaxinc/argmax-oss-swift) @ `9f99b5c` | **MIT** (+ `NOTICES`) | iOS/macOS | On-device Whisper runtime (CoreML). Pairs with KB-Whisper. |
| **KB-Whisper** — [KBLab/kb-whisper-medium](https://huggingface.co/KBLab/kb-whisper-medium) (+ tiny/base/small/large) | **Apache-2.0** (model card) | CoreML conversions exist, e.g. [Ordagrant/kb-whisper-medium-coreml](https://huggingface.co/Ordagrant/kb-whisper-medium-coreml) (Apache-2.0) | Swedish fine-tune on 50k+ h. KBLab reports WER 6.6 / 5.4 / 5.8 (FLEURS / CommonVoice / NST) vs 12.1 / 15.8 / 17.1 for OpenAI whisper-medium. |
| **Volocal** — [fikrikarim/volocal](https://github.com/fikrikarim/volocal) @ `b731963` | **MIT** | iOS 17 | Fully on-device STT→LLM→TTS with barge-in. [SentenceBuffer.swift](https://github.com/fikrikarim/volocal/blob/b731963/Volocal/Pipeline/SentenceBuffer.swift) (token stream → sentences for TTS), [VoicePipeline.swift](https://github.com/fikrikarim/volocal/blob/b731963/Volocal/Pipeline/VoicePipeline.swift) (state machine + cancel/interrupt), [SharedAudioEngine.swift](https://github.com/fikrikarim/volocal/blob/b731963/Volocal/Audio/SharedAudioEngine.swift) (one engine for mic + TTS). Its session is `.voiceChat` + speaker — not our AirPods config. |
| ElevenLabs Swift SDK — [elevenlabs/elevenlabs-swift-sdk](https://github.com/elevenlabs/elevenlabs-swift-sdk) @ `24e2c3c` | MIT | iOS 13+ | Conversational **Agents** over LiveKit/WebRTC only — no standalone TTS or Scribe client. **Not useful** for our pipeline; call the REST/WebSocket APIs directly. |

Model weight licences: Parakeet TDT v3 (NVIDIA) **CC-BY-4.0** — attribution required ([model card](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3), Docs). FluidInference's CoreML conversion page shows both Apache-2.0 and cc-by-4.0 → treat as **CC-BY-4.0**. Silero VAD upstream is MIT — **not yet verified** on the CoreML model card; check before shipping.

---

## 3. Scorecard

Technical relevance 1–10. iPhone/AirPods = fit for our iOS + AirPods pipeline. Commercial = can we ship it in a proprietary App Store app.

| Project | Code quality | Relevance | iPhone | AirPods | Real-time | Commercial use | Integration work | Verdict |
|---|---|---|---|---|---|---|---|---|
| MeetingMindAI | Prototype | **5** | Yes | No (record-only) | Partly | Yes — MIT per README, owner-approved (D11) | Low (small parts) | Reuse fallback logic |
| Parrot (main) | Good, large | **5** | **No (macOS)** | No | Yes | **No (GPL-3.0)** | — | Avoid |
| Parrot v0.11.3 | Good | 5 | No | No | Yes | Yes (MIT) | Medium (rewrite for iOS) | Design reference |
| Deepgram examples | Example-level | **4** | Yes | No | Yes | **No (no licence)** | — | Protocol reference |
| swift-speech-transcriber | Good | **7** | Yes | n/a | Yes | Yes (MIT) | Low (vendor ~300 lines) | **Reuse** |
| FluidAudio | Good, active | **8** | Yes | n/a | Yes (VAD, streaming ASR) | Yes (Apache-2.0; CC-BY-4.0 weights) | Medium (SPM + model download) | **Reuse** |
| WhisperKit + KB-Whisper | Good | **7** | Yes | n/a | Partly — iPhone real-time **not verified** | Yes (MIT + Apache-2.0) | Medium (model size 0.5 GB+) | **Benchmark** |
| Volocal | Compact, clean | **6** | Yes | No | Yes | Yes (MIT) | Low (2 files) | **Reuse parts** |
| ElevenLabs Swift SDK | Good | **2** | Yes | — | Agents only | Yes (MIT) | — | Not needed |

---

## 4. Recommended combination

```
AirPods mic ─▶ our AudioSessionManager/CaptureService (Phase 1, own code)
            ─▶ [optional] FluidAudio LocalVQE noise suppression (measure: does it lower WER?)
            ─▶ FluidAudio Silero VAD (speech segments + endpointing)
            ─▶ STT provider (protocol, own):
                 • Cloud: ElevenLabs Scribe v2 / Deepgram Nova-3 — own thin WebSocket client, backend tokens
                 • On-device: Apple SpeechAnalyzer (vendored from swift-speech-transcriber, MIT)
                 • On-device Swedish: KB-Whisper via WhisperKit, or Parakeet/Nemotron via FluidAudio
            ─▶ Question gate + classifier (own; Swedish rules; scheduling modelled on Parrot v0.11.3 design)
            ─▶ Backend (Supabase) → Claude streaming (official @anthropic-ai/sdk, MIT, server-side)
            ─▶ SentenceBuffer (adapted from Volocal, MIT, + Swedish rules) → TTS → AirPods
```

Defaults are decided by the Phase 1 benchmark, not by this audit.

---

## 5. Builder assignments

Full prompts: `prompts/2026-11-03-oss-integration.md` (OSS-1 … OSS-4). Order: OSS-1 and OSS-3 extend the Phase 1 benchmark; OSS-2 and OSS-4 are for Phase 2/4.

| ID | Task | Source | Licence duty |
|---|---|---|---|
| OSS-1 | Vendor Apple SpeechAnalyzer streaming layer as `AppleSpeechProvider` | swift-speech-transcriber (MIT) | Keep MIT header in vendored files + THIRD_PARTY_NOTICES |
| OSS-2 | Add FluidAudio (ASR+VAD traits): Silero VAD segmentation; LocalVQE as optional pre-STT stage | FluidAudio (Apache-2.0) | Apache-2.0 text + ThirdPartyLicenses; model licences in acknowledgements |
| OSS-3 | Add KB-Whisper (WhisperKit) and Parakeet/Nemotron (FluidAudio) to the Swedish STT benchmark (Mac first) | WhisperKit (MIT), KB-Whisper (Apache-2.0), Parakeet (CC-BY-4.0) | Attribution for CC-BY-4.0 weights |
| OSS-4 | SentenceBuffer + interruptible answer pipeline | Volocal (MIT) | Keep MIT header |

---

## 6. Risks and limitations

- **Licence drift:** Parrot switched MIT → GPL-3.0 mid-life. Always pin to a reviewed commit/tag and re-check `LICENSE` on every bump.
- **Unlicensed repos:** deepgram/examples has no licence → no code. MeetingMindAI relies on a README statement only (accepted by owner, D11) → ask the author for a LICENSE file.
- **Model sizes:** KB-Whisper medium ≈ 0.5 GB, Parakeet int8 encoder ≈ 0.6 GB → on-demand download, storage UI, App Store size limits for bundled assets.
- **On-device real-time on iPhone** for Swedish models: **not verified**. Parakeet EOU streaming is English-only; Nemotron multilingual streaming exists but is newer.
- **Noise suppression can hurt far-field STT** (removes quiet speech). LocalVQE must be A/B-tested by WER, not by listening.
- **SwiftPM transitive dependencies:** adding a package pulls all its dependencies; prefer vendoring small MIT code over adding meta-packages.
- **Question detection in Swedish:** nothing reusable found; English heuristics (Parrot) don't transfer.

---

## 7. Status labels

- Verified by reading code + LICENSE files: everything in §2 marked "Read" and all repository licences.
- Verified in docs/model cards only: model licences, KB-Whisper WER numbers, Parakeet language list, FluidAudio features.
- Not yet verified: on-iPhone latency of any on-device Swedish model; Silero CoreML card licence; whether LocalVQE helps WER on AirPods HFP audio.
