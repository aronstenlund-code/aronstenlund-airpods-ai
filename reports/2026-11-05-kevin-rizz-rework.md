# Kevin — Rizzläge rework (D52), 2026-11-05

## What changed (live: `answer` v27)
- **Model**: persona social runs on Claude Sonnet 5.5 (`RIZZ_MODEL`; $2/$10 per MTok, docs 2026-11-05). Haiku 5.5 stays for everything else. `thinking:disabled` is now sent to Haiku only (Sonnet/Opus 5.5 reject it with HTTP 400).
- **Generate, review, choose** in one call: 5 candidates `n|hook|line` + `TOP:`; the hook (1-2 words) forces each line to build on something concrete. The prompt requires: concrete grounding, joke logic you can explain in one sentence, natural spoken Swedish <= 10 words (no translated English, no pickup clichés), the requested style (flirtig = charming and a bit cocky, rolig = a punchline that lands, självsäker = calm and direct, avslappnad = simple, uppriktig = warm and honest), respect (a no gives respectful lines or a friendly exit). Code re-applies length/safety/duplicate rules and tops up.
- **Context**: last 10 turns (who said what) + `<stage>` opener / middle / stalled.
- **Cost** per request in the usage row and in `done.usage.est_cost_usd` (+ `model`); webtest shows it.
- **`social.spicy`** (default off, flirtig only): bolder, suggestive-but-witty flirt, never explicit/crude/pressuring, ignored over a no. Implemented as an opt-in per request because the server cannot tell who is calling; the app decides when to send it. Unit-tested; not part of the measured set (the set runs with it off).

## Measured (30 own scenarios in `testdata/rizz-scenarios.json`: fest, skola, gym, café, chatt, avstannat, nej/obekväm; judged 1-5 by Claude Opus 5.5 with a strict rubric — a model judge, not people)
| | before (Haiku, old prompt) | after (v27) |
|---|---|---|
| options per scenario | 1.9 (the 8-word rule dropped most) | 3.0 |
| logic | 3.24 | 3.64 |
| specific to the situation | 3.18 | 3.55 |
| natural to say | 3.40 | 3.69 |
| right style | 2.69 | 3.19 |
| respect | 4.62 | 4.91 |
| time to first suggestion p50 / max | ~1.2 s / 1.7 s | **~2.8 s / 3.3 s** |
| cost per request | ~0.01 US cent | **~0.23 US cent (~0.08 per suggestion)** |

**The 2.5 s target is NOT met** (p50 2.7-2.9 s, measured inside Supabase, so a phone adds more). Sonnet writes ~150 tokens (5 candidates + hooks) at ~65 tokens/s. v25 with longer hooks: 2.8-3.0 s. Options if it must be under 2.5 s: write 4 candidates, drop the hook column (~-0.5 s, less grounding), or send an early provisional suggestion after the first candidate. Not done without your say.
Ten examples (before -> after, average score of the line):
- P1 fest, flirtig, "hon bjöd in halva klassen": "Då vet jag vem som ska laga maten." (2.6) | "Halva klassen på en fest, respekt." (3.0) -> "Så du är en av de utvalda halvorna?" (3.6) | "Då får vi leva på charm resten av kvällen." (4.2) | "Pluggade ni, eller var det mest snacks?" (3.0)
- P2 karaoke, rolig: "Ingen kan sjunga alls, bara några är modiga." (3.4) -> "Vilken låt har du tänkt döda?" (4.0) | "Välj något alla kan skrika med i refrängen." (3.8) | "Vem lurade dig, och vad fick den som tack?" (3.0)
- S2 anteckningar, flirtig: "Kopierade du mina anteckningar? Det är ju kärlek." (4.4) | "Perfekt kopia, men hoppas du förstod något?" (2.8) -> "Perfekt kopia? Då tar jag äran för dina betyg." (4.2) | "Så du fuskar redan, och jag är din källa?" (3.4) | "Okej, då löser vi uppgifterna ihop, på mitt sätt." (3.4)
- G2 benträning, rolig: "Tre veckor och trappan vinner fortfarande?" (3.8) | "Då är trappan din nya motståndare, säkert." (3.2) -> "Går du baklänges ner? Det brukar hjälpa lite." (3.4) | "Var det värt det, eller ångrar du allt?" (3.4) | "Hissen är din nya bästa vän då." (4.0)
- C2 kanelbulle/kardemumma, flirtig: "Kardemumma är bättre, en uppgradering alltså." (3.8) | "Tecken på vad, att du ska byta sida?" (2.6) -> "Kardemumma är kanelns coolare kusin, så det är en uppgradering." (3.4) | "Ett tecken på vad då? Jag är nyfiken." (3.6) | "Absolut, universum tycker att du ska våga mer." (3.4)
- T2 hund åt kvittot, rolig: **"Berätta mer om det." (2.4) | "Hur har din dag varit?" (2.0)** (old generic fallback) -> "Din hund hatar uppenbarligen den tröjan också." (4.2) | "Då har du en dyr tröja och en nöjd hund." (3.6) | "Hade kvittot någon smak? Typ chili eller ren panik?" (2.8)
- A1 avstannat, uppriktig: "Låter som en lugn helg, gillar du sånt?" (3.8) | "Okej, jag ger inte upp än, berätta mer." (2.6) -> "Ibland är inget särskilt den bästa sortens helg." (4.2) | "Hur ser veckan ut då, något du ser fram emot?" (3.4) | "Vad brukar du göra när du verkligen är ledig?" (3.8)
- A3 avstannat, flirtig: "Vad är det bästa du ätit här?" (3.6) | "Okej, vilket ställe borde vi ha valt istället?" (3.6) -> "Vad beställer du här när du vill imponera?" (3.8) | "Mysigt brukar betyda att man stannar längre än planerat." (4.0) | "Bästa platsen här, om du fick välja?" (3.2)
- N1 nej, flirtig: "Okej, respekterar det." (3.6) | "Då får vi väl prata här istället." (3.0; keeps pushing) -> "Inga problem. Ha en riktigt fin kväll!" (3.8) | "Helt okej, tack för att du sa det rakt." (4.2) | "Det är lugnt, jag gillar att folk är ärliga." (3.6)
- N2 obekväm, rolig: "Okej, då byter vi ämne helt." (3.4) | "Självklart, vi kan prata om något annat." (3.4) -> "Förlåt, det var för mycket. Jag backar." (3.6) | "Tack för att du sa till. Jag respekterar det." (3.0) | "Okej, vi släpper det. Förlåt för det där." (3.6)

## Limits and things to know
- Judge = another model (Opus 5.5), strict but not human; 30 scenarios is a smoke set. Scores around 3.5 mean "decent", not "great": jokes still miss sometimes (e.g. C2 "universum tycker att du ska våga mer" is generic).
- Incident: `answer` v26 was live and broken for some minutes (a deploy by a helper agent was truncated); v27 is the complete file and passed the whole run. Deploys are done by pasting the 86 KB bundle by hand, which is error-prone; a CLI/token-based deploy would be safer.
- The Anthropic account has a **limit on concurrent requests** (we hit 429 when several calls overlapped during testing); production traffic of Sonnet calls in parallel could hit it. Worth raising the limit before many users.
- Webtest still not hosted; iPhone/AirPods untested.
