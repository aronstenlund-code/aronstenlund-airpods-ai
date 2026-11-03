# Report: Initial analysis & architecture (Architect)

Date: 2026-11-03 · Session: Architect · Type: analysis/decisions (no code)

## 1. What was done
- Analysed the product concept and turned it into an architecture (`docs/ARCHITECTURE.md`), roadmap + MVP (`docs/ROADMAP.md`), status/risk register (`docs/STATUS.md`) and decision log (`docs/DECISIONS.md`).
- Researched the critical Apple and provider constraints (findings below).
- Wrote the first coding assignment: `prompts/2026-11-03-phase1-audio-foundation.md`.
- Added `CLAUDE.md` so every coding session reads the state and writes reports.

## 2. Research findings

### Verified in documentation
| Topic | Finding | Source |
|---|---|---|
| AirPods high-quality capture | iOS 26 adds `AVAudioSession.CategoryOptions.bluetoothHighQualityRecording`; full-bandwidth input + output when the Bluetooth route supports it (certain AirPods models). Also available via `AVCaptureSession`. | Apple docs; WWDC25 session 251 |
| A2DP output + other input | With `.playAndRecord`, `.allowBluetoothA2DP` lets an A2DP device be the output while recording through the category-appropriate input. | AVAudioSessionCategoryOptions header docs |
| iPhone mic → AirPods out | Apple WWDC lab answer (forum 741513): use **only** `.allowBluetoothA2DP`, not `.allowBluetooth`, to record from the built-in mic and play on AirPods. | developer.apple.com/forums/thread/741513 |
| Background | With `UIBackgroundModes=audio` the app keeps running while it records or plays; when that stops it is suspended. | Apple DTS answer, forum 106415 |
| On-device STT | `SpeechAnalyzer` + `SpeechTranscriber` (iOS 26): on-device, long-form, no 1-minute limit, volatile + final results. `DictationTranscriber` covers more locales with lower accuracy. Not available in Simulator. | WWDC25 session 277; community docs |
| Cloud STT, Swedish | ElevenLabs Scribe v2 Realtime: 90+ languages incl. Swedish, ~150 ms; Deepgram Nova-3 supports `sv`/`sv-SE`, sub-300 ms streaming. | elevenlabs.io, developers.deepgram.com |
| Key security | ElevenLabs realtime STT supports server-issued single-use tokens that expire after 15 minutes. | ElevenLabs docs (client-side streaming) |
| TTS | ElevenLabs Flash v2.5: ~75 ms model latency, 32 languages incl. Swedish, text normalization disabled (LLM must normalize numbers). | elevenlabs.io/docs/models |
| App Store | Apps must request explicit consent and show a clear visual/audible indication while recording user activity. | App Store Review Guidelines (as reported by Apple spokesperson, 2019; current text summarised by third parties) |

### Conflicting / unverified — must be tested
1. **Does Strategy A really capture from the iPhone mic?** Forum 784318 (iOS 18.4.1) reports audio that sounded like the AirPods mic with voice isolation even though `currentRoute` said built-in mic. That setup also used `.defaultToSpeaker`. → Phase 1 physical verification test.
2. **Swedish in `SpeechTranscriber`.** Sources disagree (≈10, ≈30, "40-some" locales); Swedish was not in the launch list. → check `supportedLocales` on device in Phase 1.
3. AirPods mic pickup of distant speakers with `bluetoothHighQualityRecording`. → measure.
4. Starting capture from background, AirPods stem/remote-command trigger, ElevenLabs single-use tokens for TTS. → later phases.

## 3. Key architectural decisions
D1–D9 in `docs/DECISIONS.md`. Most important: iOS 26 baseline, keys only on backend, provider-agnostic STT/LLM/TTS, two-stage question detection, Strategy A as provisional default (pending measurements).

## 4. Biggest risks
R1 (room capture), R6 (App Store/school positioning), R2 (Swedish on-device STT), R4 (latency). Full table in `docs/STATUS.md`.

## 5. Testing
None (no code). Everything above is documentation-level unless stated.

## 6. Remaining work / next session
- Coding agent executes Phase 1 (`prompts/2026-11-03-phase1-audio-foundation.md`).
- Product owner answers the open decisions in `docs/STATUS.md` (name, languages, positioning).
- Architect reviews the Phase 1 report, then writes the Phase 2 assignment.
