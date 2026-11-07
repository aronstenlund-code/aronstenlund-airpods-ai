# Angela — D74: voice control, AirPods press, nothing stops by itself

Date: 2026-11-07 · Assignment: Aron (chat), owner decision D74, before the rest of D69 · Device: **none**

**Result:** D74 is built. The voice path is the one D69 will use for calibration and "ge mig tre". **Everything is
unverified on device** until Aron has tested it. CI: see the end of this report.

## What changed
| # | Change | Status |
|---|---|---|
| 1 | **"Lumen, …" in every mode** (`VoiceChannel`, wake word in `WakeWord.name`, one constant). "byt till frågor/provläge/intervjuläge/socialt läge/rizzläge", "växla till …" or just the mode name, "pausa", "sluta lyssna". Each gets a short confirmation in the AirPods ("Provläge.", "Pausar."). Anything else after the name: in Socialt läge and Rizzläge the D69 instruction path (heard and dropped until D69 is in, never a line of the conversation); in Frågor a question; in Provläge and Intervjuläge a turn of that mode. A command is handled whether it arrives as a final result or closes a turn first, once (5 s dedupe). | verified in CI |
| 1b | Checks by voice: Rizzläge without the 18+ answer → *"Rizzläge kräver att du bekräftar 18 år i appen."* A live mode whose start screen has never been confirmed on this phone → *"Socialt läge startas i appen första gången."* Intervjuläge without a role → *"Intervjuläge behöver en roll i appen först."* | verified in CI |
| 2 | A line under the mode picker: *Säg "Lumen, byt till provläge" för att byta utan att ta upp telefonen.* | verified in CI |
| 3 | **AirPods press** (`RemoteCommandHub`): togglePlayPause, play and pause → `togglePause`. One press pauses Lumen and lets go of the microphone, the next press listens again **in the same mode**. The same mode also comes back when resuming from the screen, the Lock Screen or the Control. Now Playing shows "Lumen lyssnar" / "Lumen är pausad". The handlers are built outside the main actor (same lesson as the crash). | untested on device |
| 4 | **Nothing stops by itself.** Provläge auto-end is off (D71). The live modes and Frågor have no timer. A Scribe session that ends after ≥ 20 s reconnects to Scribe instead of falling back to the phone for good. An on-device recogniser that ends after ≥ 20 s is restarted. After an interruption (call, Siri) and when the AirPods come back, listening resumes by itself in the same mode. After the user's own pause it does not. **Replaces "never auto-resume" in D33.** | verified in CI (logic) |
| 5 | Each turn logs `Turn · <mode> · STT <recogniser> · mic <source> · <config>`. Provläge end of turn defaults to **1.2 s** (was 0.8; a stored choice is kept). Turns that are only filler ("äh", "ja", "kom igen", "okej", "mm" …) are not sent in Frågor, Provläge or Intervjuläge, and do not trigger a suggestion in the live modes. | verified in CI |
| 6 | The indicator sits in a `VStack` above the `NavigationStack`, so the title moves down instead of being covered. During a session there is one stop button: *Stop listening* ends the session and the microphone, and the separate *End session* is gone. | look untested on device |
| 7 | `docs/DEVICE-TEST-CHECKLIST.md`: new §3z2 (voice, AirPods press, Now Playing, 20 minutes per mode, turn log, filler, indicator). §3e and §3q now expect listening to come back after a call or Siri. | done |

## What happens when a music app has taken Now Playing
**Untested assumption**, based on how iOS routes remote commands: the AirPods press goes to the app that is "Now
Playing". When Lumen pauses, it releases the audio session with `notifyOthersOnDeactivation`, Spotify resumes and
becomes Now Playing. From then on, the press plays and pauses **Spotify**, not Lumen. So "press again to start Lumen"
only works when no other app has started playing since. The way back then is "Hej Siri, starta Lumen" (D58), the
Control or the Lock Screen button.

Two more open questions:
- Whether iOS sees Lumen as Now Playing at all while it records with `.playAndRecord` and has not yet played
  anything itself.
- What a press does on an HFP route (call-style audio). It may be treated as a call control.

Checklist §3z2 steps 6 and 7 answer both.

## Tests
- New `VoiceChannelTests`:
  - Parsing: every mode, pause, stop, an instruction with the words before it kept, no name means no intent, "Lumens"
    is not the name, the name comes from the constant.
  - The filler filter.
  - The remote handler body run on a background queue.
  - Flows: Frågor → Provläge by voice, with its confirmation and no request; Rizzläge by voice without 18+; a live
    mode before and after its start screen; "pausa"; "sluta lyssna"; a question by voice; Provläge back after an
    interruption; the AirPods press back in the same mode; filler not sent.
- Updated: the reducer, controller and music tests for resuming after an interruption or when the AirPods come back
  (the user's pause still holds). StudySettings now defaults to 1.2 s. The test helpers that simulate a turn now feed
  1.8 s of silence.
- Not unit-tested: the Scribe reconnect after 20 s (it needs a clock in the coordinator), and the remote command
  registration itself.

## Concerns
- **Voice into a live mode** needs that mode's start screen confirmed once on this phone. That keeps the guardrail:
  the start screen asks you to tell people the app is listening. Without it, a voice command could start listening
  to others with no reminder at all. If Aron wants voice switching without that once-only step, it should be a
  decision of its own.
- **"ja" is filler**, as decided. In Provläge the tutor can end with a check question; a bare "ja" in reply is now
  dropped. "nej" is not on the list, because it is more often a real answer. Easy to change.
- **Resuming after an interruption** means Lumen starts listening again after a phone call without a tap. The
  indicator and the Lock Screen still show it. If iOS refuses to start recording in the background, the state
  becomes "tap to resume".

## Known limits
- D69's calibration and "ge mig tre" are not built yet. The path is there, and the instruction is currently heard and
  dropped.
- A Live Activity lasts at most 8 hours (an ActivityKit limit). Listening itself has no limit in the app.

## Next session
Aron: install the new ipa and run §3z2. Me: D69 on top of D74, through `liveInstruction`.
