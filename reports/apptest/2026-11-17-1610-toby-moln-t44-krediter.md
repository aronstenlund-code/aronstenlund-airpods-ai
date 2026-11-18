# T44: krediter per tecken i appen (A131, D213), Toby (moln)

Allt i Simulator, inte på enhet. Falskt ljud (LUMEN_TEST_HEADER=1), 0 ElevenLabs. Testet är T36 (`SayFlowTests.swift`), som nu läser kapseln och kostnadsraden både som frågor och som krediter.

## Resultat (44107271098, main efter A131, grön i alla 8 delar)
| Det som ska synas (Angela Fable, A131) | Sett | |
|---|---|---|
| Kapseln "N krediter kvar" (hårt mellanslag) | "1 500 krediter kvar" | ✅ verifierat i Simulator |
| "Kostar N krediter. Upprepningar kostar inget." under fältet | "Kostar 78 krediter …", "Kostar 234 krediter …" | ✅ verifierat i Simulator |
| Kapseln går ner med textens tecken efter en spelad ny text | **1500 → 1500** efter tre startade texter | ❌ inte sett, frågan ligger hos Kevin (kevin.md) |
| Ett nekat Spela (för få krediter) visar serverns rad och skapar inget nytt prov | – | **otestat**: testkontot har 1500 krediter, och det falska ljudet kan inte ta slut på dem |
| Ett borttaget prov kommer inte tillbaka (Fables rättning) | 2 → 1 på Start efter 10 s | ✅ verifierat i Simulator (44093016960, 44107271098) |

## Testfel som rättades på vägen
- Spelaren med en tickande tid syntes inte för en elementsökning inom 30 s. Testet läser nu skärmträdet i upp till 60 s (5f0debde).

## Nästa
- Kevins svar om krediterna med x-earmind-test.
- Ett nekat Spela kräver ett testkonto med få krediter eller ett testläge för det på servern (Kevin). Till dess är det otestat.

## Tillägg 2026-11-18 09:35 (Toby (moln)): kapseln går ner med en ny text
Kevin (16:40): befintligt ljud är gratis (D213), och T36:s text var densamma varje körning, så den kostade 0. Nu får texten en egen del per körning ("Körning N."). T36 44262990714 på toby/t44: kapseln 1 500 före första Spela och 1 400 efter Stoppa. Visningen är kort ("1,4k"), så skillnaden syns i hundratal. Krediterna dras alltså med x-earmind-test, och T44 är klar. Ett nekat Spela (för få krediter) är fortfarande otestat, eftersom testkontot har 1 500. **Verifierat i Simulator**, inte på enhet.
