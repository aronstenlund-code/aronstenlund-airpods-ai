# Assignments for Angela — open-source integration (OSS-1 … OSS-4)

From: Architect · Date: 2026-11-03
Background: `reports/open-source-code-audit.md` (read it first, plus `CLAUDE.md` and `docs/STATUS.md`).

**Order:** do these **after** the Phase 1 audio core (§3.1–3.7 of `prompts/2026-11-03-phase1-audio-foundation.md`) builds and runs. OSS-1 and OSS-3 extend the Phase 1 STT benchmark. OSS-2 and OSS-4 are for later phases — do not start them before the Architect says so.

## Licence rules (apply to every task)
- Only use code/models whose licence is listed as allowed below. **Never copy code from `turantekin/Parrot` main (GPL-3.0) or `deepgram/examples` (no licence).** Reading them as reference is fine; copying is not.
- `richlira/MeetingMindAI` @ `0cef092` may be used under MIT as declared in its README (product-owner decision D11). Header for any vendored part: `Copyright (c) 2026 Rich (richlira) — MIT, as declared in the project README (no LICENSE file upstream)`. Allowed: provider-fallback logic (`Core/Pipeline/SessionManager.swift`). Not allowed: its `.record` session, on-device API keys, every-50-words trigger, and the A17-Pro rule in `Utilities/DeviceCapability.swift` (use `SpeechTranscriber.isAvailable`).
- Pin every dependency to an exact version or commit, and record it in `docs/DECISIONS.md`.
- Before adding or bumping a dependency, open its `LICENSE` file at that exact version. If it is not MIT, Apache-2.0 or BSD, stop and report.
- Keep the original copyright + licence header at the top of every vendored file, add `// Modified by Lumen, <date>: <what changed>`.
- Maintain `THIRD_PARTY_NOTICES.md` in the repo root: component, version/commit, licence, full licence text (Apache-2.0 also requires `NOTICE`/third-party files if present). Model weights with CC-BY-4.0 need an attribution line.
- Never put API keys in the app or repo.

---

## OSS-1 — Apple on-device STT provider (vendored from swift-speech-transcriber)

**Source:** https://github.com/arraypress/swift-speech-transcriber @ `e194f56` — **MIT** (Copyright (c) 2026 David Sherlock (ArrayPress)).

**Read:** `Sources/SpeechTranscriber/Streaming.swift`, `LocaleSupport.swift`, `Enums/TranscriptionOptions.swift`, `Models/LiveTranscriptionEvent.swift`, `Models/AudioInput.swift`, `Enums/TranscriptionError.swift`.

**Reuse:** the `SpeechAnalyzer` streaming loop (volatile + final results, `finalizeAndFinishThroughEndOfInput` on stop), locale support/download logic, custom-vocabulary handling.

**Do not:** add the package via SwiftPM (it resolves WhisperKit + FluidAudio + SubtitleKit transitively). Do not vendor SRT/VTT/subtitle code.

**Adapt to our architecture:**
- New `Core/Transcription/STTProvider.swift` protocol: `func start(_ audio: AsyncStream<AudioChunk>, locale: Locale, vocabulary: [String]) -> AsyncThrowingStream<TranscriptEvent, Error>` with events `.partial(text, start, end)`, `.final(text, start, end)`, `.endOfStream`.
- `AppleSpeechProvider` implements it with `SpeechTranscriber`, falling back to `DictationTranscriber` when `sv-SE` is not supported. Input = our 16 kHz Int16 chunks converted to the analyzer's `bestAvailableAudioFormat`.
- Swift 6 strict concurrency; no `@unchecked Sendable` without a justification comment; `Logger` instead of `print`.

**Tests:** unit tests for event mapping and locale fallback (mock the analyzer boundary); on-device run of the Phase 1 WAVs through the provider.

**Acceptance:** builds with zero warnings; Phase 1 benchmark "Apple on-device" rows come from this provider; MIT header present in vendored files; `THIRD_PARTY_NOTICES.md` updated.

---

## OSS-3 — On-device Swedish models in the STT benchmark (Mac first)

Goal: know whether an on-device model can match cloud accuracy for Swedish **before** we build it into the app.

