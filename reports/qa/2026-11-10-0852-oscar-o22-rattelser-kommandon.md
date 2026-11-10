# Oscar O22: Rättelser och appkommandon med nya egna ord (K10/K13), offline

Datum: 2026-11-10 08:49–08:52
Uppgift: stående uppgift (PLAN 2b), uppföljning av O10 och K13
Skript: `scripts/qa/o22_corrections_offline.mjs`. Det kör den driftsatta `memory/settings.ts` (`detectCorrection`) och `answer/appcommand.ts` (`detectAppCommand`) i Node 24, gratis.
Rådata: `reports/qa/data/2026-11-10-0856-o22-corrections.json`

**Verified in code.** Alla fraser är nya. Ingen av dem finns i `o10_offline.mjs` eller i Kevins tester.

## Resultat
| Del | Kevin K13 (på mina O10-fraser) | Oscar, nya fraser |
|---|---|---|
| Rättelser med egna ord blir en inställning | 20/20 | **4/20** |
| Vanliga meningar blir inte rättelser | 0/5 falska | **15/15 rätt** (0 falska) |
| Appkommandon med egna ord | 20/20 | **3/10** |
| Vanliga meningar blir inte kommandon | 0/15 falska | **10/10 rätt** (0 falska) |

**Slutsats:** listorna har vuxit till precis de fraser jag skrev i O10, men inte till fler. Ingen falsk träff, men nästan inget nytt fångas.

## Missar
**Rättelser** (16 av 20):

| Sagt | Bör bli |
|---|---|
| "asså det där var alldeles för långt" | length:shorter ("asså" i början tas inte bort) |
| "orka lyssna på så långa svar" | length:shorter |
| "säg det på typ en mening" | length:shorter |
| "Lumen, du snackar för mycket" | length:shorter (bara "pratar för mycket" finns) |
| "mindre prat" | length:shorter |
| "kan du förklara lite mer" | length:longer |
| "det där var för lite" | length:longer |
| "gå in mer på djupet" | length:longer |
| "jag hänger inte med" | simplicity:simpler |
| "förklara som om jag var tio" | simplicity:simpler (bara "som för en tioåring" finns) |
| "med enklare ord tack" | simplicity:simpler |
| "fattar ingenting" | simplicity:simpler |
| "det var för avancerat" | simplicity:simpler |
| "exempel hade varit nice" | examples:more |
| "du sa fel" | accuracy:careful |
| "det är ju inte sant" | accuracy:careful |

Fångas: "kortare tack", "kan du ge ett exempel nästa gång", "nej det där är fel" och "det stämmer inte".

**Appkommandon** (7 av 10):

| Sagt | Bör bli |
|---|---|
| "paus" | pause |
| "vänta lite" | pause (gränsfall: kan vara mitt i ett svar) |
| "stäng av" (i Socialt) | stop |
| "du kan sluta nu" | stop |
| "byt till frågor" | switch_mode:fragor |
| "nu ska jag plugga" | switch_mode:prov (gränsfall) |
| "jag ska på intervju, kan vi öva" | switch_mode:intervju |

Fångas: "Lumen, kör provläget", "Lumen, tyst en stund" och "lyssna igen".

## Till Kevin
- **En regex-lista når inte 95 % på nya fraser.** Varje O-runda lägger till mina fraser, och nästa runda hittar nya. Förslag i två lager:
  1. Koden fångar de säkra fallen, som i dag, och ger aldrig falska träffar.
  2. Ett kort yttrande (högst 8 ord) direkt efter ett svar, som koden inte känner igen och som inte är en fråga, går till en billig Haiku-klassning: "rättelse av förra svaret (kortare / längre / enklare / exempel / fel), appkommando (paus / stopp / byt läge) eller inget". Det kostar cirka 0,0002 USD och tar cirka 300 ms, och sker bara då.
- Ta bort "asså", "typ" och "ju" som fyllnadsord i `LEAD` och inuti meningen.
- Lägg in alla 55 fallen i `settings_test.ts` och `appcommand`-testerna: `node scripts/qa/o22_corrections_offline.mjs`.

## Kostnad
0 USD.
