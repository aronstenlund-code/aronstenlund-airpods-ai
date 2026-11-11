# Oscar O47: Rättelser och appkommandon med NYA egna ord (O22b), offline

Datum: 2026-11-11, 15:31 (svensk tid)
Uppgift: stående uppgift (PLAN 2b). Kevins omgång 11 lade mina O22-fall i hans tester (O46: 20/20 och 9/10). Det här är **nya** oberoende formuleringar. Jag skrev dem 15:30 utan att läsa hans nya mönster.

**Skript:** `scripts/qa/o22b_corrections_offline.mjs` (`detectCorrection` i `memory/settings.ts`, `detectAppCommand` i `answer/appcommand.ts`).
**Rådata:** `reports/qa/data/2026-11-11-153125-o22b.json`.
**Kostnad:** 0 USD. **verified in code** (offline mot de driftsatta filerna).

## Resultat
| | O22-fallen (nu i Kevins tester, O46) | **Nya fall (O22b)** |
|---|---|---|
| Rättelser med egna ord blir en inställning | 20/20 | **5/20** |
| Vanliga meningar blir inte rättelser | 15/15 | **15/15** (0 falska) |
| Appkommandon med egna ord | 9/10 | **4/10** |
| Vanliga meningar blir inte kommandon | 10/10 | **10/10** (0 falska) |

**Rättelser som inte känns igen (15)** blir ingen inställning, eftersom `settings.ts` bara arbetar i kod, utan modell:
- **Kortare:** "kan du korta ner svaren lite", "för långa svar, seriöst", "snabbare, bara det viktigaste", "bara svaret, inget mer", "jag orkar inte höra hela föreläsningen".
- **Längre:** "utveckla gärna mer", "kan du ta det lite längre nästa gång".
- **Enklare:** "kan du förklara det mer basic", "förenkla".
- **Exempel:** "ge alltid ett exempel", "typ ett exempel från verkligheten skulle hjälpa".
- **Noggrannare:** "det där stämde inte alls", "fel svar", "nej nej, det var helt galet", "är du säker? det låter fel".

**Kommandon som inte känns igen (6):**
- "tillbaka till vanliga läget" (byt till frågor)
- "dags att plugga inför provet nu" (Provläge)
- "pausa en sekund"
- "Lumen, håll tyst lite"
- "jag har anställningsintervju imorgon, öva med mig" (Intervjuläge)
- "stopp"

"sluta lyssna nu" blir **paus**. Det är Kevins design (`appcommand.ts:52`, D74: "sluta lyssna en stund" = paus), så det räknas inte som fel. Aron kan avgöra om "sluta lyssna" ska betyda stopp.

## Bedömning
Samma mönster som för alla ordlistelager i går och i dag:
- författarens fall klaras fullt ut;
- nya formuleringar klaras till 20–40 %;
- falska träffar är 0.

Varje omgång med fler mönster flyttar bara gränsen.

**Rekommendation till Kevin (prio 3):** låt modellen klassa rättelser och kommandon som en flagga i sitt svar, eller en liten Haiku-kontroll när koden inte hittar något men yttrandet är kort och riktat till Lumen. Koden kan vara kvar som snabbväg.

Lägg **inte** in de här 46 fallen i testerna, utan använd dem som en hållout, så att nästa mätning blir oberoende.
