# Angela — D78: speech and question understanding

Date: 2026-11-07 · Assignment: Aron (chat), owner decision D78 (called D76 in chat, renumbered) · Device: **none**

**Result:** all five points are built. **Unverified on device.** The before/after measurement on the phone is
Aron's: checklist §3z3, with the new Diagnostics export. CI: see the end of this report.

## Before and after
- **On device:** not possible from here. §3z3 records the same text twice, local VAD off (before) and on (after), in
  Frågor, Provläge and Intervjuläge, and Aron sends WAV + transcripts. Each file also holds an on-device pass over
  the same recording, so Scribe and Apple can be compared on the same sound.
- **Offline, on Aron's example** (verified in CI): the two finals "Det är en annan ." and "Ja, obrutet." used to go
  to the question gate and the backend as two turns. They now become one utterance: "Det är en annan Ja, obrutet."
  A question split by a short pause ("Vad är skillnaden mellan mitos" … "och meios?") fires once, as one question.
  "Kom igen" was already dropped as filler (D74).

## What changed
| # | Change | Status |
|---|---|---|
| 1 | **Scribe per mode:** `vad_silence_threshold_secs` Frågor 1.0, Provläge 1.2, Intervju 1.5, Socialt/Rizz 0.8 s. `vad_threshold` explicit: 0.15, and 0.3 in Provläge where the wearer's own voice is close. `min_speech_duration_ms` and `min_silence_duration_ms` 100. `filter_background_audio=true` already comes from the backend (`extra_query`), and the app never sets `include_timestamps`; the two cannot be combined. A mode change reconnects Scribe with that mode's values. Source: ElevenLabs "Transcripts and commit strategies". | verified in docs + CI |
| 2 | **Whole utterances:** `UtteranceAssembler` sits in `TranscriptionCoordinator` before the sink, so it applies to the question gate, Provläge and the backend. Volocal's `SentenceBuffer` is vendored (MIT, commit `b731963`, licence header kept, changes noted): it is now a value type, Swedish abbreviations (t.ex., bl.a., dvs., ca., kl. …) and numbers are not sentence ends, and the line limit is 300. `?` and `!` pass the utterance on at once. A period counts only inside the text before a capital. Scribe's lone " ." after a commit is dropped. Otherwise the utterance is passed on after 0.7 s with no new words. The partial shows the pending words plus the live text. | verified in CI |
| 3 | **Silero VAD in front of Scribe (OSS-2):** FluidAudio (Apache-2.0) at `ee78635d…`, through the local package `Packages/LumenVAD`. `SpeechGate`: 256 ms windows, opens at p ≥ 0.5 with 512 ms pre-roll, stays open for Scribe's pause + 0.3 s so Scribe commits by itself, then holds silence back. It **fails open**: no model, a detector error or the setting off means all audio goes, as before. Settings → Språk → *Lokal röstdetektor före Scribe* (on by default) shows the status, including the one-time download. The Diagnostics file counts seconds sent and held back. Licence texts: `THIRD_PARTY_NOTICES.md`. | untested on device |
| 4 | **Question triggers after Parrot v0.11.3** (MIT; design only, no code copied): a question waits 1.0 s. More speech in that window joins it and the whole is judged again, so half a sentence never fires alone, and a question that turns into a statement is dropped. Automatic answers are at least 5 s apart (Parrot's minimum interval; was 8 s). `QuestionGate` also penalises a sentence that ends on a conjunction or preposition ("vad finns det i") unless it ends with "?". | verified in CI |
| 5 | **Diagnostics → Jämför taligenkänning (2 min):** records the recogniser's raw input, before any gate. It saves WAV + text: the live transcript with time and recogniser, plus mode, route, Scribe values and VAD statistics. *Kör iPhone-igenkänning på inspelningen* runs the phone's best on-device engine on the same recording and adds its text. Share with one tap. Debug builds only, started by hand (D8). | untested on device |

## Licence finding (important)
FluidAudio at the pinned commit links, through its **default traits**:
- LuxTTS G2P data generated from espeak-ng (**GPL-3.0**) and FrequencyWords (**CC-BY-SA-4.0**);
- a prebuilt text-normalisation engine;
- the diarizer.

The licence rule only allows MIT, Apache-2.0 or BSD. So the app does not depend on FluidAudio directly. The local
package `LumenVAD` declares it with `traits: []`, which leaves the VAD/ASR core (Apache-2.0) and fastcluster (BSD-2).

CI now fails the build if any LuxTTS, Kokoro, lexicon or Nemo resource ends up in the app. Whether Xcode honours the
traits of a transitive package is **verified only when CI's bundle check passes**. If it does not, the right fix is to
drop FluidAudio again, not to accept the data.

## Technical notes
- CI no longer passes `SWIFT_TREAT_WARNINGS_AS_ERRORS` / `GCC_TREAT_WARNINGS_AS_ERRORS` on the `xcodebuild` command
  line. There they would also apply to FluidAudio's own code. `project.yml` still sets both for our targets.
- New tests in `LumenTests/SpeechPipelineTests.swift`: sentence splitting (Swedish), the assembler (Aron's
  sentence, a split question, partials), Scribe values per mode and in the URL, the gate (pre-roll, hangover,
  windows), and two finals joined through the coordinator. `ActivationControllerTests` cover the debounce, half
  sentences and a question that turns into a statement.
- Unit tests elsewhere use `questionDebounce` 0 and `utteranceHold` 0 so they still see results at once. The real
  app uses 1.0 s and 0.7 s.

## Known limits and risks
- **Latency:** an utterance without "?" now waits 0.7 s after Scribe's commit, and a question 1 s more before the
  answer starts. That trades speed for whole sentences, and §3z3 and §3k show whether it is worth it.
- **Distant speech:** Silero's threshold 0.5 may miss a teacher far away on the AirPods microphone. That is why the
  switch is there and why §3z3 compares on and off.
- **Size:** the app grows by FluidAudio's VAD/ASR code (exact size in the CI log). The Silero model (a few MB) is
  downloaded on first use.
- **The on-device pass** over a recording waits a fixed 4 s for the last words. A very long last sentence may be
  cut.

## Next session
Aron: install the new ipa and run §3z3 (before/after) and §3k, then send the files. Me: tune the values per mode from
those files.
