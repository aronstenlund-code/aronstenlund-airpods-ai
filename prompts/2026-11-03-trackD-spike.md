# Claude Code assignment (Angela) — Track D spike: activation probes + push-to-talk + low-voice tests

Approved by: CREED, 2026-11-03.
**Deadline note (CREED 17:50):** the MVP sprint (`prompts/2026-11-03-mvp-sprint-app.md`) comes first; push-to-talk is already part of it. Do the rest of this spike after the core loop works.
**Start condition:** your Phase 1a report is pushed **and** the Architect's Track D report (`reports/*-architect-trackD-verification.md`) is pushed. If the Architect changed this file, follow the latest version.
Read first: `CLAUDE.md`, `docs/STATUS.md`, `reports/2026-11-03-1800-creed-track-d-discreet-interaction.md`, the Architect's Track D report.

## 1. Objective
Add a "Track D lab" to the Diagnostics app so the product owner's first on-device session also answers: which activation paths work on his AirPods, how quiet the user can speak, and whether explicit activation fixes false triggers. Compile and unit-test via CI (Phase 1a); nothing counts as verified until run on device.

## 2. Build
1. **Activation probe screen** — while capture runs in each config (C-HFP-default/measurement/voiceChat, B-HQ, A-ref), foreground / background / locked, log with timestamps every event from:
   - `AVAudioApplication.inputMuteStateChangeNotification` (+ `muteStateKey`, `isInputMuted`)
   - `MPRemoteCommandCenter` play/pause/toggle/next/previous (only enable commands while the probe runs; restore afterwards)
   - `CMHeadphoneMotionManager` availability + raw attitude/rotation stream (add `NSMotionUsageDescription`)
   Output: table "gesture → event received? latency?" per config/state, included in "Copy results as Markdown".
2. **Push-to-talk prototype** — `ActivationManager` per the Architect's design. Sources: in-app hold/tap button; a Control (Lock Screen / Control Center / Action button) via App Intent; stem press **only** through a path the probe proves. Visible listening indicator in every state. Input is genuinely muted when not in a user turn.
3. **Head-gesture classifier (experimental)** — simple nod/shake detector on motion data with logged precision; off by default.
4. **Low-voice test flow** — guided runs: wearer reads the 30 short prompts at normal / low / whisper level in quiet / office / transit noise; store WAV + RMS + SNR; score with `Packages/LumenScoring`.
5. **Fragment set** — `testdata/scripts/sv-fragments.md`: 40 Swedish keyword fragments (1–5 words) with intended full question and expected short answer, mixed subjects; plus 10 fragments that only make sense with the previous turn (context pairs).
6. **Contextual strings A/B** — DictationTranscriber with and without `AnalysisContext.contextualStrings` built from a sample prep topic; compare keyword accuracy on the same recordings.
7. **Bystander level** — instructions in the checklist: measure the wearer's voice at 1 m with the same free sound-level app each run; field in results.
8. Extend `docs/DEVICE-TEST-CHECKLIST.md` (Swedish) with the Track D steps, keeping total session time realistic (mark which runs are must-have vs. optional).

## 3. Constraints
- No concealment features; indicator always visible while capturing.
- No paid services; cloud STT comparisons only if the product owner has provided test keys out of band (never in repo).
- API names checked in CI SDK-symbol step; add new symbols to `tools/ci/check-sdk-symbols.sh`.

## 4. Acceptance
- [ ] CI green, zero warnings, new unit tests (classifier on synthetic motion, activation state machine).
- [ ] Probe, push-to-talk, low-voice flow and A/B are runnable from Diagnostics and export Markdown.
- [ ] `sv-fragments.md` and checklist updated.
- [ ] Report `reports/YYYY-MM-DD-HHMM-angela-trackD-spike.md` labelling everything verified in CI / untested on device; STATUS updated.
