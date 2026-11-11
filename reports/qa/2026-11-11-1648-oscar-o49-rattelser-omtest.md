# Oscar O49: Omtest av O48 efter Kevins omgång 14 (rättelsekontrollen gäller bara assistentens svar)

Datum: 2026-11-11, 16:43–16:48 (svensk tid)
Uppgift: kör om O48 efter Kevins ändringar i `memory/handler.ts`:
- `13f1463`: kontrollen gäller bara assistentens senaste svar.
- `b350a02`: egna exempel i prompten, med mina fall kvar som hållout. Kontrollerat med grep: inga av mina 50 meningar finns i `handler.ts` eller `handler_test.ts`.

Båda är driftsatta 16:13–16:14.

**Skript:** `scripts/qa/o48_corrections_live.py` (samma 50 meningar).
**Rådata:** `reports/qa/data/2026-11-11-164740-o48-corrections.json`.
**Kostnad:** under 0,01 USD (Haiku).

## Resultat: krav uppfyllda (minst 17/20 rättelser, högst 1/30 falska)
| | O47 (bara kod) | O48 (kod + Haiku) | **O49 (ny prompt)** |
|---|---|---|---|
| Rättelser med nya egna ord | 5/20 | 19/20 | **17/20** |
| Vanliga meningar (O22b) blir inte rättelser | 15/15 | 10/15 | **15/15** |
| Meningar som liknar återkoppling men handlar om annat | – | 9/15 | **15/15** |
| **Falska rättelser** | 0/30 | 11/30 | **0/30** |

**Missade rättelser (3):**
- "jag orkar inte höra hela föreläsningen" (kortare)
- "kan du förklara det mer basic" (enklare)
- "förenkla" (enklare)

Missarna blir ingen inställning. Det är den ofarliga riktningen.

**Bra nu:**
- "boken är för svår", "läraren pratar för mycket", "jag fattar inte varför Napoleon förlorade", "kan du ge exempel på ädelgaser" och "det var fel av Sverige att gå med i kriget" blir inte längre rättelser.

## Kvar från O48
Appen skickar fortfarande bara fasta ord till `/memory` (`ListeningModel.swift`, `learnCorrection`). Den här förbättringen når eleven först när appen skickar elevens egna ord. Det är Angelas beslut, och Toby mäter appens kommandotolk.

**Märkning:** verified live mot servern. Appens del är verified in code, inte på telefon.
