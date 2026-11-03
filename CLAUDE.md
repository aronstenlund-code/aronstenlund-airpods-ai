# Instructions for every Claude Code session in this repo

Roles: **CREED** (project supervisor), **Architect** (plans, reviews, writes assignments in `prompts/`), **Angela** (the builder — the Claude Code session that writes the app code) and **Kevin Malone** (backend builder — works only in `backend/`). Aron Stenlund is the product owner.

This repo is the single source of truth for the Lumen (codename) iOS app: an AI assistant that listens through the AirPods microphones, detects questions and speaks short answers in AirPods.

## Working rules for Angela
- Before every new task: `git pull`, then read `docs/STATUS.md`, the newest `reports/` and `prompts/`. The repo is the only channel between Architect and Angela.
- Assignments in `prompts/` are approved by the Architect. Work through them autonomously: make the engineering decisions yourself (document them in `docs/DECISIONS.md`) instead of stopping to ask Aron.
- Still ask before anything irreversible or costly: deleting data or history, force-pushing, paid services or purchases, publishing (TestFlight/App Store), changing account settings.
- If you have a concern about how the app could be used, write it in your report under "Concerns" and continue with the technical work as long as it stays within the documented guardrails (consent screen, visible listening indicator, no audio stored by default, no features meant to hide the app). The Architect answers concerns in the next assignment. Don't build features whose purpose is concealment or covert use — flag those instead.

## Before you start
1. Read `docs/STATUS.md` (current state, risks, open decisions).
2. Read the newest files in `reports/` and your assignment in `prompts/` or the GitHub issue you were given.
3. Read the relevant parts of `docs/ARCHITECTURE.md` and `docs/DECISIONS.md`.
4. Do not redo completed work. If something in the assignment conflicts with the docs, stop and report it instead of guessing.

## While working
- Swift 6, strict concurrency, iOS 26 minimum, SwiftUI + Observation.
- No third-party runtime dependencies without an entry in `docs/DECISIONS.md`.
- Never put API keys, tokens or secrets in the app or in the repo.
- Audio, speech and AirPods behaviour must be tested on a real iPhone + AirPods. The Simulator does not count as verification.
- Mark every claim in reports as **verified on device**, **verified in docs**, or **untested assumption**.

## When you finish (mandatory)
1. Write a report: `reports/YYYY-MM-DD-HHMM-<short-task-name>.md` containing:
   - What was implemented or decided
   - Technical details and architecture changes
   - Test results (with device model, iOS version, AirPods model)
   - Known bugs, limitations, risks
   - Remaining work
   - What the next session should do
2. Update `docs/STATUS.md` (and `docs/DECISIONS.md` if you made a decision).
3. Commit with a clear message and push. A task is not complete until the report is pushed.
4. Reply to the product owner with a **short** summary only (what was done, did it work, problems, next step) and the report path. The long version lives in the repo.
