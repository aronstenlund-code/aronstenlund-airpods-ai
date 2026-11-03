# Background noise for the speaker-distance test

Phase 1 assignment §3.8 requires **one fixed background-noise file** (room chatter or ventilation),
royalty-free, played from a loudspeaker at a fixed position and volume during the "noisy" runs.

## Status: file not yet chosen (2026-11-03)

The file must be picked and listened to on the test Mac before the first noisy run. Nothing is
committed here except this README; the audio file itself lives next to the WAV recordings (not in git).

## Requirements for the file
- Content: steady room chatter ("babble", several voices, no intelligible Swedish) **or** ventilation /
  fan noise. Prefer babble: it is the harder case for STT and closer to a classroom.
- Length ≥ 60 s so it covers a whole paragraph take without looping artefacts.
- Licence: CC0 or another licence that allows use without attribution problems. Record the exact
  licence and URL below. Candidate sources: freesound.org (filter licence = Creative Commons 0),
  the BBC Sound Effects archive (RemArc licence, personal/research use only — acceptable for an
  internal test, not for shipping), or a recording we make ourselves (preferred if in doubt).
- No music, no single dominant voice.

## Fixed playback setup (fill in before the first noisy run)

| Field | Value |
|---|---|
| File name | _to fill in_ |
| Source URL | _to fill in_ |
| Licence | _to fill in_ |
| Loudspeaker model | _to fill in_ |
| Speaker position relative to AirPods wearer | _e.g. 3 m behind, 1 m above floor_ |
| Playback device + volume setting | _to fill in_ |
| Measured level at the wearer's head (SPL meter app, dBA) | _to fill in — target 55–60 dBA, "busy classroom"_ |
| Measured quiet-room level (dBA) | _to fill in_ |

Write the same values into the Phase 1 report so every "noisy" row in
`reports/data/phase1-stt-results.csv` refers to one known condition.
