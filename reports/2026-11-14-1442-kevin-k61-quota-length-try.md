# K61: Arons svar på mina fyra frågor, D175–D178 (Kevin, 2026-11-14 14:42)

## Kort
- **D175, aldrig fler frågor än som finns kvar:** klart och **verifierat live**.
  - `/exam drill` gör högst det som finns kvar av månadens frågor och svarar med `quota` (used, limit, left, resets).
  - Finns inga kvar kommer 402 innan modellen anropas.
  - Den nya `/drill {"action":"quota"}` ger `suggest` = min(kvar, 20) till Nytt prov (A99).
- **D176, ingen ordgräns:** borttagen ur prompterna, gallringen, kontrollen, importens varningar, ChatGPT-prompten, HJALP.md och testerna.
  - Varje fråga får `voice_chars` (frågan plus långa svaret, i tecken till ElevenLabs) och `length_class` (`normal`, `longer` eller `too_long`).
  - Gränserna 800 och 1 600 står i `drill_settings` och ändras där, utan ny kod. Ingen debitering (D157).
  - **Verifierat i databasen:** alla 6 befintliga frågor är `normal` (500–645 tecken, snitt 576). Frågan i livetestet fick 497, `normal`.
- **D177, try räknas en gång:** klart och **verifierat live**. Prova gav 3 frågor och 3 räknades. När en av dem sparades blev det `generated_questions: 0` och `already_counted: 1`, och kvoten var kvar på 3.
- **D178, gammalt ljud raderas aldrig:** inget är byggt. Ingen `last_played_at` och ingen raderingsregel. Morgonrapporten (K59) är kvar.

## Tekniskt
- **Migration** `20261114140000_drill_length_try_credits.sql`, körd via MCP:
  - kolumnerna `drill_items.voice_chars` och `drill_items.length_class`
  - inställningarna `length_normal_max = 800` och `length_longer_max = 1600` i `drill_settings`
  - tabellen `drill_try_credits (user_id, question_key)`, bara för tjänstenyckeln
- **`drill/length.ts`:** `lengthClass`, `lengthLimits` (läser drill_settings, med reservvärden) och `questionKey`, där versaler, mellanslag och skiljetecken inte spelar roll.
- **`/exam` (D175):**
  - Läser kvoten utan att räkna (`use_drill_quota` med n = 0). Frågorna räknas som förut när ljudet görs i `/drill save`.
  - Ett `_max_questions` från appen ignoreras. Servern sätter det själv.
- **Frågekontrollen (D176):** den får aldrig fylla ut en fråga. Högst två ord fler tillåts, och bara när tecken skrivs ut som ord. Det är inte en ordgräns, utan ett skydd mot utfyllnad.
- **Kontraktet** finns i `backend/README.md`, avsnittet "K61".

## Live (`k61live` i scratchpad, nytt konto)

| Steg | Resultat |
|---|---|
| `quota` | used 0, limit 15, left 15, suggest 15 |
| `help try` | 3 frågor, quota used 3 |
| `drill save` med 1 av try-frågorna | generated_questions 0, already_counted 1, voice_chars 497, length_class normal |
| `quota` efter save | used 3, left 12 |
| `exam drill` med questions 20 på en kort text | 4 frågor (materialet räckte), quota.left 12 |

Testprovet togs bort efteråt. Taket med få kvar och 402 med 0 kvar är **verifierade i test** (`exam/drill_test.ts`), inte live, eftersom kvoten bara kan ätas upp genom att göra ljud.

## Tester och kostnad
- **Tester:** `deno task test` ger 599 gröna, varav 4 nya för K61. `check` är ren. Tre tester uppdaterades: de krävde högst 8 eller 5 ord.
- **Kostnad Claude:** cirka 0,04 USD.
- **Kostnad ElevenLabs:** cirka 500 tecken, motsvarande cirka 200 krediter, för en fråga i livetestet av D177.

## Kvar och risker
- **R3-mätningarna:** `scripts/k45-measure.py` och `scripts/live-eval.py` mäter fortfarande ord per fråga som statistik. Det är ingen gräns längre, och Oscar kan sluta använda R3 som krav.
- **Angela (A99):** kan använda `quota.suggest` och visa `length_class`.
