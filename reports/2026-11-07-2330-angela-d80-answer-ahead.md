# Angela — D80: answer ahead and deliver at the pause, memory, keyterms, feedback by voice

Date: 2026-11-07 · Assignment: Aron (chat), owner decision D80 · Device: **none**

**Result:** all eight points are built. **Everything is unverified on device** until Aron has tested it. CI: see the
end of this report.

## What changed
| # | Change | Status |
|---|---|---|
| 1 | **Answer ahead, deliver at the pause** (all modes). Details below the table. | verified in CI (logic) |
| 2 | **Pause per mode** in Settings → *Paus innan Lumen svarar* (0.5–3.0 s; defaults Frågor 1.0, Provläge 1.2, Intervju 1.5, Socialt/Rizz 0.8). It replaces D78's fixed 0.7 s hold and 1.0 s question wait. Scribe commits 0.4 s before the pause is over (`vad_silence_threshold_secs` = pause − 0.4, at least 0.3), the coordinator passes the utterance on when the pause is over, and Provläge, Intervju and the live modes end the turn at the pause. A final that arrives after its turn has already ended is no longer counted as the start of the next turn. | verified in CI |
| 3 | **Socialt/Rizz:** a suggestion is requested while the other person is still talking, at most every 3 s during a long monologue. It is shown at once and spoken in the pause. If the turn ended with exactly that text, no new call is made. | verified in CI (logic) |
| 4 | **Latency log per turn** (Diagnostics log): `Turn timing · heard→call · call→first token · call→done · heard→pause over · pause over→first sound`, plus `ahead N · used N · discarded N (x/min) · TTS ahead N, wasted N`. Target < 0.3 s from pause to first sound when the answer is ready. | untested on device |
| 5 | **Minne** (extends D49). Details below the table. | client verified in CI; backend not built |
| 6 | **Keyterms** (max 20): own commands, the active topic (last question), the latest two answers, course goals, memory and prep, in that order. Content words of six letters or more, no function words. Scribe only takes keyterms when a session opens, so a running session is reopened after an answer, after 3 s of quiet, at most every 2 minutes. | verified in CI (builder); reconnect untested |
| 7 | **Feedback by voice** (extends D57): "det där var inte riktigt rätt", "det var fel", "dåligt svar", "det stämmer inte" and about 20 similar phrases, plus the old "rapportera". It must be the whole utterance and come within 30 s of an answer. The previous turn goes to /feedback and Lumen says "Skickat"; nothing is asked as a new question. | verified in CI |
| 8 | Checklist: new §3z4 (latency per mode, "add a sentence before the pause", pause setting, live suggestions, memory, keyterms, voice feedback). | done |

**1. Answer ahead.**
- **Start:** as soon as a sentence is heard (a Scribe commit, or a partial that ends with "?" or "!"), the call to
  the backend starts. In Frågor that only happens when the question gate says it is a question; in Intervjuläge only
  for the interviewer, or for the wearer's explicit requests.
- **Kept, not shown:** everything the answer engine sends is kept in `AheadAnswer`. Nothing is shown or spoken, and
  Provläge does not go to "thinking".
- **More words:** words heard before the pause is over throw the call away and start a new one with the whole text.
  There is one call at a time.
- **Delivery:** when the pause is over and the turn is the same text, the kept answer is played back through the
  normal path at once. If the turn went on, the kept answer is thrown away and the whole turn is asked normally, so
  an answer to something that continued is never read.
- **TTS:** the voice for the first sentence (ElevenLabs) is fetched only once that sentence is complete and the
  speaker has been quiet for half the pause, and it plays straight from memory. Apple's voice is not fetched ahead;
  it is local.

**5. Minne.**
- After each of the user's **own** turns, and never in the answer path, the turn goes to
  `POST /functions/v1/memory`. What comes back is saved by itself, marked "hittat av Lumen", with the date.
