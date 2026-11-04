# Kevin — D43 Rizzläge backend + testsidans panel (2026-11-04)

## Done
- `/answer`: `persona:"social"` + `social{style,trigger,transcript,interests,profile}` -> one SSE `suggestions` event (2-3 Swedish one-liners, best first, <= 8 words), then `done`. Contract in `backend/README.md`; decision D45.
- Prompt follows the STYLE NOTE (witty, specific, hook, per-style tone; respectful/honest; decline signal). Code filter + safe fallbacks. Deployed: `answer` v17.
- `backend/webtest` Rizzläge panel (styles, "den andra sa…" + mic, stall/opener buttons, best option spoken, all shown). 121 unit + e2e tests green; panel tested with mock backend in headless Chromium.

## Measured (live, Haiku 5.5, 12 own scenarios x 2, client inside Supabase)
- Model first token ~620 ms; full 3 lines ~1.06 s. `suggestions` event (after 2 clean lines): **p50 1 295 ms, p90 1 529 ms; warm p50 ~1 066 ms (n=5)**. **Target < 900 ms NOT met** for the array; most requests hit fresh isolates.
- Words: asked "eight" -> 25/36 lines over eight; asked "six" -> 6/36 over; over-long lines are dropped.
- Quality read by hand: mostly punchy and specific; some options still a bit wordy or stiff. Decline cases all accepted kindly. **Not judged by real 17-25 year olds.**
## Limits / risks
- Not tested on device; panel not in real Safari/AirPods; testsidan still not hosted (Vercel 200-project limit).
- Hold-out/own examples only. The benches (`bench`) run with an embedded key in a deployed temp function — to be removed.
## Next
- If < 900 ms matters: add an early `best` event after the first clean line (~800 ms). D44 waits until Friday (owner).
