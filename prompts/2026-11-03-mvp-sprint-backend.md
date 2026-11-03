# Claude Code assignment (Builder B) — MVP sprint: backend `/answer`

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
- [ ] Report `reports/YYYY-MM-DD-HHMM-builderB-backend.md`, STATUS line updated.
