# Lumen backend (Kevin Malone's area)

Supabase Edge Functions (Deno/TypeScript). **No provider key ever reaches the app** (D2). Zero-cost rules (D18/D19): Supabase free tier, Claude Haiku 5.5 on the owner's prepaid credits, ElevenLabs TTS on the owner's existing plan. Every external failure *fails closed* and returns an error the app turns into Apple TTS / on-device answers.

| Endpoint | What | Status |
|---|---|---|
| `POST /functions/v1/answer` | SSE: `meta` -> `delta`* -> `done` (or `error`) | **deployed** (v1) · unit + local end-to-end tested with a mock LLM · **not yet run against real Claude** (waiting for `ANTHROPIC_API_KEY`) |
| `GET /functions/v1/voices` | The allowed Swedish voices (names + ids) | **deployed** (v1), unit tested |
| `POST /functions/v1/tts` | Streams ElevenLabs audio (TTS only, never Agents) | **deployed** (v1) · unit tested against a fake upstream · **not yet run against ElevenLabs** |

## Connect the app (Angela)
| | |
|---|---|
| Project | **Lumen**, ref `xjczbzfkmbjdebwlccki`, region eu-north-1, Supabase **free plan** |
| Project URL | `https://xjczbzfkmbjdebwlccki.supabase.co` |
| Publishable key | `sb_publishable_UNDoMfEur7nwt4qH8RRanQ_pVJCrGy8` (public by design; the app may embed it. It is **not** a secret and grants nothing without a user JWT) |
| Answer endpoint | `POST https://xjczbzfkmbjdebwlccki.supabase.co/functions/v1/answer` |
| TTS endpoint | `POST https://xjczbzfkmbjdebwlccki.supabase.co/functions/v1/tts` |
| Voices endpoint | `GET https://xjczbzfkmbjdebwlccki.supabase.co/functions/v1/voices` |

Flow: (1) `POST {url}/auth/v1/signup` with header `apikey: <publishable key>` and body `{}` (or `supabase.auth.signInAnonymously()` in supabase-swift) -> `access_token` (JWT, refresh via the SDK); (2) call the functions with `Authorization: Bearer <access_token>` and `apikey: <publishable key>`. Never send the publishable key as the bearer token: it is rejected (verified: 401). Contract, SSE format, errors and `fallback:true` handling are in the sections below.

**State on 2026-11-03:** both functions are deployed and reject missing/invalid tokens (**verified live**, 401). Anonymous sign-ins are **off** in the project (verified live: 422 `anonymous_provider_disabled`) until the owner flips the switch, and `ANTHROPIC_API_KEY` is not set yet, so `/answer` returns `503 provider_unconfigured` until then. Do not wire the app to expect answers before STATUS says "backend live".

