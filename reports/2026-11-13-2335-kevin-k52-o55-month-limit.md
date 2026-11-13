# K52: Oscars O55-fynd och gränsen 15 frågor per månad (Kevin, 2026-11-13 23:35)

Status för varje påstående: **verifierat live**, **verifierat i docs** eller **antagande, ej testat**.

## Kort
- **Gräns (D155): klar.** Högst 15 genererade frågor per konto och kalendermånad, räknat i svensk tid. Värdet ligger i `drill_settings.free_generated_questions`. Räknaren börjar om när månaden byts (**verifierat i databasen**). 402-svaret och `list` ger `per: "month"` och `resets`.
- **Tomt svar (prio 1): löst.** Ett tomt, enordigt eller avhugget svar godtas inte. Frågan görs om, först i sats och sedan ensam. Lyckas det ändå inte kommer `error` ("Svaret kunde inte skrivas. Gör om frågan."), aldrig ett tomt svar. **Verifierat live:** 0 tomma svar av 199.
- **Årskurs (prio 2): ändrad.** Den gissas aldrig längre som "åk 8".
  - Den läses ur förfrågan, sedan ur materialet. Går den inte att läsa blir `summary.grade` tom, och appen frågar användaren. Det var ett av Oscars två förslag.
  - Profilkoderna `y8` och `gy1` förstås.
  - Live, utan årskurs i förfrågan: 10/10 tomma, alltså 0 fel men 0 lästa ur innehållet. Oscars material anger med avsikt ingen årskurs.
  - Till Angela (A85): skicka profilens årskurs med.
- **Frågorna:** varje fråga granskas av Haiku efter genereringen.
  - Frågor som kräver materialet framför sig skrivs om, tecken skrivs som ord ("3x + 5 = 20", "O2") och svenskan rättas.
  - Frågor som "nämns i texten" eller "i exemplet" tas bort först, sedan rena minnesfrågor, sedan frågor över 5 ord. Modellen ger 6 extra frågor att välja bort.
- **Tillagda fakta:** svarsprompten säger nu bara säkra skolkunskaper, hellre utelämna än gissa, och inga orsaker eller exempel som frågan inte bad om. **Antagande, ej testat**: domaren behövs för R4, så Oscar mäter i O55b.
- **R3 klaras inte.** Se nedan.

## R3: frågornas längd (inte nått, förslag till Deangelo)
**Mätning live:** `scripts/k45-measure.py --no-context` och `reports/eval/k45-drill-2026-11-13.json`, Oscars tio prov utan ämne och årskurs.

| | Högst 5 ord | Högst 6 ord | Högst 8 ord |
|---|---|---|---|
| Alla tio prov (142 frågor) | 65 % | **83 %** | 100 % |
| De fyra svåraste (kemi, matte, engelska, svenska; 57 frågor) | 47 % | 72 % | 100 % |

- **Varför:** frågorna på 6–7 ord är tydliga och bra, till exempel "Hur många mol är 88 gram koldioxid?" och "Varför räknar man om massa till mol först?". När de kortades till 5 ord blev det fragment som "Mol metan i 16 g?", och Oscar räknade dem som fel (fynd 3). Kraven "högst 5 ord" och "går att förstå när man bara hör frågan" krockar i räkne- och språkämnen.
- **Förslag:** R3 blir "högst 6 ord i minst 80 %, alla högst 8". Det klaras i dag (83 %). Alternativt undantas räknefrågor. Beslutet är Deangelos eller Arons, så det står som fråga under Till Aron i rapporten och på tavlan. Jag har inte ändrat kravet.
- **Förståelsefrågor:** min grova räkning ger cirka 61 %, men den missar till exempel "Vad händer med y om k är negativ?". Oscars rubrik i O55b avgör.

## D159 i Oscars bank
- Materialen är korta (cirka 1 000 tecken), så de flesta prov får nu 8–15 frågor i stället för 20. Utfyllnaden är borta.
- Kemi gav en gång 14 och en gång 20 frågor. Modellens bedömning av `questions_possible` varierar.

## Signal i provets röst (Kelly N1, Angela)
- `get` och `status` ger `cue.press_for_answer: {status, url, duration_ms}` med texten "Tryck en gång för svaret."
- Filen görs en gång per röst via samma hashcache. Den är gratis och räknas inte i kvoten eller provets förlopp.
- **Verifierat live:** A 1,3 s, B 2,0 s och C 1,5 s, alla giltig mp3.

## Tester
`deno task test`: 544 gröna och `check` ren. Nya tester täcker:
- om-frågor vid tomma eller avhuggna svar, och `error`
- årskurskoder och prompten
- granskningens regler: får bara bli längre för tecken eller hänvisning till materialet
- `nextMonthStart` i svensk tid (31 dec 23:30 UTC räknas som januari)
- 402 med `per` och `resets`
- signalfilen en gång per röst

## Kostnad
- **Claude:** cirka 0,6 USD för 14 prov-mätningar.
- **ElevenLabs:** cirka 75 tecken för signalerna och 2 × 70 för testfrågorna, ungefär 90 krediter.

## Nästa
- Oscar O55b: R2–R4 med domare, på nya hållout-prov.
- Deangelo: R3-kravet (5 eller 6 ord).
- Angela: skicka `grade`, visa `items[i].error`, och använd `cue.press_for_answer`.
