# Kevin K27: Självfrågor, ekofiltret och länkbegäran

Datum 2026-11-10 12:15 · Uppgift: `prompts/queue/kevin.md` K27 · Underlag: Oscars O24, O30 och O31 (offline) · Inga modellanrop. Commit 8e7ced4.

## Vad som ändrats
1. **Frågor om Lumen (`answer/self.ts`):** frågorna matchas nu på innehållet (vem som tilltalas och vad det gäller), inte på hela meningar. Fall som nu känns igen:
   - "är det chatgpt", "vilken AI är du", "vem har gjort dig";
   - "spelar du in lektionen", "lyssnar du när appen är stängd", "kan du höra mig när skärmen är släckt";
   - "vem ser det jag frågar", "kan läraren se vad jag frågar", "säljer ni min data", "vart skickas ljudet".

   Fall som fortfarande inte räknas som självfrågor: "spelar du piano", "lyssnar du på musik", "spelar du in en låt", "sparar du pengar", "hör du vad läraren sa", "är du på riktigt arg" och "vem är du i Hamlet". Svarstexterna har inte ändrats (de är ordagrant ur "Om appen").
2. **Ekofiltret (`answer/echo.ts`, `handler.ts`):** om eleven med sina egna ord frågar om det upprepade ("vad menar du med i form av glukos", "vad betyder …", "vänta, när Tyskland anföll Polen, vad hände sen", "så … ?"), räknas upprepningen som ett citat. Hela följdfrågan behålls och märks med `quoted: true`. Ett rent eko med brus ("och lägger till tio. Gud- ehm") tas fortfarande bort.
3. **Länkbegäran (`answer/resource.ts`):** en länkbegäran känns nu igen på innehållet. Den behöver tre delar:
   - ett frågeord (hitta, visa, länka, rekommendera, vill se, nån eller nåt …);
   - ett ord för film eller sida (klipp, youtube, UR …);
   - ett ämne ("om …").

   Även "var kan jag läsa mer om …" räknas. En film som någon redan har sett eller gjort ("jag såg en film om hajar") räknas inte. Ämnet tar bort "på UR Play" och liknande, och faller tillbaka på den senaste frågan.

## Resultat (offline)
| Test | Före | Efter |
|---|---|---|
| O24 självfrågor (`scripts/qa/o24_k20_offline.mjs`) | 5/20 | **20/20**, inte-självfrågor 10/10 (+6 egna liknande fall, alla null) |
| O30 eko och citat (`o30_echo_offline.mjs`) | 8/12 | **12/12** |
| O31 länkbegäran (`o31_k19_resource_offline.mjs`) | 5/15, ämne 7/8 | **15/15**, inte-begäran 8/8, ämne **8/8**, domäner 9/9 |
| `answer/*_test.ts` + `memory/*_test.ts` | – | 323/323, nytt `k27_test.ts` |

## Risker
- Ett eko som råkar innehålla ett frågeord ("… eller …") behålls nu i stället för att tas bort. A28 begränsar redan ekot till det som börjar medan Lumen talar eller inom 1,5 s därefter, så risken är liten (**untested assumption**, bör provas på en enhet).
- Självsvaret ges i alla lägen, även i Auto när en klasskompis frågar "lyssnar du nu". Då svarar Lumen sanningsenligt om sig själv, vilket är ofarligt.

## CI
Deploy backend (typkontroll, alla tester, driftsättning) lyckades: körning 42805896061. Regressionen hoppades över (`[skip eval]`, ingen API-kostnad). Live: **driftsatt**, men inte mätt live efter ändringen.
