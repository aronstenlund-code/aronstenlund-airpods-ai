# Kevin K13: Kort svar först, mer på ett "ja", och Lumen lär sig längden

Datum 2026-11-10 · Uppgift: `prompts/queue/kevin.md` K13 (ägarkrav 2026-11-09 21:33), först Oscars O10-fynd (`reports/qa/2026-11-09-2110-oscar-o10-k10-k8.md`) · Driftsatt (den sista är Deploy backend 42773556273, commit 7f6e812) · Allt live är **verified live** mot driftsatt backend. **Inget är testat på telefon**, och appens del (A15) är inte inkopplad mot det här.

## Resultat
| Krav | Resultat |
|---|---|
| **O10: rättelser med egna ord ≥ 18/20** (K10 räknas inte som klar annars) | **20/20** på Oscars egna 20 fraser (`scripts/qa/o10_offline.mjs`, den driftsatta koden offline) och 0/5 falska. Mina egna 13 andra varianter är 13/13 och 5 vanliga meningar 0 falska (unit-test). Oscar bör göra om sitt test live |
| O10: appkommandon med egna ord | **20/20** (Oscars fraser, krav ≥ 95 %), **0/15** falska |
| O10: räckvidd och vidgning | **12/12** (Oscars sekvenser). Läget sparas nu i varje räckvidd: samma rättelse i ett annat läge blir global och flyttas aldrig bort |
| O10 #4–#8 | Profilen byggs av de inställningar som gäller i sammanhanget. "Mer exempel" kräver minst två exempel. Telefonfiltret byter inte ut "omkring 800 000" längre (4/4 av Oscars meningar). Klippningen slutar efter sista hela meningen (ingen lös "["). "Första raden i …" går till textvägen (unit-test för alla) |
| **Två nivåer:** kort svar, sedan det utvecklade A-svaret | Provläge-banken, 30 fall (vart sjunde), Sonnet svarar och Sonnet bedömer: det korta svaret är **25–31 ord** (p50), det utvecklade kommer i **97 %**, och tid till första ord är **1,3 s** p50 (server) |
| **Huvudmått: "första svaret plus högst ett ja räcker"** | **93,3 %** och **86,7 %** i två körningar på samma 30 fall, sammanlagt **90,0 %** av 60. Det korta svaret ensamt räcker i 13–17 %, vilket väntas (det ska vara kort). Jämförelse: ett enda långt svar gav 91,6 % i K2 (191 fall). Skillnaden ligger inom slumpen för 30 fall |
| Det långa svaret efter "ja" kommer under 1 s | Det långa svaret skickas i samma ström direkt efter det korta (`more_delta`, och helt i `done.more`). Det ligger alltså redan i appen när eleven säger ja, och tiden är 0 s plus appens uppspelning. **Verified live**, eftersom det långa var klart 1–3 s efter det korta. Att appen spelar det direkt är **untested** (A15) |
| **Inlärd längd:** 2 ja av 3 ger långt direkt, och "kortare" återställer | Serie live (`scripts/k13-series.py`): fråga 1 och 2 ger kort plus mer, ja + ja ger fråga 3 långt direkt (222 ord, inget kort först), "kortare" gör fråga 4 kort först igen. **4/4 steg rätt** |
| **Situationen** (läge, ämne, hur nära provet är, tid på dygnet, om andra pratar) används | Raden skickas med varje svar. Med "andra pratar" var svaret kortare i 3/5 när bara situationsraden fanns. Nu finns också en fast längdregel (högst tre korta meningar), men den är **inte mätt live igen** |

Filer:
- `reports/eval/provlage-2026-11-10-sonnet-k13-two-v1-sample.*`: före kortgränsen i kod, det korta var 103 ord.
- `-v2-`: med kortgränsen, men det korta hölls kvar till slutet, så första ordet kom efter 4,2 s.
- `provlage-2026-11-10-sonnet-k13-two-sample.*`: den sista körningen.
- `reports/eval/k13-series-2026-11-10.json`.

