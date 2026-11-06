# Deangelo Vickers — handoff (2026-11-06 18:45)

For a new Deangelo (project supervisor) session. Read this, then CLAUDE.md, docs/STATUS.md, docs/DECISIONS.md (D1–D62), docs/ROADMAP.md.

## Roles
Deangelo = supervisor (plans, decides with Aron, writes prompts, verifies live). Angela = iOS app (Opus 5.5). Kevin Malone = backend `backend/` (Sonnet 5.5, own Supabase MCP scoped to Lumen). Oscar Martinez = QA (Opus 5.5 medium, judge in-session, cost rules). Kelly Kapoor = demo site `site/` (Opus 5.5, ui-ux-pro-max, frontend-design, Emil Kowalski skills). Architect = paused (Track D).

## Working agreements with Aron (owner)
- Swedish, short answers; details in the repo. Always give the **full** prompt when changing one.
- Aron never runs SQL/CLI; agents deploy/migrate. He only enters secrets, approves projects/costs, flips settings with exact click paths.
- Nothing may cost money except his existing Claude API credits (~5 USD prepaid, auto-reload off) and ElevenLabs Starter plan.
- Verify live before claiming things work; label verified / untested.
- Rizz/Intervju modes: consent-based (friend test / practice); no covert-use features; discreet indicator without text (owner decision); other people's speech never stored verbatim.

## Infrastructure
- Supabase project **Lumen** `xjczbzfkmbjdebwlccki` (free tier, eu-north-1). Never touch `netiicslmonsrwhjhupb` (Prospektregistret).
- Secrets set: ANTHROPIC_API_KEY (expires 2027-03-31), ELEVENLABS_API_KEY (TTS + STT + voices read), ELEVENLABS_VOICE_ID (Adam), ELEVENLABS_VOICES = Adam/Saga/Max.
- Publishable key + URL in backend/README.md. Anonymous sign-in on.
- Test page: https://raw.githack.com/aronstenlund-code/aronstenlund-airpods-ai/<commit>/backend/webtest/index.html (pin a commit to avoid cache).
- Live eval: `scripts/live-eval.py`.

## State (2026-11-06)
- Backend: answers (Haiku 5.5; Rizz on Sonnet 5.5), digits→words + arithmetic + time zones in code, topic relation by model (D53), web search, summaries + memory + categories (D48/D49), Scribe STT token (verified live), voices. Next queued for Kevin: D57 feedback/shared history, D62 demo backend (waitlist, demo caps, CORS), Supabase-Lumen MCP setup.
- App: MVP items 1–9 + Provläge + music switch built, CI green, **never run on a device**. Queued for Angela (in prompts/2026-11-03-mvp-sprint-app.md): D49/D56 history+memory, D44 Scribe, D55 mic source, D42/D43 mode picker, checklist, D57 feedback, D58 Siri/Control start. D60 nod-to-expand is deferred — Aron decides timing.
- Blocker: **no Mac with Xcode** → no device test. Deadline for first working version: 2026-11-10.
- Marketing: ad script + Higgsfield prompts agreed in chat (Provläge corridor → classroom WW1 question with nod → drömutbildningen → club pickup line #4 → morning → grade paper A+ 100 % → montage). App name still undecided.
