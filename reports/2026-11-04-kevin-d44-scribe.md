# Kevin — D44 Scribe v2 Realtime backend + webtest (2026-11-04)

## Done
- `GET /stt-token` (new function `stt-token`, v1, JWT required): mints a single-use ElevenLabs token (`POST /v1/single-use-token/realtime_scribe`), never returns the key; caps 6/min, 120/day per user, 600/day global. `POST /stt-token {seconds}` logs seconds + estimated cost ($0.39/h).
- Webtest: Scribe v2 Realtime is the default recogniser (mic -> PCM16 16 kHz -> WebSocket, hold-to-talk, commit on release, optional keyterms field); on any failure it switches to Safari for the rest of the page session. The page shows the recogniser used and release -> transcript ms. Tested in headless Chromium with a fake WebSocket, fake mic, fake backend: Scribe path (12 audio chunks, token not leaked into logs, usage POST) and fallback path (stt-token 503 -> Safari). 145 unit tests green.
- `scripts/wer.ts`: WER and exact-match against `testdata/scripts/sv-short-prompts.md` (digits/words normalised).

## NOT done / blocked (owner action)
- **Live Scribe has never run.** Probing from inside Supabase: the token endpoint exists, but ElevenLabs answers `401 missing_permissions: speech_to_text` for the key stored as `ELEVENLABS_API_KEY` (also `user_read`). Click path: elevenlabs.io > Developers > API Keys > the Lumen key > enable *Speech to Text* and *User* (read) > Save. If the error remains, create a new key with those permissions and replace the Supabase secret (Dashboard > Edge Functions > Secrets). No code change is needed afterwards.
- **Accuracy comparison** (Scribe vs Safari on the 30 short prompts): needs the owner reading them aloud on the phone; then `deno run --allow-read scripts/wer.ts hyp.tsv` per recogniser. No numbers exist yet.
- **Billing on the owner's plan:** not readable (no `user_read`). From the pricing page (D44): $0.39/hour streamed; whether the plan includes hours and shares the TTS credit pool is **unverified**. Seconds are logged per user via `POST /stt-token`.
- Untested assumptions: audio message field names (`audio_base_64`, `sample_rate`, `commit`), `keyterms` as repeated query parameter, `language_code=swe`, behaviour on iOS Safari (AudioContext + ScriptProcessor); the iPhone mic/AirPods path is unverified.
