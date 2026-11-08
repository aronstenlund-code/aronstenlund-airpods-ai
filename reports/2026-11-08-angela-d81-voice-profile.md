# Angela — D81: voice profile, "Du / Talare N", CV in the interview, study cards, barge-in

Date: 2026-11-08 · Assignment: Aron (chat), owner decision D81 · Device: **none**

**Result:** every point is built. **Unverified on device.** CI: see the end of this report.

**Answer time:** the voice is never waited for. The embedding runs when the recogniser commits a sentence, beside the
answer that starts at the same moment (D80). A turn whose voice is not known yet is decided by the level, as before.
The only new wait is a barge-in with a voice profile: one embedding of 1.2 s of audio before Lumen stops talking.
That stops speech; it does not delay an answer. **Untested assumption:** an embedding takes tens of ms on the Neural
Engine.

## What changed
| # | Change | Status |
|---|---|---|
| 1 | **Voice profile.** Settings → *Din röst* → *Lär dig min röst (10 s)*. Details below the table. | verified in CI (fake model); real model untested |
| 2 | **Where the profile is used**, only when there is one. Details below the table. | verified in CI |
| 3 | **"Du / Talare 1 / Talare 2"** in the live transcript. Details below the table. | verified in CI (fake model) |
| 4 | **Battery and CPU per 10 min.** Details below the table. | untested |
| 5 | **CV in Intervjuläge.** Details below the table. | verified in CI (text); PDF reading untested |
| 6 | **Study cards and the mini test.** Details below the table. | verified in CI |
| 7 | **Barge-in in every mode:** in every hands-free mode, speaking for 0.4 s stops Lumen. With a voice profile, only the wearer's own voice does; someone else talking is logged "Barge-in ignored" and Lumen goes on. Without a profile, the level decides as before. | verified in CI (the check); flow untested |

**1. Voice profile**
- **Recording:** you read a short text aloud. The 10 s of audio are cut into overlapping 3 s windows, silent windows
  are skipped, and the WeSpeaker embeddings (256 numbers) are averaged into one.
- **Storage:** the average is stored in Application Support, excluded from backup (not in iCloud) and protected until
  first unlock. It never leaves the phone. It is a voiceprint, not a recording; the audio is not kept.
- **Delete** with one tap, after a confirmation.
- **The model:** WeSpeaker + pyannote segmentation via FluidAudio's `Diarizer` trait, downloaded once (about 30 MB)
  at the first session that needs it.

**2. Where the profile is used**
- **Auto:** never answers the wearer's own words; "Lumen, …" is how the wearer asks.
- **Intervjuläge:** answers only when it is not the wearer. The voice outranks the level.
- **Rizzläge / Socialt läge:** "you" or "the other person" by voice.
- **Minne:** memory extraction skips a turn whose voice was someone else's.
- **Barge-in:** see point 7.

**3. "Du / Talare 1 / Talare 2"**
- Each committed sentence is embedded and clustered online:
  - close to the profile is "Du";
  - another voice joins the nearest speaker when the similarity is ≥ 0.45, otherwise it gets the next number;
  - at most 6 speakers.
- **Without a profile** everyone, including the wearer, is "Talare N".
- **Toggle:** Settings → *Visa vem som pratar*, on by default.
- **Session only:** the numbers last only for the session. Nobody is identified.

**4. Battery and CPU per 10 min**
- While listening, the log gets one line every 10 minutes, for example "Resources · CPU 6.4 % · battery −3 % ·
  10 min · voice 41 embeddings, avg 38 ms · labels on · profile yes".
- CPU is the app's own CPU time over wall time (`getrusage`).
- Compare a session with labels on and one with them off.

**5. CV in Intervjuläge**
- *Lägg till CV (PDF eller text)*: read on the phone (PDFKit), stored only on the phone.
- Every interview call carries `persona_setup` = "Jobbannons: … CV: …", at most 2 000 characters (Kevin raised the
  limit), cut at a sentence.
- Removed first: e-mail, phone numbers, personnummer, street address with postcode, links.
- Without a CV the setup is exactly as before.
- A scanned PDF has no text: the screen says so.

**6. Study cards and the mini test**
- **Cards:** every Provläge answer to a real question (three words or more) becomes a card.
  - It holds the question and the first two sentences of the answer, the subject and the D83 exam date.
  - It is shown until the day after the exam (without a date: 30 days).
  - Settings → *Studiekort*: delete cards one by one or all at once.
- **Offer:** when Provläge ends, the notice offers a mini test. The Provläge card gets a *Minitest · 5 frågor*
  button, and "Lumen, minitest" / "förhör mig" works too.
- **The test**, all by voice inside Provläge:
  - Lumen asks "Fråga 1 av 5: …" and the wearer answers.
  - The tutor gets the question, the stored answer and the wearer's answer, and starts its reply with "Rätt" or
    "Inte riktigt".
  - "vet inte" / "hoppa över" skips without a call.
  - At the end: "Klart. 3 av 5 rätt."
