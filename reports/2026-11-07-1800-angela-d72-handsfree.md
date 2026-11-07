# Angela — D72: every mode hands-free, Provläge card, interview answers only, one suggestion

Date: 2026-11-07 · Assignment: Aron (chat), owner decision D72, after the crash fix and before D69 · Device: **none**

**Result:** D72 is built and documented. **Unverified on device** until Aron has installed the new
`Lumen-unsigned.ipa` and tested it. CI: see the end of this report.

## What changed
| # | Change | Status |
|---|---|---|
| 1 | Hold-to-ask is gone: button, setting, `ActivationMode`, `releaseGrace`, the push-to-talk code in `ActivationController` and `ListeningModel`, and its strings. **Frågor (Auto)** listens through `QuestionGate` (cooldown, own voice suppressed) and is the mode on the first start. The picker remembers the last mode (`mode.lastSelected`); Rizzläge is only remembered after the 18+ confirmation. The text field and *Fråga om det senast sagda* stay as fallbacks. Settings → *Questions* now only has the sensitivity. | verified in CI |
| 2 | Picker: Frågor (Auto), Provläge, Intervjuläge, Socialt läge, Rizzläge (18+). The gate is unchanged. | verified in CI |
| 3 | A card at the top of the main screen, **Få A-svar till provet**, starts Provläge with one tap, with no start screen or settings in between. It is hidden while a session runs. Provläge never ends by itself (D71). | verified in CI |
| 4 | Intervjuläge sends only `turn: "question"`, for the interviewer's question, and plays the answer. The wearer's own turns (louder than *Din röst är starkare än*, by input level) are not sent: no feedback and no follow-up. They are only sent when the wearer asks for something out loud: "klar"/"avsluta", "sammanfatta", "ge mig feedback" or "hur var mitt svar". The start screen now says: *Intervjuläge är till för träning … Använd det inte i en riktig intervju utan att den andra vet om det.* | verified in CI |
| 5 | Socialt läge and Rizzläge show and speak exactly one suggestion, on screen and on the Lock Screen. "nästa" (voice or the Live Activity button) asks for a fresh one, with trigger `stall`, or `opener` before anyone has spoken. | verified in CI |
| 5b | Asking for more ("ge mig tre pickup lines", "fler förslag") goes through the D69 voice instruction, which is not pushed yet, so it is built together with D69. | not built |
| 6 | `docs/DEVICE-TEST-CHECKLIST.md`: §3k rewritten (hands-free, remembered mode, text fallback), and the hold steps in §3l, §3m, §3s and §3t replaced. §3v covers the card and 15 minutes of silence, §3w the answer-only interview, §3x and §3x2 one suggestion. `docs/INSTALL-SIDELOADLY.md` updated to match. | done |

## Tests
- Rewritten: `ActivationControllerTests` (auto, cooldown, own playback, sensitivity, last sentence, text, settings).
- New `ListeningActivationTests`: Frågor is the default and hands-free, the last mode is remembered, and a
  remembered Rizzläge is not kept without the 18+ confirmation.
- Updated `ModeTests`: the interviewer's question is answered; the wearer saying the answer aloud gets no request;
  the next question is answered; `user_answer` is never sent; "Sammanfatta" said aloud is sent; exactly one suggestion; "nästa" fetches a new one. New: the interview request matcher.
- Tests that used push-to-talk now use auto or the text trigger.

## Backend (Kevin's `e75c6c8`, already on main)
The backend does its half of D72: one suggestion by default, a request for more ("ge mig tre", max 5) through
`social.calibrate` for that one call, and the interview reply is the perfect answer in first person, with a summary
or feedback only when asked for. The app matches that. The app sends only `turn: "question"`, and the wearer's
explicit requests go as the fragment. The app has no "ge mig tre" yet: it needs the D69 instruction channel.
**Verified in docs** (`backend/README.md`).

## CI
- `fe3e41a` failed on one test that still expected the backend mode `push_to_talk` for a typed question (it is `text`).
  Fixed in `4872c88`.
- **Green:** run 42391668005 on `4872c88`. Build (warnings are errors), unit tests and the unsigned archive all passed.
  New ipa with the crash fix + D71 + D72:
  https://github.com/aronstenlund-code/aronstenlund-airpods-ai/actions/runs/42391668005/artifacts/13581583867 (available
  until 2026-11-21).
- **Not tested on device.**

## Concerns
- **"Få A-svar till provet"** can be read as help *during* an exam. The consent screen and D41 say Lumen must not be
  used during exams, and R6 (school policy) is rated high. Provläge is a study session, and the card is built as
  asked. I suggest wording that says *before* the exam, for example "Plugga till A på provet". Owner's call.
- **Intervjuläge** now reads a finished, perfect answer aloud on every question. That is exactly what someone would
  use covertly in a real interview. The guardrails are the start screen text, the visible indicator and the consent
  screen. The mode itself does nothing to hide the app.
- With everything hands-free, false answers in a room (R5) depend only on `QuestionGate` and the 8 s cooldown.
  §3k measures it.

## Known limits
- Telling the wearer from the interviewer uses the input level. With the iPhone microphone on the table it is
  unreliable, so the AirPods mic is the default for Intervjuläge. The threshold is a setting.
- The remembered mode does not start listening by itself; *Börja lyssna* is still one tap.

## Next session
Aron: install the new ipa, run §3k, §3v and §3w. Me: D69 (calibration, mode switch, more suggestions on request)
on top of D72. The hold button in D69 is gone, so calibration is only "Lumen, …".