- Sensitive categories (health, beliefs, sexuality, politics, origin, union membership, crime) are never saved by
  themselves; the app filters them as well as the backend. The user may still add them by hand or by voice.
- Settings → *Minne* has three sections: *Regler*, *Om dig* (each item with its date and source) and *Egna
  kommandon* (D37). Everything can be changed or deleted.
- Voice: "Lumen, kom ihåg …", "Lumen, glöm …", "Lumen, regel: …". Rules go to the backend as "Regel: …".
- Memories saved before D80 still load.

## For Kevin: the memory extraction endpoint (needed for point 5)
`POST /functions/v1/memory`, authorised like `/answer`.

The app sends:

```json
{"turn": {"question": "Jag har biologiprov på fredag", "answer": "…", "mode": "prov"},
 "memories": ["…"], "today": "2026-11-07", "weekday": "lördag", "timezone": "Europe/Stockholm", "language": "sv"}
```

Reply: `{"add": ["Biologiprov fredag 14 nov"]}`. Objects with `text` are accepted too.

Rules for the reply:
- Only important facts about the user, written with absolute dates.
- Nothing already in `memories`.
- No sensitive categories.
- An empty list when nothing is found.

Until the endpoint exists the app gets a 404 and ignores it. **The app side is verified in CI; the backend is not
built.**

## Tests
`LumenTests/AnswerAheadTests.swift`:
- **Answer ahead:**
  - the call starts at "sentence heard" and nothing is spoken before the pause; at the pause the answer is spoken
    with no second call;
  - words added before the pause replace the call (one discarded);
  - an answer to something that went on is never read.
- **Memory:** "kom ihåg" / "regel" / "glöm" by voice; rules and facts; sensitive items not saved by themselves;
  memories saved before D80 still load; the extraction body (today, weekday, time zone) and reply (strings, objects,
  sensitive filtered).
- **Other:** a complaint after an answer goes to feedback and is not a question; complaints only as a whole
  utterance; the pause per mode with the owner's defaults; Provläge ends turns at its pause; keyterms take the
  topic first, without duplicates.

Updated: the Scribe values in `SpeechPipelineTests` now follow the pause.

## Known limits and risks
- **Cost:** every discarded call is a backend call that is paid for. The log counts them per minute. A short pause
  setting gives more discarded calls.
- **The first sentence's TTS** is only fetched ahead with the premium voice. A discarded answer whose TTS was already
  fetched counts as "wasted" in the log.
- **Frågor:** an answer is made ahead only for what the question gate calls a question. A teacher's long question
  without a recogniser commit in the middle gets no head start.
- **Keyterm reconnect:** the reconnect after an answer takes about half a second, in a quiet moment. If the user
  speaks right then, the first words can be lost. It happens at most every 2 minutes.
- **The 0.3 s target** is only reachable when the answer is ready and its first sentence was fetched ahead. Whether
  the backend's ~0.7–1 s to first token fits inside the 0.4 s lead plus the pause is what §3z4 measures.

## CI
CI failed three times before it went green. The first two were compile errors, the last a test:

| Run on | What failed | Fixed in |
|---|---|---|
| `09b3c50` | A tuple property broke `StudyMachine`'s `Equatable` | `dde5d62` |
| the next push | A closure in the TTS stream was inferred as `throws(any Error)` instead of `throws(AudioError)` | `718bbc1` |
| `718bbc1` | The test for memories saved before D80 wrote its dates in the wrong format; the app uses ISO 8601 | `762d510` |

- **Green:** run 42414791995 on `762d510`. Build, unit tests, licence check and the unsigned archive all passed.
- New ipa: https://github.com/aronstenlund-code/aronstenlund-airpods-ai/actions/runs/42414791995/artifacts/13591820533
  (available until 2026-11-21).
- **Not tested on device.**

## Next session
- Kevin: build `/memory` as described above.
- Aron: install the new ipa, run §3z4 and send the Diagnostics log.
- Me: tune the lead time and the prefetch threshold from the timings.
