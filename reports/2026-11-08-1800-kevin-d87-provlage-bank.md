# Kevin: D87, Provläge test bank, Haiku vs Sonnet, answer structure

Date: 2026-11-08 · Assignment: Aron (chat), owner decision D87. Deploy backend: last run `42491906157` **green**.
Live: **answer v87**, new function **provlage-eval** v5 (answers on a chosen model + grading, behind the user JWT and daily caps).

## Headline
- **Target not reached.** The share where the first answer is enough is **70–72 % on Haiku** and **80–85 % on
  Sonnet**, against the target of ≥ 90 %.
- **Sonnet is clearly better**, but it is **0.3 s slower to the first word (p50) and about 22 times more expensive
  per answer**.
- **I have not switched Provläge to Sonnet.** That would break "svarstiden får inte bli märkbart längre" and is a
  big cost decision. Provläge stays on Haiku. Sonnet can be turned on with one setting (`TUTOR_MODEL`), see "Decision
  for Aron".

## What was built
| # | Change | Status |
|---|---|---|
| 1 | **Test bank, `scripts/provlage-bank.json`** (built by `scripts/provlage-bank.py`): **179 spoken cases** for Åk 7–9 and Gymnasiet 1–3. Subjects: NO (biologi, kemi, fysik), SO (historia, samhälle, geografi, religion), Språk (svenska, engelska) and Matte. By kind: 80 bare terms, 10 half sentences, 32 follow-ups with earlier turns ("och cellandning då?", "varför då?", "och den andra?", "räkna ut det"), 23 misheard subject words ("perifera systemet" in kemi), 24 exam questions, 6 short profiles and 4 cases with the exam tomorrow. All are my own cases; none is a prompt example. | done |
| 1 | **Grading:** `POST /provlage-eval` `grade` scores every answer 0/1 with a stronger model on five criteria: correct, A level for the grade, sufficient without a follow-up, natural to hear, and length per the profile. **The main measure is "first answer enough" = correct AND sufficient.** The comparison used Claude Opus 5.5 as judge, so neither candidate grades itself; the nightly run uses Sonnet 5.5. The runner is `scripts/provlage-eval.py`. | done |
| 2 | **Comparison:** `POST /provlage-eval` `answer` runs the same `/answer` code with Provläge on Haiku 5.5 or Sonnet 5.5. Sonnet runs without thinking (`between_tools`), because thinking would cost time. Production can switch with the new setting `TUTOR_MODEL`. | measured |
| 3 | **Answer structure in Provläge** (the tutor prompt): the first sentence answers what the student means, and a bare key word means "explain at exam level". Then why or how, one concrete example, and, when it helps, a last sentence "På provet …" on what to write. The answer foresees the natural next question and answers it briefly. All of it stays within the length: 4–6 sentences by default, or the profile's length. When the meaning is unclear, it chooses the most likely reading within the exam's subject and never asks back. | deployed |
| 4 | **Context:** the last three turns in `recent_qa`, `<active_topic>` and the profile already come with every call. The prompt now says that follow-ups ("och X då?", a pronoun about the last answer) are read from them. With an exam profile, a guessed reading only drops the guess sentence and keeps the answer. Before, the whole answer became silent, which gave empty answers for "gra vi ta tion", "ma kt del ning" and "par tes läran". | deployed |
| 5 | **Nightly:** `.github/workflows/nightly-eval.yml` runs the whole bank every night (`--model haiku --judge sonnet`) and commits `reports/eval/provlage-<date>-haiku.md/.json`. | done (first run tonight) |

## Results (Claude Opus 5.5 as judge)
| Run | Cases | First answer enough | Correct | A level | Sufficient | Natural | Length | First word p50 / p90 (server ms) | Per answer (USD) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Haiku, old prompt (baseline) | 179 | **72.6 %** | 83.8 % | 89.4 % | 83.2 % | 77.1 % | 70.4 % | 846 / 1 049 | 0.00031 |
| Haiku, structure 1 | 179 | 67.0 % | 81.0 % | 86.0 % | 80.4 % | 62.6 % | 67.6 % | 842 / 1 020 | 0.00033 |
| Sonnet, structure 1 | 179 | **84.9 %** | 88.8 % | 95.0 % | 95.0 % | 60.3 % | 2.2 % | 1 133 / 1 524 | 0.0076 |
| Haiku, structure 2 (deployed) | 60 | 70.0 % | 91.7 % | 80.0 % | 73.3 % | 80.0 % | 80.0 % | 852 / 1 076 | 0.00034 |
| Sonnet, structure 2 | 60 | **80.0 %** | 91.7 % | 88.3 % | 86.7 % | 93.3 % | 48.3 % | 1 168 / 1 517 | 0.0077 |

