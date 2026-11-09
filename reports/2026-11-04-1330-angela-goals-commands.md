# Report: Målbeskrivning and Egna kommandon (D37, D39)

Date: REPORT_DATE · Session: Angela (builder) · Assignment: "ALSO QUEUED" at the top of `prompts/2026-11-03-mvp-sprint-app.md` (Deangelo 2026-11-04 11:50)

Evidence labels: **verified in CI** (compiles with zero warnings / tests pass on the GitHub macOS runner against fakes), **untested on device**, **untested against the live backend** (Kevin's side of D37 — accepting `goals` and `commands` — is queued; until then the fields are sent and, per the README's validation style, may be rejected or ignored).

## 1. Summary
- **Kursmål:** the user pastes or imports (PDF/text) the course's goal description under Prep material. It is stored on the phone (file-protected JSON, on/off switch) and a compact form (≤ 1 500 chars: the whole text when it fits, else the first sentences plus "Nyckelord: …" from the key-term extractor) goes with every question as `goals`.
- **Egna kommandon:** keyword → instruction pairs, created in a list editor or by voice ("spara kommando fission: förklara fission och jämför med fusion"). Keywords are matched in the spoken question tolerant to STT spelling (edit distance 0 for words under 5 letters, 1 for 5–8, 2 for 9+; multi-word keywords in sequence) and the matched pairs (≤ 10) go as `commands`. A spoken save is stored, confirmed in the AirPods ("Sparade kommandot fission.") and never sent as a question.
- CI_RESULT_LINE
- **Untested on device**: the voice path (does the recogniser hear "spara kommando" cleanly?), the tolerance against real STT output, and the answer effect (needs Kevin's prompt work). Checklist §3s.

## 2. What was implemented
| Piece | Files | Notes |
|---|---|---|
| Goals | `Lumen/Core/Prep/GoalsStore.swift`, `Lumen/Features/Prep/PrepView.swift` | `set/clear/setEnabled`, `compact` (sentence-bounded cut + 15 key terms), persisted `goals.json`; Prep screen section with TextEditor, Save, Import, Clear, on/off, size line. |
| Commands | `Lumen/Core/Commands/CommandMatcher.swift`, `CommandStore.swift`, `Lumen/Features/Commands/CommandsView.swift` | Matcher on `LumenScoring.TextNormalizer` tokens (numbers kept as words) with `EditDistance.distance`; `parseSaveCommand` (colon, comma, semicolon or first word; "spara kommando(t)", "save (the) command"); store with replace-by-keyword, limits 60/300, `commands.json`; editor sheet (More menu → Commands). |
| Request | `Lumen/Core/Answer/AnswerProvider.swift`, `CloudAnswerProvider.swift` | `AnswerContext.goals`, `.commands` with clamping (1 500 / 10 × 300); body fields `goals`, `commands: [{keyword, instruction}]` omitted when empty. |
| Wiring | `Lumen/Features/Listening/ListeningModel.swift` | Matched commands + compact goals added in `activated`; a final transcript starting with "spara kommando" is saved and confirmed instead of being gated/sent; notices. |
| Docs | `docs/DECISIONS.md` D39, `docs/DEVICE-TEST-CHECKLIST.md` §3s | |

## 3. Test results
| Suite (iPhone 17 Pro simulator, iOS 26.5) | Tests | Result | Basis |
|---|---|---|---|
| `CommandMatcherTests` — exact/normalised, STT tolerance by length, multi-word order, spoken save parsing (sv/en, colon/comma/bare, rejects) | 4 | TEST_RESULT | **verified in CI** |
| `CommandStoreTests` — save/replace/delete/persist/limits, cap at 10 matches | 2 | TEST_RESULT | **verified in CI** |
| `GoalsStoreTests` — store/compact/toggle/persist, long text cut at sentences within 1 500 | 2 | TEST_RESULT | **verified in CI** |
| `ListeningCommandsAndGoalsTests` — matched command + goals travel with the question (and not when disabled), spoken save stored/confirmed/not sent, request body + clamping | 3 | TEST_RESULT | **verified in CI** |
| Everything before this task | 237 | TEST_RESULT | **verified in CI** |

## 4. CI iterations
CI_ITERATIONS

## 5. Known limitations, risks
- The backend does not yet validate/accept `goals` and `commands` (Kevin's queued task); the client sends them already. If Kevin's validator rejects unknown fields with 400, questions would fail until his deploy — the README's validator so far ignores unknown fields, but this is **untested against the live backend**.
- Tolerance is per token: "fisjon" (two edits) does not match "fission"; one edit does. Tune after §3s.
- Spoken save needs the exact lead-in "spara kommando"; other phrasings are not recognised.
- One goals text per device (no per-course list); goals are not yet used for STT contextual strings (only prep material is).
- Notices and the voice confirmation are hard-coded sv/en strings, not in the catalog.

## 6. Concerns (per CLAUDE.md)
None. Goals and commands are the user's own data, stored only on the phone; they go to the backend as plain fields and change nothing in the app's rules.

## 7. Next
Whatever Deangelo queues next; otherwise the first device session (checklist §3i–3s).
