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
  "social": { "style": "flirtig|rolig|självsäker|avslappnad|uppriktig", "trigger": "other_spoke|stall|opener",
              "transcript": [{"speaker":"other","text":"..."},{"speaker":"user","text":"..."}],
              "interests": ["löpning"], "profile": "" } }
```
Defaults: `style` rolig, `trigger` other_spoke. A non-empty `fragment` with `trigger: other_spoke` is appended as the other person's latest line. Limits: `transcript` 40 lines x 300 chars (send the last ~2 min), `interests` 10 x 60, `profile` 1000 (413 otherwise); `social` requires `persona: "social"`. Without `social`, `persona: "social"` keeps the older D42 single-line suggestion.

Response: **no `meta`, no `delta`**. One event, then `done`:
```
event: suggestions
data: ["Chili? Då vet jag vem som bjuder.","Hur stark, är du modig eller galen?"]

event: done
data: {"answered":true,"timing":{"ttft_ms":1010,...},"usage":{...}}
```
- Array of 2-3 strings, **best first**, each <= 8 words (dropped otherwise), Swedish, written to be spoken. The app speaks `[0]` in a pause and shows the rest.
- It is sent as soon as two clean lines have streamed (the model writes three; the third is not waited for).
- Filter: lines with sexual or pressuring wording are dropped. If nothing survives (or the model returns nothing) a safe fallback is sent (`["Berätta mer om det.","Hur har din dag varit?"]`; if the other person's latest line is a no/leaving/discomfort -> `["Okej, helt lugnt.","Vi tar det en annan gång."]`) and the usage row has `status: "filtered"`.
- Decline handling: a no/leaving/discomfort in the other person's latest words is flagged to the model (`<signal>decline`), so every option accepts it kindly or ends the conversation warmly. Nothing is stored: the transcript lives only in the request; usage rows hold counts and timings.

## Answer quality in code (D46)
Root causes of the external 45-answer test were fixed in code, not with more prompt text:
- **Digits -> Swedish words, in code.** The model writes digits (`1789`, `3,5`, `12 %`, `2,5 liter`); `answer/svnum.ts` turns them into speakable Swedish before every `delta` (years 1100-1999 as hundreds, `1800-talet`, decimals, percent, units, times, dates, ordinals), so the app/TTS only ever receives words. Held back across chunk boundaries, so a number is never split. Consequence for the app: `delta.text` is already spoken-form (no digits); there is no separate display text.
- **Arithmetic in code.** Plain arithmetic, percentages and unit conversions in the fragment (`17 gånger 24`, `12 procent av 250`, `2,5 liter i ml`) are computed by `answer/calc.ts` and passed to the model as `<computed>` (it only phrases the result). Everything else is left to the model.
- **Context.** The last turn is `<active_topic>`; a fragment of 3+ words with no word in common with the last turn and no follow-up cue starts a new topic (older turns are left out). If an answer starts like an earlier answer for a different fragment it is stopped before anything is sent and regenerated once (`usage.input_tokens` counts both attempts).
- **No questions back.** A closing question to the user ("Vill du att jag ...?") is dropped from the stream; an answer that is only a question is regenerated once. Not applied in `tutor` mode (its check question), personas, or Rizz suggestions.
- **Social situations in every explicit mode** (`hon skrev hej`, `vad svarar jag`, `ge mig en komplimang`): routed to a ready-to-say line (<= 12 words) plus at most one short tip; rewrite commands (`mer självsäkert`, `kortare`, `roligare`) rewrite the last line; ambiguous signals are described as uncertain; refuses guilt/pressure/manipulation and keeps that when pushed.
- **Web search / fetch when needed** (explicit "sök/kolla upp", current facts like prices, weather, opening hours, news, or a URL/domain in the fragment): Anthropic server tools `web_search_20250305` (max 3 searches) and `web_fetch_20250910` (max 2 fetches), no beta header; spoken form "verdict + 1-2 reasons + källa: <domän>". Cap per user 20 web answers/day and 3/minute, global 150/day (`WEB_PER_DAY`, `WEB_PER_MINUTE`, `WEB_GLOBAL_PER_DAY`); over the cap the answer is given without the web and says it may be out of date. Each search costs $0.01 on the owner's Claude credits (counted in `est_cost_usd`; `done.usage.web_searches`). Adds latency: the first text arrives after the searches (seconds, not ~0.8 s). A search turn the API pauses (`pause_turn`) fails closed with `provider_unavailable` (app fallback).
- **`/tts` `model`** (optional): `eleven_flash_v2_5` (default), `eleven_turbo_v2_5`, `eleven_multilingual_v2` (metered at 2x characters). Webtest has a selector.

## API: `GET /stt-token` (D44, Scribe v2 Realtime)
`GET /functions/v1/stt-token` (JWT like the other endpoints) -> `{ "token", "expires_in": 900, "model_id": "scribe_v2_realtime", "ws_url": "wss://api.elevenlabs.io/v1/speech-to-text/realtime", "language_code": "swe" }`. The token is a **single-use** ElevenLabs token (type `realtime_scribe`, expires after 15 minutes); the API key never leaves the backend. The client opens the WebSocket itself: `ws_url?model_id=...&token=...&language_code=swe&audio_format=pcm_16000&commit_strategy=manual[&keyterms=...]`, sends JSON `input_audio_chunk` messages (PCM16 mono 16 kHz, base64; last one with `commit:true`) and receives `partial_transcript` / `committed_transcript`. Caps: 6 tokens/minute, 120/day per user, 600/day global (`STT_*` env). Errors carry `fallback:true`: the app uses Apple/Safari recognition.
`POST /stt-token` with `{"seconds": n}` (0-3600) logs the seconds the client streamed (usage row `endpoint: "stt"`, `total_ms` = seconds x 1000, cost estimate at $0.39/hour). **Status:** deployed; **not yet verified live**: ElevenLabs answers `401 missing_permissions: speech_to_text` for the key stored in Supabase (it also lacks `user_read`, so plan allowance/usage cannot be read). Audio field names (`audio_base_64`, `sample_rate`) and `keyterms` are from the API reference snippets and untested until the permission is fixed.
Accuracy: `deno run --allow-read scripts/wer.ts hyp.tsv` scores recognised phrases ("<item>\t<text>") against `testdata/scripts/sv-short-prompts.md` (WER + exact match, digits/words normalised); run it per recogniser.

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
