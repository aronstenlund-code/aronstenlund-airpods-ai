# Report: AirPods high-quality recording — EU restriction & updated Phase 1 test plan

Date: 2026-11-03 · Session: Architect · Type: research + plan change (no code)

## 1. Trigger
Product owner found that Apple's documentation says Bluetooth high-quality recording is not currently supported in the EU. Checked against the primary source before changing the plan.

## 2. Findings (Apple docs: `AVAudioSession.CategoryOptions.bluetoothHighQualityRecording`)

| Claim | Status |
|---|---|
| Enables full-bandwidth audio when the Bluetooth route supports it (certain AirPods models) | Verified in docs |
| Can be combined with `allowBluetoothHFP`, which is the fallback when the route doesn't support it | Verified in docs |
| Can only be requested in `.default` session mode | Verified in docs |
| **Not currently supported in the European Union** | Verified in docs |
| Capability API: `inputPort.bluetoothMicrophoneExtension?.highQualityRecording.isSupported` and `.isEnabled` | Verified in docs |
| May increase input latency; not recommended for real-time communication | Verified in docs |
| What triggers the EU restriction (device region, Apple account country, location…) | **Not verified** — undocumented; Phase 1 logs region per test |
| Whether Apple's own studio-quality recording (Voice Memos/Camera) works in Sweden | **Not verified** — manual check in Phase 1 |
| Which AirPods models report `isSupported` | **Not verified** — press coverage says AirPods 4, AirPods 4 ANC, AirPods Pro 2; measure |
| How well AirPods (HFP) capture other people's voices at 1–4 m | **Not verified** — core Phase 1 measurement |
| HFP output (answer audio) quality while mic is live | **Not verified** — rated in Phase 1 |

## 3. Plan changes
- Capture configs replaced: **B-HQ** (`.default` only, `[.bluetoothHighQualityRecording, .allowBluetoothHFP]`), **C-HFP** in `.default`, `.measurement`, `.voiceChat`, and **A-ref** (iPhone mic) as reference. Removed the invalid "HQ + `.measurement`" combination.
- New mandatory per-test logging: input port, mode, options, sample rate, channels, HQ `isSupported` + `isEnabled`, device region, OS version. Every CSV row carries these fields.
- System recording feature vs. developer API reported separately.
- AirPods stay the primary microphone; EU restriction changes the expected path to HFP, it does not remove AirPods from testing.
- Updated: `prompts/2026-11-03-phase1-audio-foundation.md` (§3.2, §3.6, §3.10–3.12, tests, acceptance, report), `docs/ARCHITECTURE.md` §4.1, `docs/DECISIONS.md` D10, `docs/STATUS.md` R10.

## 4. Technical assessment (pre-measurement)
- AirPods as mic in Sweden: **possible with limitations** (HFP).
- AirPods HQ recording in Sweden for a third-party app: **not possible with current technology per Apple docs** (unless the restriction is lifted or its trigger turns out not to apply) — to be confirmed by `isEnabled` logs.
- HFP accuracy for other speakers at 1–4 m: **not yet verified**.

## 5. Next
Coding agent executes Phase 1 with the updated prompt. Architect reviews the report and recommends the Phase 2 STT/audio setup.

Source: https://developer.apple.com/documentation/avfaudio/avaudiosession/categoryoptions-swift.struct/bluetoothhighqualityrecording
