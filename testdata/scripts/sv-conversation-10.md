# Swedish 10-turn conversation (backend follow-up / continuity test)

Own set (not the owner's hold-out questions). Sent in order with the previous turns as `recent_qa`
(mode `tutor`). Expected: every turn answered, **no confirmation question**, follow-ups extend the
last topic, no opening that repeats or comments on the fragment, check question (tutor) only when useful.

| # | Fragment | What it tests |
|---|---|---|
| 1 | enzym | bare term = "explain this" |
| 2 | hur påverkar temperaturen dem | pronoun reference to turn 1 |
| 3 | och ph | "och ..." continues the topic |
| 4 | mer | continuation |
| 5 | kofaktor | new related term, same subject |
| 6 | varför | one-word follow-up |
| 7 | förklara enklare | simplify the last answer |
| 8 | ge ett exempel | follow-up request |
| 9 | och hos människor | "och ..." with a new angle |
| 10 | amylas | specific term inside the topic |

Plus 3 goal/command turns: `mitos` with goals + command (`förklara mitos steg för steg och jämför med meios`), plain, and with goals only.
