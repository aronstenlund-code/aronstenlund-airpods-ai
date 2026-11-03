# Project status — Lumen (codename)

Single overview page. Update it at the end of every session.
Last updated: 2026-11-03 19:05 by Angela (builder).

## Completed
- Phase 0: initial analysis, architecture, roadmap, MVP definition, first coding assignment. → `reports/2026-11-03-1600-architect-initial-analysis.md`
- EU restriction on AirPods high-quality recording verified in Apple docs; Phase 1 plan updated. → `reports/2026-11-03-1615-architect-eu-hq-restriction.md`
- Open-source code audit: reusable components and licences. → `reports/open-source-code-audit.md`; assignments for Angela in `prompts/2026-11-03-oss-integration.md`
- **Phase 1a — CI build (Angela):** Phase 1 §3.1–3.7 implemented and green on `main` (device build, warnings as errors, 21 + 41 unit tests, SDK API-name check 24/24). **Verified in CI only, nothing on device.** → `reports/2026-11-03-1905-angela-phase1a-ci.md`, `docs/DEVICE-TEST-CHECKLIST.md`, D13–D17.

## In progress
- Phase 1 — Audio foundation. Code done (Phase 1a); **device measurements (§3.5–3.6, §3.9–3.12) wait for the owner's Mac** next week — run `docs/DEVICE-TEST-CHECKLIST.md`. Then OSS-1 + OSS-3.
- **MVP sprint (Angela):** `prompts/2026-11-03-mvp-sprint-app.md` — step 0 done (CI green, Phase 1a report pushed); next: item 1 listening screen + consent.

- **MVP backend (Kevin).** `/answer` (SSE) + `/tts` built and tested offline (46 Deno tests, mock LLM); **not deployed**. Blocked on: owner approval to create a Supabase project, and the owner entering `ANTHROPIC_API_KEY` / `ELEVENLABS_API_KEY` / `ELEVENLABS_VOICE_ID` as Supabase secrets himself. TTFT on the 30 prompts not yet measured. → `reports/2026-11-03-1900-kevin-backend.md`, `backend/README.md`, D20.

## Next
- Phase 2 — Transcription (after the Phase 1 report is reviewed).

## Known bugs
- None confirmed (no device run yet). Known limitations of the Phase 1 code are listed in `reports/2026-11-03-1905-angela-phase1a-ci.md` §5.

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