## Hur det fungerar (kontrakt för Angela, DECISIONS D100)
- **Begäran:** `two_level: true` på /answer (Provläge, eller förklaringar i Frågor). Utan fältet blir det ett svar som förut, så ingenting ändras förrän appen slår på det. Inte i quiz, kommandon, fortsättningar, webb och text.
- **Svaret:**
  - `delta` är det korta svaret, som läses upp.
  - `more_delta` är det utvecklade svaret, som inte läses upp och sparas i appen i cirka 2 minuter.
  - `done.more` är hela det utvecklade svaret.
  - Det utvecklade upprepar aldrig det korta, eftersom resten av det modellen skrev efter två meningar blir början på det utvecklade.
- **Efter "mer?":** appen skickar `/memory` `{"length_signal": {"signal": "yes"|"no", "context": {mode, subject?, exam?, answer_type?}}, "settings": [...]}`. Ett nej eller tystnad är `"no"`. Svaret har `settings` (som appen sparar och skickar tillbaka som `preferences`) och `long_first`.
  - Två ja av de tre senaste i samma räckvidd lägger till "Längre, utförligare svar i biologi".
  - Med den inställningen ger /answer det långa svaret direkt, utan delning.
  - "kortare" (K10) tar bort den igen.
  - Bara bokstäverna y och n sparas, aldrig ljud eller ord.
- **Situationen:** valfritt `situation: {others_talking: true}` (A10). Läge, ämne, dagar till provet (ur profilen, till exempel "(om 3 dagar)") och tid på dygnet räknas ut på servern.

## Ändrat i koden
- **`memory/settings.ts`:**
  - `detectCorrection` tar bort omslag som "Lumen", "nej", "kan du", "lite", "tack" och "i fortsättningen", och har många fler fraser.
  - `guessScope` behåller läget, och `widen` blir global mellan lägen.
  - `applySignal` är ny.
- **`memory/handler.ts`:** vägen `length_signal`.
- **`answer/appcommand.ts`:**
  - "sätt på", "kan du sluta lyssna", "ta en kort paus", "nu räcker det för idag", "dags för …" och "inget mer förhör";
  - "kan vi plugga till provet istället".
- **`answer/handler.ts`:**
  - `TWO_LEVEL_RULE`, delningen vid `[[MER]]`, kortgränsen i kod och `more_delta`/`done.more`;
  - situationsraden;
  - profilen per sammanhang;
  - klippningen vid gränsen (bara hela meningar, inget efter klippningen);
  - "mer exempel" med två exempel.
- **`answer/speechsym.ts`:** telefonfiltret har ordgränser och räknar inte tusentalsgrupper som nummer.
- **`answer/web.ts`:** "första raden i".

## Tester
Lokalt är 293 gröna (answer och memory). Nya tester finns i `answer/k13_test.ts` och `memory/settings_test.ts`. Oscars `o10_offline.mjs` är grön. Actions med typkontroll är grönt.

## Kvar och risker
- **Angela (A15):** skicka `two_level`, spela `more` på ja, nick eller tryck, och skicka `length_signal`. Toby såg i T7 att mikrofonen i Mer-fönstret var döv (0/7 ja hördes), så appens del behövs innan någon märker det här.
- Mät "andra pratar" live igen när A10 skickar fältet.
- **D87:s huvudmått** byts till "första plus högst ett ja". Nattkörningen (`nightly-eval.yml`) mäter fortfarande bara det första svaret. Byt till `--two-level` när appen använder det.
- Bedömaren hittade språkfel i svaren ("ett kubikdecimeter", "en kommunfullmäktige"). Det tas i K5 (språkkontroll).
- Kostnad per svar med två nivåer är 0,010–0,012 USD (Sonnet), cirka 25 % mer än ett svar, eftersom båda nivåerna alltid tas fram.

## Kostnad
Ungefär 1,8 USD (tre körningar av 30 fall med Sonnet och bedömning två gånger per fall, och serien).
