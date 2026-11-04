# Angela — core flow against the real server (x-warm, first sentence, /voices)

Date: 2026-11-04 · Assignment: Aron, chat (Track D skipped, economy mode) · Commit: `de6014e` · Device: **none** (no Mac yet)

**Result:** the flow hold button → STT → `/answer` → `/tts` → playback was reviewed against Kevin's contract and the live server. The app could not have read a single answer on a real iPhone; that is fixed. x-warm, first sentence at once and `GET /voices` are in. Build and all app tests green in CI (run 41789799523, warnings are errors). **Nothing has run on device.**

## What changed
| Change | Why | Status |
|---|---|---|
| **SSE blank lines (critical).** `URLSessionHTTP.lines` splits the bytes itself instead of `bytes.lines` | `AsyncBytes.lines` skips empty lines, and the blank line is what ends an SSE event. Every event would have collapsed into one, and every answer on a phone would have failed to decode. `FakeHTTP` passes blank lines, so CI never saw it | **verified in CI**: a test through a real `URLSession` shows `bytes.lines` drops the blank lines, and a live-shaped stream now decodes fully |
| **x-warm.** New `BackendWarmer`: `GET` + `x-warm: 1` + `apikey` on `/answer` and `/tts`, at most once per 60 s, when the Listening screen opens, the app becomes active, or listening starts | Kevin's D31 ask | verified in CI; endpoint **verified live** (204 without a user token) |
| **First sentence at once.** `SentenceSplitter` releases a sentence on the delta that ends it instead of waiting for the next one. Kept back: `3.`, `bl.`, `t.`, anything under three letters before a `.`. A stray `!` in the next delta is not spoken | Sentences already went to TTS one by one, but a sentence ending a delta waited for the next delta (for a one-sentence answer, the end of the stream) | verified in CI |
| **Voices.** Fetched when the Listening screen opens, not only in Settings. Decoder follows the live shape incl. `default_id`. D32: the server's default voice is used until the user picks one; a voice no longer on the list is replaced | Before this the app used Apple's voice until someone opened Settings, so `/tts` was never part of the flow on a fresh install | verified in CI; shape **verified live** |
| **One sign-in.** Concurrent `accessToken()` callers share one renewal; a network failure during refresh keeps the session | Voices now load at launch next to other calls: each would have created its own anonymous user (Supabase limit: 30 sign-ins/h/IP). Offline used to throw the session away | verified in CI |
| **Latency honesty.** "First speech" is now marked when the first audio buffer is scheduled, not when the TTS request starts | The overlay would have left `/tts` wait time out of the D28 number | verified in CI |
| Cancelled TTS no longer schedules a stray tail after `playback.stop()` | Found in review | CI build only, no test of its own |

## Live check against the real server
One run with curl from this Windows machine: `signup` 200, warm 204, `voices` 200, `answer` 200 with exact SSE framing, `tts` 200 (`audio/L16`, 78 020 bytes = 1.6 s of `pcm_24000`). **Verified live**; this is curl, not the app. It created one anonymous user in project Lumen and used one answer plus 23 TTS characters.

| One cold sample, Sweden → Supabase | |
|---|---|
| `/answer` first byte | **3.66 s** (`llm_first_chunk_ms` 3 466, `cold: true`, right after the warm ping) |
| `/tts` first byte | **1.46 s** |

Sum **≈ 5.1 s before STT and network to AirPods**, one sample only, so it says nothing about p50/p95. But it is above the D28 limit (≤ 5 s p95), and the warm ping did not prevent `cold: true`.

## Known limits / risks
- **Untested on device:** all of it. AirPods/HFP playback of PCM and first-audio timing need the iPhone.
- **Hold button release costs up to 2 s** (D24 `releaseGrace`): when the recogniser still has an open partial, which is likely the normal case, the app waits for the final. That is 2 s of the 3 s target. Left unchanged: a shorter wait may cut the last word, and only the device can show the trade-off. **Measure first** (untested assumption).
- **Only one voice is configured:** `GET /voices` returns one entry, "Adam", not the three Swedish voices of D23. Whether it sounds Swedish is unknown.
- `warm` opens one isolate; Kevin measured 29 of 30 requests in fresh isolates, so it may help little. The ping is free.
- Fallback when `/answer` fails on iPhone 14 Pro: no on-device engine, the error is shown.

## Concerns
None about use. Guardrails unchanged (consent, indicator, no audio stored).

## Remaining work / next session
1. **Aron:** add the three Swedish voices in Supabase secret `ELEVENLABS_VOICES` (click path in `backend/README.md`), then ask Kevin to redeploy.
2. **Kevin:** `*.supabase.co` is reachable from this Windows machine, so `deno task ttft` can run here, cold and warm; find out why `llm_first_chunk_ms` was 3.5 s.
3. **First device session:** `docs/DEVICE-TEST-CHECKLIST.md`, latency overlay on; note release → first audio.
