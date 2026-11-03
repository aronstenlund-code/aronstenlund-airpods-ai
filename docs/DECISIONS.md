# Architecture decision log

Format: ID · date · status · decision · reason. Status: Proposed / Accepted / Superseded.

| ID | Date | Status | Decision | Reason |
|---|---|---|---|---|
| D1 | 2026-11-03 | Accepted | Minimum iOS 26, Swift 6 strict concurrency, SwiftUI + Observation | SpeechAnalyzer + AirPods high-quality recording are iOS 26 APIs |
| D2 | 2026-11-03 | Accepted | No provider API keys in the app; backend issues single-use tokens / proxies calls | Spec quality requirement; ElevenLabs supports 15-min single-use tokens for realtime STT |
| D3 | 2026-11-03 | Superseded by D10 | Default capture = iPhone built-in mic, output = AirPods via A2DP (Strategy A) | — |
| D10 | 2026-11-03 | Accepted (owner) | Default capture = AirPods mic: request `bluetoothHighQualityRecording` (mode `.default`) with `allowBluetoothHFP` fallback; user sits near the speaker | Product owner decision. Apple: HQ not currently supported in the EU → HFP expected in Sweden; Phase 1 measures both |
| D4 | 2026-11-03 | Accepted | Internal audio format 16 kHz mono Int16 PCM | Accepted by Apple and cloud STT providers; small payloads |
| D5 | 2026-11-03 | Proposed | Provider-agnostic interfaces for STT, LLM and TTS; pick defaults per language via bake-off | Fast-moving vendor market; Swedish support differs per provider |
| D6 | 2026-11-03 | Proposed | Backend on Supabase (Edge Functions, Auth, Postgres) | Owner already operates Supabase; covers auth + notes storage |
| D7 | 2026-11-03 | Accepted | Two-stage question detection (local gate → LLM classifier) | Cost + latency + false-positive control |
| D8 | 2026-11-03 | Accepted | No audio persisted by default; consent screen + visible indicator | App Store recording rules, GDPR, trust |
| D9 | 2026-11-03 | Proposed | XcodeGen (`project.yml`) as dev-only tool for a reproducible project file | Agents edit YAML far more reliably than `.pbxproj` |
| D11 | 2026-11-03 | Accepted (owner) | richlira/MeetingMindAI @ `0cef092` may be reused under MIT as declared in its README (no LICENSE file upstream); attribution in THIRD_PARTY_NOTICES | Product owner verified; residual risk low; ask author to add LICENSE |
