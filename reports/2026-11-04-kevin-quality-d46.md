# Kevin — D46 answer quality (external 45-answer test, Rizz test, web search, TTS) — 2026-11-04

## What changed (live: `answer` v20, `tts` v9)
- **Numbers/years in code** (`svnum.ts`): the model writes digits, code speaks Swedish words (years 1100-1999 as hundreds, `1800-talet`, decimals, %, units, times, dates), safe across chunk boundaries. Prompt forbids self-corrections.
- **Arithmetic in code** (`calc.ts`): arithmetic, percent, unit conversion -> `<computed>`; the model only phrases it.
- **Context**: `<active_topic>`; an unrelated 3+ word fragment drops older turns; an answer repeating an earlier one is stopped before sending and regenerated once.
- **No questions back**: closing question dropped, question-only answer regenerated once (not tutor/personas/Rizz).
- **Prompt rules (general)**: social remarks, complete practical answers, no invented summary conclusions, translation vs slang.
- **Rizz findings 10-12**: social-situation fragments routed in code to a ready-to-say line (<= 12 words + one tip); rewrite commands rewrite the last line; no mind-reading; holds the line on guilt/pressure.
- **Web search/fetch (8)**: `web_search_20250305` + `web_fetch_20250910` (docs 2026-11-04: both list `claude-haiku-5-5`; search $10/1000 + tokens, fetch no extra fee). Enabled only by code router; max 3 searches + 2 fetches; caps 3/min + 20/day per user, 150/day global; over cap -> answer without web. **Not live-tested** (no web answer was run against Anthropic yet; unit tests with a fake provider only). Latency added: unmeasured, expect seconds.
- **TTS (9)**: `/tts` accepts allowlisted `model`; webtest has a selector.

## Measured (live, 35 own cases incl. the ChatGPT inputs; no special-case code or prompt lines for them)
| | before (v17) | after (v20) |
|---|---|---|
| cases flagged by automatic checks | 14 / 35 | 2 / 35 (both are false alarms of my checks: a correct refusal that quotes "samvete"/"nej", and a correct 39-word answer over my 30-word limit) |
| arithmetic / unit conversion wrong | 3 (408, 2500 ml, 263) | 0 |
| self-corrections ("nittonhundrafemton... nej") | 3 | 0 |
| wrong topic / repeated answer ("varför då", bankkort) | 2 | 0 |
| first text p50 (client in Supabase) | ~750 ms | ~700-840 ms |
Intermediate run (v19) found a regression I introduced (`till engelska: …` answered in Swedish), fixed in v20.
Honest limits: 35 cases are a smoke set, not an evaluation; judged by regex checks plus reading, not by users; TTFT measured from inside Supabase, not from a phone.

## TTS A/B (10 Swedish sentences with long compounds and number words, voice = configured default)
First byte p50 / max: flash_v2_5 **130 / 1034 ms**, turbo_v2_5 **155 / 998 ms**, multilingual_v2 **368 / 1281 ms**. All < 3 s. **Quality (e.g. "åderhundratalet") not scored**: the automatic check via ElevenLabs speech-to-text failed with 401 (the key stored in Supabase still lacks the speech-to-text permission). Probable causes of stutter found: none in our splitter (the app speaks whole sentences; the backend now never cuts a token); pronunciation of rare compounds is the TTS model's. Please compare the three models by ear with the selector on the webtest page; default stays flash until then. This used ~2.2k ElevenLabs credits.

## Next
- Owner: check the ElevenLabs key permissions (speech-to-text) before D44; listen to the TTS models; decide.
- Webtest still not hosted (Vercel project limit). Temp functions `bench` and `ttsab` were retired to 410 stubs.
- D44 (Scribe) next, per the owner's order.
