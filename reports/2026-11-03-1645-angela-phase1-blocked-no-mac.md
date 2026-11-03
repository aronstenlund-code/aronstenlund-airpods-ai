# Report: Phase 1 start — blocked on build environment (Angela)

Date: 2026-11-03 16:45 · Session: Angela (builder) · Type: status / blocker (no app code)

## 1. What was done
- Committed the Architect's docs, reports and assignments as the repo's first commit (`c57a1d0`) and pushed `main`.
- Read `CLAUDE.md`, `docs/STATUS.md`, `docs/ARCHITECTURE.md`, `docs/DECISIONS.md`, `docs/ROADMAP.md`, all three reports and both assignments.
- Wrote the Phase 1 test material (assignment §3.8), the only part of Phase 1 that does not need a Mac:
  - `testdata/scripts/sv-paragraphs.md` — 3 Swedish teaching paragraphs (science, maths, history), 52 / 60 / 56 words, exact reference text and reader rules.
  - `testdata/scripts/sv-short-prompts.md` — 30 short items (maths, science, history, language, geography, imperative forms) with spoken form and scoring reference.
  - `testdata/noise/README.md` — requirements and a fill-in table for the fixed background-noise condition. **The noise file itself is not chosen yet**; picking it needs a listening check on the test Mac.

## 2. Blocker
The Phase 1 assignment (§3.1) says to run it "on a Mac with Xcode 26" and, if XcodeGen cannot be installed, to **stop and tell the product owner**. This session runs on **Windows 11**. Checked and confirmed:

| Need | Available here |
|---|---|
| Xcode 26 / iOS 26 SDK headers | No (Windows) |
| Swift toolchain (`swift`, `swiftc`) | No |
| XcodeGen / Homebrew | No |
| A reachable Mac (saved SSH connection) | None configured |
| Cloud environment | Linux only ("Aron Website Builder") — no Xcode |
| Real iPhone + AirPods for verification | Not from this machine |

Consequences, per the rules in `CLAUDE.md` and the assignment:
- §3.2–3.7 (AudioSessionManager, CaptureService, PlaybackService, lifecycle, Diagnostics, telemetry) require the iOS 26 SDK. The assignment explicitly says to check API names in the SDK headers and not guess; the acceptance criteria require zero warnings in Swift 6 mode and a run on a physical iPhone. Writing ~2 000 lines of Swift blind on Windows would not satisfy any of that and would hand the next session an unverified pile to debug, so I did **not** write app code.
- The OSS tasks are gated on §3.1–3.7 building and running on a real iPhone (product owner's instruction), so OSS-1 and OSS-3 are not started either.

## 3. Decisions taken (minor, documented here only)
- Test material lives in `testdata/scripts/` exactly as the assignment names it. Paragraphs are 52–60 words, which is about 20 s at lecture pace; word counts are verified by script.
- Short-prompt item 16 keeps the hyphen in "ph-värde" and item 25 is deliberately colloquial ("hur stavas man") — both noted in the file so scoring rules are not surprised later.
- No entry added to `docs/DECISIONS.md`: nothing architectural was decided.

## 4. Testing
None possible. Everything in this report is **verified in docs / by reading the repo**; nothing is verified on device.

## 5. Options for the product owner (pick one)
1. **Run Angela on a Mac** with Xcode 26: clone the repo there and start a Claude Code session from the same assignment. Fastest path; the assignment was written for exactly this.
2. **Add an SSH connection to a Mac** in the Claude desktop app so a session from this machine can build and run `xcodebuild` remotely. Device testing still needs someone at the Mac with the iPhone and AirPods.
3. **Accept Mac-independent work only for now**: scoring code (WER/CER + Swedish number normalisation) and the `tools/stt-bench/` cloud CLI. Note the trade-off: the assignment wants the scoring code in **one place** shared by app and CLI, which argues for a Swift CLI compiled on the Mac, not a second Python implementation. I recommend waiting for option 1 or 2 rather than building a parallel Python scorer.

## 6. Next session should
- On a Mac: `git pull`, run `brew install xcodegen`, then execute `prompts/2026-11-03-phase1-audio-foundation.md` from §3.1. The test material in `testdata/` is ready; fill in `testdata/noise/README.md` before the first noisy run.
- Then OSS-1 and OSS-3 from `prompts/2026-11-03-oss-integration.md`.

## Concerns
None beyond the documented guardrails. The test material contains no personal data and no recordings.
