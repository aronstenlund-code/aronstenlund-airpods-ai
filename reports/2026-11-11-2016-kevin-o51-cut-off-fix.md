# Oscars O51 (prio 1): hela frågor blev tysta i Standardläge, rättat (Kevin, 2026-11-11 20:16)

## Fynd
Oscar O51 (`reports/qa/2026-11-11-1852-oscar-o51-avklippt-fraga.md`) hittade felet, som kom med min omgång 15.
- I svenska bisatser hamnar verbet sist ("kan du säga vad klockan är").
- Därför blev hela frågor som slutar på "är", "blir" eller "har" tysta: 6/8 live, och 2/12 hela frågor besvarades offline.

## Ändring (`answer/handler.ts` `isCutOff`)
- **Verb sist** ("har", "hade", "är", "blir", "blev") räknas bara som avklippt i en huvudsats. Det får inte stå något subjekt eller någon bisats före verbet, alltså inget av du, jag, det, hon, man, att, som, om, tror, vet, säga, kolla, förklara … "Hur många invånare har" blir avklippt, men "vad tror du att svaret är" blir det inte.
- **"än"** är borttaget ur listan.
- **Ord som eleven frågar om** räknas aldrig: "ordet och", "betyder", "mening med", "på engelska", "skillnaden mellan X och Y".
- Övriga ord (mellan, och, eller, som, att, en, ett, possessiva pronomen, vilken) gäller som förut.
- Allt gäller som förut **bara i Auto**.

## Tester
- `deno task test`: **492 gröna**. Nya tester med mina egna formuleringar i `k_standing16_test.ts`. Oscars 12 fall används inte i testerna, så hans omtest blir oberoende.
- **Oscars offlinetest** (`scripts/qa/o51_cutoff_offline.mjs`, utdata i min scratchpad): hela frågor **12/12** besvaras (förut 2/12). Avklippta frågor är **14/18** som förut.
  - De fyra missade är "huvudstaden i", "det andra", "den största" och "Sveriges".
  - Prepositioner, adjektiv och genitiv är medvetet utanför regeln, eftersom svenska frågor ofta slutar så ("vilka är de största?" är en riktig följdfråga).
- **Live** (`59bf5f6`, Auto):
  - "kan du säga vad klockan är": svarar "Klockan är tjugo över åtta på kvällen".
  - "hur svårt tror du provet blir", "vad betyder ordet och" och "hur gammal tror du att jag är": besvaras.
  - "Hur många invånare har": fortfarande tyst (`cut_off`).
  - "vad tror du att svaret är": tyst men **inte** `cut_off`. Modellen valde själv tystnad, eftersom det inte finns någon fråga att syfta på (det andra lagret som Oscar nämnde). Det är inte ändrat.

## Till Oscar
Omtest med `o51_cutoff_offline.mjs` och `o51b_cutoff_live.py`.

## Till Aron
Rättat: "kan du säga vad klockan är" fungerar igen i Standardläge.
