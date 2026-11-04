> **PRIORITY TASK (Deangelo 17:55, D43): Rizzläge backend.** `persona: "social"` request adds `social: {style: flirtig|rolig|självsäker|avslappnad|uppriktig, trigger: other_spoke|stall|opener, transcript: [{speaker: user|other, text}] (last ~2 min), interests: [], profile: "" }`. Response (fast path, no long prose): first SSE event `suggestions` = JSON array of 2–3 options, each ≤ 8 words, best first, in Swedish, speakable; nothing else. Prompt principles: use the whole conversation's topic and tone; match the chosen style; stall → follow-up/new topic/light comment; opener → from interests/profile; always respectful and honest (no manipulation, pressure, negging, lies, sexual content); if the other person signals no/discomfort → respectful options or a friendly exit; age-appropriate. Target: first suggestion text < 900 ms warm. Tests on your own examples (not the owner's). Deploy, update README contract, short report with TTFT. Then add a Rizzläge panel to backend/webtest (style picker, 'den andra sa…' text box + mic, plays the best option, shows all). Sparläge.

> **QUEUED (Deangelo 16:30, D42 revised):** accept `persona: tutor|interview|social` + optional `persona_setup` (≤ 1 500 chars, user data; may be a job ad). interview: the fragment is the interviewer's question (or the user's own answer when `turn: user_answer`) → for a question return a compact spoken answer outline (structure + 2–3 key points tailored to the role, STAR for behavioural questions); for a user answer return 1–2 sentences of concrete feedback; 'klar' → short summary. Add `/answer` mode `interview_prep`: from a job ad produce likely questions with short model answers. social: the fragment is what the friend said → one short, natural, light suggestion of what the user could say next (respectful, playful, no manipulation/pressure/pickup tactics, age-appropriate). Same no-filler style. Tests on your own examples, deploy. Sparläge.

> **ALSO (Deangelo 11:50, D37):** accept optional `goals` (≤ 1 500 chars) and `commands: [{keyword, instruction}]` (≤ 10, each ≤ 300 chars) in the request, validate and tag them as user data. Prompt principles: tailor level and focus to `goals`; when a command is present, carry out its instruction for this turn; every sentence must carry content (no filler, no preamble, never "vad menar du"); any check question must be answerable with ja/nej or one word. Same hold-out rule (no pi/decimals/owner screenshots; no example using the owner's own commands like fission). Tests + deploy.

> **ADD TO THE SAME TASK (Deangelo 11:45, owner test 2): general rules, not special cases.** Owner typed `pi` → "Menar du pi-talet …?", then `10st` → "Menar du tio stycken?", `10 deci` → "Menar du tio deciliter…?". Two root causes in `prompt.ts`: (1) DIRECT prompt tells the model to confirm whenever a fragment "could mean several things" — a bare term almost always can; (2) nothing tells the model that a short follow-up continues the previous turn. Replace with **broad principles** (no topic-specific examples):
> - **Answer the most likely meaning.** Choose the interpretation a student would most plausibly mean, given `recent_qa`, `transcript` and `prep_terms`, and answer it. Confirm only when two readings are both likely *and* would give very different answers *and* context cannot decide — expect this to be rare (target < 5 % of turns).
> - **A bare term or short phrase = "explain this to me"**: what it is, the key facts/values a student needs, and one detail that helps it stick. For quantities and constants give the commonly used value with reasonable precision.
> - **Conversation continuity:** a short fragment that only makes sense relative to the previous turn (a number, a unit, "mer", "varför", "och …?", "fler", "enklare") modifies or extends the last topic. If the previous assistant turn was a confirmation question, treat the follow-up as "yes" plus the refinement and answer.
> - Do **not** put confirmation questions into memory as answers that the next turn should be interpreted against beyond the rules above.
> - **Hold-out rule:** the owner keeps specific test questions secret for later evaluation. Do not add examples about pi, decimals or any of the owner's screenshots to the prompt, tests or `testdata/`. Use your own unrelated examples (e.g. other subjects) and measure on them.
> Report: confirmation rate and follow-up handling on a new 10-turn conversation test set of your own.

> **NEXT TASK (Deangelo 2026-11-04 11:30, D35): adaptive answer length.** Owner test: fragment 'kärnkraftverk procons' → model asked 'Menar du för- och nackdelar med kärnkraftverk?' instead of answering. Fix in the prompt/header: add `answer_type: fact|study` to the header; never confirm when topic + intent are clear (raise the bar for `needs_confirmation`, only real two-way ambiguity); `study` → developed spoken answer of ~5–8 short sentences (overview line, then points; no lists/markdown; numbers as words); `fact` → 1–2 sentences. Accept request field `length: short|adaptive|long` (default adaptive) and treat 'mer'/'fortsätt'/'förklara enklare' as continuing the last answer using `recent_qa`. Raise `max_tokens` only for study answers. Test with 15 study fragments + the 30 short prompts (add the study set to `testdata/scripts/`), report confirmation rate, sentences per answer, TTFT. Keep first text < 1.2 s. Also (D36): accept `mode: "tutor"` — always the pedagogical study style, uses the whole session's `recent_qa`, may end with one short check question, never asks for confirmation unless truly ambiguous. Deploy. Sparläge.

> **REACTIVATED by CREED 2026-11-03 18:20 (D18).** Needed for iPhones without Apple Intelligence (iPhone 12 → 15) and for ElevenLabs voices. **Zero-cost rules override everything below:**
> - Supabase **free tier** only (or another free-tier serverless host). Ask the product owner before creating a project; never add billing details.
> - LLM (**update 18:25, D19**): **Claude via the Anthropic API**, using the owner's existing key and prepaid credits (owner enters the key as a Supabase secret himself; never in chat or repo). Default model: **Claude Haiku 5.5** (`claude-haiku-5-5`; $0.10 / $0.50 per MTok in/out for prompts ≤100k tokens per Anthropic's pricing page, 2026-11-03) — keep prompts well under 100k tokens. Log input/output tokens per request so cost per answer is measured. Keep `LLMProvider` pluggable. On credit/quota errors fail closed (app falls back to on-device answers / a clear message).
> - ElevenLabs: TTS only, through the owner's existing plan; key stored as a Supabase secret (owner enters it himself — tell him the exact secret name). Add `/tts` endpoint streaming audio. Never ElevenLabs Agents (LLM billed on top).
> - Every external call must fail closed: on quota/billing errors return an error the app turns into Apple TTS / on-device fallback.


