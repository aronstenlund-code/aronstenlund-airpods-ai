# Claude Code assignment — Phase 1a: Build Phase 1 code against a cloud compiler (no Mac yet)

Approved by: CREED (project supervisor), 2026-11-03. Supersedes the "run on a Mac" requirement in §3.1 of `prompts/2026-11-03-phase1-audio-foundation.md` **until the product owner has a Mac with Xcode 26** (planned: next week). Everything else in that assignment still applies.

---

## 1. Objective

Unblock Phase 1 now. The product owner has no Mac this week. GitHub Actions macOS runners have Xcode and the iOS SDK, so **CI becomes Angela's compiler**: write the Phase 1 code (§3.1–3.7), push, read the CI result, fix, repeat until green with zero warnings. Everything that needs a real iPhone + AirPods waits for next week, but must be fully prepared so the first device session is short.

## 2. Context

- Read first: `CLAUDE.md`, `docs/STATUS.md`, `reports/2026-11-03-1645-angela-phase1-blocked-no-mac.md`, `prompts/2026-11-03-phase1-audio-foundation.md`.
- Repo is **public** → standard GitHub-hosted macOS runners are free. If the repo is made private, stop and ask before running more macOS jobs (they cost money on private repos).
- Runner images for macOS 26 exist (`actions/runner-images`, tags `macos-26/...`). Which exact Xcode/SDK versions they contain is **not verified** — your workflow must print them.

## 3. Tasks

### 3.1 CI workflow — `.github/workflows/ios-build.yml`
- Triggers: `push` to any branch, `pull_request`, `workflow_dispatch`.
- `runs-on: macos-26`. If that label does not exist, use the newest label whose image ships Xcode 26 and record the choice in `docs/DECISIONS.md`.
- Steps, in order:
  1. Print `sw_vers`, `xcodebuild -version`, `xcodebuild -showsdks`. Select Xcode 26 explicitly with `sudo xcode-select -s` (path taken from the image, not guessed).
  2. **API-name check:** grep the iOS 26 SDK headers / `.swiftinterface` files for every AVFoundation/Speech symbol the code uses (at minimum `bluetoothHighQualityRecording`, `allowBluetoothHFP`, `bluetoothMicrophoneExtension`, `highQualityRecording`, `SpeechTranscriber`, `DictationTranscriber`, `supportedLocales`) and print the matching lines. This replaces "check the SDK headers locally" in the Phase 1 assignment. A symbol not found = fix the code, never guess.
  3. `brew install xcodegen` → `xcodegen generate`.
  4. `xcodebuild build` for `generic/platform=iOS` with `CODE_SIGNING_ALLOWED=NO` and `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES` (Swift 6 strict concurrency on).
  5. `xcodebuild test` on an iOS 26 Simulator for `LumenTests` (pick a simulator that exists on the image; list them in the log first).
- No signing certificates, profiles, Apple IDs or secrets in the workflow or repo.

### 3.2 Read CI results yourself
Use `gh run list` / `gh run view --log-failed`, or the GitHub REST API, to read failures after every push. If you cannot read CI results from your environment, stop and report — do not push blind.

### 3.3 Implement Phase 1 §3.1–3.7
Exactly as specified in `prompts/2026-11-03-phase1-audio-foundation.md` (project skeleton, `AudioSessionManager`, `CaptureService`, `PlaybackService`, background/lifecycle, Diagnostics screen, telemetry, HQ capability logging §3.11). Iterate until CI is green.

### 3.4 Unit tests for everything testable without hardware
- Conversion to 16 kHz mono Int16 (feed synthetic buffers at 48 kHz / 24 kHz / 16 kHz).
- 60 s ring buffer: wrap-around, `snapshot(lastSeconds:)`, thread safety.
- RMS / peak / SNR computation on synthetic signals with known values.
- **Scoring core for §3.9:** WER, CER and short-prompt exact match, with Swedish number/normalisation rules, as one Swift module reusable by the app and a later CLI (no second Python implementation). Test against hand-computed examples, including items from `testdata/scripts/`.

### 3.5 Device test checklist — `docs/DEVICE-TEST-CHECKLIST.md`
Written for the product owner (Swedish, plain language) for the first session on his Mac next week:
1. Install Xcode, sign in with a free Apple ID, clone the repo in Xcode, run `xcodegen` (or how to open the project if XcodeGen isn't available — solve this, e.g. commit the generated project if needed and document the decision).
2. Connect iPhone, enable Developer Mode, select personal team, Run.
3. Exactly which buttons to press, in what order, for the mic-source sanity check, the speaker-distance test (1/2/4 m, quiet/noisy, all configs), background test with locked screen, interruption test, and "Copy results as Markdown".
4. What to send back (the copied Markdown + iPhone model, iOS version, AirPods model).
Note open question: whether background audio works with free provisioning is **not verified** — include it as an explicit check.

## 4. Out of scope this week
- Any on-device verification (§3.5 background verification, §3.6 runs, §3.9 measurements, §3.10 model matrix).
- OSS-1 / OSS-3 (still gated on a device run).
- TestFlight, paid Apple Developer Program, paid services.

## 5. Evidence labels
Add a fourth label: **verified in CI** (compiles with zero warnings / unit test passes on the runner). It is **not** "verified on device". Never present CI results as device results.

## 6. Acceptance criteria
- [ ] Workflow runs on push; its log shows macOS version, Xcode 26 and the iOS 26 SDK.
- [ ] API-name check output in the log covers every audio/speech symbol the code uses.
- [ ] `main` is green: app builds for iOS with zero warnings in Swift 6 mode; all unit tests pass.
- [ ] §3.1–3.7 implemented per the Phase 1 assignment.
- [ ] `docs/DEVICE-TEST-CHECKLIST.md` exists and a non-developer can follow it.
- [ ] Report `reports/YYYY-MM-DD-HHMM-angela-phase1a-ci.md` with link to the green run, what is verified in CI vs. still untested on device, problems, and next steps; `docs/STATUS.md` updated.
