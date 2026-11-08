# Angela — D87 (app): keyterms from the exam, the last turns in every Provläge call, recording a study session

Date: 2026-11-08 · Assignment: Aron (chat), owner decision D87, the app part · Device: **none**

**Result:** all three points are built. **Unverified on device.** CI: see the end of this report.

## 1. Provläge's keyterms come from the active exam
**What Scribe gets:** in Provläge, the 20 keyterms Scribe gets always start with the active exam's words
(`ExamKeyterms`). They go in this order, each word once:
- the subject;
- the course;
- what is on the exam ("fotosyntes, cellandning och klorofyll" becomes three terms; "kapitel 4" is skipped);
- Kevin's subject terms from `/study-profile`.

The other keyterms (commands, the topic, Minne) follow after them.

**"From the first word":** the keyterms are set before Scribe connects for Provläge. When Scribe was already running
(listening in Frågor first), it reconnects with them as Provläge starts (`applyKeytermsNow`), before the user has said
anything.

**Status:** verified in CI (order and content); hearing the terms right is untested on device.

## 2. The last three turns and the exam id in every Provläge call
**New fields:** every Provläge call now carries two new fields. `/answer` ignores unknown fields, so they are safe
before the backend reads them:
- `context.recent_turns`: the wearer's last three Provläge turns before this one, oldest first, each
  `{"text", "answered"}`. `answered` is false when Lumen stayed silent, the turn was filler or a command, or the answer
  was cut off. This is in addition to `recent_qa`, which only has the answered pairs.
- `exam_id`: the active exam (`ExamPlan.id`): the one picked on Start, else the nearest exam in the profile's
  subject. When the user switches exams, the turn list starts over.

**For Kevin:** read `context.recent_turns` (≤ 3, text ≤ 400 characters) and `exam_id` (a UUID string, top level) in
`validate.ts`.

**Status:** verified in CI (encoding and a Provläge flow).

## 3. Diagnostik: "Spela in plugg-session"
**Where:** Settings → Diagnostik → Diagnostik → *Spela in plugg-session (10 min)*.
- If nothing is running, the button starts Provläge.
- It records for up to 10 minutes; *Stoppa* ends it earlier.
- *Exportera WAV, transkript och JSON* shares the three files.

**The files:**
- `lumen-plugg-<tid>.wav`: the same 16 kHz audio the recogniser gets, before any gate.
- `lumen-plugg-<tid>.txt`, everything in time order from the start, with the setup at the top (device, mode,
  recogniser, route, exam, profile, the exam's keyterms):
  - HÖRDE (recogniser): what was heard;
  - FRÅGADE: what was sent, with its trigger;
  - SVAR: source, ms to the first text, the question and the answer;
  - SA: what Lumen said;
  - the whole session log (turn timelines, echo, Scribe reconnects).
- `lumen-plugg-<tid>.json`: the same events, for scripts (`t` = seconds from the start).

**Only in the test build:** the IPA is built in Debug, so it is there for Aron. No audio is stored otherwise (D8).

**Status:** verified in CI (the text format); the recording itself is untested on device.

## Tests
`LumenTests/D87Tests.swift`:
- **Keyterms:** the exam's words come first, in order, each once, with "kapitel" skipped.
- **The request:** carries the last three turns and the exam id; outside Provläge neither is sent.
- **A Provläge flow:** the second call carries the exam id and the turn before it, marked answered.
- **The recording's text:** in time order, with timings.

## Known limits
- **Long recordings:** a 10-minute WAV is about 19 MB.
- **Speech:** "SA" is when a sentence started playing, not when it ended.

## Next session
Aron: record a real study session and send the files. Kevin: read the two new fields.