## Database changes (working rule from the owner)
Rarely and in bulk: collect all schema changes into **one larger migration** (a file in `supabase/migrations/`), apply it myself with `apply_migration`, and ask the owner only when the Supabase server itself asks for confirmation of a destructive statement (`drop ...`). No ad-hoc `execute_sql`; measurements and logic stay in Edge Function code. Only project Lumen (`xjczbzfkmbjdebwlccki`) is ever touched.
- **Pending (waiting for Supabase's confirmation prompt):** `drop extension pg_net;` - `supabase/pending/drop_pg_net.sql`. Move it into `migrations/` once applied.

## Layout
```
backend/
  deno.json                    tasks: test, check, dev, ttft
  supabase/
    config.toml                anonymous sign-ins on, verify_jwt on
    migrations/                rate_limits + check_rate_limit() + answer_usage
    functions/
      _shared/                 auth (JWT), rate limit, errors, SSE, usage log
      answer/                  handler, prompt, parser, validate, llm/{anthropic,mock,factory}
      tts/                     handler (ElevenLabs proxy)
  dev/local.ts                 local server, mock LLM, fixed dev token (no Supabase needed)
  scripts/ttft.ts              runs the 30 Swedish prompts, prints time-to-first-token
```

## Run locally (costs nothing)
```bash
npm i -g deno            # or any Deno >= 2.1
cd backend
deno task test           # unit/handler tests (75), no network
deno task e2e            # starts the REAL answer/tts/voices entry points against local fake Anthropic/ElevenLabs/Supabase (JWKS, PostgREST): request shape, auth, limiter, abort, fallbacks
deno task check          # type-check everything
deno task dev            # mock LLM on http://127.0.0.1:8787/functions/v1/answer
deno task ttft -- --url http://127.0.0.1:8787/functions/v1/answer --token dev-token
```

## API: `POST /answer`
Headers: `Authorization: Bearer <Supabase user JWT>` (anonymous sign-in), `Content-Type: application/json`.
```json
{ "fragment": "roten ur hundra", "mode": "push_to_talk", "language": "sv",
  "context": { "transcript": "", "recent_qa": [{"q":"...","a":"..."}], "prep_terms": ["mitokondrie"] } }
```
`mode`: `push_to_talk` | `auto` | `text`; `language`: `sv` | `en`. `context` and its members are optional.
Limits: body 16 KB, fragment 1000 chars, transcript 6000, `recent_qa` 6 x 400, `prep_terms` 30 x 60 (413 otherwise).

Response `200 text/event-stream`:
```
event: meta
data: {"reconstructed_question":"Vad är roten ur hundra?","confidence":0.96,"is_question":true,"needs_confirmation":false}

event: delta
data: {"text":"Roten ur hundra "}
...
event: done
data: {"answered":true,"timing":{"meta_ms":380,"ttft_ms":410,"llm_first_token_ms":300,"total_ms":620},"usage":{"input_tokens":1010,"output_tokens":38,"model":"claude-haiku-5-5"}}
```
- `auto` mode, not addressed to the assistant: `meta` with `is_question:false`, then `done` (`answered:false`); the upstream request is aborted immediately.
- `push_to_talk` / `text`: `is_question` is always `true` (the user asked on purpose).
- `needs_confirmation:true` (confidence below `CONFIDENCE_THRESHOLD`, default 0.6): the streamed text is a 2-4 word confirmation question ("Menar du roten ur hundra?"), not an answer.
- `ttft_ms` is measured from request arrival at the function to the first `delta`; `meta_ms` to `meta`. Client-side TTFT adds network + cold start; the app should log its own.
- Failure after the stream started: `event: error` with `{code, message, fallback:true}`.

Errors before the stream starts are JSON `{"error":{"code","message","fallback"}}`:

| HTTP | code | meaning / app action |
|---|---|---|
| 400 / 413 | `invalid_request` / `payload_too_large` | bug in the app |
| 401 | `unauthorized` | refresh anonymous session |
| 429 | `rate_limited` (+`Retry-After`) | back off; use on-device meanwhile |
| 503 | `provider_quota` | **credits exhausted** -> on-device answers / Apple TTS (`fallback:true`) |
| 503 | `provider_unconfigured` / `provider_misconfigured` / `provider_busy` | fallback |
| 502 | `provider_unavailable` / `provider_error` | fallback |

`fallback:true` means: use Apple TTS / on-device answer engine for this request.

## Request fields added by D35/D36/D37
| Field | Meaning |
|---|---|
| `mode: "tutor"` | Hands-free tutoring session (D36): always a developed, pedagogical answer (5-8 sentences), builds on `context.recent_qa` (send the whole session, max 6), may end with ONE useful ja/nej-or-one-word check question. Explicit mode: `is_question` always true. |
| `length: "short"\|"adaptive"\|"long"` | Default `adaptive`: server picks `fact` (1-2 sentences) or `study` (5-8 sentences) from intent words (förklara, varför, jämför, för- och nackdelar, orsaker, procons ...). `short`/`long` force one. |
| `goals` (<=1 500 chars) | The student's course goals; the answer matches level and focus (D37). |
| `commands: [{keyword, instruction}]` (<=10; keyword <=60, instruction <=300) | The student's own saved shortcuts **already matched by the app**; the instruction is carried out for this turn. A matched command makes the answer developed. |

`meta` now also carries `answer_type: "fact"\|"study"`. 'mer' / 'fortsätt' / 'förklara enklare' continue the last answer when `recent_qa` is present. Confirmation questions are rare by design (target < 5 %); a confirmation the assistant did ask last is passed to the model as `<last_assistant_turn>confirmation` so the next fragment is read as the reply. Limits: body 64 KB, `recent_qa` answers up to 1 500 chars each.

## Rizzläge: `persona: "social"` + `social` (D43/D45)
Fast path for the live wingman. Send `persona: "social"` **and** a `social` object (`mode` any explicit mode, `"tutor"` recommended; `fragment` may be empty):
```json
{ "fragment": "", "mode": "tutor", "language": "sv", "persona": "social",
  "social": { "style": "flirt|social", "trigger": "other_spoke|stall|opener",
              "transcript": [{"speaker":"other","text":"..."},{"speaker":"user","text":"..."}],
              "interests": ["löpning"], "profile": "",
              "calibration": "mindre kaxig; hon gillar fotboll", "calibrate": "" } }
```
Defaults: `style` social (missing, unknown and the five old styles all mean `social`); `trigger` other_spoke. A non-empty `fragment` with `trigger: other_spoke` is appended as the other person's latest line. Limits: `transcript` 40 lines x 300 chars (send the last ~2 min), `interests` 10 x 60, `profile` 1000 (413 otherwise); `social` requires `persona: "social"`. Without `social`, `persona: "social"` keeps the older D42 single-line suggestion.

Response: **no `meta`, no `delta`**. One event, then `done`:
```
event: suggestions
data: ["Chili? Då vet jag vem som bjuder.","Hur stark, är du modig eller galen?"]

event: done
data: {"answered":true,"timing":{"ttft_ms":1010,...},"usage":{...}}
```
- **D72: an array of exactly 1 string** (the best suggestion), <= 10 words (dropped otherwise), Swedish, written to be spoken. When the user explicitly asks for more through `social.calibrate` ("ge mig tre pickup lines", "ge mig fem skämt", "visa fler"; "nästa" / "ge mig en till" = one fresh suggestion), that one call returns the asked number (max 5, `fler`/`några` = 3) as a normal `suggestions` call (Sonnet, no `done.calibration` change: it is `null`); the next call is 1 again. "fler skämt" / "mer skämt" without a verb stays a calibration. The stream stops as soon as the asked number of valid lines is complete, so the list arrives with the first line (~1.1-1.4 s instead of ~2.4 s). The app speaks `[0]`. Pass the last **6-10** turns in `transcript` (who said what); the backend uses the latest 10.
- **Generate, review, choose (D52):** in ONE call the model (Claude Sonnet 5.5, `RIZZ_MODEL`; everything else stays on Haiku 5.5) writes 4 candidates (D63: line 1 is the strongest; `n|line`, no hook column) `n|hook|line` and picks the best 3 (`TOP: a,b,c`) after checking each for: built on something concrete in the conversation/context, a joke logic that can be explained in one sentence, natural spoken Swedish from a 17-25 year old, the requested style (flirtig = charming and a little cocky, rolig = a punchline that lands, självsäker = calm and direct, avslappnad = simple, uppriktig = warm and honest), and respect (no negging, pressure, lies, manipulation; a no or discomfort gives respectful lines or a friendly exit). Code re-applies the hard rules (length, safety, duplicates) and tops up from the other candidates. The event is sent as soon as the TOP line is complete. `done.usage` carries `model` and `est_cost_usd` for the request (about 0.24 US cent on average, i.e. about 0.08 cent per suggestion).
- **D63 styles.** `social.style: "flirt"` is Rizzläge (charming, playful, respectful; adults only): the request must carry `adult_confirmed: true` (top level or inside `social`), otherwise **403** `{"error": {"code": "adult_confirmation_required", ...}}`. `"social"` is Socialt läge for everybody: 2-3 short options (a light joke, a friendly comeback, a follow-up question, a small-talk topic), never flirting and never mocking the other person. The D43 safety rules are the same for both: no negging, pressure, lies or sexual content, a no or discomfort is respected. `social.spicy` no longer exists (ignored).
- **D69 (amends D63).** *Rizzläge* (`flirt`): every option is flirty, funny and confident at once (playful teasing, compliments with a twist, confident light invitations), clearly flirtier than Socialt läge; same D43 rules. *Socialt läge* (`social`): jokes meant to make people laugh, built on what others just said (callbacks, observations, light self-irony), plus **one comeback that is always among the three options** (last); never mocking anyone present, no flirting. `transcript` may hold several other speakers (all `speaker: "other"`).
- **D72 Intervjuläge** (`persona: "interview"`): the reply is the perfect answer to the interviewer's question, first person, ready to say aloud (no preamble, outline, feedback, question back or summary; STAR as a story, never named). `turn: "user_answer"` returns the perfect version of the user's own answer. Feedback only when the fragment explicitly asks for it ("ge mig feedback", "hur var mitt svar"), a summary on "klar" / "avsluta" / "sammanfatta" / "ge mig en sammanfattning" (DECISIONS D72 (4)). No placeholders like "Här lägger du ett exempel" any more (interview_prep keeps its format).
- **D75 silence (Provläge `mode: "tutor"` and Auto `mode: "auto"`):** a fragment that is not a question or request (filler, a reaction such as "kom igen", talk to someone else, a half sentence) or that is too broken to map to any subject gets **no reply**: `meta` with `is_question: false`, no `delta`, `done.answered: false` (status `not_question`), exactly like a non-question in Auto, so the app stays quiet. In these modes the `meta` event with `is_question: true` is sent together with the first spoken text (it no longer comes first on its own). Provläge asks the model for a `[[TYST]]` marker; sentences that comment on what the speaker seems to mean or ask for clarification ("Det låter som att du …", "Berätta gärna …", "Menar du …?") are dropped in code, and a reply with nothing else left is silence. Auto never asks a confirmation question any more (low confidence = silent). A misheard subject word is mapped to the nearest plausible term from the session context and answered without mentioning the interpretation (all modes). A reply to the last check question ("kloroplast", "vet inte") is always answered.
- **D77 interview facts and demo cap texts:** `persona: "interview"` answers state no personal fact that is not in `persona_setup`, `memories`, `goals` or the user's own words (no name, age, school, earlier job, past event); a sentence or clause that says facts are missing is removed in code (`stripInterviewMeta`). Demo caps keep their codes (`demo_limit_visitor` / `_ip` / `_global`) but the message names the cap: questions, speech (`/stt-token?source=demo`: "dagens 8 röstfrågor") or read-aloud (`/tts` with `source: "demo"`: "dagens uppläsning"). Anonymous sign-ins per IP are limited by Supabase Auth (Dashboard > Authentication > Rate Limits); `.github/workflows/auth-rate-limit.yml` can set it only with a token that has auth write.
- **D69 calibration.** `social.calibration` (string, <= 300 chars; longer is cut, not rejected): the stored calibration, sent with **every** request and applied to every option (it never overrides the safety rules). `social.calibrate` (string, <= 300 chars, else 413): a spoken instruction ('lite mindre kaxig', 'mer skämt', 'hon gillar fotboll'). With `calibrate` present the request is **not** conversation: no `suggestion_preview`/`suggestions`, only `done` with `calibration` = the merged calibration (<= 300 chars, `""` after a reset instruction such as 'återställ'); store it per mode and send it as `social.calibration` from then on. Runs on Haiku 5.5 (~0.5-1 s). `done.calibration` is `null` on every other request. A `flirt` calibrate still needs `adult_confirmed`.
- Filter: lines with sexual (sexual or suggestive) or pressuring wording are dropped. If nothing survives (or the model returns nothing) a safe fallback is sent (`["Berätta mer om det.","Hur har din dag varit?"]`; if the other person's latest line is a no/leaving/discomfort -> `["Okej, helt lugnt.","Vi tar det en annan gång."]`) and the usage row has `status: "filtered"`.
- Decline handling: a no/leaving/discomfort in the other person's latest words is flagged to the model (`<signal>decline`), so every option accepts it kindly or ends the conversation warmly. Nothing is stored: the transcript lives only in the request; usage rows hold counts and timings.

## Answer quality in code (D46)
Root causes of the external 45-answer test were fixed in code, not with more prompt text:
- **Digits -> Swedish words, in code.** The model writes digits (`1789`, `3,5`, `12 %`, `2,5 liter`); `answer/svnum.ts` turns them into speakable Swedish before every `delta` (years 1100-1999 as hundreds, `1800-talet`, decimals, percent, units, times, dates, ordinals), so the app/TTS only ever receives words. Held back across chunk boundaries, so a number is never split. Consequence for the app: `delta.text` is already spoken-form (no digits); there is no separate display text.
- **Arithmetic in code.** Plain arithmetic, percentages and unit conversions in the fragment (`17 gånger 24`, `12 procent av 250`, `2,5 liter i ml`) are computed by `answer/calc.ts` and passed to the model as `<computed>` (it only phrases the result). Everything else is left to the model.
- **Context (D53).** The recent turns (send 4-6) and `<active_topic>` (the last question) are always passed on; nothing is dropped in advance. The model decides the relation of the fragment to the active topic in the same call and reports it as `done.relation` (and `meta.relation` in `auto` mode): `continues` (modifies the last answer: kortare, enklare, mer, varför då, omskrivning), `refines` (a short fragment, enumeration, name, concept or own question that plausibly belongs to the active topic; answered within it) or `new_topic` (clearly something else; answered as if there were no earlier turns). `null` without history or when the model gave none. Follow-ups attach to the latest turn only. If an answer starts like an earlier answer for a different fragment it is stopped before anything is sent and regenerated once (`usage.input_tokens` counts both attempts).
- **No questions back.** A closing question to the user ("Vill du att jag ...?") is dropped from the stream; an answer that is only a question is regenerated once. Not applied in `tutor` mode (its check question), personas, or Rizz suggestions.
- **Social situations in every explicit mode** (`hon skrev hej`, `vad svarar jag`, `ge mig en komplimang`): routed to ONLY a ready-to-say line (<= 12 words; D51: no tip, no context question; only the first output line is spoken); rewrite commands (`mer självsäkert`, `kortare`, `roligare`) rewrite the last line; ambiguous signals are described as uncertain; refuses guilt/pressure/manipulation and keeps that when pushed.
- **Web search / fetch when needed** (explicit "sök/kolla upp", current facts like prices, weather, opening hours, news, or a URL/domain in the fragment): Anthropic server tools `web_search_20250305` (max 3 searches) and `web_fetch_20250910` (max 2 fetches), no beta header; spoken form "verdict + 1-2 reasons + källa: <domän>". Cap per user 20 web answers/day and 3/minute, global 150/day (`WEB_PER_DAY`, `WEB_PER_MINUTE`, `WEB_GLOBAL_PER_DAY`); over the cap the answer is given without the web and says it may be out of date. Each search costs $0.01 on the owner's Claude credits (counted in `est_cost_usd`; `done.usage.web_searches`). Adds latency: the first text arrives after the searches (seconds, not ~0.8 s). A search turn the API pauses (`pause_turn`) fails closed with `provider_unavailable` (app fallback).
- **`/tts` `model`** (optional): `eleven_flash_v2_5` (default), `eleven_turbo_v2_5`, `eleven_multilingual_v2` (metered at 2x characters). Webtest has a selector.

## API: `GET /stt-token` (D44, Scribe v2 Realtime)
`GET /functions/v1/stt-token` (JWT like the other endpoints) -> `{ "token", "expires_in": 900, "model_id": "scribe_v2_realtime", "ws_url": "wss://api.elevenlabs.io/v1/speech-to-text/realtime", "language_code": "swe" }`. The token is a **single-use** ElevenLabs token (type `realtime_scribe`, expires after 15 minutes); the API key never leaves the backend. The client opens the WebSocket itself: `ws_url?model_id=...&token=...&language_code=swe&audio_format=pcm_16000&commit_strategy=manual[&keyterms=...]`, sends JSON `input_audio_chunk` messages (PCM16 mono 16 kHz, base64; last one with `commit:true`) and receives `partial_transcript` / `committed_transcript`. Caps: 6 tokens/minute, 120/day per user, 600/day global (`STT_*` env). Errors carry `fallback:true`: the app uses Apple/Safari recognition.
`POST /stt-token` with `{"seconds": n}` (0-3600) logs the seconds the client streamed (usage row `endpoint: "stt"`, `total_ms` = seconds x 1000, cost estimate at $0.39/hour). **Status:** deployed; **not yet verified live**: ElevenLabs answers `401 missing_permissions: speech_to_text` for the key stored in Supabase (it also lacks `user_read`, so plan allowance/usage cannot be read). Audio field names (`audio_base_64`, `sample_rate`) and `keyterms` are from the API reference snippets and untested until the permission is fixed.
Accuracy: `deno run --allow-read scripts/wer.ts hyp.tsv` scores recognised phrases ("<item>\t<text>") against `testdata/scripts/sv-short-prompts.md` (WER + exact match, digits/words normalised); run it per recogniser.

## Summaries, memory and usage insight (D48/D49)
- **`done.summary`** (string or `null`): 1-2 Swedish sentences (topic, what was asked, gist of the answer; no quotes, no other people's names), written by the model in the **same call** as a trailer line `[[SAMMANFATTNING]] ...` that the backend strips before anything is spoken. It arrives last, so audio is never delayed. `null` when the answer was cut at the length cap, in `auto` mode without an answer, and for Rizz `suggestions`. The app saves only this (no transcripts or answers); the server never stores any text (D20).
- **`memories`** (request, optional): `string[]`, at most 30 x 200 chars (413 otherwise). Used as facts about the user (level, interests, situation), never recited. All flows (answers, interview, social, Rizz).
- **`done.memory_add`** (string or `null`): an explicit "kom ihåg [att] ..." / "minns att ..." / "glöm inte att ..." is answered locally (no model call: "Okej, det kommer jag ihåg.") and the fact (<= 200 chars) comes back here for the app to store. Nothing is ever inferred as a memory.
- **Usage row:** `category` (fixed list: matte, naturvetenskap, historia, språk, samhälle, praktiskt, socialt/rizz, intervju, webbsökning, övrigt) and `persona`, decided in code; no text. Owner view: Supabase Dashboard > Table Editor > view `usage_by_category_day` (counts per category and day), or `GET /functions/v1/usage-stats?days=14[&format=html]` with the **service role key** as bearer (anyone else gets 401).
- **No vendor logging:** TTS requests carry `enable_logging=false`, STT sockets get `enable_logging=false&filter_background_audio=true` (via `extra_query` in the `/stt-token` reply). Verified live 2026-11-05: both are accepted, but ElevenLabs only applies zero retention on enterprise/trial plans (the STT socket says so in a `warning` message and carries on); `disable_logging=true` is not a real parameter and is ignored. If a plan ever rejects the parameter, `/tts` retries once without it and remembers.

## Cancelling an answer (D51)
To abort a running answer the client just **closes the connection** (cancel the fetch / SSE stream) and stops its audio queue; the backend notices the disconnect and aborts the model call (no more tokens are generated or billed). The webtest 'Avbryt' button does exactly this; the native app should do the same on a single tap or on barge-in.

## API: `GET /voices`
`GET https://xjczbzfkmbjdebwlccki.supabase.co/functions/v1/voices` with the same headers as `/answer` -> `200 {"voices":[{"name":"Astrid","id":"..."},...],"default_id":"..."}` (names + ids from `ELEVENLABS_VOICES`; no secrets, no ElevenLabs call; cacheable 5 min). `voices` may be empty if the secret is not set yet; the app should then offer only Apple's voice. Same errors as the other endpoints (401/405/429).

## API: `POST /tts`
**`voice_id` (D23):** optional; must be one of the ids from `GET /voices` (or the default voice), otherwise `400 invalid_voice` and nothing is sent to ElevenLabs. Omitted -> default voice.
> **Untested assumptions:** ElevenLabs endpoint path/params (`/v1/text-to-speech/{voice}/stream`, `model_id: eleven_flash_v2_5`, `language_code`, `output_format` values, quota error shape) are written from memory of their API - docs.elevenlabs.io was not reachable from the build session. Verify with one real call before relying on it.

`{ "text": "Roten ur hundra är tio.", "language": "sv", "output_format": "mp3_44100_64", "voice_id": "<optional>" }` -> streamed `audio/mpeg` (or PCM for `pcm_16000` / `pcm_24000`). Text <= 500 chars. Model `eleven_flash_v2_5`. Limits are in **characters** (ElevenLabs bills per character).

## Auth and abuse protection
- Supabase anonymous sign-in; the function verifies the JWT itself (JWKS, or `SUPABASE_JWT_SECRET` for legacy HS256 projects) and requires `role=authenticated` + `sub`. The project anon/publishable key alone is rejected. The gateway also enforces `verify_jwt`.
- Rate limits (Postgres, atomic, shared across instances), all configurable by env, all **fail closed** (a limiter error denies the request):

| Env | Default | Meaning |
|---|---|---|
| `ANSWER_PER_MINUTE` | 20 | per user |
| `ANSWER_PER_DAY` | 400 | per user |
| `ANSWER_GLOBAL_PER_DAY` | 5000 | **global kill switch** for all users |
| `TTS_CHARS_PER_MINUTE` / `TTS_CHARS_PER_DAY` / `TTS_GLOBAL_CHARS_PER_DAY` | 1500 / 15000 / 100000 | characters; **tune to the owner's ElevenLabs plan** |

- Privacy: transcripts/fragments/answers are **never logged or stored**. `answer_usage` keeps only metadata (user id, mode, tokens, timings, estimated cost, status).
- Privacy (D80): `/memory` processes one turn and the existing memory and then drops them: nothing of the text is stored or logged, only the same metadata row in `answer_usage` (endpoint `memory`). The memory itself lives on the device (D49). Feedback the user sends on purpose (`POST /feedback`, D57) is the one place text is kept: a row is deleted within an hour after the owner marks it `processed` (the problem is fixed), and every row is deleted at the latest **90 days** after it was sent (hourly `pg_cron` job `purge-feedback`). Opt-in shared history: at most 12 months (unchanged).

## Deploy
Done by the agent (the owner never runs SQL/CLI by hand). Free plan only; never enter billing details.

**Via Supabase MCP (what was used for v1, because the container cannot reach the Supabase CLI login):**
1. Migration: `apply_migration` with `supabase/migrations/*.sql`.
2. Each function is bundled into one file, because MCP deploy takes flat files and our code shares `_shared/`:
   ```bash
   cd backend
   deno bundle --platform deno --format esm --no-check --minify --keep-names \
     --external "npm:*" --external "jsr:*" -o /tmp/answer.js supabase/functions/answer/index.ts
   deno bundle ... -o /tmp/tts.js supabase/functions/tts/index.ts
   ```
   then `deploy_edge_function` with `name`, `entrypoint_path: index.ts`, `verify_jwt: true` and the bundle as `index.ts`. npm packages stay external (resolved by Supabase at runtime).
3. Re-deploy a function after setting secrets if the first request still sees old values (new isolates pick up secrets).

**Via CLI (alternative):** `supabase link --project-ref xjczbzfkmbjdebwlccki && supabase db push && supabase functions deploy answer && supabase functions deploy tts`.

**Owner-only click-paths (no tool can do these):**
- Anonymous sign-ins: https://supabase.com/dashboard/project/xjczbzfkmbjdebwlccki/auth/providers -> *Sign In / Providers* -> scroll to **Anonymous Sign-Ins** (or *Allow anonymous sign-ins*) -> switch **on** -> *Save*. Supabase limits this to 30 sign-ins/hour/IP and recommends CAPTCHA/Turnstile (verified in Supabase docs).
- Secrets: see below.

### Secrets (the owner enters the values himself - never in chat or in the repo)
Dashboard -> https://supabase.com/dashboard/project/xjczbzfkmbjdebwlccki/functions/secrets -> **Add new secret** (name, value) -> *Save*. Names, exactly:

| Name | Value |
|---|---|
| `ANTHROPIC_API_KEY` | the owner's Anthropic key (`sk-ant-...`) |
| `ELEVENLABS_API_KEY` | the owner's ElevenLabs key |
| `ELEVENLABS_VOICES` | the three Swedish voices, **one line, format `Name:voiceId,Name:voiceId,Name:voiceId`** (see below) |
| `ELEVENLABS_VOICE_ID` | optional default voice id; if absent the first voice in `ELEVENLABS_VOICES` is the default |

**`ELEVENLABS_VOICES` format (D23):** exactly `Name1:voiceId1,Name2:voiceId2,Name3:voiceId3`, e.g. `Astrid:21m00Tcm4TlvDq8ikWAM,Elin:AZnzlk1XvdvUeBnXmlld,Oskar:EXAVITQu4vr4xnSDxMaL` (illustrative ids). Rules: entries separated by commas; name and id separated by one colon; names are what the app shows (letters incl. å ä ö, digits, spaces, `_ . ' -`, max 40, no commas/colons); ids are the 20-character ElevenLabs voice ids (letters+digits only); spaces/line breaks around entries are ignored; at most 10 entries. Invalid or duplicate entries are skipped and logged by name only. Find an id in ElevenLabs: Voices -> the voice -> *ID* (copy icon). After changing the secret, the agent redeploys `tts` and `voices` (new isolates read it).

(CLI equivalent for agents: `supabase secrets set NAME=value`.)
`SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` are injected by Supabase. Optional: `LLM_MODEL` (default `claude-haiku-5-5`), `LLM_EFFORT` (`low`|`medium`|`high`, default `low`), `LLM_DISABLE_THINKING` (`0` to allow adaptive thinking), `CONFIDENCE_THRESHOLD`, `PRICE_IN_PER_MTOK` / `PRICE_OUT_PER_MTOK` (cost estimate only; defaults 0.10 / 0.50), `SUPABASE_JWT_SECRET` (legacy HS256 projects only).

With no `ANTHROPIC_API_KEY` the function answers `503 provider_unconfigured` (fail closed). The mock provider only runs when `LLM_PROVIDER=mock` is set explicitly - never set it in production.

**Cost guard rails the owner should also set on the provider side:** Anthropic Console - keep auto-reload off and set a low monthly spend limit; ElevenLabs - disable usage-based/overage billing so the plan stops instead of charging.

## curl
```bash
SUPABASE_URL=https://<ref>.supabase.co
ANON=<publishable/anon key>
# (anonymous sign-in via POST /auth/v1/signup with an empty JSON body is how supabase-js does it - not yet run against a real project)
TOKEN=$(curl -s -X POST "$SUPABASE_URL/auth/v1/signup" -H "apikey: $ANON" -H 'content-type: application/json' -d '{}' | jq -r .access_token)
curl -sN -X POST "$SUPABASE_URL/functions/v1/answer" \
  -H "Authorization: Bearer $TOKEN" -H "apikey: $ANON" -H 'content-type: application/json' \
  -d '{"fragment":"roten ur hundra","mode":"push_to_talk","language":"sv","context":{}}'
```

## Measuring time-to-first-token
```bash
export SUPABASE_URL=https://<ref>.supabase.co SUPABASE_ANON_KEY=<publishable key>
deno task ttft -- --url $SUPABASE_URL/functions/v1/answer --mode push_to_talk --out results/prod-$(date +%F).json
```
`--set auto` instead runs `testdata/auto-gate.json` (10 questions, 10 non-questions) in `auto` mode and reports gate accuracy (false positives = answers nobody asked for). Prints per-prompt meta/TTFT/total, cold vs warm TTFT, flags style violations (more than two sentences, digits or symbols in the answer, empty answer) and p50/p90. Run once cold and once warm; report both.

## Latency design (D28/D31)
Measured from a client inside Supabase (eu-central-1), 30 Swedish prompts, `push_to_talk`:

| | first answer text p50 / p90 | server-side p50 | input / output tokens |
|---|---|---|---|
| v1 (header JSON, long prompt, 3 sequential limit RPCs, SDKs) | 1 590 / 2 005 ms (max 4 353 cold) | 1 277 ms | 1 447 / 78 |
| v2 (direct mode, short prompt, one limit RPC in parallel with the LLM call) | 980 / 1 079 ms (max 2 326 cold) | 630 ms | 512 / 38 |
| v3 (no SDK / supabase-js, warm-up; **deployed, not yet measured**) | - | - | - |

What the numbers showed: DB round trips from the function cost 150-240 ms each (functions run in Frankfurt, the database in Stockholm); Anthropic is ~120-150 ms away; 29 of 30 requests ran in a fresh isolate, so import weight is paid per request. The `done` event carries a `breakdown` (`auth_ms`, `body_ms`, `limits_ms`, `llm_first_chunk_ms`, `direct`, `cold`) so every future measurement shows where time goes.
- `meta.confidence` is `1` in direct mode (`push_to_talk`/`text`); the confirmation behaviour is in the answer text ("Menar du roten ur hundra?"). Set `DIRECT_MODES=0` to get the JSON-header protocol for all modes.
- **Keep-alive (app side, no cost):** when the listening screen opens, call `GET /functions/v1/answer` (and `/tts`) with headers `x-warm: 1` and `apikey: <publishable key>`; it answers 204 and opens the upstream connection, so the first real question does not pay a cold start.
- **TTS:** the character budget is checked in parallel with the ElevenLabs request (no audio before it passes). Start `/tts` on the first finished sentence of the streamed answer instead of waiting for the whole text.

## Design notes
- **Wire protocol with the model:** first line is a JSON header (`is_question`, `reconstructed_question`, `confidence`), then the answer text. The server parses it incrementally, emits `meta` as soon as the header closes, and streams the rest as `delta`. Chosen over tool-use/structured output because it keeps a single streaming call with the lowest time-to-first-token; a bad header fails safe (auto mode: no answer).
- Runtime dependencies: only `jose` (JWT). The Anthropic SDK and supabase-js were replaced by `fetch` clients for boot time (D31).
- `LLMProvider` (`answer/llm/types.ts`) is the swap point; add a class and a branch in `llm/factory.ts`.
- Haiku 5.5 request: no `temperature`/`top_p`/`top_k` (rejected by the model), `thinking: disabled` + `output_config.effort: low` for latency (documented as accepted at effort <= high).

## Feedback and opt-in shared history (D57)

Migration `supabase/migrations/20261106120000_feedback_and_shared_history.sql` (one migration): tables `feedback` and `shared_history` (RLS on, insert-own-only policy, no client select/update/delete, service role does the writes), owner view `feedback_admin`, `purge_shared_history()` and a daily `pg_cron` job that deletes shared history older than 12 months. Not mixed with `answer_usage` (D49 category stats, no text).

| Endpoint | What |
|---|---|
| `POST /feedback` | `{install_id, type?: "report"\|"app"\|"suggestion", fragment?, answer?, comment?, mode?, persona?, timings?, app_version?}` (at least one of fragment/answer/comment). `install_id` = random id of the install (8-64 chars `A-Za-z0-9_-`). Limits: body 16 KB, fragment 1000, answer 4000, comment 2000; 6/min and 100/day per user. `user_id` comes from the verified JWT, never from the body. Returns `{ok:true}`. |
| `POST /shared-history` | `{install_id, items:[{fragment, answer, summary?, mode?, persona?}]}`, max 50 items, body 256 KB; 12/min and 400/day per user. Only the user's own question and the assistant's answer (never other people's speech). Returns `{ok, stored}`. |
| `DELETE /shared-history` | Opt-out: deletes every row of the caller (verified user id; and the given `install_id` when sent as `{"install_id": "..."}` so history survives a lost anonymous session). Returns `{ok, deleted}`. |
| `GET /feedback-admin?limit=50&type=report&format=html` | Owner view, **service role key as bearer only**. Shared history is deliberately not exposed there (query it with SQL). |
| `POST /answer` | A spoken report command ("rapportera", "rapportera det där", "det där var fel", "skicka till utvecklarna", "report this") in `auto` / `push_to_talk` / `tutor` is recognised in code: no model call, no spoken answer; SSE `meta` (`is_question:false`) then `done` with `report:true`, `answered:false`. The app then sends the previous turn to `POST /feedback` and plays its own confirmation. |

| `POST /feedback-admin` | D80: `{"id": "<uuid>", "status": "processed"}` with the service role key as bearer marks a row processed once the problem is fixed; the hourly job `purge_feedback()` deletes processed rows and every row older than 90 days. 404 when there is no such row. |

Migration `20261107233000_feedback_status_retention.sql`: `feedback.status` (`new` | `processed`), `processed_at`, view `feedback_admin` with `status`, `mark_feedback_processed(id)`, `purge_feedback()` and the cron job `purge-feedback` (minute 41 every hour).

Tests: `supabase/functions/feedback/handler_test.ts`, `answer/d48_test.ts`.

## Memory extraction (D80)

`POST /functions/v1/memory` (user JWT like `/answer`), outside the answer path: the app calls it after a turn, in the background.

Request `{"turn": {"question": "<the wearer's own words>", "answer": "<optional>", "mode": "prov"}, "memories": ["..."], "language": "sv"}` as the app sends it (`MemoryExtraction.swift`; `q`/`a` also accepted, the app's `today`/`weekday`/`timezone` are ignored because the server uses its own Swedish date) (question at most 1000, answer 2000, at most 30 memories of 200 characters; body 16 KB). Send only the wearer's own words as `q`, never other people's speech.

Reply `{"add": ["Har prov i kemi fredag 13 november 2026."], "update": [{"old": "<exact memory>", "new": "..."}], "remove": ["<exact memory>"], "usage": {...}}`: at most 5 items, each at most 160 characters, dates always absolute (from the Swedish date on the server). Only important facts about the wearer (tests, dates, subjects, level, goals, wishes for the answers, rules). Never sensitive categories (health, allergies, diagnoses, religion, politics, sexuality, ethnicity, union, crime): the prompt forbids them and code drops them. A turn with no first-person word (`jag`, `mig`, `min`, `vi`, ...) returns `{"skipped": "no_self_reference"}` without a model call. Haiku 5.5, cached system prompt, about 0.0001 USD per call. Limits: 10/min, 300/day per user, 3 000 per network and day, 10 000/day global (`MEMORY_*` env).

The memories go back to `/answer` as `memories` with every request (unchanged, D49). They are part of the user message, after the static system prompt, so the cached prefix is the same with or without memories.

## Limits for app traffic (D79) and aborted answers (D80)

- Per network (hashed client IP, like the demo): 1 500 answers and 30 000 TTS characters per UTC day for the app (`ANSWER_PER_NETWORK_PER_DAY`, `TTS_CHARS_PER_NETWORK_PER_DAY`). A new anonymous user does not reset it.
- A new session (JWT `amr` timestamp less than 10 minutes old; the timestamp stays the same across token refreshes) gets at most 20 answers in its first clock hour (`NEW_USER_AGE_SEC`, `NEW_USER_ANSWERS_PER_HOUR`). Without an `amr` timestamp the check is skipped.
- All of these are checked in the same round trip as the per-user windows; a denial is `429 rate_limited` with `fallback: true`, as before.
- An answer the client aborts before `done` (the app's preliminary answer, redone when the user keeps talking) is not counted against the user's own minute and day windows (`release_rate_limits`, migration `20261107230000_release_rate_limits.sql`); the network, global and new-user windows stay counted. The usage row gets status `aborted`.

## Nightly live eval (D59)

`python3 scripts/live-eval.py [--only CAT] [--dry]` runs ~100 conversations from `scripts/live-eval-cases.json` against the deployed backend (anonymous session, public key; no secrets) and writes `reports/eval/<date>.md`, `latest.json` and `history.csv`. Checks are pure functions covered by `python3 -I scripts/test_live_eval.py`. `.github/workflows/nightly-eval.yml` runs it at 02:17 UTC (and on demand: Actions -> Nightly live eval -> Run workflow) and commits the result (docs-only paths, so no iOS build).

## Public demo page: contract for the site (D62/D64)

Everything the page (`site/`, GitHub Pages) needs. All calls go to `https://xjczbzfkmbjdebwlccki.supabase.co/functions/v1/...` with the public publishable key; the page signs in anonymously exactly like the app.

1. **Session.** `POST https://xjczbzfkmbjdebwlccki.supabase.co/auth/v1/signup` with header `apikey: sb_publishable_UNDoMfEur7nwt4qH8RRanQ_pVJCrGy8` and body `{}` -> `access_token`. Keep the session in `localStorage` (a new session = a new visitor, but see "network" below). Send `Authorization: Bearer <access_token>` and `apikey: <publishable key>` on every call except `/waitlist`.
2. **CORS.** Browser calls are allowed from `https://aronstenlund-code.github.io`, from `http://localhost:*` and `http://127.0.0.1:*`. Other origins get no CORS header. A custom domain is added in the Supabase secret `CORS_ORIGINS` (comma separated). Native apps send no Origin and are unaffected.
3. **Question.** `POST /answer` `{"fragment": "...", "mode": "text" | "push_to_talk", "language": "sv", "source": "demo", "context": {"recent_qa": [{"q","a"}]}}` -> SSE (`meta`, `delta`*, `done`). In demo: Haiku only, answer cut at 400 characters (short, no summary trailer), no web search, no Rizz / interview / tutor / auto, memories and commands are ignored, a spoken "kom ihåg" or report command is just a question. `persona`/`mode` outside this give `403 demo_unavailable`.
4. **Voice.** `POST /tts` `{"text": "<at most 400 characters>", "source": "demo"}` -> `audio/mpeg` stream. Voice, model and format cannot be chosen in the demo. Longer text -> `413 demo_text_too_long` (cut the answer at a sentence before sending).
5. **Speech to text.** `GET /stt-token?source=demo` (same auth) -> single-use Scribe token (see `/stt-token`), 8 per visitor and day.
6. **Waitlist.** `POST /waitlist` (no auth headers needed) `{"email": "...", "consent": true, "consent_version": "2026-11-06", "source": "demo", "website": ""}`. `consent` must be `true` (the page shows the consent text and the privacy notice next to the checkbox); `website` is a hidden honeypot field that must stay empty. -> `200 {"ok":true}` (also for an address that is already on the list), `400 invalid_email` / `consent_required`, `429 rate_limited` (5 per hour and 20 per day per network). The table is never readable from a browser.

**Limits and errors.** Per visitor (the page's anonymous user): 5 questions/day, 2000 TTS characters/day, 8 STT tokens/day. Per network (hash of the IP, so clearing the browser does not reset it): 20 questions, 8000 characters, 30 tokens per day. Whole demo: 600 questions, 60000 characters, 400 tokens per day (env `DEMO_GLOBAL_QUESTIONS_PER_DAY`, `DEMO_GLOBAL_TTS_CHARS_PER_DAY`, `DEMO_GLOBAL_STT_PER_DAY`, `DEMO_QUESTIONS_PER_VISITOR`). Windows are UTC days. When a cap is reached the call returns **HTTP 429** with `{"error": {"code": "demo_limit_visitor" | "demo_limit_ip" | "demo_limit_global", "message": "<Swedish text the page can show as is>", "fallback": false}}` and a `Retry-After` header (seconds). `demo_unavailable` (403) = mode not available in the demo; `503 demo_unavailable` = the limiter itself is down (fails closed). Errors from the model/voice providers use the usual codes with `fallback: true`.

Tests: `supabase/functions/_shared/demo_test.ts`, `answer/d48_test.ts`.


**Rizz timing (D63).** The first suggestion is streamed at once: SSE event `suggestion_preview` `{"text": "..."}` as soon as candidate 1 is a complete line (the model's strongest line; same safety filter), then the usual `suggestions` event with the final 2-3 options, the preview always first. Four candidates and a shorter prompt cut the output to about 70 tokens. `done.timing.ttft_ms` is the time to the first of them. Cache reads are priced at 0.1x the input price (was 0.05x).
## Quality fixes from QA round 1 (D65)

- **Data in every request:** `<now>` (date, weekday, ISO week, Swedish time) and, when the memories mention an allergy or a health condition, a binding `<safety>` rule. Date, weekday, week, clock and "how many days until X" are answered from code (`datecalc.ts`); time zones from the tz database (`timezone.ts`); a bare unit in a follow-up ("och i fot") is converted from the previous answer's value (`calc.ts`).
- **Speech:** the model never has to spell symbols: `speechsym.ts` handles formulas, powers, clock times (`17.40` -> "sjutton och fyrtio"), regnal numbers ("Oscar I" -> "Oscar den förste"), `2x`, GHz/Hz, soft hyphens, and replaces any phone number except 112 / 1177 / 114 14 (police) with "numret som står på deras webbplats".
- **Never spoken:** the summary line in any variant (`[[SAMMANFATTNING]]`, `SAMMANFATTNING:`, `Sammanfattning:` line); the `[[REL ...]]` tag; the `källa:` line as written.
- **Web answers:** Swedish only, own words (English sentences are dropped), reliable domains only (no wikis), spoken source "Källa: SCB." and `done.source` = the domain for the screen.
- **Tutor mode:** `<already_asked count=N>` is built from the session's earlier answers; one short check question (two-part and long ones are dropped).
- **`done` fields:** `relation` (D53), `summary` (D48), `memory_add` (D49), `source` (web), `report` (spoken report command, D57).
