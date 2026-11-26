# K121: lägre modellkostnad per svar

Kevin (moln), 2026-11-26.

- **Inga modellanrop** och **0 ElevenLabs**. Mätningen läste bara `answer_usage` med tjänstenyckeln (`scripts/k121-usage.py`, kevin-live 45780172775).
- **Tester:** **860/860**.

## 1. Vad varje åtgärd kostade (1–21 november, uppskattat av servern)

**Totalt $95,54**: riktiga användare $84,05 och testtrafik $11,48 (12 %). Det stämmer med att 100 USD tog slut på cirka två veckor.

| Åtgärd och modell | Anrop | USD | USD/anrop | In / ut tokens per anrop | Andel |
|---|---:|---:|---:|---|---:|
| `/answer` **Sonnet 5.5** (Provläge, rankfrågor, rizz, demo, sök) | 7 060 | 57,40 | 0,0088 | 7 209 / 247 | 60 % |
| `exam drill_answers` **Sonnet 5.5** | 233 | 11,53 | 0,0495 | 7 943 / 3 360 | 12 % |
| `/answer` test, Sonnet | 1 156 | 8,54 | 0,0100 | 6 767 / 252 | 9 % |
| `/answer` Haiku 5.5 | 13 604 | 8,24 | 0,0006 | 4 999 / 186 | 9 % |
| Scribe (lyssning) | 513 | 2,56 | 0,0050 | – | 3 % |
| `exam drill_answers` test, Sonnet | 99 | 2,44 | 0,0246 | – | 3 % |
| `exam drill` (frågorna), Sonnet och Haiku | 1 454 | 2,75 | – | – | 3 % |
| help (Haiku) | 1 151 | 0,62 | 0,0005 | 5 038 / 65 | 1 % |
| Allt annat (kristester, minne, studiekort, betyg, Komprimera …) | – | < 0,5 | – | – | < 1 % |

- **Provläge på Sonnet är posten som kostar** ("tutor | övrigt": 5 789 anrop, $37,68, $0,0065 per anrop).
- **Systemprompten cachas redan.** Den är cirka 5 500 tokens, och $0,0065 per anrop motsvarar en cachad systemprompt plus cirka 1 700 ocachade tokens (historik och frågan) och cirka 250 tokens ut.
- **Kostnaden sitter alltså i modellvalet** (Sonnet kostar 20 gånger mer än Haiku) och i den del av texten som inte kan cachas. Den sitter inte i cachen.
- **Kristesterna (O17 och D256) går redan på Haiku** och kostar nästan inget. Där finns inget att spara.
- **Uppskattningen var lite för hög för Sonnet:** cacheläsningar räknades som 0,1 gånger priset, men Sonnet 5.5 tar 0,05 (rättat, punkt 2c). Den verkliga Sonnet-kostnaden var några procent lägre än tabellen.

## 2. Byggt (bakom flagga, eller bevisat oförändrat)

**a. `DRILL_ANSWER_MODEL`** (ny, saknas = Sonnet som förut)
- Provets svar går på den modell flaggan anger, och priset tas från modellen (`_shared/prices.ts`).
- Saknas flaggan blir konfigurationen exakt `DEFAULT_DRILL_CONFIG`; det är testat.

**b. Modellvalet i testhuvudet når nu Provläge och provets svar**
- `x-earmind-test: … model-haiku` (K104) gällde förut bara sökta svar.
- Nu kör det också Provläge (och rankfrågor och demon) och `drill_answers`/`drill` på Haiku, prissatt som Haiku. Det gäller bara anrop med testhuvudet.
- Produktionen är oförändrad (testat). Den som sätter huvudet själv får en billigare modell, aldrig en dyrare.
- Provlägets egen flagga `TUTOR_MODEL` fanns redan (saknas = Sonnet).

**c. Kostnadsuppskattningen** räknar cacheläsning per modell (0,05 på Sonnet 5.5, 0,1 på Haiku 5.5). Svaren påverkas inte.

