# Project status — Lumen (codename)

Single overview page. Update it at the end of every session.
Last updated: 2026-11-03 23:34 by Angela (builder).

## Completed
- Phase 0: initial analysis, architecture, roadmap, MVP definition, first coding assignment. → `reports/2026-11-03-1600-architect-initial-analysis.md`
- EU restriction on AirPods high-quality recording verified in Apple docs; Phase 1 plan updated. → `reports/2026-11-03-1615-architect-eu-hq-restriction.md`
- Open-source code audit: reusable components and licences. → `reports/open-source-code-audit.md`; assignments for Angela in `prompts/2026-11-03-oss-integration.md`
- **Phase 1a — CI build (Angela):** Phase 1 §3.1–3.7 implemented and green on `main` (device build, warnings as errors, 21 + 41 unit tests, SDK API-name check 24/24). **Verified in CI only, nothing on device.** → `reports/2026-11-03-1905-angela-phase1a-ci.md`, `docs/DEVICE-TEST-CHECKLIST.md`, D13–D17.

## In progress
- Phase 1 — Audio foundation. Code done (Phase 1a); **device measurements (§3.5–3.6, §3.9–3.12) wait for the owner's Mac** next week — run `docs/DEVICE-TEST-CHECKLIST.md`. Then OSS-1 + OSS-3.
- **MVP sprint (Angela):** `prompts/2026-11-03-mvp-sprint-app.md` — **items 1–9 implemented and green in CI** (run 41729913430, 193 app tests): consent + listening screen + indicator (D21), on-device STT chain (D22), activation hold-to-ask/auto/QuestionGate (D24), answer engine `CloudAnswerProvider` against Kevin's deployed `/answer` with anonymous Supabase auth (D25), voice output Apple + ElevenLabs via `/tts` sentence by sentence (D26), text mode, latency log + debug overlay, local notes, prep material → STT contextual strings + `prep_terms` (D27). **Untested on device; the app has never called the live backend** (backend live since 22:38 per Deangelo, slow TTFT; `GET /voices` not deployed yet), so nothing is marked done. Reports: `reports/2026-11-03-2115-angela-mvp-item1-listening-consent.md`, `reports/2026-11-03-2140-angela-mvp-item2-stt.md`, `reports/2026-11-03-2334-angela-mvp-item3-activation.md`, `reports/2026-11-03-2334-angela-mvp-item4-answer-engine.md`, `reports/2026-11-03-2334-angela-mvp-items5-9-voice-text-latency-notes-prep.md`. **Next: item 10 / Track D is gated** on the Architect's Track D report (`reports/*-architect-trackD-verification.md`, not pushed yet) per `prompts/2026-11-03-trackD-spike.md`; then the first device session (`docs/DEVICE-TEST-CHECKLIST.md` §3i–3p).

- **MVP backend (Kevin).** Supabase project **Lumen** (`xjczbzfkmbjdebwlccki`, eu-north-1, free plan) created; migration applied (rate limiter verified in DB); `/answer` and `/tts` **deployed** and reject bad tokens (verified live). **Not yet usable by the app:** owner must (1) switch on *Anonymous sign-ins* and (2) add secrets `ANTHROPIC_API_KEY`, `ELEVENLABS_API_KEY`, `ELEVENLABS_VOICE_ID` (click paths in `backend/README.md`); (3) the build container must allow `*.supabase.co` before Kevin can run the TTFT test. **For Angela:** project URL + publishable key + flow are in `backend/README.md` > *Connect the app*; wire `AnswerClient` to it but expect `503 provider_unconfigured` until STATUS says "backend live". Report: `reports/2026-11-03-1900-kevin-backend.md`, D20.
- **Backend latency (Kevin, D28/D31).** First answer text (30 Swedish prompts, `push_to_talk`, client inside Supabase): **p50 1 590 ms -> 980 ms, p90 2 005 -> 1 079 ms**; target <700 ms **not yet met**. v3 (SDK-free, warm-up endpoints) is deployed but unmeasured: needs `*.supabase.co` allowed in the build container (then `deno task ttft`). App: send `GET answer` + `x-warm: 1` when the listening screen opens; start TTS on the first sentence. `auto` mode and the 30-prompt answer quality after the prompt change are not yet reviewed. Report: `reports/2026-11-03-2330-kevin-latency.md` (+ addendum: local e2e test `deno task e2e`, `ttft --set auto`).

## Next
- Phase 2 — Transcription (after the Phase 1 report is reviewed).

## Known bugs
- None confirmed (no device run yet). Known limitations of the Phase 1 code are listed in `reports/2026-11-03-1905-angela-phase1a-ci.md` §5.

## Reminders
- **Anthropic API key expires 2026-12-03** (created 2026-11-03 with 30-day expiry). Before then: create a new key in console.anthropic.com and replace the Supabase secret `ANTHROPIC_API_KEY` in project Lumen. The backend fails closed (`provider_unconfigured`/auth error) if it expires.

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
