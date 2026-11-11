# Stående uppgift, omgång 16 (K4-loopen): ett talintervall med mellanslag lästes fel (Kevin, 2026-11-11 19:17)

## Eval
- Live-eval i kväll (`reports/eval/2026-11-11-1914-live-eval-evening.md`): 388 turer, 343 utan anmärkning, 45 med. Resten är långsamma svar (över 2,5 s) och jag-form i intervjuläget, som förut.
- **Sämsta fallet:** "vad händer med klimatet i framtiden" sades som "ökar mellan **ett komma fyra – fem till sju** grader". Fel siffror hördes. Kostnad: eval cirka 1 USD, regression 0,33 USD.

## Orsak och ändring
- Hela texten "1,4 – 5,7" översätts rätt. I strömningen (`NumberStream`) skickades däremot "1,4 –" vidare innan "5,7" hade kommit, så intervallet bröts isär (verifierat i kod med chunkstorlek 1–11).
- Nu hålls ett tal + ett tankstreck med mellanslag kvar tills nästa tal har kommit. "Minus 3 - inte mer" påverkas inte.
- Talet läses nu "ett komma fyra till fem komma sju". "Sidorna 12 – 15" blir "tolv till femton".

## Tester
- `deno task test`: **481 gröna** (nytt `answer/k_standing16_test.ts`). `check` är ren.
- Regressionen i deploy gav **90,5 %**, inom brusintervallet 81–100 %.
- **Live** (`cc82ace`): tre frågor med intervall, inga siffror och inga tankstreck i talet ("mellan ett komma fem och fyra grader", "trettio till fyrtio sidor").

## Nästa
Det näst sämsta är fortfarande att det tar mer än 2,5 s till första ord i Provläge och vid "praktiskt" (p50 3,1–3,4 s).

## Till Aron
Inget nytt.