On the same 60 cases (every third case), the earlier runs gave:

| Run | First answer enough |
|---|---:|
| Haiku baseline | 71.7 % |
| Haiku, structure 1 | 71.7 % |
| Sonnet, structure 1 | 83.3 % |

The differences between Haiku's prompt versions are within the noise of 60 cases (±6 points).

- **Structure 1** asked for why, an example, an exam sentence and the follow-up, but also kept "five to eight
  sentences". Both models got longer, and the judge counted "Ett A-svar …" as meta talk. Sonnet was almost never
  within the length.
- **Structure 2** keeps everything within 4–6 sentences and uses "På provet …". This brought natural speech up a lot
  (Sonnet 60 → 93 %, Haiku 63 → 80 %) and length up (Haiku 80 %, Sonnet 48 %).
- **Haiku's misses are mostly "sufficient" and "A level"**: a key part is left out (antikroppar in immunförsvaret, the
  four criteria in källkritik, the shell model of the atom). Then come small factual errors ("pepparmal" for
  björkmätare, Wienkongressen dated after Waterloo) and odd Swedish grammar now and then.
- **Sonnet's misses** are mostly length (too long) and a few factual errors.
- **First sound:** these are server times to the first token. TTS adds the same 0.2–0.4 s for both models. The app's
  answer-ahead (D80) starts the call during the pause, which hides part of the difference, but Sonnet is still about
  **0.3 s later at p50 and 0.5 s at p90**.
- **Cost per answer with caching:** Haiku about **0.00034 USD**, Sonnet about **0.0077 USD**. At 200 Provläge answers
  per student and day, that is about 0.07 USD with Haiku against 1.5 USD with Sonnet.
- All results: `reports/eval/provlage-2026-11-08-*.md/.json`.

## Decision for Aron
- **My recommendation:** stay on Haiku now, and keep improving it against the bank: what to cover per kind of term,
  shorter sentences, and the profile's terms from D84.
- **Sonnet** gives about +10 points but costs 0.3 s and about 22 times as much. If you want it anyway, I set
  `TUTOR_MODEL=claude-sonnet-5-5` with the Supabase tool (no deploy needed), and the nightly run switches to Sonnet
  answers.

## Cost
- **D87 in total: about 8.4 USD.** Almost all of it is the Opus judge on 2 × 179 + 179 + 2 × 60 graded answers
  (about 0.009 USD per grade), plus 1.8 USD of Sonnet answers.
- **The nightly bank:** 179 Haiku answers (about 0.06 USD) plus Sonnet grading (about 0.85 USD) is **about 0.9 USD
  per night**. With `--every 3` (60 cases) it is about 0.3 USD per night. Say if I should reduce it.

## Known limits and risks
- The judge is a model too. Opus marks "sufficient" and "A level" strictly and in its own way.
- 60-case samples are noisy (±6 points).
- The nightly judge (Sonnet) is not the comparison judge (Opus), so nightly numbers are not directly comparable with
  the table above.
- `provlage-eval` is behind the user JWT and capped: 700 answers and 700 grades per user and day, 2 500 / 1 500 global,
  and at most 800 Opus grades per day. Someone with an anonymous session could spend up to those caps.
- Supabase's per-IP limit on anonymous sign-ins stopped local runs twice. The runner now keeps refresh tokens
  (`--tokens FILE`).
- **Not tested on a device.**

## Next session
- Aron: choose Haiku or Sonnet for Provläge, and say whether the nightly bank should be full or `--every 3`.
- Kevin: D88 (audio and the whole chain without a phone), then the queue.
