# O99: röktest för dagen krediterna kommer tillbaka, Oscar (moln)

**Resultat:** torrkörningen gav **14/14** (Actions 45780328327, 08:06 UTC, main 75393171). Det är **verifierat live**.
- Alla steg som inte behöver modellen fungerar på riktigt:
  - krisfrasen gav krissvaret, eftersom koden känner igen den;
  - webbkontot fick 1 500 krediter;
  - 19 röster, ingen Marlon, PS3 character finns;
  - Säg i AirPods via webben: kostnaden 79 före, falskt ljud klart, 79 dragna.
- Alla modellsteg svarade 503 `provider_quota` med rätt text: "EarMind är nere en stund. Försök igen senare." och "EarMind is down for a moment. Try again later."
- 0 ElevenLabs (testhuvud, falskt ljud), 0 Claude, 0 USD.

## Så startas det
1. GitHub › Actions › **Oscar live QA** › **Run workflow**, gren `main`.
2. Välj **script** `o99_credits_back.py`.
3. **args:**
   - **tomt** för den skarpa körningen, den dag krediterna är tillbaka;
   - `--dry` för en torrkörning som i dag.
4. Svaret står i loggen under steget **Run**, med en tabell per steg och kostnaden i USD. Raden längst ner är `=== O99 skarp N/14 ok`.
   - Exit 0 betyder att allt är grönt.
   - Exit 1 betyder att något steg är rött. Se raderna som börjar med `FEL`.
   - **Exit 2** betyder att `/answer` fortfarande svarar 503. Krediterna är då inte tillbaka, och inget annat körs.
5. **Webbläsaren** körs separat: Actions › **apptest-t56** (Tobys) › Run workflow med `live` = true. O99 gör bara serverns del av T56-vägen.

Från en session: `actions_run_trigger` `run_workflow`, `workflow_id` `oscar-live.yml`, `ref` `main`, `inputs` `{"script": "o99_credits_back.py", "args": ""}`.

## Stegen (`scripts/qa/o99_credits_back.py`)
| Steg | Modell | Skarp: grönt när | I dag (torr) |
|---|---|---|---|
| answer sv "vad är fotosyntes" / en "what is photosynthesis" | ja | 200, svar på över 20 tecken, det engelska utan svenska småord | 503 `provider_quota` sv / en |
| krisfrasen "jag vill inte leva längre" | nej | krissvaret (Självmordslinjen / ring ett ett två) | **200, krissvar** |
| "recept på ris" (D256, K116) | ja | inget krissvar, källa eller `source_fallback`, inget `source_missing`, högst 90 ord | 503 |
| exam drill, 3 frågor | ja | minst 3 frågor med kort svar | 503 |
| exam grade (drill-rättning), rätt svar | ja | minst 1 poäng och en återkoppling | 503 |
| exam compress sv och en | ja | kortare text än in | 503 sv / en |
| help "Hur delar jag ett prov?" | ja | `in_scope` true och ett svar | 503 |
| webb (Origin earmind.vercel.app): konto och quota | nej | 1 500 | **200, 1 500** |
| webb: voices | nej | minst 10 röster, ingen Marlon, PS3 character | **19** |
| webb: Säg i AirPods cost, save+start, status | nej | 200 och ljudet klart | **79 krediter, klart** |
| webb: prov från engelsk text, `lang` en | ja | 3 frågor utan svenska småord | 503 en |

**Kostnaden** läses ur varje svar: `usage.est_cost_usd` i `done` för /answer, och `usage` för /exam och /help. Väntat cirka 0,05 USD, och "recept på ris" får högst 2 webbsök av testtaket.

**Untested assumption:** de skarpa kontrollerna av modellsvaren (fälten `questions`, `total`/`feedback`, `in_scope`, `text`) är skrivna efter serverns kod och dokumentation. De har inte provats mot ett riktigt svar. Om ett steg blir rött den dagen kan det vara skriptet.

## Även gjort
`scripts/live-eval.py` sparar nu serverns felkod vid HTTP-fel, till exempel `{"http": 503, "code": "provider_quota"}`. Orsaken syns då i nattens rapport, vilket var C3 i O97. Testerna gav **57/57**.
