# Kevin (moln) – O103 (Q1, Q2, Q4, verktyget) och K123: kortare väg före modellen

**Datum:** 2026-11-27 00:00. **Uppdrag:** Deangelo 23:38.
**Regler:** inga riktiga modellanrop, 0 ElevenLabs. **Svit:** 897/897.
**Driftsatt:** deploy 382 (O103) och 383 (K123).

## O103 (Oscars nya fall)

| Fynd | Gjort | Status |
|---|---|---|
| **Q1 medel:** webbregeln sa "Answer ONLY in Swedish" också med språk en | Se punktlistan under tabellen. | verifierat i test och K122-återspelning |
| **Q2:** "1066" lästes "tusen sextiosex" | Ett år 1001–1099 läses "tiohundrasextiosex" i ett datum, efter "år" eller "året" och efter ett månadsnamn. "1066 kr" och "1066 personer" läses som förut ("tusen sextiosex"). "år 1000" är "år tusen". | verifierat i test |
| **Q4:** "källa:  domain " i webbens omförsöksnot | Rättat redan med P3 (`noteText`), nu ‹domain›. | verifierat i test |
| **Verktyget:** felmeddelanden på svenska med x-earmind-lang en | K122 kör nu handlern i samma omslag som `index.ts` (`withCors`, språket). Egna anrop (`--endpoint`) skriver sina promptar i `--out`, inte bland bankens. | verifierat i test |
| **Q3 låg:** bara svenska recept tvingas till webben | **Inte gjort.** Receptdomänerna är svenska (ica.se med flera). Ett tvingat sök för engelska recept behöver egna engelska domäner, och det är ett beslut. Det engelska receptet går nu rätt via modellens `[[SÖK]]`. | – |
| **Q5 låg:** Komprimera "about half" mot "every fact kept" | **Inte gjort.** Det ändrar svaren och behöver riktig eval. | – |

**Q1, i detalj:**
- `webPrompt(lang)` och `textPrompt(lang)`: på engelska står "Answer ONLY in English" och "The sources I found do not say."
- Filtret som tar bort engelska meningar ur webbsvar gäller bara svenska svar.
- Källan sägs "Source: X." på engelska.
- "källa:" är kvar som markör, eftersom servern klipper bort den och säger källan själv.
- Återspelningen av RQ3 ("how do I make pancakes", `[[SÖK]]`, sedan svaret) ger engelsk webbprompt och det engelska svaret, avslutat med "Source: Bbcgoodfood.", och `source` blir bbcgoodfood.com.

## K123: första svaret snabbare

### Mätt, utan modellanrop

**Lokalt** (`backend/scripts/k123-premodel.ts`, varje databasanrop simulerat till 60 ms, varm isolat; antagandet 60 ms är en untested assumption):

| Väg | Före K123 | Efter K123 |
|---|---|---|
| Vanlig fråga (tryck och prata): modellen startar | 2 ms | 2 ms |
| Provläge: modellen startar | 2–3 ms | 2 ms |
| Webbfråga: modellen startar | 65 ms | 63 ms (webbtaket, se nedan) |
| Räkning som servern svarar själv: första byte | 125 ms | 63 ms |
| Krissvar från koden: första byte | 62 ms | 0 ms |
| /exam drill: modellen startar (test, 80 ms per anrop) | 192 ms | under 150 ms (ett väntande i stället för två) |

- **Modellvägen är redan kort.** Inloggningen verifieras lokalt mot cachade nycklar (K100), gränsen per minut ligger i minnet och den delade gränsen körs samtidigt som modellen. Den första byten väntar på den delade gränsen, cirka 60 ms, men i drift tar modellens första token längre tid än så, så väntan syns inte.
- **Svaren som servern ger själv väntade på kostnadsraden.** Krissvar, räkning och kommandon gjorde `await recordUsage` (en insert i `answer_usage`) innan svaret skickades.

**Live, ur loggarna** (function_edge_logs, senaste dygnet, verifierat live):
- `/answer` 503 (modellen nekar, krediterna slut) tar p50 491 ms och p90 1,2 s. Det inkluderar Anthropics svar och går inte att dela upp.
- 400 (valideringsfel efter inloggning och kropp) tar p50 58 ms.
- Kallstart ("booted") tar 50–75 ms och sker vid ungefär var sjunde anrop.

Mer live finns inte att mäta utan modellanrop.

**Live före och efter** med `scripts/k123-live.py` (en räkning som servern svarar själv, 8 gånger): **Före** (körning 103 och 104, gamla versionen): servern p50 706 ms respektive 267 ms. Plattformen varierar mycket mellan körningar.

**Uppdelning live** (körning 105 efter deploy 384, åtta räkningar, verifierat live):

| Del | Tid |
|---|---|
| `auth_ms` | 1–174 ms (bara de första, kalla anropen) |
| `body_ms` | 1–443 ms. Det räknas från start och inkluderar alltså inloggningen; bara de första är höga. |
| **`limits_ms`** | **225–772 ms, p50 cirka 600 ms** |

Den delade gränsen (RPC `check_rate_limits`, som gör en upsert per fönster) är alltså nästan allt ett kodsvar väntar på. På modellvägen hölls också modellens första text tills gränsen hade svarat.

**Efter K123b:** LIVE_EFTER

### Ändrat

1. **`supabaseUsageSink`.** På plattformen skrivs raden i bakgrunden (`EdgeRuntime.waitUntil` håller isolatet vid liv för den), och den som anropar väntar inte. Lokalt utan EdgeRuntime väntar den som förut. Inget i funktionerna läser `answer_usage` för gränser. Det gäller alla svarsvägar i /answer (10 ställen) och /exam (3 ställen).
2. **`/exam`** läser krediterna medan gränsen kontrolleras. Det är ett databasväntande före modellen i stället för två.
3. **K123b: den delade gränsen hålls inte före första ljudet.**
   - **Kodsvar** (räkning, minnesregel, sparat svar, rapport, tidiga svar) svarar direkt. Den lokala gränsen per minut, som kontrolleras först i varje anrop, är spärren. Den delade räknas samtidigt i bakgrunden, så nästa modellsvar ser den.
   - **På modellvägen** avgör det som kommer först. Kommer gränsen först gäller den som förut, och ett nej stoppar anropet. Kommer modellens första text först går svaret ut, eftersom anropet redan är startat och betalt, och ett nej gäller från nästa anrop (loggas `answer_over_limit_after_first`).
   - Antal och priser är oförändrade. Den som är över gränsen kan få högst det svar som redan är på väg.
   - `BLOCK_ON_SHARED_LIMIT=1` (secret) ger det gamla sättet tillbaka.
   - Verifierat i test (`_shared/k123_latency_test.ts`, 899/899).

Test: `_shared/k123_latency_test.ts`.

### Kvar (inte ändrat, med skäl)

- **Webbsvar:** webbtaket (`webLimit`, ett databasanrop) kontrolleras före modellen, eftersom det avgör om webbverktygen är på. Att starta modellen spekulativt och starta om den vid nej vore att betala för anrop som sedan kastas. Ett webbsvar tar ändå flera sekunder för sökningens skull.
- **Kallstart:** 50–75 ms. Uppvärmningen finns redan (K100, `x-warm`).
- **Rösten utan provljud** lämnas enligt Deangelo (ElevenLabs får inte användas).

## Nästa

- Oscar: omtest av Q1 och Q2 med K122, och före och efter för O102-fallen.
- Riktig eval när krediterna är tillbaka: Q3, Q5 och listan i `reports/2026-11-26-2320-kevin-o100b-d239-o102.md`.
