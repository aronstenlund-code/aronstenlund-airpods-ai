# Architecture — Lumen (codename)

> Codename "Lumen" is a placeholder until the product owner picks a name.
> Status legend used throughout: **[VERIFIED]** = confirmed in official docs or on hardware · **[DOCS]** = documented by Apple/provider but not yet tested by us · **[ASSUMPTION]** = unverified, must be tested.

Last updated: 2026-11-03 by the Architect session.

---

## 1. Product in one paragraph

An iPhone app that listens to the room through a microphone, transcribes speech continuously, decides when something was asked that the user would want answered, generates a short answer and speaks it into the user's AirPods — with selectable voices and speed, a text-only silent mode, user-triggered note-taking and an optional preparation mode with study material.

## 2. Platform baseline

| Decision | Value | Why |
|---|---|---|
| Minimum OS | **iOS 26.0** | Needed for `SpeechAnalyzer`/`SpeechTranscriber` and `AVAudioSession.CategoryOptions.bluetoothHighQualityRecording` [DOCS] |
| Language | Swift 6, strict concurrency | Audio + network pipeline is concurrency-heavy; catch data races at compile time |
| UI | SwiftUI + Observation (`@Observable`) | Modern, no third-party UI deps |
| Devices | iPhone with Neural Engine. `SpeechTranscriber` reported unavailable on iPhone SE 2nd gen and not in Simulator [DOCS – community reports] | All audio/STT testing must be on real hardware |
| Dependencies | Zero runtime third-party SDKs in Phase 1. Provider SDKs only if they clearly beat a thin `URLSession`/WebSocket client. XcodeGen allowed as a dev-only tool. | Spec: "avoid unnecessary dependencies" |

## 3. High-level pipeline

```
 ┌────────────┐   PCM 16 kHz mono   ┌──────────────┐  partial/final text  ┌──────────────────┐
 │ Capture    │ ──────────────────▶ │ Transcription│ ───────────────────▶ │ Context buffer   │
 │ (AVAudio-  │                     │ (STTProvider)│                      │ (rolling window, │
 │  Engine)   │                     └──────────────┘                      │  speaker turns)  │
 └────────────┘                                                           └────────┬─────────┘
       ▲                                                                           │
       │ route/interruptions                                                       ▼
 ┌────────────┐                                                       ┌──────────────────────┐
 │ AudioSession│◀─── Session Orchestrator (actor, state machine) ───▶ │ Question detector    │
 │ Manager     │                                                       │ 1) local gate        │
 └────────────┘                                                       │ 2) LLM classifier    │
       │                                                               └──────────┬───────────┘
       ▼                                                                          ▼
 ┌────────────┐   audio chunks      ┌──────────────┐   streamed tokens   ┌──────────────────┐
 │ Playback   │ ◀────────────────── │ TTSProvider  │ ◀────────────────── │ Answer engine    │
 │ (AirPods)  │                     └──────────────┘                     │ (LLM via backend)│
 └────────────┘                                                          └──────────────────┘
```

All cloud calls go through **our backend** (token broker + LLM proxy). No provider API key ever ships in the app.

## 4. Audio architecture (Priority 1)

### 4.1 Capture strategies — must be decided by measurement in Phase 1

| ID | Session config | Input | Output | Status |
|---|---|---|---|---|
| **B-HQ** | `.playAndRecord`, mode `.default` only, `[.bluetoothHighQualityRecording, .allowBluetoothHFP]` | AirPods mic, full bandwidth | AirPods | [DOCS] Apple: **not currently supported in the EU**; can only be requested in `.default`; may increase input latency, not recommended for real-time communication. Falls back to HFP. |
| **C-HFP** | `.playAndRecord`, `[.allowBluetoothHFP]`, modes `.default` / `.measurement` / `.voiceChat` | AirPods mic, narrowband/wideband speech | AirPods (HFP — call quality) | [DOCS] available everywhere. Pickup of other speakers: [ASSUMPTION – measure] |
| **A-ref** | `.playAndRecord`, `[.allowBluetoothA2DP]` only | iPhone mic | AirPods (A2DP) | Reference measurement only |