**Sources:**
- WhisperKit: https://github.com/argmaxinc/argmax-oss-swift @ `9f99b5c` — **MIT** (+ `NOTICES`). Use `whisperkit-cli` on the Mac.
- KB-Whisper (KBLab, **Apache-2.0**): https://huggingface.co/KBLab/kb-whisper-small and https://huggingface.co/KBLab/kb-whisper-medium; CoreML builds e.g. https://huggingface.co/Ordagrant/kb-whisper-medium-coreml (Apache-2.0). Record which conversion you use and its licence.
- FluidAudio: https://github.com/FluidInference/FluidAudio @ `ee78635` — **Apache-2.0**. Parakeet TDT v3 / Parakeet Ultra (25 European languages incl. Swedish; weights **CC-BY-4.0**) and Nemotron Unified multilingual streaming (read `Documentation/Models.md`, `Documentation/ASR/GettingStarted.md`, `Documentation/ASR/ParakeetUltra.md`).

**Do:**
- Extend `tools/stt-bench/` so the same WAV set and the same scoring code run through: KB-Whisper small + medium (WhisperKit), Parakeet Ultra (or TDT v3) and Nemotron Unified multilingual with language `sv` (FluidAudio CLI or a small Swift CLI target).
- Record WER, CER, short-prompt exact-match and real-time factor on the Mac. Label all on-device numbers as **"Mac proxy — iPhone not verified"**.
- Pick at most the best two on-device candidates and run one 60 s WAV through each **on the iPhone** (Diagnostics debug button) to get a real iPhone real-time factor and memory peak.

**Acceptance:** results added to `reports/data/phase1-stt-results.csv` with a `provider` value per model; report section "On-device Swedish candidates" with verified/unverified labels; licences recorded in `THIRD_PARTY_NOTICES.md` only for what is actually kept.

---

## OSS-2 — VAD + optional noise suppression (Phase 2 — wait for go-ahead)

**Source:** FluidAudio @ `ee78635` (Apache-2.0). Read `Documentation/VAD/GettingStarted.md`, `Documentation/VAD/Segmentation.md`, `Documentation/Enhancement/LocalVQE.md`. Add via SwiftPM **pinned**, with traits limited to what we use (README shows the ASR+VAD-only trait setup).

**Do:**
- `Core/Understanding/VoiceActivity.swift`: Silero VAD over our 16 kHz stream → speech segments + end-of-speech events for the question gate. Measure added latency (Silero works on 256 ms windows).
- `Core/Audio/SpeechEnhancer.swift`: LocalVQE (beta) as an **optional** pre-STT stage, off by default. A/B it in the benchmark by **WER**, not by ear; ship enabled only if it lowers WER on AirPods HFP audio.
- Verify the Silero CoreML model card licence before shipping and record it.

**Acceptance:** VAD segments match speech in the Phase 1 recordings (report precision/recall vs. hand labels on 5 files); LocalVQE A/B results in the report; no model downloads without user-visible progress.

---

## OSS-4 — Sentence streaming + interruptible answer pipeline (Phase 4 — wait for go-ahead)

**Source:** https://github.com/fikrikarim/volocal @ `b731963` — **MIT** (Copyright (c) 2026 Fikri Karim).

**Read:** `Volocal/Pipeline/SentenceBuffer.swift`, `Volocal/Pipeline/VoicePipeline.swift`, `Volocal/Audio/SharedAudioEngine.swift` (reference only — its session is `.voiceChat` + speaker, not our AirPods config; do not copy the session setup).

**Do:**
- Vendor `SentenceBuffer` into `Core/Voice/SentenceBuffer.swift`, then add Swedish rules: don't split on abbreviations ("t.ex.", "bl.a.", "dvs.", "osv.", "ca.", "s.k.", "kl."), decimal numbers ("3,5", "3.5"), ordinals ("1."), and a minimum first-chunk length so TTS can start early.
- Reimplement the cancel/interrupt pattern from `VoicePipeline` inside our `SessionOrchestrator` actor (new question while answering → cancel generation + flush TTS queue).

**Tests:** table-driven unit tests for Swedish sentence splitting (≥ 30 cases); orchestrator cancel test with mocks.

**Acceptance:** first sentence reaches TTS before the LLM stream ends; tests pass; MIT header kept.

---

## Report when finished
Per `CLAUDE.md`: one report per task in `reports/` (e.g. `reports/YYYY-MM-DD-HHMM-oss-1-apple-stt-provider.md`), `docs/STATUS.md` and `docs/DECISIONS.md` updated, `THIRD_PARTY_NOTICES.md` current. Short chat summary to Aron with the report path.
