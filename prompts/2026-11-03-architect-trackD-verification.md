# Assignment for THE ARCHITECT — Track D verification & architecture

Issued by: CREED, 2026-11-03. Read first: `reports/2026-11-03-1800-creed-track-d-discreet-interaction.md`, `docs/ROADMAP.md` (Q1, Track D), `docs/ARCHITECTURE.md`.

## Objective
Turn Track D (discreet interaction) into a verified architecture and a precise spike spec Angela can build, without overstating what Apple allows.

## 1. Verify (docs, SDK headers via CI log, developer forums, WWDC sessions)
For each item give: status (VERIFIED-DOCS / POSSIBLE-UNTESTED / NOT POSSIBLE / UNKNOWN), source link, and the exact on-device test that would settle it.
1. `AVAudioApplication.inputMuteStateChangeNotification` on iOS 26: does an AirPods stem gesture toggle input mute for a **non-CallKit `.playAndRecord`** session? Which models? Foreground / background / locked? Does voice processing (`.voiceChat`) or `setInputMuted` participation change it? Any App Review guidance on non-call use.
2. `MPRemoteCommandCenter`: are stem single/double presses delivered while the app captures over HFP? Requirements (Now Playing info, active playback, A2DP vs HFP route).
3. `CMHeadphoneMotionManager`: supported models today, sample rate, background behaviour, battery cost.
4. `AnalysisContext.contextualStrings` and custom language model: DictationTranscriber only, or also SpeechTranscriber? Is Swedish supported by each transcriber (`supportedLocales`)?
5. Deepgram Nova-3 and ElevenLabs Scribe: Swedish keyterm/keyword boosting — limits, latency impact.
6. Controls (Lock Screen, Action button) and interactive Live Activities: can an App Intent start/stop capture in an already-running app session without opening the UI? Background audio constraints.

## 2. Design
- `ActivationManager`: one interface over activation sources (in-app button, Control/App Intent, stem via mute notification, remote command, head gesture), with explicit states (idle, listening-for-user, capturing-user-turn, answering) and a visible indicator in every state.
- Capture thresholds per activation mode (always-on VAD vs explicit turn).
- Fragment pipeline: context pack contents, reconstruct-then-answer JSON schema, confidence threshold, confirmation phrasing.
- Prep-mode vocabulary pipeline: term extraction → ≤100 contextual strings (Apple) / provider keyterms.
- Update `docs/ARCHITECTURE.md` (new section "Discreet interaction") and `docs/DECISIONS.md`.

## 3. Deliverables
- `reports/YYYY-MM-DD-HHMM-architect-trackD-verification.md` with the table above and sources.
- If anything changes Angela's spike, edit `prompts/2026-11-03-trackD-spike.md` and note the change at the top.
- `docs/STATUS.md` updated. Short chat summary to the product owner.

## Success
Every Track D capability has a status with a source and a concrete device test; Angela can build the spike without guessing any API name or behaviour.
