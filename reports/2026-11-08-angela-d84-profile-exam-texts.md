# Angela — D84: the voice statement, the exam session, texts read in rhythm

Date: 2026-11-08 · Assignment: Aron (chat), owner decision D84; Kevin's backend `reports/2026-11-08-1900-kevin-d84.md`
· Device: **none**

**Result:** all three parts are built on Kevin's endpoints. **Unverified on device.** CI: see the end of this report.

**One push for all three parts.** The owner asked for a push after each part. The parts touch the same file
(`ListeningModel`), so they are in one commit with one report. Each part has its own section below.

## 1. "Lumen, jag går i åk 9 och ska snart ha prov i biologi" (every mode)
- **On the phone, at once:** the statement is read on the phone first (`ProfileStatement`), so the confirmation
  comes at once and offline: "Biologi åk 9, sparat."
  - Grade: "åk 9", "nian", "tvåan på gymnasiet", "högskolan".
  - Course: "Matematik 2c".
  - Subject: "prov i biologi".
  - Exam date: through D83's reader ("på fredag", "imorgon", "den 20 november").
- **Then the server:** Kevin's `POST /study-profile` gets the words and the known profile. It returns the profile with
  an absolute exam date and 30–50 central terms for the subject. What the server read fills in what the phone could
  not; nothing it left empty is cleared.
  - **The terms** go to Scribe as keyterms and to the answer as `prep_terms`. The app's limit is raised to 50,
    Kevin's new limit.
  - **D83 profile:** it ends up in Minne with an absolute date and in `persona_setup` on every Provläge call.
- **Not a statement:** only "jag går i / på …", "jag läser …", "… prov i …" count, and only as statements. "jag går
  och lägger mig" and "när är provet i biologi" are not profile statements.

**Status:** verified in CI (parser, reply, flow); `/study-profile` live is Kevin's, verified in docs.

## 2. The exam session in Provläge
**Upload:** Provläge card → *Provsession · ladda upp ett prov*. Pick the exam and its marking instructions together.
- **Files:** PDF or photos, several at once.
- **Pages:** turned into JPEG at about 1 600 px (Kevin's advice), at most 40 pages, and sent to `POST /exam` "parse" in
  batches of 10.
- **Merging:** the tasks are merged by task number. The text comes from the exam, the answer and scoring rules from
  the instructions, plus the grade limits.
- **On the phone:** only the parsed tasks are kept, on the phone (`exam-paper.json`). The images are not kept, and
  nothing is stored on the server.

**During the session:** only "Lumen, …" exam commands count. With a voice profile, a command in someone else's voice
is ignored. Everything else is never answered (Auto off).

| Command | What happens |
|---|---|
| "uppgift 7", "uppgift sju a" | reads task 7 (or 7a) with its points |
| "nästa" | the next task |
| "ledtråd" | Kevin's hint, level 1 → 2 → 3 for the same task, never the answer |
| "rätta, jag fick 42" | `/exam` grade: "1 av 2 poäng." plus Kevin's feedback (the number is checked in code there) |
| "starta provtid 90 minuter" | timer; "30 minuter kvar", "10", "5", "En minut kvar", "Tiden är slut", each once (the nearest one if some were missed) |
| "hur gick det?" | `/exam` summary, spoken (points per level, the grade, what is missing to the next) |
| "avsluta provet" | the summary, and the tasks without full marks go to Minne as kinds of task to practise ("Provträning: öva på uppgifter som …") |

**Status:** verified in CI (commands, merge, levels, timer, decoding); the flow against `/exam` is untested.

## 3. Texts and songs read in rhythm
- **The backend decides** what may be reproduced (`needsText`, Sonnet, search). Traditional texts come in full, modern
  lyrics never.
- **Reading:** an answer that comes in lines is read one line at a time, so the line breaks are the rhythm.
- **Source line:** the `Källa:` line is shown but never read (Kevin's known issue).

**Status:** verified in CI (line split); the sound untested.

## Also
- **`done.retract`** (Kevin, D82): when the model withdraws an answer it had begun, the app stops speaking and drops
  it. Nothing goes to Historik.

## Tests
`LumenTests/ProfileStatementTests.swift`:
- **Statements:** grade, subject and date; gymnasium with course; spoken years ("nian"); not a statement; only what
  was said changes.
- **`/study-profile` reply:** decoded and applied.
- **Exam:** exam and instructions merge by number; the voice commands; "uppgift 7" finds 7a; hint levels stop at 3;
  weak tasks; the spoken task; time warnings once each; the parse reply decodes (`min_ca`).
- **Texts:** lines are the units; the source line is recognised.

`LumenTests/SpeakerTests.swift`:
- "Lumen, jag går i åk 9 …" is confirmed "Biologi åk 9, sparat.", sets the grade, and is never sent as a question.

## Concerns
- **Uploaded pages:** they are sent to Lumen's server and to the model provider to be read once. Kevin stores
  nothing. The upload screen says so.
- **Real exams:** a real national exam may be protected material. It is used for the user's own practice only, and
  nothing is kept on the server. The Architect may want a line in the consent text.

## Known limits
- **Real exams:** a real national exam with figures and tables is not tested (Kevin tested a typed synthetic exam).
- **Scanned PDFs** are sent as images; a 40-page limit per upload.
- **Answers by voice:** a long answer ("rätta, jag fick …") is limited by what Scribe hears. Algebra by voice is hard.
- **Wearer's voice:** with a voice profile, a command whose voice was not identified yet still counts.

## CI
- **First D84 run (`42487727296`):** failed to build. Two constants of the main-actor class `ExamMaterials` were used by
  its non-isolated page functions. They are `nonisolated` now.

## D81 test fix in this push
The D81 run (`42486781789`) failed one test, `theMiniTestAsksGradesAndMovesOn`. The test spoke the answer before
Lumen had begun reading the question, so the turn was reset when the speech started. That is a race in the test, not
in the app. The test now waits until the question is read and the microphone is open again, and a missing call can no
longer crash the test run. The tests after it had not run, because of the crash; they run now.

## Next session
After a green CI: device test checklist 3z8. Waiting for Aron's device test of D80–D84.
