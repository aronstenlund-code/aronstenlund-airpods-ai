# Vilka fall som körs om efter en rättning (Oscar, K122-återspelningen)

Inga riktiga modellanrop och 0 ElevenLabs: allt körs lokalt utan nät (deno utan `--allow-net`).
Det sparade svaret återanvänds. Om Kevin har ändrat en prompt så att svaret borde se annorlunda ut, skriver Oscar ett nytt svar i samma fil.

## Så körs det
```bash
DENO=deno   # eller sökvägen till deno
# bankfallen (scripts/qa/cases.json och backend/scripts/k122-cases.json)
(cd backend && $DENO run --no-lock --allow-read --allow-write --allow-env scripts/k122-replay.ts --case <ID,ID> --out ../reports/qa/k122-out-<datum>)
# Oscars egna fall
python3 scripts/qa/o103/run.py $DENO --only <ID,ID>
python3 scripts/qa/o104/run.py $DENO --only <ID,ID>
python3 scripts/qa/o105/run.py $DENO --only <ID,ID>
(cd backend && $DENO run --no-lock --no-check --allow-read --allow-env ../scripts/qa/o105/style_voice.ts)
```
**Jämför** med förra körningen: `said`, `done.source`, `source_fallback`, `source_missing`, `safety`, felkod och `json` (poäng, frågor). Ett skript som gör det finns i rapporten O103 del 2.

## Ändrat område → fall
| Ändring i | Kör om |
|---|---|
| Svarsprompten (`answer/prompt.ts`, SURE OR SEARCH, RELATION, sammanfattning) | bank: F01 F03 F05 F10 F14 S01 S03 U01 U05 B05 L01 L03 M01 P03 P04 O01 · o103: K1 K2 K3 N1 N2 N6 |
| Kris (`answer/crisis.ts`, `[[KRIS]]`, kontrollfrågan) | o103/o102: de egna krisfraserna (`--endpoint answer`, se O102 och O103 del 2) · bank: P03 (1177) · o103: N5 |
| Webb och källa (K108, K116, D254, `mustSearch`, källraden, språk i webben) | bank: W01 R01 R02 R04 F05 · o103: RQ1 RQ2 RQ3 N3 N4 |
| Talformat (`voiceText`, K115, D46, år, decimaler, telefonnummer) | o103: N1–N6 · o105: TT1–TT5 · bank: F05 F10 F14 C05 T03 P03 |
| Provets drill (plan, kortkontroll, slutkontroll, påfyllnad, trim, `isRecall`, `dropNearSame`) | o104: PX1–PX6 PF1 PF2 · bank: EX1 EX2 HT1 |
| Svarsskrivaren (`drill_answers`, `drill_one`, display/screen) | o104: DA1 DO1 PX1–PX4 PF1 PF2 |
| Rättningen (`grade`, `numericCheck`, `correctPoints`, K1.7, övningsläget) | o104: G1–G7 · bank: EX4 |
| Ledtråd (`hint`) | o104: H1 · bank: EX3 |
| Provläge (`mode: tutor`, `<note>`, `quiz_key`, `last_assistant_turn`) | o104: T1–T4 · bank: E01 PE1 PE2 PG1 |
| Komprimera (`compress`) | o103: CS1 CE1 CS2 CX1 · o105: CO2 · bank: CO1 |
| Modellen nere (`provider_*`, i18n) | o103: D1–D6 |
| Hjälpen (`help`, `docs/HJALP.md` / `shared/hjalp.ts`) | o105: HL1–HL5 · bank: HE1 HE2 HT1 |
| Säg i AirPods: stil och röstval (`drill/style.ts`) | o105: ST1–ST5 VO1–VO5 |
| Lyssnarläget (auto, frågegrinden, `isClearQuestion`, `isCutOff`, direktvägen) | o106: A01–A34 (`python3 scripts/qa/o106/run.py $DENO`; för tydliga frågor är c1 grinden ja/nej och c2 svaret) |
| Provläge från foto (`parse`, talad uppgiftstext, rättning med siffror) | o107: P1–P6 PT1 PT2 D1 D2 G1–G8 H1 H2 (`python3 scripts/qa/o107/run.py $DENO`) |
| Minnet, studieprofilen, studieplanen | `(cd backend && $DENO run --no-lock --no-check --allow-read --allow-env ../scripts/qa/o107/memory_plan.ts)` |
| Delning och publicering (live) | `o107_share_live.py` i oscar-live.yml |
| Socialt, Rizz, intervju | bank: O01 RZ1 RZ1s I01 |

Livetester som inte går genom K122:
- `o100b_retest_live.py` (+ `--s5`) efter ändringar i IP, testläge eller kroppsgränser;
- `o101_reviewer_today.py` efter ändringar i krediter eller granskarens väg;
- `o99_credits_back.py` den dag krediterna är tillbaka.
