# AppTests/E2E (Toby, app tester)

Toby's tests of the app, written independently of Angela. Nothing here changes app or backend code.

## Screens/ — screen tour (T3)

`ScreenTourTests` is an XCUITest that walks the app as a user would (labels only, no hooks in the app): first start
(intro, consent, first question, add exam), the share prompt, Start without and with an exam, every page under
Inställningar, Lyssnar in Frågor, Byt läge, the first screens of Intervju, Socialt and Rizz 18+, and Provläge's first
start. Each screen is attached as a screenshot; a screen it cannot reach fails the test and the tour goes on.

- Target `LumenScreenTour` lives in `AppTests/E2E/project-e2e.yml`, which includes `project.yml` unchanged.
- Runner: `scripts/apptest/screens.sh [config ...]` (fresh simulator per config: erased, appearance, text size,
  microphone permission, clean status bar). Configs: `pro-light`, `pro-dark`, `pro-light-storsta-text`,
  `pro-dark-storsta-text`, `liten-light`, `liten-dark`, `pro-light-mikrofon-nekad`.
- CI: `.github/workflows/apptest-screens.yml` (push to app code on main, nightly, manual). Artifact `apptest-screens`:
  one folder per config and `index.html` with one row per screen, one column per config.
- The app runs in Swedish (`-AppleLanguages (sv)`) with Apple's recogniser (`-stt.useCloud NO`) so CI opens no paid
  Scribe session. Each run signs in anonymously to the live backend once per config.

**Simulator only.** A screenshot here is never a verification on a device.

## Audio chain (T1, T2)

Waits for Angela's A1 (a WAV audio source behind a protocol and her test target here).
