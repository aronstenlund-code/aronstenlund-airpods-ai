# O90 (D238): granskarens väg live med ett nytt anonymt konto, Oscar (moln)

**Resultat:**
- **Nej, krediterna räcker inte för hela vägen utan köp.** Ett nytt konto får **1 500**. Välkomstens 5 000 ges inte utan Team ID (503 `attest_unconfigured`).
- Säg i AirPods, Hur ska det låta? och en katalogröst kostade tillsammans **634**. Det räcker.
- Men **ett prov från text med 12 frågor kostar 5 882**. Det är mer än 1 500, och servern svarade 402 "Det här kostar 5 882 krediter. Du har 1 259 kvar."
- **Även med 1 500 + 5 000 = 6 500 räcker det precis inte.** Hela vägen kostade 6 516 här, alltså 16 för mycket. Med appens standard, 20 frågor, blir provet cirka 9 800.
- Att spela om kostar 0. Radera konto fungerar, och därefter svarar kontot 401 `account_deleted`.
- **Inget i den text användaren ser nämner testläge, admin eller interna namn.** Modellnamn finns bara i tekniska fält (`usage.*.model`, `voice_model`).

Körning: Actions 44570019926, 16:47–16:49 UTC, main 616077fc. Testkonto med tyst testljud, **0 ElevenLabs**, inga köp. Claude kostade cirka 0,05 USD för provet och Haiku användes för stil och röstval.

## Krediter per steg (**verifierat live**, serverns egna tal)
Först förhandsvisades varje steg med `action: "cost"` (drar inget, kvoten var oförändrad 1 500). Sedan gjordes `save` med `defer_audio` och `start` i granskarens ordning, och kvoten lästes efter varje steg.

| Steg | Text | Förhandsvisat (`cost`) | Draget | Kvar | Spela om (`start` igen) |
|---|---|---|---|---|---|
| Nytt konto | – | – | – | **1 500** (`monthly_free` 1 500, `gift` 0, `purchased` 0) | – |
| Välkomsten (App Attest) | – | – | **503** `attest_unconfigured` "Välkomstkrediterna är inte på än." | 1 500 | – |
| Säg i AirPods | en påminnelse, 241 tecken | 241 | 241 | 1 259 | 0 |
| Prov från text, 12 frågor | ekosystem, 1 519 tecken; 12 frågor med långa svar (cirka 90 ord) | **5 882** (`enough: false`) | **402** `quota_exceeded`, inget sparat | 1 259 | – |
| Hur ska det låta? | 210 tecken, "Lugnt och tydligt, som en lärare" | 210 | 210 | 1 049 | 0 |
| Röst ur katalogen | 183 tecken, Jonas (inte review) | 183 | 183 | 866 | 0 |
| Radera konto | – | – | 200 `deleted: true`, 3 ljudfiler borta | – | `quota` därefter: **401** `account_deleted` "Kontot finns inte längre." |

- **Förhandsvisningen stämde med det som drogs**, i 3 av 3 steg som gick igenom.
- **Spela om är gratis:** ett andra `start` gav `audio.cost: 0`, och kvoten ändrades inte. Tio minuters upprepning kostar alltså bara textens tecken en gång.
- **Katalogen:** 14 röster, 0 med review. AI-valet för stilen gav Karin vid förhandsvisningen och en annan röst (`kpTdKf…`) vid sparandet, båda med en `voice_reason` på svenska.
- **Provet:** `exam drill` och `drill_answers` gav 12 frågor och drog inga krediter (kvoten var 1 500 efteråt). Krediterna dras först när provet sparas, och då kom 402. Genereringen kostade alltså Claude-pengar för ett prov som inte gick att spara.

## Räcker det? (**verifierat live** för 1 500; 6 500 är räknat på samma tal)
| Krediter | Säg + stil + röst (634) | + prov 12 frågor (5 882) = 6 516 | Prov med appens standard, 20 frågor (cirka 9 800) |
|---|---|---|---|
| 1 500 (utan Team ID, i dag) | räcker | **räcker inte** | räcker inte |
| 6 500 (med välkomsten) | räcker | **räcker inte, 16 för lite** (provet först ger 618 kvar, och sista steget behöver 634) | räcker inte |

- 20 frågor är `Drill.defaultQuestionCount = 20` och 90 ord är `defaultLongWords = 90` i appen. Siffran cirka 9 800 är räknad som 5 882 / 12 × 20 och är en **untested assumption** (beror på texten).
- Kostnaden domineras av de långa svaren: 12 frågor gav i snitt cirka 490 tecken per fråga och svar.

