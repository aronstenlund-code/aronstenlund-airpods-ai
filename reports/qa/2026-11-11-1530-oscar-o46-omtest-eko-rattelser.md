# Oscar O46: Omtest av ekofiltret (O30) och rättelser/kommandon (O22) efter Kevins omgång 10–11, offline

Datum: 2026-11-11, 15:30 (svensk tid)
Uppgift: stående uppgift (PLAN 2b). Kevins stående omgång 10 (ekofiltret, `reports/2026-11-11-1305-kevin-standing10-echo-followup.md`) och omgång 11 (mina O22-fall, `reports/2026-11-11-1336-kevin-standing11-corrections-commands.md`) hade inget omtest.

**Skript:** `scripts/qa/o30_echo_offline.mjs` och `scripts/qa/o22_corrections_offline.mjs`. Båda läser den driftsatta koden i `backend/` och kostar 0 USD.
**Rådata:** `reports/qa/data/2026-11-11-153036-o30-echo-omtest.json` och `…-153036-o22-corrections-omtest.json`.

## Resultat
| | 2026-11-10 | **Nu** |
|---|---|---|
| Ekofiltret: följdfrågor som citerar svaret behåller innehållet, och riktigt eko tas bort (O30) | 8/12 | **12/12** |
| Rättelser med egna ord blir en inställning (O22) | 4/20 | **20/20** |
| Vanliga meningar blir inte rättelser | 15/15 | **15/15** |
| Appkommandon med egna ord | 3/10 | **9/10**. Kvar: "stäng av" i Socialt läge blir inget stoppkommando |
| Vanliga meningar blir inte kommandon ("han sa stäng av musiken") | 10/10 | **10/10** |

**Förbehåll:** omgång 11 bygger på just mina O22-fall, så siffrorna visar att rättningen fungerar men är ingen oberoende mätning. Nästa gång behövs nya fall (O22b). Det gäller inte O30: Kevin rättade efter sitt eget live-eval (klocka-01), och mina 12 fall ligger inte i hans tester (inte kontrollerat rad för rad).

**Märkning:** verified in code (offline mot de driftsatta `.ts`-filerna), inte live.
