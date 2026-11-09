# Report: MVP item 4 — Answer engine (Claude via the backend)

Date: 2026-11-03 REPORT_TIME · Session: Angela (builder) · Assignment: `prompts/2026-11-03-mvp-sprint-app.md` item 4, as amended by D18/D19 (cloud default, Foundation Models later)

Evidence labels: **verified in CI** (compiles with zero warnings / tests pass on the GitHub macOS runner against fakes), **verified in docs** (Kevin's `backend/README.md`), **untested against the live backend**, **untested on device**.

## 1. Summary
- The core loop is now wired end to end in code: a detected question (item 3) → `AnswerEngine` → `CloudAnswerProvider` → Kevin's deployed `POST /functions/v1/answer` (SSE `meta → delta* → done`) → the answer streams into the Listening screen's history, with the backend's reconstructed question shown as the question. Sentences are split as they stream, ready for TTS (item 5).
- CI_RESULT_LINE
- **The app has not talked to the live backend yet.** The whole client side is tested against scripted HTTP fakes that replay the exact bodies in `backend/README.md`. The backend itself **is live**: Deangelo's test at 22:38 (secrets set, anonymous sign-in on) got correct Swedish answers from `/answer` and audio from `/tts`, but slow (`ttft_ms` 1.8–2.8 s; Kevin has a latency task). So the first device session can exercise the real loop; if sign-in or secrets regress, the app shows the exact code ("anonymous_provider_disabled", "provider_unconfigured") as a notice.

## 2. What was implemented
| Piece | Files | Notes |
|---|---|---|
| Provider contract | `Lumen/Core/Answer/AnswerProvider.swift` | `AnswerProvider` protocol (`answer(_:) -> AsyncThrowingStream<AnswerEvent>`), `AnswerRequest` (fragment, `mode`, `language`, `context`) clamped to the backend limits (1000 / 6000 / 6×400 / 30×60), `AnswerMeta`/`AnswerDone`/`AnswerFailure` mirroring the README, typed `AnswerError` with `wantsFallback` (`fallback:true` or offline). |
| SSE | `AnswerSSEParser.swift` | Incremental line parser (CRLF, multi-line data, comments) + decoder (snake_case); unknown events ignored; error bodies decoded in the backend's `{error:{…}}` shape, Supabase Auth's `{error_code,msg}` shape and plain text. |
| Auth | `SupabaseAuth.swift` | Anonymous sign-up (`POST /auth/v1/signup`, `apikey`, `{}`), refresh (`/auth/v1/token?grant_type=refresh_token`), fallback to a new anonymous user when refresh is rejected; session in the **Keychain** (`KeychainSessionStore`), never UserDefaults. The publishable key is in `BackendConfig.lumen` — public by design per Kevin, grants nothing without a user JWT (D2 holds: no provider keys in the app). |
| Cloud provider | `CloudAnswerProvider.swift` | `Authorization: Bearer <user JWT>` + `apikey`, JSON body in the README shape (empty context members omitted), one automatic re-sign-in on 401, HTTP errors → `AnswerError.backend(status, failure)`, `event: error` mid-stream yielded then thrown, URLError → `.offline`. `MockAnswerProvider` streams a deterministic local answer (Debug toggle "Mock answers"). |
| Engine | `AnswerEngine.swift` | One answer at a time; a new question cancels the current request (the stream's `onTermination` cancels the URLSession task); `meta.isQuestion == false` → skipped; `needsConfirmation` keeps the user's words as the question; activation → first delta measured with `ContinuousClock`; signposts `answer.requested` / `answer.firstDelta`; `SentenceSplitter` emits whole sentences (decimals, abbreviations, initials kept). |
| UI / model | `Conversation.swift`, `ListeningModel.swift`, `ListeningView.swift` | `Conversation.streamingAnswer` → "Thinking…" then live text → moves into the history with latency and source; notices for failures / "not a question"; `ListeningModel` is the `AnswerSink`, builds the context pack (60 s transcript excluding our playback, last 3 Q/A), cancels answers on stop. |
| HTTP seam | `HTTPStreaming.swift` | `URLSessionHTTP` (bytes → lines) in the app, `FakeHTTP` in tests. |

Not in this item: Foundation Models provider (guarded optional, after the loop works on device — and not testable on the owner's iPhone 14 Pro), TTS (item 5), text-entry UI (item 6; `submitText` exists), prep terms (item 9; the field is sent when present).

## 3. Test results
| Suite (iPhone 17 Pro simulator, iOS 26.5) | Tests | Result | Basis |
|---|---|---|---|
| `SSELineParserTests`, `AnswerSSEDecoderTests` — README example, CRLF/multi-line, not-a-question, mid-stream error, unknown events, error bodies | 8 | TEST_RESULT | **verified in CI** |
| `SentenceSplitterTests` | 4 | TEST_RESULT | **verified in CI** |
| `ConversationAnswerTests` — streaming → history, empty dropped, interruption, recent Q/A, request clamping, mode/language mapping | 5 | TEST_RESULT | **verified in CI** |
| `SupabaseAuthTests` — sign-up + Keychain-shaped store, cached token reuse, refresh, refresh failure → new user, anonymous sign-ins disabled (422), offline | 5 | TEST_RESULT | **verified in CI** (fakes) |
| `CloudAnswerProviderTests` — sign-up then stream, body shape, 401 retry once, double 401, 503 `provider_quota` → fallback, mid-stream error, auto not-a-question, offline | 8 | TEST_RESULT | **verified in CI** (fakes) |
| `AnswerEngineTests` — deltas/sentences/completion + latency, skipped, confirmation, failure with fallback flag, offline message, interruption cancels the first request, cancel, mock switch | 8 | TEST_RESULT | **verified in CI** |
| `ListeningAnswerTests` — hold-to-ask ends with an answer in the history (context carries the transcript), failure notice, not-a-question notice, stop cancels | 4 | TEST_RESULT | **verified in CI** |
| Items 1–3 + Phase 1 suites | 173 | TEST_RESULT | **verified in CI** |
| `LumenScoring` (macOS host) | 21 | TEST_RESULT | **verified in CI** |
| Live backend from the app (sign-in, real Claude answer, TTFT), device | — | not run | backend is live since 22:38 (Deangelo); needs the Mac + iPhone |

## 4. CI iterations
CI_ITERATIONS

## 5. Known limitations, risks
- **Live contract unverified.** The README's SSE/JSON shapes are mirrored exactly, but one real call will tell. First thing in the device session: hold-to-ask → watch the notice line. The error texts are precise on purpose (`code` + HTTP status).
- Error texts from the engine are English only for now (they come from `LocalizedError` descriptions, not the string catalog).
- No Foundation Models fallback yet: when the backend says `fallback:true` or the phone is offline the user sees the message, no on-device answer (D19: fallback only on Apple Intelligence devices anyway).
- `URLSessionHTTP.lines` relies on `URLSession.bytes(for:)`; SSE keep-alive comments are handled, but a proxy that buffers the whole response would delay all deltas to the end (not expected with Supabase).
- Anonymous Supabase users are per install (Keychain); reinstalling creates a new user and new rate-limit buckets.
- The debug mock toggle is compiled only in Debug.

## 6. Concerns (per CLAUDE.md)
None new. Only transcribed text leaves the phone, as the consent screen says; the backend stores no transcripts (D20).

## 7. Next
Item 5 — voice output: `TTSProvider` protocol, `AppleTTSProvider` through `PlaybackService` (sv/en voices, speed), ElevenLabs via `/tts` with the three allowlisted voices (D23) when the backend is live, sentence-by-sentence speaking from `answerSentence`, a new question interrupts the current speech.