HQ detection [DOCS]: `currentRoute.inputs.first?.bluetoothMicrophoneExtension?.highQualityRecording` → `isSupported` (port can do it) and `isEnabled` (active in this session). Logged on every test.

Consequence for Sweden: the realistic AirPods path is **HFP**, which also downgrades AirPods *output* to call quality while the mic is active. Answer audio quality under HFP must be rated in Phase 1.

**Decision (product owner, 2026-11-03):** capture through the **AirPods microphones**. Request B-HQ where available (falls back to HFP automatically); in the EU expect C-HFP. The user sits close to the speaker. A-ref is only a measured reference.

Known limitation [ASSUMPTION – measure in Phase 1]: AirPods mics are beamformed toward the wearer's mouth, so other speakers are captured at lower level. Phase 1 measures usable speech pickup vs. distance (1 m / 2 m / 4 m). Software mitigations: no voice-processing IO, `.measurement` mode if it reduces processing (HFP only — HQ requires `.default`), gain normalization before STT, noise-robust cloud STT with keyterms (Phase 2).

### 4.2 Capture pipeline
- `AVAudioEngine` input tap → `AVAudioConverter` → **16 kHz, mono, Int16 PCM** (the common denominator for Apple and cloud STT).
- Fan-out via `AsyncStream<AudioChunk>` (20–100 ms chunks) + a **60 s ring buffer** (lets us re-transcribe context and supports "answer the last question" on demand).
- No voice-processing IO (`setVoiceProcessingEnabled(false)`) — we want the room, not just one voice. Test session modes per §4.1.
- Audio is **not persisted** by default. Debug builds may write WAV files for analysis.

### 4.3 Playback
- One `AVAudioPlayerNode` on the same engine for TTS audio; plays while capture keeps running.
- Speed control: `AVAudioUnitTimePitch` (rate without pitch change) as a provider-independent fallback; use provider speed param when available.
- Self-hearing: answers play inside the ears while the AirPods mics are live; leakage into the mics is [ASSUMPTION – measure]. Orchestrator still tags transcript segments that overlap our own playback so they are never treated as questions.

### 4.4 Background & lifecycle
- `UIBackgroundModes` → `audio`. While recording/playing, the app is not suspended; when it stops, it is suspended [DOCS – Apple DTS answer]. iOS always shows the microphone indicator while the mic is in use — this is desirable for consent.
- Capture must be **started in the foreground** by explicit user action [ASSUMPTION – verify; starting input from background is generally refused].
- Handle: interruptions (calls, Siri, alarms), route changes (AirPods removed → pause + haptic), media services reset, other apps' audio (decide mix vs. duck).

## 5. Speech recognition (Priority 2)

Provider-agnostic `STTProvider` protocol (`start(stream:) -> AsyncStream<TranscriptEvent>` with `.partial`, `.final`, `.endpoint`).

| Provider | Where | Swedish | Latency | Notes |
|---|---|---|---|---|
| Apple `SpeechTranscriber` (iOS 26) | on-device | **Not confirmed** — community lists ~10–30 locales, Swedish not listed at launch [DOCS/unclear] | low, no network | Free, private, long-form; check `supportedLocales` on device |
| Apple `DictationTranscriber` | on-device | likely (legacy dictation locales) [ASSUMPTION] | low | Lower accuracy fallback |
| ElevenLabs Scribe v2 Realtime | cloud WebSocket | **Yes** (90+ languages) [DOCS] | ~150 ms [DOCS] | Client connects with a **single-use token** from our backend, expires after 15 min [DOCS] |
| Deepgram Nova-3 streaming | cloud WebSocket | **Yes** (`sv`, `sv-SE`) [DOCS] | sub-300 ms [DOCS] | Keyterm prompting for subject vocabulary |

**Decision (provisional):** build the protocol + Apple provider first (no backend needed), then one cloud provider; choose the default per language from a **bake-off** on our own recorded test set (classroom-like distance, noise, sv + en). Prep-mode material later feeds keyterms/vocabulary.

## 6. Question detection (Priority 3)

Two stages so we don't pay an LLM call for every sentence:

1. **Local gate** (cheap, every final segment): endpoint/pause detected, segment length, interrogative words (sv/en), math-expression patterns ("five plus two", "roten ur 100"), short topical noun phrases, imperative cues ("explain", "förklara"), cooldown/rate limit, and drop anything overlapping our own playback.
2. **LLM classifier** (only when the gate fires): input = last ~60 s of transcript + prep-mode context; output = strict JSON `{answer: bool, confidence: 0–1, interpreted_query: string, language: "sv"|"en"}`. User-adjustable sensitivity = confidence threshold.

Always available manual paths: on-screen "answer last" button, text input (silent mode). AirPods stem/remote-command trigger is a candidate [ASSUMPTION – needs research: `MPRemoteCommandCenter` only works while we are the Now Playing app].

## 7. Answer engine (Priority 4)

- Backend streams an LLM response (SSE). Small/fast model for classification + answers by default; larger model only on explicit request or low-confidence escalation.
- Answer contract: 1–2 sentences unless asked otherwise, same language as question, **text pre-normalized for TTS** (numbers/symbols spelled out — ElevenLabs Flash v2.5 disables normalization for latency [DOCS]).
- Provider-agnostic `AnswerEngine` interface server-side, so the model can be swapped without an app update.

## 8. Voice output (Priority 5)

| Option | Latency | Swedish | Role |
|---|---|---|---|
| ElevenLabs Flash v2.5 | ~75 ms model latency; ~200 ms median first audio in a third-party benchmark [DOCS] | Yes (32 languages) | Default premium voices |
| `AVSpeechSynthesizer` | on-device | Yes | Offline / no-quota fallback, also used in Phase 1 tests |

Stream answer → split at sentence boundaries → TTS per sentence → enqueue on player. Target: first audio while the LLM is still generating.

## 9. Latency budget (targets, to be measured)

From end of the question being spoken to first answer audio in the ear:

| Stage | Target |
|---|---|
| Endpoint detection | 300–500 ms |
| Final transcript | ≤ 300 ms |
| Gate + classifier | ≤ 400 ms (classifier skipped for strong gate hits) |
| LLM first sentence | ≤ 500 ms |
| TTS first audio | ≤ 250 ms |
| **Total p50** | **≤ 1.5 s** (p90 ≤ 2.5 s) |

Every stage logs timestamps (`os_signpost`) from Phase 1 on.

## 10. Backend

**Supabase** (Edge Functions + Auth + Postgres) — chosen because the product owner already operates Supabase and it gives auth + storage for notes later.

Phase 2–4 endpoints:
- `POST /stt-token` → returns a provider single-use token (no API key on device).
- `POST /answer` → classifier + answer, streamed (SSE).
- `POST /tts` → streams audio (proxy) — or token-based direct connection if the provider supports single-use TTS tokens [ASSUMPTION – verify].
- Auth: anonymous Supabase auth per install first; rate limiting per user from day one (cost protection).

## 11. App module layout

```
Lumen/
  App/                  // entry, DI container, scene
  Core/
    Audio/              // AudioSessionManager, CaptureService, PlaybackService, RouteMonitor, AudioFormat, RingBuffer
    Transcription/      // STTProvider protocol, AppleSpeechProvider, CloudSTTProvider
    Understanding/      // ContextBuffer, QuestionGate, ClassifierClient
    Answer/             // AnswerClient (SSE)
    Voice/              // TTSProvider, ElevenLabsTTS, SystemTTS
    Session/            // SessionOrchestrator (actor), SessionState
    Telemetry/          // signposts, latency log
  Features/
    Listening/  Settings/  Notes/  Prep/  Diagnostics/
  Tests/
```

Orchestrator is a single `actor` with an explicit state machine (`idle → arming → listening → answering → paused → error`). UI observes state; no business logic in views.

## 12. Privacy, consent and policy

- App Store Review Guidelines require **explicit user consent** and a **clear visual or audible indication** when an app records or logs user activity [DOCS].
- In-app: consent screen before first session, persistent listening indicator in-app + the system mic indicator, one-tap stop.
- No audio stored by default; transcripts stored locally; cloud providers configured for zero/limited retention where offered.
- GDPR applies (Sweden/EU): privacy policy, data-processing terms with every provider, deletion.
- Product positioning: learning/lecture companion with consent. Not marketed for exams or covert use (see RISKS in STATUS.md).
