# Kevin K17: Lumen kommer ihåg vad du missade, och en plan fram till provet

Datum 2026-11-10 · Uppgift: `prompts/queue/kevin.md` K17 (godkänt av Aron 2026-11-09 22:03) · Driftsatt (Deploy backend 42777600986, commit 8333362), med den nya funktionen `study-plan`. Allt nedan är **verified live** (anrop mot driftsatt backend, `reports/eval/k17-2026-11-10.json`) där inget annat står. **Inte testat på telefon**, och appens del finns inte än.

## Resultat
| Del | Resultat live |
|---|---|
| 1. Repetition med mellanrum, `POST /study-plan` | Ett exempel med fyra begrepp: dagens begrepp är cellandning och mitos (missade i går) och osmos (rätt för tre dagar sedan, dags att repetera). Fotosyntes (rätt två gånger) väntar 7 dagar. Frågan som läses upp: **"I går missade du cellandning och mitos. Ska vi ta dem nu?"** Svaret kom på 762 ms, utan modellanrop |
| 3. Plan fram till provet | Provet om 3 dagar ger 3 pass: 10, 10 och 15 minuter. Pass 1 tar det som missades först, pass 2 det som är svårast, och dagen före provet blir ett blandat förhör. Alla begrepp kommer tillbaka minst en gång |
| 2. Sammanfattning när eleven avslutar | `session_end: true` på /answer ger fyra upplästa meningar: tre huvudpunkter med ämnesorden, och sedan "Det du var osäker på var vad som bildas vid cellandning, nämligen koldioxid och vatten …" |

## Hur det fungerar (DECISIONS: se raden "K17")
**`POST /study-plan`** är bara kod: inget modellanrop, ingen kostnad och inget sparas. Appen sparar historiken per prov.
- **Begäran:**
  - `{"today", "exams": [{"name", "date", "concepts": [{"concept", "history": [{"date", "ok"}]}]}]}`;
  - `history` innehåller varje gång begreppet kom upp i förhör, rättning eller övningsprov, där ett osäkert svar räknas som `ok: false`.
- **Svaret:**
  - `due`, med begrepp, senaste datum, låda, nästa datum och orsak (`missed` eller `review`);
  - `prompt`, den upplästa frågan;
  - `plan`, med datum, minuter, begrepp och en anteckning för varje dag fram till dagen före provet (högst 14 dagar).
- **Lådorna (Leitner):** fel betyder tillbaka i morgon. Rätt flyttar upp en låda: 1, 3, 7 och sedan 14 dagar. Ett fel efter flera rätt börjar om.

**`session_end: true`** på /answer i Provläge:
- "avsluta" blir då inget appkommando, utan uppgiften `session_summary`: tre huvudpunkter ur `recent_qa` och det eleven var osäker på, ur `concept_stats` och rättade svar.
- Appen sparar svaret som studiekort (D81, `/study-cards` med svaret som `summary`) och i Anteckningar.

## Till Angela
1. Spara per prov och begrepp `{date, ok}`. Källor: förhörssvar (rättningen "Rätt"/"Inte riktigt"), `/exam grade` och övningsprov (K15, där `topic` är begreppet).
2. Anropa `/study-plan` när appen öppnas. Läs upp `prompt` och visa `plan[0]` som en notis ("10 minuter i dag: cellandning, mitos, osmos").
3. Vid "avsluta" i Provläge: skicka en sista /answer med `session_end: true`. Läs upp svaret och spara det som studiekort.

## Tester
Lokalt finns `study-plan/handler_test.ts` (lådor, dagens begrepp och frågan, planen, slutpunkten) och `answer/k13_test.ts` (`session_end`). Hela sviten är 313 gröna. Actions med typkontroll är grönt.

## Risker och kvar
- Planen bygger bara på det appen skickar. Utan historik kommer planen från begreppen i provprofilen, och appen måste då skicka dem utan `history`. Att det blir bra är en **untested assumption**.
- Planen tar inte hänsyn till hur mycket tid eleven har. Alla pass är 10 minuter (15 dagen före).
- **Till Aron:** ska notisen komma vid en fast tid, till exempel kl. 16, eller när appen öppnas? Det är Angelas del, men det är ditt beslut.

## Kostnad
Under 0,01 USD (ett Sonnet-svar för sammanfattningen).
