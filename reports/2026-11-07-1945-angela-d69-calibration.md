# Angela — D69 on the D74 voice path: calibration and "ge mig tre"

Date: 2026-11-07 · Assignment: Aron (chat), after D74 · Device: **none**

**Result:** "Lumen, …" in Socialt läge and Rizzläge now reaches Kevin's backend as `social.calibrate`. A calibration
is stored per mode and sent with every request. A request for more shows and speaks all suggestions, that one time
only. **Untested on device.** CI: see the end of this report.

## What changed
| Change | Detail | Status |
|---|---|---|
| Instruction path | `liveInstruction` (the D74 hook) sends `social.calibrate` with the stored `social.calibration` and the conversation so far in `transcript`. The instruction itself is never a line of the transcript or of the session. Rizzläge still needs the 18+ answer. | verified in CI |
| Calibration | `done.calibration` is stored per mode in UserDefaults (≤ 300 characters). `""`, the backend's answer to "återställ", clears it. Lumen says "Okej." in the AirPods. Every later suggestion request carries `social.calibration`. | verified in CI |
| Settings → Kalibrering | Socialt läge and Rizzläge each show their calibration with **Återställ**. | verified in CI |
| "ge mig tre" / "fler förslag" | When the instruction call returns suggestions, all of them are shown (screen and Lock Screen) and spoken, once. The next ordinary request shows one again (D72). "nästa" moves through the list while it holds more than one. | verified in CI |
| Order | Suggestions triggered while an instruction is on its way wait for it. They are dropped if the instruction itself brought suggestions, so the three are not replaced at once. | verified in CI |
| Several speakers | Every line from everyone in the last two minutes is kept, in order. Everyone but the wearer is `other`, since the backend contract has only user/other and the level tag cannot tell voices apart. | verified in CI |
| Start screen text | Now says "nästa", "Lumen, mer skämt" and "Lumen, ge mig tre". | done |
| Checklist | New §3x3. | done |

The backend contract is in `backend/README.md` (Kevin, D69/D72/D73). **Verified in docs.**

## Tests
`LumenTests/CalibrationTests.swift` covers:
- **Request building:** several other speakers in order; the instruction never in the transcript; the calibration in
  every request; nothing built for Rizzläge without 18+; `done.calibration` decoded.
- **Storage:** per mode, kept across restarts, Återställ, empty clears, long is cut.
- **Flows:**
  - "Lumen, mer skämt" is stored, then sent with the next request.
  - "Lumen, ge mig tre pickup lines" shows and speaks three, and the next ordinary suggestion is one again.
  - Words before the name stay conversation.
  - "Lumen, återställ" clears the calibration.

## Not built
- The one-tap switch button between the live modes from the first D69 draft. Switching now goes through the D74
  voice command or the mode picker.
- The AirPods stem and the hold button are gone (D72); "Lumen, …" is the only way.

## Known limits
- If someone else in the room says "Lumen" in an ordinary sentence, the rest of that sentence becomes an
  instruction. Checklist §3x3 step 5 measures how often.
- Two instructions in quick succession: the second cancels the first.

## CI
- **Green:** run 42403156253 on `8cf02cb`, which includes `671a7f9`. Build (warnings are errors), unit tests and the
  unsigned archive all passed. New ipa:
  https://github.com/aronstenlund-code/aronstenlund-airpods-ai/actions/runs/42403156253/artifacts/13586712549
  (available until 2026-11-21).
- **Not tested on device.**

## Other
Kevin's commit `8cf02cb` is titled "D76" but adds no row to `docs/DECISIONS.md`. D76 there is this decision, so
Kevin's next one should be D77.

## Next session
Aron: install the new ipa and run §3x3 together with §3z2.
