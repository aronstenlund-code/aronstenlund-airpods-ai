# Project status — Lumen (codename)

Single overview page. Update it at the end of every session.
Last updated: 2026-11-03 17:00 by CREED (project supervisor).

## Completed
- Phase 0: initial analysis, architecture, roadmap, MVP definition, first coding assignment. → `reports/2026-11-03-1600-architect-initial-analysis.md`
- EU restriction on AirPods high-quality recording verified in Apple docs; Phase 1 plan updated. → `reports/2026-11-03-1615-architect-eu-hq-restriction.md`
- Open-source code audit: reusable components and licences. → `reports/open-source-code-audit.md`; assignments for Angela in `prompts/2026-11-03-oss-integration.md`

## In progress
- Phase 1 — Audio foundation. Assignment: `prompts/2026-11-03-phase1-audio-foundation.md`. **Blocked:** Angela's session runs on Windows (no Xcode, no Swift, no reachable Mac), so §3.1–3.7 cannot be built or run; see `reports/2026-11-03-1645-angela-phase1-blocked-no-mac.md` for options. Done so far: test material §3.8 in `testdata/` (noise file not yet chosen). Then OSS-1 + OSS-3 from `prompts/2026-11-03-oss-integration.md`.
- **Phase 1a — CI build (unblocks Phase 1 code this week).** Assignment: `prompts/2026-11-03-phase1a-ci-build.md`. GitHub Actions macOS runner is the compiler until the product owner has a Mac with Xcode 26 (planned next week). Device tests wait for that Mac.

## Next
- Phase 2 — Transcription (after the Phase 1 report is reviewed).

## Known bugs
- None yet (no code).

## Open decisions for the product owner
0. **Build environment:** decided 2026-11-03 — code is compiled in GitHub Actions (Phase 1a) this week; product owner gets a Mac with Xcode 26 next week for on-device runs (free Apple ID first; paid Developer Program only when TestFlight is needed). The current Mac cannot install software.
1. Product name + bundle identifier (placeholder: Lumen, `com.rsolutions.lumen`).
2. Primary launch language(s): proposed Swedish + English.
3. Positioning: lecture/study companion with consent (recommended) vs. "answers the teacher's questions in class" (high App Store/commercial risk, see R6).

## Technical risks

| ID | Risk | Impact | Status / mitigation |
|---|---|---|---|
| R1 | AirPods mics favour the wearer's voice; speakers 1–4 m away may be too weak/processed for accurate STT | **Critical** — core feature depends on hearing the speaker | Phase 1 measures pickup vs. distance per mode; Phase 2 picks the most noise-robust Swedish STT |
| R10 | Bluetooth high-quality recording not supported in the EU (Apple docs); HFP gives narrowband input **and** call-quality output while the mic is live | High — affects STT accuracy and answer audio quality | Phase 1 measures HFP vs. HQ (where available) per model; log `isSupported`/`isEnabled` and device region |
| R2 | Apple `SpeechTranscriber` may not support Swedish | High | Fallback to DictationTranscriber or cloud STT; check `supportedLocales` on device in Phase 1 |
| R3 | Far-field / noisy classroom audio → poor transcription | High | Bake-off on our own recordings; cloud models with keyterms; phone placement guidance |
| R4 | End-to-end latency > 2 s feels useless | High | Streaming at every stage, sentence-level TTS, signposts from day one |
| R5 | False positives (answering things nobody asked) annoy users | Medium | Two-stage detection + sensitivity + cooldown + evaluation set |
| R6 | App Store / school policy: an app that whispers answers to teacher questions can be seen as cheating; Apple requires explicit consent + clear recording indication | **High (commercial)** | Position as study/lecture companion, consent flow, visible indicator, no exam use in marketing |
| R7 | Cloud cost per listening hour (STT + LLM + TTS) | Medium | Local gate before LLM, on-device STT where good enough, rate limits, measure cost per hour in Phase 4 |
| R8 | Background capture stops (suspension, interruptions) | Medium | Phase 1 background + interruption tests |
| R9 | Bystander privacy / GDPR | Medium | No audio stored, local transcripts, provider DPAs, privacy policy |

## Architectural decisions
See `docs/DECISIONS.md`.
