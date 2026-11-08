# Kevin: K0, key swap and error logging

Date: 2026-11-08 · Assignment: `prompts/queue/kevin.md` K0.
Deploy backend run `42503835435` **green**. Live: **answer v100, tts v73, stt-token v65** (all functions redeployed by the same run).

## What was done
1. **Secrets are cleaned when read** (new `_shared/secrets.ts`, `secret(env, name)`):
   - **What is removed:**
     - spaces and line breaks;
     - non-breaking and zero-width spaces, including the BOM;
     - quotes around the value, including the curly quotes a phone keyboard adds.
   - **Why:** a key never contains whitespace. A pasted key with a hidden character or a line break makes the header invalid, so `fetch` throws before any request is sent. That is the "502 provider_unavailable on ~1 s, always" Deangelo saw at 17:50.
   - **Used for:**
     - `ANTHROPIC_API_KEY`, which covers answer, exam, memory, study-cards, study-profile and provlage-eval through `providerFromEnv`;
     - `ELEVENLABS_API_KEY` in tts, stt-token and provlage-eval;
     - `SUPABASE_SERVICE_ROLE_KEY` in restdb, feedback-admin and usage-stats.
   - An empty value after cleaning counts as unset, so it still fails closed with `provider_unconfigured`.
2. **The cause of "unavailable" is logged:**
   - **Anthropic** (`classifyAnthropicError`): one line `{"event":"provider_unavailable","status","error","message"}` with the HTTP status (or null), the error name (for example `TypeError` or `overloaded_error`) and the first 200 characters of the message, including `cause`.
   - **ElevenLabs:** the same line for tts and stt-token when the provider cannot be reached or answers with an "unavailable" status.
   - **Keys never reach the log:** the key itself, `sk-ant-…`, `sk_…` and JWTs are replaced with `[redacted]` before anything is written.
   - Other error kinds (quota, auth, rate_limited, bad_request) already had their own message and log nothing new.
3. **Live check after deploy** (verified live, 21:38):

   | Call | Result |
   |---|---|
   | `/answer`, text mode, "vad är fotosyntes" | 200, first text after 956 ms, full answer |
   | `/answer`, Provläge Åk 9 Biologi, "vad är mitos" | 200, 1 015 ms, full answer |
   | `/tts`, "Hej." | 200, 5 268 bytes audio/mpeg |

   Cost: 0.0008 USD.
4. **Aron's key:** the re-pasted key (17:55) works. The fix means a new paste with a line break or space no longer breaks anything. **untested assumption** that the 17:50 paste had exactly such a character: the old value cannot be read back, but the symptom (502 in ~1 s with no status) matches a `fetch` error before sending.

## Tests
- New `_shared/secrets_test.ts`, 4 tests:
  - cleaning (spaces, `\r\n`, a line break inside the key, zero-width space, BOM, straight and curly quotes, empty values);
  - the provider gets the cleaned key;
  - nothing in a log line contains the key;
  - only "unavailable" is logged, with status, name and message.
- Node shim: **280 pass**. `auth_test` fails as always under the shim and is known. CI `deno check` and deploy are green.

## Known limits
- `SUPABASE_JWT_SECRET` is not cleaned (legacy HS256, not set on this project).
- The log line is in the Supabase function log (Edge Functions > answer > Logs). The app does not see it. Angela's A5 shows the user the error code.
- A cause that is not an `Error` (very unusual) is logged as text.

## Next
K2 (D87 to ≥ 90 %), already marked pågår.
