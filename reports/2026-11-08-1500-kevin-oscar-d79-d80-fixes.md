# Kevin: Oscar's D79/D80 points (reports/qa/2026-11-08-1330-oscar-d79-d80.md)

Date: 2026-11-08 · Assignment: Aron (chat), part 1 of 2. **Live: answer v78** (memory v22, tts v51, stt-token v43).
Deploy backend: last run `42487596587` green.

## What was built
| Oscar's point | Change | Status |
|---|---|---|
| (a) The new-session cap counts aborted calls and blocks for up to an hour | An answer the app aborts is now given back in the **new-session window** too (the network and global windows stay counted). The cap is raised from 20 to **40** answers in the first hour. A 429 from that window says **`Retry-After` ≤ 120 s** instead of "until the end of the clock hour". | verified live |
| (b) Provläge says its reading of a misheard term, or guesses the wrong subject | A new code step looks only at the **first sentence**:<br>• "Fragmentet … låter som / liknar …" and "Och jag svarar på det:" are cut.<br>• "Det låter som X, …" always becomes "X är …".<br>• "Det är / Det här är / Det verkar vara (begreppet) X, …" is rewritten to "X är …", or dropped when it says nothing else. This happens only when X is close to what was heard, so "Det är rätt." after a check question is never touched.<br>• **A first sentence that guesses** ("som du kanske menar", "jag är inte säker") **makes the whole answer silent**, rather than the wrong subject.<br>The prompt adds that two possible terms mean silence, and that the answer starts with the term itself. More meta phrases are dropped ("ingen tidigare tur", "svårt att avgöra", "så jag svarar inte"). | verified live, see results |
| (c) Interview: remarks about missing facts, and an empty answer | "Jag har inget namn angivet …", "Jag vill hellre prata om … än om mina år", "Jag är inte så noga med siffror", "Hur gammal jag är spelar inte …" and "Jag tänker inte fokusera på min ålder …" are dropped. **An interview answer that ends up empty is regenerated once**, with a note to answer directly about what the user brings to the role. | verified live |
| (d) `/memory` stores address and debts | Never kept: home address, debts, loans, credit, debt collection, salary, income, money, CSN, bank account, personal identity number, password (Swedish and English words). This is enforced in the server (prompt and code filter) and in the app's `SensitiveFilter` (`Lumen/Core/History/MemoryExtraction.swift`, same words). English first-person turns ("I have a chemistry exam on Friday") are now read; items are always written in Swedish. | verified live |
| (e) README about `q`/`a` | Corrected: `q`/`a` work only inside `turn`, not at the top level. The README also now says 40 per hour, aborted calls given back, Retry-After ≤ 120 s, and the money rule. | done |
| (f) `answer vN` in STATUS | Every Kevin line in STATUS now names the live version (here **v78**). | done |
| Oscar's feedback test row | `oscar-qa-d80` is marked `processed` (13:49 UTC); the hourly purge deletes it at minute 41. | marked; deletion is checked in part 2 |

## Test results
- **Unit tests** (Node shim): 259 pass (`auth_test` fails only under the shim; CI green).
- **New session live** (`answer` after the change): **30 aborted calls 2 s apart, then a complete answer: no 429**. In
  Oscar's test, number 21 got 429 with Retry-After 2 563 s.
- **Provläge live**, 14 misheard terms in the last run: "fo to syn tesen", "ko sinus satsen", "den mo kra tin",
  "ren ässans en", "ex po nentiell funktion", "gra vi ta tions kraften" and "pe ri o diska syste met", each twice.
  - **Before the last fixes, 3 leaks:** "Det låter som perifera nervsystemet, som du kanske menar …", "Det verkar vara
    en fråga om fotosyntesen, men jag är inte säker …" and "Fragmentet … liknar …".
  - **After the fixes:** most answers now start with the term ("Kosinussatsen är …", "Fotosyntesen är …").
    "gra vi ta tions kraften" was silent once.
  - **Two misses I saw by reading:**
    - "Eftersom ingen tidigare tur finns är det svårt att avgöra." and "Det verkar vara begreppet demokratin, så här är
      det kort: …". Both are now covered by the last commit and unit-tested, **but there is no live run after it**.
    - "Perifera system är de delar av nervsystemet …" for "pe ri o diska syste met": the wrong subject without any guess
      word, once out of two. It can only be stopped in the prompt, and that does not hold every time. **Still a known
      error.**
- **Interview live:** "vad heter du" ×2 and "hur gammal är du" ×3 gave answers in jag-form, with no remark about
  missing facts and no empty answer. Example: "Det viktigaste jag tar med mig till jobbet är att jag är snabb …".
  The answers repeat the same qualities (Oscar's observation).
- **Memory live:**
  - "jag bor på Storgatan 5 i Umeå" and "jag har skulder på 50 000 kronor": nothing kept.
  - "I have a chemistry exam on Friday" became "Har prov i kemi fredag 13 november 2026.".
- **Time to first token** (server median, 6 calls each, after the changes):

  | Mode | ms | Earlier today (ms) |
  |---|---:|---|
  | text | 608 | 599–662 |
  | Provläge | 806 | 767–887 |
  | Auto | 929 | 1 029–1 119 |
  | push_to_talk | 721 | 557–747 |
  | interview | 726 | 684–827 |

  **Not longer.**
- **Not tested on a device.**

## Cost
About **0.016 USD**: live checks about 0.007, time to first token about 0.009.

## Known limits and risks
- The new-session cap is still a cap. 40 answers in 10 minutes plus not-aborted preliminary answers can still be
  reached in a very fast Rizz session; Retry-After is now short.
- The Provläge filter only looks at the first sentence and only at known shapes; a wrong subject stated with
  confidence still gets through.
- The app's `SensitiveFilter` change is Swift; it is tested only through the iOS CI build (no device).

## Next session
- Kevin: part 2 (D86 backend).
- Oscar: rerun the new-session cap with aborted calls (Rizz rhythm) and the Provläge mishearing list on answer v78.
