# Kevin K15: Övningsprov fråga för fråga med rösten

Datum 2026-11-10 · Uppgift: `prompts/queue/kevin.md` K15 (Aron 2026-11-09), pausad 09:45 för K21 och klar efter · Driftsatt (den sista är Deploy backend 42776943272, commit e36ef0a, och "en poäng"-rättningen efter). Allt nedan är **verified live** (anrop mot driftsatt `/exam`, `scripts/k15-eval.py`) där inget annat står. **Inte testat på telefon**, och appens del (A16) finns inte än.

## Resultat (två övningsprov skrivna för Lumen, `scripts/k15-practice-exams.json`)
- **Matte åk 9** liknar ett nationellt prov: 12 uppgifter med 3a och 3b, poäng som (E/C/A) och facit på 8 av dem.
- **Historia åk 9** är 10 instuderingsfrågor utan poäng och facit.

| Krav | Matte åk 9 | Historia åk 9 |
|---|---|---|
| Rätt uppdelning (numrering, ordning, 3a och 3b) | **12/12** i rätt ordning | **10/10** |
| Poäng per uppgift | 3/3 kontrollerade rätt (4: 2/0/0, 8: 1/1/0, 11: 0/1/2) | inga poäng, och varje fråga rättas som rätt eller fel (1 E-poäng) |
| Facit eller "eget svar" | 8 "facit". De 3 utan facit har Lumens eget svar, och **3/3 är rätt** (37,5 %, x = 10, y = 9) | 10/10 "eget svar" (inget facit fanns) |
| Ämnesord per fråga | ja ("procent", …) | ja ("urbanisering", "Sarajevo 1914", "Versaillesfreden" …) |
| "fråga 7", "fråga sju", "uppgift 3b", "nästa", "hoppa över", "upprepa" | **6/6** | **5/5** ("3b" finns inte) |
| Rättning med förklaring, rätt svar ger poäng och fel ger inga (D87) | **10/10** (5 rätta och 5 fel, talade) | **5/5** bedömda. Ett anrop fick 429 (`/exam` tillåter 12 per minut och mätningen gick för fort) |

Uppläsningen börjar till exempel: "Fråga ett. Beräkna femton procent av åttahundrafyrtio kronor. Den ger en poäng."

Filer: `reports/eval/k15-2026-11-10-first.json` är första körningen (rättning 14/16, två mattesvar räknades fel, se nedan), och `reports/eval/k15-2026-11-10.json` är den sista.

## Vad som byggts (DECISIONS: se rad "K15" nedan)
**`POST /exam` `parse`:**
- Tar nu också `{"text": "…"}`, alltså inklistrad text eller en PDF:s textlager, utöver sidbilder.
- Varje uppgift får:
  - `topic`, 1–3 ord, för "testa mina svagaste" (K9 `weak_areas`; appen räknar rätt och fel per ämnesord);
  - `spoken`, så som Lumen läser upp den: talen i ord och poängen sist;
  - `answer_source`, som är "facit" eller "eget svar".
- Saknas facit skriver Sonnet 5.5 ett A-nivåsvar i ett extra anrop med 60 s tidsgräns. Felar det anropet kommer uppgifterna ändå tillbaka, utan eget svar. Med `own_answers: false` stängs det av.

**`nav`** (ny, bara kod, kostar inget): `{"utterance", "current", "nos"}` ger `next`, `prev`, `goto` (med index), `skip`, `repeat`, `stop`, `results` eller `answer`.
- Den förstår "fråga sju", "uppgift 3b", "fråga tre", som betyder 3a, och fraser som "kan vi ta fråga sju".
- Allt annat är ett svar som ska rättas. "sju" ensamt är alltså ett svar och ingen navigering.

**`grade`:**
- Med `practice: true` börjar återkopplingen med "Rätt.", "Delvis rätt." eller "Inte riktigt." och säger rätt svar och varför, i två till tre meningar.
- En fråga utan poäng rättas som rätt eller fel.
- Rättat efter första körningen: när eleven säger resultatet först och skälet efter "för" eller "eftersom" ("trehundrasjuttiofem kronor, för tjugofem procent av trehundra är sjuttiofem") räknas resultatet, inte det sista talet.

## Till Angela (A16)
1. Lägg till övningsprov med `parse`, med text eller bilder.
2. Läs upp `tasks[i].spoken`.
3. Skicka varje yttrande till `nav`. Är svaret `answer`, skicka det till `grade` med `practice: true` och läs upp `feedback`.
4. Visa "Fråga 3 av 12".
5. Räkna rätt och fel per `topic` och skicka det som `concept_stats`, så att "testa mina svagaste" fungerar.
6. Visa resultatet i slutet med `summary`.

## Risker och kvar
- **Prov från PDF:** jag har bara testat med text. En PDF utan textlager måste gå som bilder (D84-flödet).
- **Gränsen på 12 per minut i `/exam`:** en elev som svarar snabbt hinner inte nå den (en rättning tar 2–4 s). Mätskriptet gjorde det.
- Ett eget svar kan vara fel. Det är märkt "eget svar" så att appen kan säga det. Matten var 3/3 rätt här.
- Två nationella prov i original testades inte (upphovsrätt). Proven är skrivna för Lumen och liknar dem.

## Kostnad
Ungefär 0,07 USD (tre körningar).
