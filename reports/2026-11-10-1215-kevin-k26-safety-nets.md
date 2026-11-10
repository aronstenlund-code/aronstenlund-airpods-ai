# Kevin K26: Skyddsnät i Rizz/Socialt och för känsliga minnen

Datum 2026-11-10 12:15 · Uppgift: `prompts/queue/kevin.md` K26 · Underlag: Oscars O27 (`reports/qa/2026-11-10-1103-oscar-o27-rizz-skyddsnat.md`) och O28 (`…-1104-oscar-o28-minne-kansligt.md`) · Inga modellanrop. Commit 1449df1.

## Vad som ändrats
1. **Rizz och Socialt (`answer/rizz.ts`, `SEXUAL` och `PRESSURE`):** samma två mönster som alla kontroller redan använder är breddade. De fångar nu:
   - hem och säng ("hemma hos mig", "följer med dig hem", "min säng", "hotellrum");
   - kroppen ("din kropp", "ser het ut", "ta av dig");
   - ett nej som inte respekteras ("nej är bara ett kanske", "nej som svar", "sa nej men", "fråga igen", "ignorera att");
   - press ("inga ursäkter", "ge mig ditt nummer", "du kan inte gå", "spela svår");
   - nedvärdering ("för att vara", "om du log", "du duger", "i din ålder");
   - manipulation ("om du gillade mig", "gå inte till dem");
   - lögner ("säg att du är/har");
   - att utnyttja att någon är berusad ("full … passa på").
2. **Känsliga minnen (`memory/handler.ts` `SENSITIVE_RAW`):** listan täcker nu dessa kategorier:
   - hälsa (epilepsi, celiaki, dyslexi, mens, vikt, medicinnamn);
   - kris;
   - sexualitet och relationer;
   - tro (ramadan, kyrka, bön);
   - politik (ungdomsförbund, "röstade på");
   - ursprung ("kommer från", romsk, same);
   - brott (snatta, fängelse);
   - andra personer (mamma, kompis …, "heter X");
   - kontaktuppgifter (e-post, telefonnummer, insta/snap);
   - pengar ("2000 kr", "på kortet") och var någon bor ("bor i").

   Korta ordstammar har nu ordgränser, så "lånat", "sjukt mycket", "brottslighet", "kristendomen", "judeförföljelsen" och "partiklar" sparas fortfarande. Studieord som "uppsats om X", "läser om X" och "i religion" tas bort före kontrollen. Mönstret står kvar på en rad, eftersom Oscars test läser det ur filen. `isSensitiveMemory` exporteras för testerna.
3. **Oscars förslag om en Haiku-kontroll** av de tre valda raderna är inte byggt i dag. Det kostar API och lägger till väntetid, och kodlagret stoppar nu 25/25. Förslaget ligger kvar som nästa steg om Oscar hittar nya luckor.

## Resultat (offline)
| Test | Före | Efter |
|---|---|---|
| O27 olämpliga rader stoppade (`scripts/qa/o27_rizz_filter_offline.mjs`) | 0/25 | **25/25** |
| O27 vanliga rader släpps igenom | – | **10/10** |
| O28 känsliga minnen stoppade (`o28_memory_sensitive_offline.mjs`) | 2/27 | **27/27** |
| O28 vanliga minnen sparas | – | **20/20** |
| `answer/*_test.ts` och `memory/*_test.ts` | – | 318/318, nytt `answer/k26_test.ts` med alla 82 rader |

## Till Angela
- Appens `SensitiveFilter` (A27) bör följa samma lista. Det gemensamma testet är `answer/k26_test.ts` (eller Oscars O28-skript). I dag stoppar appen "Läser religionskunskap", som servern släpper igenom.

## Risker
- Mönster missar nya formuleringar. Modellen är fortfarande det första lagret (D43/D63/D69, D80).
- "heter X" och relationsord stoppar också minnen som "Kompisen heter Elin". Det är avsiktligt, eftersom D80 säger att inga fakta om andra personer ska sparas.

## CI
Deploy backend (typkontroll, alla tester, driftsättning) lyckades: körning 42805093491. Regressionen hoppades över (`[skip eval]`, ingen API-kostnad). Live: **driftsatt**, men inte mätt live efter ändringen.
