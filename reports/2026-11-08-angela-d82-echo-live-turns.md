# Angela — D82: Lumen never answers itself; live turns by voice activity

Date: 2026-11-08 · Assignment: Aron (chat), owner decision D82 plus the shared-history follow-up · Device: **none**

**Result:** D82 is built, together with the shared-history fix. **Unverified on device** until Aron has tested it.
CI: see the end of this report.

## Echo (D82.1)
Aron's test and his shared history (8 Nov) show that at least six fragments were Lumen's own previous answer. He
confirmed it only happens when the sound goes out of the iPhone's loudspeaker, not with AirPods.

| Part | What | Status |
|---|---|---|
| (a) | In every mode the recogniser is closed while Lumen speaks. It opens again only when the audio has really stopped playing, plus 0.7 s. Before, this was only in the hands-free modes, and the recogniser opened when the speech queue was empty, while the last buffers could still be playing. | verified in CI (logic) |
| (b) | Voice processing (echo cancellation) **only when the output is the iPhone's built-in speaker**, never with AirPods or headphones, so the AirPods keep their best recording (`bHQ`). The session controller decides at start and on resume. It switches by itself when the output changes mid-session: the input restarts in place, without a state change, so a hands-free session goes on. Setting: Settings → Mikrofon → *Ekoreducering i iPhonens högtalare* (on). Provläge's `useVoiceChatMode` is no longer used. | verified in CI (logic); audio untested |
| (c) | A transcript of 3+ words where ≥ 60 % of the words are in something Lumen said in the last 30 s is dropped: finals, partials, "sentence heard" (D80) and turn ends. The log shows "Echo filtered: N % of the words were Lumen's own". | verified in CI |

## Live turns (D82.2–3)
- **Talking and turn end:** in Socialt läge and Rizzläge, Silero (the D78 detector in front of Scribe) decides whether
  someone is talking and when a turn ends, instead of the level, so music or chatter no longer keeps a turn open.
  The suggestion is spoken at the end of the other person's turn plus the pause (0.8 s). While Lumen speaks, barge-in
  still goes by the level, because the recogniser is closed then. Without a running VAD (Apple's recogniser, or the
  VAD switched off) the level is used as before.
- **Who spoke:** a turn is the wearer's only with a clear 3 dB margin above *Din röst är starkare än*. Anything
  uncertain is the other person's and gets a suggestion.
- **Stall:** 2 s (was 4 s).
- **Log per turn:** `<mode> turn · wearer/other · -29 dBFS vs threshold -30 + 3 dB → uncertain, treated as other ·
  speech by Silero`, then `Live turn timing · requested … · ready … · spoken … ms (from the end of the turn)`.

## Shared history (follow-up, 8 Nov)
**Cause found:** `setSharing(true)` reset `sharedThrough`. Saying yes in onboarding and again in Settings, or
turning sharing on again before an opt-out deletion was confirmed, uploaded the whole history again. That fits
"Norge huvudstad" and "Kabel" twice on 7 Nov 16:18.

**What changed:**
- The app remembers what it has uploaded, both by entry id and by question + answer, and never sends either again.
- Only a deletion the server has confirmed starts afresh.
- Each item now carries `mode`, `persona` and `client_id` (the entry's id).

**For Kevin:**
- Delete the duplicates already in `shared_history`.
- Store `client_id` with a unique constraint, so a retried upload cannot create a second copy. The current
  validator ignores the field.

The `supabase-lumen` connection needs re-authorising (`/mcp`) before an agent can do this.

## Tests
`LumenTests/EchoAndShareTests.swift`:
- **Echo filter:** Aron's two real cases; a real question with a few shared words is not echo; the 30 s window;
  utterances under 3 words are not judged.
- **Echo through the model:** Lumen's spoken answer coming back as a "question" is not answered.
- **Echo cancellation:** on with the built-in speaker, off with AirPods, follows a route change mid-session without
  stopping it.
- **Live turns:** an uncertain speaker is the other person; loud background noise is not a turn when Silero says
  silence; a turn ends at the pause even over noise; stall is 2 s.
- **Shared history:** switching sharing on again does not upload twice; the same question + answer goes once; mode,
  persona and client_id go along; a confirmed opt-out starts afresh.

## CI fix after the first run
The first CI run failed one old test, `ModeFlowTests.aUsedSuggestionIsCountedNotStored`. In Rizzläge, the wearer
saying the suggestion out loud matched what Lumen had just said, so the echo filter (c) dropped it.

Fix: in Rizzläge and Socialt läge, a turn that repeats the current suggestion is the wearer using it when both hold:
- the level says it is the wearer;
- the sound is not going out of the iPhone's own speaker.

Through AirPods the microphone never hears Lumen (owner, D82). Everything else still goes through the filter.

## Known limits
- (a) costs the first 0.7 s after every answer. Words said in that window are not heard.
- With echo cancellation on the loudspeaker, iOS's voice processing also dampens distant voices.

## Next session
D83, then D81.