## Välkomsten utan Team ID (**verifierat live** och **verifierat i kod**)
- Servern svarar `attest_challenge` 200, men `welcome` 503 `attest_unconfigured` "Välkomstkrediterna är inte på än." Kontot får inga krediter (`gift.welcome: 0`).
- **Appen visar inte meddelandet** (`Purchases.swift` rad 524–530 loggar bara "Welcome: refused"). Granskaren ser alltså bara 1 500 och ingen förklaring. Butiksbild 8 och beskrivningen säger dock "5 000 krediter att börja med" (`docs/appstore/README.md` rad 22 och 66), och det stämmer inte utan Team ID.
- **Risk (verifierat i kod, inte på enhet):** appen försöker högst **3 gånger** (`maxWelcomeTries = 3`, rad 324), och varje 503 räknas som ett försök (rad 528).
  - Utmaningen ges även utan Team ID, så appen kommer hela vägen till `welcome` vid varje start.
  - Efter tre starter utan Team ID frågar appen aldrig mer. Den som installerar före Team ID, till exempel granskaren, Aron eller TestFlight-testare, får då aldrig välkomstkrediterna, inte heller när Team ID väl är satt.
  - Förslag till Kevin: `attest_challenge` svarar 503 när `appId` saknas, så att appen går tillbaka direkt (rad 506–509) utan att räkna försöket. Förslag till Angela: en 503 räknas inte som ett försök.

## Ord i svaren (**verifierat live**, alla svar i körningen genomsökta)
Sökta ord: test, admin, debug, intern, QA, Oscar och teamets namn, Supabase, ElevenLabs, Haiku, Sonnet, Claude, Anthropic, Lumen och interna nummer (D/K/O/A + siffror). Sökningen gällde alla strängar utom id, url och hashar.

38 träffar, ingen i text som användaren ser:

| Fält | Värde | Bedömning |
|---|---|---|
| `error.code` | `attest_unconfigured` ("test" i "attest") | felkod, visas inte; texten är "Välkomstkrediterna är inte på än." |
| `usage.plan/notes/shorten/final_check/answers.model` (exam) | `claude-haiku-5-5`, `claude-sonnet-5-5` | tekniskt fält, visas inte (appens kod läser inte `usage.*.model`, untested assumption) |
| `drill.voice_model`, `audio.model` | `eleven_multilingual_v2`, `eleven_v3` | tekniskt fält; appen sparar det som `voiceModel` (DrillCloud rad 698) men visar det inte enligt namnet (untested assumption) |
| `drill.title` | "… (QA)" | mina egna titlar, inget från servern |

- Inga fältnamn innehåller test, admin eller debug.
- Felmeddelanden, `voice_reason`, frågor och svar är vanlig svenska utan interna namn.
- **Inte provat:** att ett riktigt konto utan testmärkning får samma svar. Testkontot får tyst testljud, men inga synliga testord kom i svaren.

## Fynd
**Till Deangelo/Aron (beslut, hög inför inskickningen):** granskaren kan inte göra ett prov från text utan köp. Det går inte heller med välkomsten. Ett prov på 12 frågor kostar 5 882 och ett på 20 cirka 9 800.
- (a) Sätt Team ID **och** låt granskarens väg börja med prov från text med få frågor.
- (b) Sätt testkontot för granskningen (Apples demo-konto) till fler krediter.
- (c) Räkna provets långa svar billigare, eller sänk standarden från 20 frågor.
- (d) Skriv i granskningsanteckningarna att provet kräver ett köp och hur sandlådeköpet görs.

Påståendet "5 000 krediter att börja med" i butikstexten stämmer inte förrän Team ID är satt.

**Till Kevin (medel):** `attest_challenge` bör svara 503 när `appId` saknas, så att appens tre försök inte förbrukas innan Team ID finns. Dessutom kostar genereringen Claude-pengar för ett prov som sedan inte går att spara. `exam drill` skulle kunna returnera en uppskattad kostnad (frågor × cirka 490 vid 90 ord) så att appen kan varna före genereringen.

**Till Angela (medel):** en 503 `attest_unconfigured` på `welcome` bör inte räknas som ett av de tre försöken (`Purchases.swift` rad 528). Före "Gör prov" bör appen visa vad provet ungefär kostar när krediterna inte räcker, så att granskaren inte väntar på 12–20 frågor som sedan inte kan sparas. Det senare kan redan finnas; jag har inte provat appen.

## Kvar
- Toby (T55) provar samma väg i Simulatorn.
- O91 när Kevin säger att K108 är klar.
