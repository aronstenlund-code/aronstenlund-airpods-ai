# Angela — A4: choppy voice (jitter buffer, gap counts, the next sentence fetched early)

Date: 2026-11-08 · Assignment: `prompts/queue/angela.md` A4 (Aron: "rösten låter ibland extremt hackig") · Device:
**none**

**Result:** the likely causes are fixed in code and the voice is now measured per answer. **Unverified on device:**
Toby checks in the Simulator, Aron on the phone. CI: see the end of this report.

## The causes (verified in code)
- **(a) Streamed voice played every chunk at once.** ElevenLabs' `pcm_24000` was cut into 100 ms buffers, and
  `PlaybackService` started playing on the first one. When the network or ElevenLabs delivered unevenly, the player
  ran dry in the middle of words. That is the hack.
- **(b) A pause between sentences.** Each sentence was a TTS call of its own, made only after the one before had been
  scheduled.
- **(c) A held-back tail in Apple's voice.** The sample-rate converter keeps its last frames until it is flushed, and
  nothing flushed it at the end of a sentence. The tail was lost, or opened the next sentence of the same rate (a
  click). ElevenLabs' 24 kHz audio passes straight through and was not affected.
- **(d) A route switch mid-answer:** not found. The capture and output route is set when listening starts and only
  changes when iOS changes the route (D82 echo cancellation then restarts capture). Speaking does not switch between
  A2DP and HFP.

## What changed
| # | Change | Status |
|---|---|---|
| 1 | **Jitter buffer**, details below the table. | verified in CI (simulated network) |
| 2 | **Counted per answer**, details below the table. | verified in CI (format); real numbers from Aron's phone |
| 3 | **Between sentences**, details below the table. | verified in CI |
| 4 | **The converter's tail**, details below the table. | verified in CI (build); sound untested |

**1. Jitter buffer** (`JitterBuffer`, `ElevenLabsTTSProvider.startBufferSeconds = 0.3`)
- **Start:** speech starts once 300 ms of audio is queued, or the stream has ended (a short sentence is never held).
- **Running dry mid-sentence:** if the player runs dry, it collects 300 ms again before playing, so a stalled network
  gives one pause instead of a stutter for every chunk.
- **Why 300 ms:** it absorbs a chunk that is 150 ms late, every other chunk (tested), and a 400 ms gap between
  ElevenLabs' bursts.
- **Answer time:** the cost is the time it takes 300 ms of audio to arrive, usually much less than 300 ms because
  ElevenLabs sends faster than real time. It is logged per sentence as "startbuffert" so Aron's phone gives the real
  number. A sentence fetched ahead (D80, and point 3) plays at once, without this wait.

**2. Counted per answer**
- **What is counted:** sentences, underruns, ms of silence from underruns, the start buffer's wait in ms, and the
  sentences fetched ahead.
- **Where it shows:**
  - after every answer, the log line "Röst: 3 meningar, 0 avbrott, 0 ms tystnad, startbuffert 120 ms, 2 förhämtade";
  - Settings → Diagnostik → *Rå transkription och svar* → *Fördröjning*, for the last answer and the total.

**3. Between sentences**
- **Fetched early:** a sentence queued while another one is being spoken has its ElevenLabs voice fetched right away.
- **Played at once:** when its turn comes, it plays straight after the one before. This is the same mechanism as D80's
  answer-ahead.

**4. The converter's tail**
- **At the end of a sentence:** the converter is flushed and reset (`endOfSpeech`), so its held frames end that
  sentence.
- **On "Avsluta":** an interrupted sentence's tail is thrown away (`resetForNextStream`).

## Tests
`LumenTests/VoiceSmoothnessTests.swift`, a player that plays in real time:
- **Late chunks:** every other chunk 150 ms late stutters more than five times without the buffer, and not once with
  it.
- **Bursts:** bursts with a 400 ms gap play without a gap.
- **A long stall:** a 2 s stall is one pause, not a stutter per chunk.
- **A short sentence** is never held back.
- **The stats line** adds up and reads in Swedish.
- **Prefetch:** the second sentence is fetched while the first plays.

## Known limits
- **The value:** 300 ms is a value from the simulation, not from measuring on a phone. Aron's numbers decide whether
  it should be 200 or 400.
- **Apple's voice** (on the phone) has no jitter buffer; it is local and has no network gaps.

## Next session
A3 (choose a voice) when Kevin's K6 is done; otherwise the queue.
