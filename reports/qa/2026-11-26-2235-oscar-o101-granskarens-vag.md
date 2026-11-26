# O101: Apples granskares väg mot servern i dag, Oscar (moln)

**Resultat:** det granskaren gör först fungerar:
- nytt konto utan inloggning, 1 500 krediter, Säg i AirPods 10 min, gratis upprepning;
- serverns besked när modellen är nere (sv och en);
- kontroll av köp och Radera konto.

**Det som inte fungerar för en granskare i dag är Starta prov.** Med 1 500 krediter ryms inget prov alls, och modellen är dessutom nere. Det motsäger meningen i punkt 4: "the quiz screen suggests a number of questions that fits the credits".

Körning: Actions 45898461094, 21:31 UTC. Ett nytt anonymt testkonto med `user-path` (D240), så att servern räknar som för en vanlig användare. Falskt ljud, 0 ElevenLabs, 0 Claude (modellen är nere), inga riktiga köp. Påståendena kommer ur `docs/appstore/granskning.md` §3 (Ke84/Ke90).

| Punkt | Påstående | Resultat | Belägg (**verifierat live** om inget annat sägs) |
|---|---|---|---|
| intro | No sign-in is needed | **stämmer** | anonymt konto 200 |
| 4 | 1,500 free credits per month | **stämmer** | `limit` 1 500, `monthly_free` 1 500, `gift.welcome` 0, `resets` 2026-12-01 |
| 1/4 | 1,500 is enough to try Say in AirPods | **stämmer** | en kort studietext kostar 105 före och drar 105, ljudet klart, 1 395 kvar |
| 4 | Repeats and existing audio are free | **stämmer** | att starta samma igen drar 0 |
| 1 | "How should it sound?" | **går inte att prova nu** | `cost` med stil räknar 110 utan modell, men stilen görs av modellen, som är nere |
| 1 | voice sheet, previews are free | **stämmer nästan** | 19 röster, **18 har provljud**, och provljuden drar 0. En röst saknar `preview_url` (till Kevin, låg) |
| 4 | the quiz screen suggests a number of questions that fits the credits | **stämmer inte med 1 500** | 12 frågor ger 402: "An exam with 12 questions costs about 7 704 credits. You have 1 395 left, not enough for an exam (at least 3 questions)". Uppskattningen är 642 per fråga, så 3 frågor kostar 1 926, mer än 1 500 |
| 2 | Start quiz: text becomes quiz questions | **stämmer inte i dag** | också 3 frågor ger 402 före modellen, och modellen är nere (503) |
| 7 | Compress, server or phone's model | **stämmer (serverdelen)** | 503 `provider_quota` "EarMind is down for a moment. Try again later." Telefonens modell provas inte här |
| 9 | server can't answer → phone's model | **stämmer (serverdelen)** | `/answer` 503 `provider_quota` med engelsk text. Foundation Models på telefon är **[O]** (Aron) |
| 4 | Inviting a friend gives 2,000 | **går inte att prova nu** | koden skapas (`invite_credits` 2 000, högst 10 per månad), men vännens del kräver App Attest (`invite_needs_device`, O100) |
| före inskickning | Welcome (5,000) needs Team ID and App Attest | **stämmer** | `attest_challenge` 503 `attest_unconfigured` "The welcome credits are not on yet." |
| 4 | Purchases are verified on our server | **stämmer** | falskt kvitto 422 `purchase_invalid`. Sandbox-taket (S3) är **verifierat i test** |
| 5 | Delete account | **stämmer** | 200 `deleted: true`, ljudfilen borta, samma token 401 efteråt |
| 10 | Record it yourself (free) | **går inte att prova här** | ingen serverdel finns (D263); det provas i appen (Toby T58) |

## Fynd
**G1 (hög, till Deangelo, Aron och Kelly): granskaren kan inte prova Starta prov med 1 500 krediter.**
- Det minsta provet (3 frågor) uppskattas till 1 926.
- Granskningsanteckningen lovar "a number of questions that fits the credits".
- `granskning.md` säger redan "1 500 räcker för Säg men inte för ett fullt prov". Men texten till Apple säger något annat, och i dag ryms inte ens det minsta provet.
- **Före inskickning behövs ett av följande:**
  1. välkomsten på (Team ID, TILL-ARON #31);
  2. krediter till granskarens konto på servern, och en mening om det i punkt 4;
  3. Kelly ändrar punkt 4 till sanningen, till exempel: "the quiz screen shows what a quiz costs; with the free monthly credits a quiz needs more credits".
- Dessutom måste modellkrediterna finnas när granskningen sker, annars får granskaren 503 på allt som gör frågor.

**G2 (låg, till Kevin):** en av 19 röster i katalogen saknar `preview_url`, så "previews are free" går inte att prova för den.

## Inte prövat
- Appens egna skärmar: telefonens modell, Spela in själv och O97-texten i appen. Det gör Toby och Aron.
- Riktiga Sandbox-köp.
- Vännens del av inbjudan, som kräver App Attest.
