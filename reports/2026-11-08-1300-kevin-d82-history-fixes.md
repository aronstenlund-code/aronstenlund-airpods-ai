# Kevin: D82 and the fixes from Aron's shared history (8 Nov)

Date: 2026-11-08 · Assignment: Aron (chat): D82, then the six findings from `shared_history` (install 51706993…).
Commits: `d3df0e7` (D82 rule), `55921e0` (history fixes), `85f5a81` (echo strip), `b92a068` (echo note), and the `client_id` commit after this report. Deploy backend: last
run `42478463707` **green**. Two deploys first failed in `supabase/setup-cli` ("Failed to resolve latest Supabase CLI
release: Service Unavailable", a GitHub outage); a rerun of the job passed both times.
Migrations (applied with the Supabase MCP): `20261108120000_shared_history_fill_mode.sql`, `20261108130000_shared_history_client_id.sql`.

## What was asked and built
| # | Change | Status |
|---|---|---|
| D82 | **No new question = `[[TYST]]`, never a comment on the sound or the fragment.** The Provläge SILENCE rule and the Auto `is_question` rule now say that a leftover of the app's own last answer, with or without noise, is silence. **In code (`echo.ts`, Provläge and Auto):** words of the fragment that repeat the last answer (a run of ≥ 4 words in order) are removed before the model sees the fragment. If fewer than 2 words remain, the reply is silence without a model call. Otherwise the model gets a note that only a complete new question gets an answer. | verified live (meta-01) |
| 1 | **Arithmetic in code, no model.** The old calculator was right (`270 × 270 = 72900`), but Haiku phrased it as "sjutusen niohundra" and invented wrong steps. Now arithmetic and percentages (`calc.ts` `spokenComputed`) are **answered entirely by code**: no model call, the numbers become words in the normal speech step. Provläge also gets the steps of a multiplication, all computed in code ("Räkna 270 gånger 200, som är 54 000, och 270 gånger 70, som är 18 900. Tillsammans blir det 72 900."). Conversions and dates keep the model with `<computed>`. | verified live: **20/20** |
| 2 | **Metasvar filter after the model.** A new code filter (`INPUT_META` in `speech.ts`, Provläge and Auto) drops sentences about the fragment, the sound, the microphone or the recording, and sentences that ask the user to clarify or name a subject. All four from the history are covered, plus "jag väntar på nästa fråga", "jag tolkar det som att du …", "Det här är en fortsättning på …" and "fragmentet blandar …". If nothing is left, the reply is silence. | verified live: 4/4 silent |
| 3 | **`[[TYST]]` is never shown or spoken**, in any mode, even split over stream chunks. If it comes after text that was already streamed ("… nöjd med det.\n\n[[TYST]]"), the stream stops there, and `done` gets `answered:false` and `retract:true`, so the app can drop the answer (**Angela: handle `retract`**). The prompt now says the marker is only ever the whole reply. | verified in tests and live |
| 4 | **Unknown words and everyday talk.** A word the model does not know as a real word ("vartom") is never given a meaning; it is treated as too garbled, which means silence in Provläge. The D80 mishearing repair applies only when the fragment is a question, a request or a bare term, never to everyday talk ("Det är en köttjätte. Så. Det är orange"). | verified live: both silent |
| 5 | **Clock times.** "vad är 20:20" was computed as 20 ÷ 20. A bare "HH:MM" is now a clock time, answered by code: "Klockan tjugo och tjugo är tjugo över åtta på kvällen." A prompt rule keeps follow-ups on the 24-hour clock: never a comma number, never "the clock only goes to twelve". | verified live |
| 6b | **`client_id` (D82, Angela's row: "refusing a second `client_id` is backend work"):** new column, unique `(install_id, client_id)`; a re-upload is ignored (PostgREST `ignore-duplicates`), a repeat in one batch is stored once. The 2 exact duplicates already in the table were removed (same install, question and answer; earliest kept): 34 → 32 rows. | done (database, tests) |
| 6 | **`shared_history` mode and persona:** all 34 rows were null. They are back-filled from the same user's nearest `answer_usage` row: 4 × `text`, 30 × `tutor`. A new `before insert` trigger does the same for every future row that arrives without them. The current app (D80) already sends `mode` and `persona`; the device most likely ran an older build. | done (database) |

## Test results
- **Unit tests** (Node shim): 237 pass (`auth_test` fails only under the shim; CI ran `deno task test` green).
- **Live eval**, new categories (answer v6x, 8 Nov, about 13:00):
  - **räkna 20/20 correct.** Covered: multiplication of three-digit numbers, percentages, division, powers, square,
    cube, root and a mixed expression. First word 240–660 ms, because there is no model call.
  - **metasvar 7/7.** meta-01 to meta-04 and the two unknown-word cases were silent; meta-05 ("Vad heter jag? Det
    är skönt.") was answered without the marker. Before the echo fix, meta-01 was still answered.
  - **klocka 3/3.** Follow-up: "Ja, precis, tjugo och tjugo och tjugo över åtta på kvällen är samma tid."
  - **Verified live (text against the server).**
- **Time to first token per mode** (server `ttft_ms`, median; 3 runs this morning before any change, 6 after):

  | Mode | Before (ms) | After (ms) |
  |---|---:|---:|
  | text | 697 | 662 |
  | push_to_talk | 708 | 604 |
  | Provläge | 799 | 767 |
  | Auto | 1 119 | 1 046 |
  | interview | 753 | 684 |

  **Not longer in any mode.** Calculations are much faster (about 0.3 s, no model).
- **Not tested on a device.**

## Cost
About **0.012 USD** (baseline and after-measurements about 0.009, evals about 0.003). Calculations now cost nothing
(no model call).

## Known limits and risks
- The echo strip needs 4 words in a row from the last answer; a leftover of 2–3 words still goes to the model (the
  SILENCE rule covers it).
- `retract:true` needs the app to drop an answer already partly shown or spoken; until Angela handles it, such an
  answer stays visible (the marker itself is never shown).
- The metasvar filter is a list of phrases; new wordings can slip through. Each new one from the history should become a
  live-eval case.
- Arithmetic answered by code has no relation tag and no check question in Provläge.
- `supabase/setup-cli` with `version: latest` depends on the GitHub API; during an outage the deploy fails before
  anything is deployed. Pinning a version would avoid it; I left it, because the version could not be read from the
  logs.

## Next session
- Angela: handle `done.retract` (drop the answer); confirm the device build sends `mode`/`persona` to `/shared-history`.
- Kevin: D83 (Provläge profile), then D81, then D84.