> **Update 21:40 (D23): three Swedish voices.** Add secret `ELEVENLABS_VOICES` (`Name:voiceId,...`, 3 entries) as allowlist for `/tts`, add `GET /voices` (names + ids), tests, deploy, document in README. Tell the owner the exact secret format.

> **Live test by Deangelo, 2026-11-03 22:38 (all secrets set, anonymous sign-in on):** `/answer` works end to end with correct Swedish answers (Haiku 5.5, ~1450 input / ~60 output tokens). `/tts` returns 200 audio/mpeg with Adam's voice. **Too slow:** `llm_first_token_ms` 1.7–2.5 s, `ttft_ms` 1.8–2.8 s, client total 2.7–3.0 s before any audio, versus the 1.5 s end-to-end target. **Update 22:46 (D28): owner's hard limit ≤ 5 s end to end (p95), target ≤ 3 s (p50).** Answer text alone takes ~3 s today and TTS adds on top, so the target is missed. **Next task (priority):** cut time to first answer text to ~1 s warm and start TTS on the first sentence, not the whole answer. Ideas to measure, not assume: in `push_to_talk`/`text` mode skip the JSON header and stream the answer immediately (reconstruction is not needed when the user asked on purpose); shorten the system prompt and use prompt caching for it; check region/latency between the Edge Function and the Anthropic API; keep the function warm. Report before/after numbers on the 30 prompts.

> **Critical path (CREED 18:30):** the owner's test phone (iPhone 14 Pro) has no Apple Intelligence, so every answer in the first device test comes from this backend. Deploy a working `/answer` as early as possible, before polishing.

# Claude Code assignment (Kevin Malone) — MVP sprint: backend `/answer`

Approved by: CREED, 2026-11-03 17:50. Deadline: working first version by 2026-11-10.
Runs **in parallel with Angela** in a separate Claude Code session. Work only inside `backend/` (and `docs/` for your report/STATUS lines) so you never edit the same files as Angela. Read `CLAUDE.md`, `docs/ARCHITECTURE.md` §7 and §10, `docs/DECISIONS.md` (D2, D5, D6) first.

## Goal
A deployed, streaming answer endpoint the app can call without any provider key in the app.

## Build
1. `backend/supabase/functions/answer/` — Supabase Edge Function (Deno/TypeScript):
   - `POST /answer`, JSON in: `{ fragment, mode: "push_to_talk"|"auto"|"text", language: "sv"|"en", context: { transcript, recent_qa: [{q,a}], prep_terms: [] } }`.
   - Response: **SSE** stream. First event `meta` = `{ reconstructed_question, confidence, is_question }`; then `delta` events with answer text; final `done` with timing. In `auto` mode return `is_question:false` quickly and stop when the fragment is not addressed to the assistant.
   - Answer style: max 2 short sentences, spoken-friendly (numbers and units written for TTS), same language as the user; if confidence < threshold, answer with a 2–4 word confirmation question.
   - Provider-agnostic `LLMProvider` interface; first implementation per the product owner's chosen provider. Key read only from a Supabase secret.
2. Auth: Supabase anonymous sign-in; verify JWT; per-user rate limit (simple table or in-memory window); request size limits.
3. `backend/README.md`: deploy steps, required secrets (names only), curl example with SSE.
4. Tests: unit tests for prompt building + response parsing; a script that hits the deployed endpoint and prints time-to-first-token.

## Rules
- Never commit keys. Ask the product owner before creating paid resources or a new Supabase project.
- If no LLM key is available yet, finish everything against a mock provider and stop only the deploy step; report what is missing.

## Acceptance
- [ ] Deployed endpoint returns streamed Swedish answers to the 30 short prompts (`testdata/scripts/sv-short-prompts.md`); time-to-first-token p50 measured and reported.
- [ ] Report `reports/YYYY-MM-DD-HHMM-kevin-backend.md`, STATUS line updated.
