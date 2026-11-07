# Kevin: D77, interview facts, demo cap texts, anonymous sign-ins, waitlist cleanup

Date: 2026-11-07 · Assignment: Aron (chat), after Oscar's report `reports/qa/2026-11-07-1830-oscar-demo-d72.md`.
Commits: `8cf02cb`, `b7370b0`, `5565e8c`, `24c3619` and the follow-ups below. Deploy backend: last run **green**.
Live: **answer v54, tts v27, stt-token v19**.

**Decision number:** D77. Angela's calibration work took D76 in the same hour (`671a7f9`), so my first commit message
says "D76" by mistake. I did not rewrite history. Code comments, DECISIONS and STATUS all say D77.

## What was asked
1. The interview mode made up facts about the user ("Jag är sjutton år och går tredje året", "Jag har handlat i den här
   butiken länge"). Use only facts from `persona_setup` and the conversation. When facts are missing, give a strong
   answer that states no concrete personal details. Add the cases to the live eval.
2. The demo showed "Du har använt dagens 5 demofrågor" when the STT cap (8) or the TTS cap was reached. Each cap needs
   its own text.
3. The demo caps can be bypassed: an anonymous sign-in is a new user every time, and calls without `source:"demo"`
   get the app's normal limits. Limit anonymous sign-ins per IP (Supabase auth rate limit), and propose more if needed.
   Nothing may stop real app users.
4. Delete Oscar's test rows (`oscar-qa-*`) in the waitlist.

## What was built
| # | Change | Status |
|---|---|---|
| 1a | **Interview prompt** (`personas.ts`). Facts about the user come only from `<persona_setup>`, `<memories>`, `<goals>` and the user's own words in `<recent_qa>`. The model must never state a concrete personal fact that is not there: name, age, school, school year or programme, grades, employers, earlier jobs, how long or where the user has worked, shopped or studied, family, hobbies, certificates, numbers or past events. It must never claim that the user has or lacks some experience. The text in `persona_setup` is the job being applied for, not experience: "Extrajobb som vårdbiträde …" describes the job, and only "Om mig: …" or "jag har …" are facts about the user. With no example given, a behavioural question is answered in the present tense as the steps the user takes ("När två barn bråkar sätter jag mig ner …"), never as an invented story. The model must never say that facts are missing. The old rule that caused the bug, "tell a believable, general example", is removed. | verified live |
| 1b | **Interview filter in code** (`speech.ts`: `InterviewMeta`, `stripInterviewMeta`, only when `persona:"interview"`). Even with the rule, Haiku often said the gap out loud: "Jag har inte någon konkret upplevelse att utgå från, så jag svarar med …", "Jag kan inte säga min ålder här, men …", "Jag heter inte nämnt här …", "Jag heter och är sexton år". The filter removes only the meta part. If the sentence goes on with ", men …" or ", så …" and the rest is a real answer, the rest is kept with a capital letter. "Jag heter och är sexton år" becomes "Jag är sexton år". A sentence that is only meta is dropped. No other mode is affected. A question to the interviewer such as "Kan ni berätta mer om …?" is kept. | verified in tests + live (final run below) |
| 1c | **Live eval**: 5 new cases (`intervju-05` to `-09`, 139 cases in total) and the flag `no_invented_facts` on `intervju-01` to `-03`. The check `INVENTED_FACT` covers "jag är N år", "går tredje året", "jag går på gymnasiet", "jag har jobbat/handlat/…", "i somras", "på mitt förra jobb", "när jag jobbade", "när två barn började …", "jag har inte jobbat …" and similar. A new check `INTERVIEW_META` runs on every interview answer and flags lines about missing facts and empty names. `intervju-05` uses Oscar's setup and questions. `intervju-08` and `-09` check that facts which are given, in the setup or in memories, are still used. The words that flag the old "names a structure" error are now "en struktur", "strukturen" and "star ". The old check matched "ordning och struktur" and "stark". | done |
| 2 | **Own text per demo cap** (`_shared/demo.ts`). The error codes are unchanged (`demo_limit_visitor`, `_ip`, `_global`), so the page keeps working. **STT:** "Du har använt dagens 8 röstfrågor i demon. Skriv frågan i stället, eller kom tillbaka i morgon." It has its own network and global texts. **TTS:** "Du har använt dagens uppläsning i demon. Svaren visas som text, och i morgon läses de upp igen." It also has its own network and global texts. The question cap text is unchanged. | STT verified live; TTS verified in tests |
| 3 | **Anonymous sign-ins per IP:** set to 15 per hour in the workflow `.github/workflows/auth-rate-limit.yml` (manual only). It reads and sets only `rate_limit_anonymous_users` through the Supabase Management API. **It could not be run:** run `42403156192` got **403** on GET, because the repo token is scoped to Edge Functions and Project Settings read. **Aron has to set the value** (click path below). A limit is already active: after about 36 anonymous sign-ins from this machine in about 40 minutes (my eval runs, 5 each), Supabase answered `429 Too Many Requests` on `/auth/v1/signup`. That matches the default of 30 per hour per IP (**verified live**: the 429; the exact current value is **not readable** with the token). | Aron to do |
| 4 | **Waitlist:** listed first. The table held exactly 3 rows, all of them Oscar's (`oscar-qa-1794071877@example.com`, `oscar-qa-r0-…`, `oscar-qa-r1-…`). I deleted those 3 with `delete … where email like 'oscar-qa-%@example.com'`. The waitlist is now empty. | done (verified in the database) |

### Aron: one click path
Supabase Dashboard → project **Lumen** → **Authentication** → **Rate Limits** → "Rate limit for anonymous users" →
**15** (per hour per IP) → Save.

Why 15: every app install and every demo visitor signs in anonymously **once** and then keeps the session in the
Keychain or the browser. A real user needs one sign-in, plus a rare re-sign-in when the refresh token is rejected. The
nightly eval needs 5 and the deploy smoke test 1 (from GitHub's IPs). The risk is a whole class installing the app on
the same school Wi-Fi within one hour: number 16 and later then wait up to an hour. The app retries on the next request.
Raise the value before a school rollout.

### Proposal: more is needed (my judgement)
The sign-in limit only slows a script down. At 15 per hour, one IP can still create 360 users a day, and each of them
gets the app's normal allowance (400 answers, 15 000 TTS characters). The cost is still capped by the global emergency
stops (5 000 answers, 100 000 TTS characters per day), so the real risk is that **one IP uses up the whole day's budget
and stops every real user** (availability), not an unlimited bill. My proposal, in order:
1. **A cap per network on app traffic too** (key = hashed IP, as in the demo): for example 1 500 answers and 30 000 TTS
   characters per network and day, high enough for a school class. This takes about an hour in `_shared/ratelimit` and
   uses the same RPC. **Owner decision needed:** schools share one IP.
2. **A low allowance for new users:** a user whose JWT is less than 10 minutes old gets for example 20 answers in its
   first hour. Scripts make new users all the time; real users are new only once.
3. **Spending caps at the providers** (Anthropic and ElevenLabs), as Oscar proposed. Only Aron can set these.
4. Later: App Attest or DeviceCheck for the app, so that only real installs get the app's limits. This is a bigger app
   change for Angela.

## Test results
- **Unit tests** (Node shim): 218 pass. The 1 failure is `auth_test` "accepts an anonymous-user token". It fails
  because the shim stubs `jose`, which is known and is also the case without my change. **Verified in CI:** every
  deploy run ran `deno task test` and passed, except `b7370b0`, where one of my test strings was wrong. CI stopped that
  deploy, as it should, and the fix `5565e8c` was green.
- **STT cap live** (stt-token v19, a fresh anonymous visitor):
  - token 1–6 were 200;
  - 7–8 were the general `rate_limited` (6 calls in a short time, an older limit);
  - call 9 gave **429 `demo_limit_visitor` "Du har använt dagens 8 röstfrågor i demon. Skriv frågan i stället, eller
    kom tillbaka i morgon."**
  - **Verified live.**
- **TTS cap:** **verified in tests only.** A live check would mean really reading 2 000 characters on ElevenLabs.
- **Interview live eval** (`--only intervju`, 15 turns per run). 7 runs, each run after the next fix:
  - **Before:** Oscar's bug. **After the first prompt fix:** no invented age, school or store history, but meta lines
    such as "Jag har inte någon konkret upplevelse …, så jag svarar med …" and "Jag heter och …".
  - **After the filter that drops whole sentences**: 14/15 without remarks.
    - Oscar's questions were answered with no personal details. Example: "Jag är en engagerad person som trivs med att
      möta människor … Jag är noggrann …".
    - "Hur hanterar du en arg kund" gave the steps in the present tense, and the conflict question likewise.
    - Facts that were given were used: "Jag är sexton år och går naturvetenskapsprogrammet …" and "Jag har jobbat två
      somrar i min mosters klädbutik …".
    - Remaining remark: "Jag har inte jobbat inom vården tidigare, men …", which claims the user lacks experience.
    - New problem: dropping a whole sentence also removed real facts once (intervju-08). That led to the version that
      removes only the meta part.
  - First word p50 about 1.0–1.1 s, max 2.2 s.
  - **Final version (v54):** see "Final run" below.
- **Not tested on a device.** No iPhone or AirPods test after the change.

### Final run
**Final run** (answer v54, 21:04, 15 turns, about 0.0026 USD). It could start only after the anonymous sign-in limit
on this IP opened again: 429 from about 20:13 to 21:04. **Verified live.**
- The eval at the time reported 0 remarks. When I read the answers myself, I found two misses. The checks are now
  sharper and catch both:
  - **intervju-07** ("hur gammal är du och vad pluggar du", nothing given): *"Jag kan inte säga vilken ålder eller
    studieinriktning du har. Däremot kan du svara att du …"*. The model turns into a coach in du-form. **This is still a
    known error.** It happens only when the question asks for nothing but a missing fact. A filter that drops only the
    first sentence would leave "Däremot kan du …", which is worse, so I did not add one.
  - **intervju-06 turn 2** ("vad har du för erfarenhet av vård"): *"Jag har ingen erfarenhet av vårdarbete sedan
    tidigare, men …"*. This claims the user lacks experience. It is milder than inventing experience, but against the
    rule.
- **The rest were correct (13/15 by my own reading):**
  - Oscar's four questions (intervju-05) were answered with no invented personal details;
  - the conflict and "ledsen" questions were answered as present-tense steps;
  - the given facts were used ("Jag är sexton år och går naturvetenskapsprogrammet …", "Jag har jobbat två somrar i
    min mosters klädbutik …");
  - no remark about missing facts.
- First word: p50 0.97 s, max 2.1 s.

## Cost
- Interview live eval: 8 runs × about 0.0028 = about **0.022 USD**, Haiku with caching.
- STT: 8 single-use tokens, which cost nothing unless they are used.
- No TTS, no database cost.
- **Total about 0.02 USD.**

## Known limits and risks
- **The interview filter is a list of phrases.** Haiku keeps finding new ways to say that facts are missing. Each one I
  saw is covered, but new ones can come.
- The rule "never claim that the user lacks experience" is not always followed ("Jag har inte jobbat inom vården
  tidigare"). I left that in the eval rather than filtering it, because a user who really said it must be able to have
  it in the answer.
- A sentence that begins with a meta phrase but carries real facts without ", men" or ", så" is dropped.
- With the interview filter, the first sentence is spoken only when it is complete. In live runs the first word was
  still about 1 s at p50.
- The demo page (`site/index.html`, Kelly) shows the server text only for `/answer` (lines 733–734). On the STT and TTS
  caps it throws `stt 429` or `tts 429` (lines 818 and 648), so a visitor does not yet see the new texts. Kelly should
  show `error.message` for every `demo_limit_*`. That is outside `backend/`, so I did not change it.
- The `auth-rate-limit` workflow works only if the token gets "Auth write". The dashboard is simpler.

## Concerns
None new.

## Next session
- Aron: set "Rate limit for anonymous users" to 15 (click path above). Decide on proposal 1 (a cap per network) and on
  spending caps at Anthropic and ElevenLabs.
- Kelly: show the server text for every `demo_limit_*`, including on `/stt-token` and `/tts`.
- Kevin: fix the open interview error. When a question asks only for a missing fact ("hur gammal är du"), the answer must still be in jag-form. Measure it with `intervju-07` over several runs.
- Oscar: rerun the interview checks against v54 with his own setups, plus the STT cap text on the page in a browser.