**d. `testModelPick`** ligger nu i `_shared/testmode.ts`, så att /exam inte drar in hela answer-modulen.

**Driftsatt:** allt ovan. Med flaggorna osatta och utan testhuvud är anropen byte för byte som förut (testat), så **ingen användare får andra svar**.

## 3. Uppskattat före och efter (samma trafik som 1–21 november, riktiga användare)

| Steg | Provläge m.fl. (Sonnet-svar) | Provets svar | Totalt riktiga | 100 USD räcker |
|---|---:|---:|---:|---|
| Före (i dag) | $57,4 | $11,5 | $84 | cirka 2,5 veckor |
| `TUTOR_MODEL=claude-haiku-5-5` | cirka $3,3 | $11,5 | cirka $30 | cirka 7 veckor |
| plus `DRILL_ANSWER_MODEL=claude-haiku-5-5` | cirka $3,3 | cirka $0,6 | cirka $19 | cirka 10 veckor |

- Beräkningen: samma tokens till Haikus pris ($0,10/$0,50, cache 0,1).
- **Båda byter modell och ändrar alltså svaren.** De sätts bara efter Oscars live-eval (punkt 5) och Deangelos ja.
- Flaggorna sätts som hemligheter i Supabase (Edge Functions › Secrets). Agenterna kan göra det; Aron behöver inte göra något.

## 4. Undersökt men inte byggt

- **Cache för historiken (`recent_qa`):** appen skickar ett glidande fönster, där den äldsta frågan faller bort. Prefixet ändras då varje gång, så historiken kan inte cachas utan att svarens indata ändras.
- **Kortare systemprompter:** Provlägets prompt (cirka 5 500 tokens) läses redan från cachen för $0,10 per miljon tokens, cirka $0,0006 per anrop. Att korta den sparar högst cirka 10 % av en Provläges-fråga och ändrar svaren. Det lönar sig inte före modellvalet.
- **Tak för `max_tokens`:** Provläget ger i snitt 247 tokens med taket 800, och provets svar är själva produkten. Ett lägre tak skulle bara klippa svar.
- **Testtrafiken (12 %):** nattens eval och QA går på riktig modell. Att köra evalen varannan natt, eller bara på ändrade delar, sparar cirka $5 på två veckor. Det är Deangelos och Oscars avvägning.

## 5. Till Oscar: live-eval när krediterna är tillbaka

**Kör samma material två gånger, utan och med `model-haiku` i testhuvudet**, och jämför:

1. **Provläge (tutor):** hans Provläges-eval (provlage-eval/O79-frågorna).
   - Rätt svar och "förklarar varför".
   - Längd i ord.
   - Kontrollfrågornas kvalitet.
   - Krismarkörer (`done.crisis_marker`).
   - Matte och ordproblem, där Sonnet tänker vid ordproblem (K7.6) och Haiku också tänker när den väljs.
2. **Rankfrågor** ("Sveriges tredje största stad", K42.2): de gick till Sonnet för att Haiku svarade fel 19 av 21 gånger. **Väntad svag punkt.** Ger Haiku fel här bör rankfrågorna ligga kvar på Sonnet även om Provläget flyttas.
3. **Provets svar:** `o79_quality.py`.
   - Förståelse.
   - "framgår inte".
   - Par med samma svar (F3/F5).
   - Längd mot `long_words`.
   - Sista kontrollens källor.
4. **Kostnad:** `est_cost_usd` per anrop i båda körningarna (`k121-usage.py` för ett datumintervall).

**Kriterium för att sätta flaggan:**
- Inte sämre än Sonnet på rätt och förståelse, inom eval-brus.
- Rankfrågorna rätt, annars blir de kvar på Sonnet.
- Om bara Provläget håller: sätt `TUTOR_MODEL` och låt `DRILL_ANSWER_MODEL` vara.
