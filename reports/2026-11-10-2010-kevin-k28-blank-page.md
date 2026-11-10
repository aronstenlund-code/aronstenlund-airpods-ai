# Kevin K28: D113, blank sida för restriktioner (servern)

Datum 2026-11-10 19:40–20:10. Uppgift: `prompts/queue/kevin.md` K28 och `docs/RESTRIKTIONER.md` del A (D113, D114, D119). Commit `a9fa3c4` (minnesdelen i `da880a5`, se K34). Driftsatt med Deploy backend 42878898634.

## Vad som ändrats
- **A1 (`answer/rizz.ts`):** kodfiltren `SEXUAL` och `PRESSURE` är borttagna överallt: förslagsraderna, förhandsvisningen, påfyllningen, `filterReasons` och kalibreringen. Koden stoppar nu bara rader som är för långa och rader med talaretiketter ("Talare 1").
- **A2:** det tvingade avskedet är borttaget: `isDecline`, `detectDecline`, `FALLBACK_DECLINE` och `<signal>decline</signal>`. Rollbeskrivningen i prompten säger fortfarande att ett nej respekteras ("If the other person says no … accept it kindly … Never persuade or keep them"). Om alla rader filtreras bort blir reserven alltid "Berätta mer om det.".
- **A3 (`answer/prompt.ts`):** "Never say that you are an AI, an assistant or a program" är borttagen. I stället står det: tillfrågad om den är en robot, en AI eller en människa säger Lumen ärligt att den är en AI-assistent.
- **A5/B5 (minnet):** bara hälsa, kris och ID-nummer stoppas. Det är gjort i K34 (`da880a5`).
- **Orört (del B):** krissvaret, hastighetsgränsen, K24, telefonnummer, länkar och allergiregeln.
- **Testerna speglar beslutet:**
  - `k26_test.ts`: O27-delen är borttagen, B5 har DROP/KEEP, och tro/politik/ursprung/pengar/bostadsort ligger i KEEP_A5.
  - `rizz_test.ts`, `k10_test.ts` och `handler_test.ts`: innehållsrader släpps igenom, och talaretiketter och längd stoppas fortfarande.
  - `memory/handler_test.ts` och `settings_test.ts`: adress, skulder och pengar sparas, ID-nummer stoppas.

## Resultat
- Backendtester (Node-shim): answer 307/307 och memory 13/13 vid commit. CI-testerna med typkontroll var gröna (deploy success).
- Regressionen (K4, 21 D87-fall, Sonnet): **90,5 %** första svaret räcker (95,2 % i föregående körning). Jag kontrollerade samma urval för hand: 90,5 %, 0 krissvar, och de två missarna gällde ämnesdetaljer (inflation och andraderivatan). I dag har körningarna varierat mellan 81 och 100 % på orelaterade ändringar, så jag bedömer skillnaden som brus (**verified live**).
- Rizz utan kodfilter är **inte mätt live**. D119 säger att det inte finns några innehållsregler utöver de åtta skydden, så Oscars O27-fall är inte längre krav. `scripts/qa/o27_rizz_filter_offline.mjs` förväntar sig att de stoppas och ska pensioneras.

## Till Oscar och Angela
- Oscar: O27 och O28:s religion-, politik- och kontaktfall är inte längre fel (D113 A1/A5).
- Angela: appens `SensitiveFilter` (A27) bör bara stoppa hälsa, kris och ID-nummer, samma som `answer/k26_test.ts`. 18+-spärren (A4) är din del.
- `self.ts` svarar redan "AI-assistent" på frågan om Lumen är en robot. Den borttagna meningen gällde sociala repliker i prompten.

## Kostnad
CI-regressionen cirka 0,32 USD. Inga andra anrop.