- **Which cards:** the last session's cards first, then the ones most often wrong. Right and wrong are counted per
  card.

## Kevin's D81 contracts, used by the app
- **Socialt/Rizz labels:** each `other` line in `social.transcript` carries `label` ("Talare 1"), and
  `social.speaker` names who spoke last. Only when the labels are on and the voice is known.
- **Interrupted answers:** a barge-in keeps what Lumen had said as a turn with `interrupted: true` in
  `context.recent_qa`, so the next answer never repeats it. Only the sentences actually spoken count.
- **`POST /study-cards`:** when a Provläge session ends, its questions and answers are sent as `summary` (≤ 6 000
  characters, newest kept), with the profile. The backend's cards join the local ones, one per question. Its five
  test questions are the next mini test, used once. Offline, the local cards are used.
- **`persona_setup`:** up to 2 000 characters for the job ad + CV.

## Deviation (for the Architect)
**Live diarization:**
- **Asked for:** LS-EEND through FluidAudio.
- **Problem:** LS-EEND's model card (FluidInference/lseend-coreml) answers HTTP 401 without a login, so its licence
  cannot be read.
- **Rule:** no model with an unverified licence.
- **Instead:** "Talare N" is online clustering of the same WeSpeaker embeddings the voice profile uses. No second
  model, no extra download.
- **Limit:** two people talking at once in one sentence get one label. LS-EEND could split them.
- **Way back:** if the licence is published, it can be added behind the same toggle.

## Licences (THIRD_PARTY_NOTICES.md)
- **FluidAudio:** the `Diarizer` trait is now on. It is FluidAudio's own Swift code (Apache-2.0, VBx port included),
  with no resources and no binaries. `TTS` and `NemoTextProcessing` stay off; the CI bundle check is unchanged.
- **Models**, downloaded at first use from FluidInference/speaker-diarization-coreml, Hugging Face revision
  `df2625ac…` (pinned by FluidAudio):
  - `pyannote_segmentation`: pyannote/segmentation-3.0, MIT, © 2023 CNRS. The licence text is reproduced.
  - `wespeaker_v2`: pyannote/wespeaker-voxceleb-resnet34-LM, CC-BY-4.0.
  - Attribution is in the notices and in the app (Settings → *Din röst*, footer).
- **Licence scope:** taken from the repository's `NOTICE.md` (read 2026-11-08).
- **PLDA JSON files** (CC-BY-4.0, BUT Speech@FIT) may land in the model cache through FluidAudio's root sweep. They
  are listed in the notices, but Lumen does not use them.
- **No GPL parts.**

## Tests
`LumenTests/SpeakerTests.swift`:
- **Profile matching:** wearer, other and uncertain.
- **Labels:** stable numbers per voice; the label lands on the right segment.
- **The profile on disk:** saved, read back, excluded from backup, deleted; silence makes no profile.
- **Barge-in voice check:** nil without a profile, true for the wearer, false for someone else.
- **Flows with a fake voice model:**
  - Auto does not answer the wearer but answers someone else.
  - The transcript shows "Du" and "Talare 1".
  - Intervjuläge follows the voice over the level.
  - A Provläge answer becomes a card.
  - The mini test asks, sends the grading, counts right, skips "vet inte" without a call, and ends "Klart. 1 av 2 rätt."
- **Cards:** two sentences; they expire after the exam; one card per question; the last session goes first.
- **CV:** contact details are removed while the years stay; the setup is ≤ 1 500 characters; without a CV it is
  unchanged.
- **Resource line:** the format.
- **Kevin's contracts:** the interrupted turn keeps only what was said, and the flag is sent only when true; the
  live lines carry the label and `social.speaker`; the study-card request stays within its limits; the backend's test
  is used once.

## Concerns
- **Consent:** a voice profile is biometric data under GDPR. It never leaves the phone and is deleted with one tap,
  but the consent screen does not mention it yet. The Architect should decide whether *Lär dig min röst* needs its
  own line of consent. The section's footer already explains it.
- **Barge-in on the iPhone speaker:** without a profile, Lumen's own voice can still stop itself there. Echo
  cancellation (D82) dampens it; the voice profile removes it.

## Known limits
- **Thresholds:** wearer ≥ 0.5, other ≤ 0.3, same speaker ≥ 0.45. They are guesses for WeSpeaker and must be tuned
  on device. Enrol in a quiet room.
- **Short sentences:** a sentence shorter than 1 s is not embedded. It gets no label, and the level decides.
- **First session:** downloads the model (about 30 MB). Until it is ready, everything works as before D81.

## CI
- **First D81 run (`42485333729`):** failed to compile on two slips.
  - A line break had got inside the Settings footer string.
  - A closure in the mini-test selection mixed `$0` with a named argument.
- **Both fixed.** No other control characters or broken strings in the changed files (checked by script).

## Next session
D84: the voice statement "Lumen, jag går i åk … och ska snart ha prov i …", the exam session in Provläge, and reading
texts aloud.
