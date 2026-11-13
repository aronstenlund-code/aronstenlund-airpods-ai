# K54 och K55: första meningen som svar, första ljudet och verklig kostnad (Kevin, 2026-11-13 23:45)

Status för varje påstående: **verifierat live**, **verifierat i docs** eller **antagande, ej testat**.

## K54: det korta svaret är svaret (D162)
- **Prompten:** det korta svaret är en mening, två bara om det behövs, högst 25 ord. Det ska innehålla själva svaret: orsaken, mekanismen, faktumet eller skillnaden. En inledning som "Fotosyntes är en viktig process i växterna." godtas inte. Resten av det långa svaret bygger vidare utan att upprepa.
- **Kontroll i koden** (`isIntroShort`): ett kort svar som börjar som en inledning görs om. Det gäller "är en viktig …", "handlar om", "Det finns flera …", "Det här är …", ett svar som slutar med kolon, fler än två meningar eller fler än 35 ord. Vid sista försöket godtas svaret hellre än att det uteblir.
- **Mätning live:** Oscars tio prov, med ämne och årskurs som appen skickar dem; `reports/eval/k45-drill-2026-11-13.json`.

| | Före K54 | Efter K54 |
|---|---|---|
| Korta svar | 142 | 143 |
| Median, ord | 18 | 20 |
| Högst 25 ord | 132 (93 %) | 135 (94 %) |
| Inledningar enligt regeln | 0 | 0 |
| Tomma | 0 | 0 |
| D145 (långt börjar med kort) | 142/142 | 143/143 |

- **Exempel efter ändringen:** "Fiskar dör för att det blir syrebrist i vattnet, eftersom bakterier förbrukar syret när de bryter ner döda alger." och "Ryssland lämnade kriget därför att bolsjevikerna tog makten 1917 och ville få slut på kriget."
- **Med årskurs i anropet** blev den rätt i 10 av 10 prov. Utan årskurs är den tom (K52).

## K55: tid till första ljud och verklig kostnad
**Ett fel hittades och rättades.** Den första riktiga mätningen gav 15 av 30 misslyckade filer. Orsaken var att Arons ElevenLabs-plan tillåter **högst 3 samtidiga anrop** (ElevenLabs svarade 429 "concurrent_limit_exceeded"). Varje `status`-anrop startade en egen generering, så flera körde parallellt. Rättningen:
- **Globalt tak:** `claim_drill_audio` håller högst `drill_settings.tts_concurrency` = 2 filer under arbete för hela servern. Det lämnar 1 plats till appens live-röst, och ett lås hindrar flera instanser från att överskrida taket.
- **429 är inget fel:** filen läggs tillbaka i kön utan att räknas som försök, och genereringen väntar på en ledig plats i stället för att sluta.
- **Misslyckade filer** görs om när samma text sparas igen. De 15 från mätningen lades tillbaka och blev klara.
- **Rättvis ordning:** varje provs första fråga och första långa svar tas före resten av kön, så ett nytt prov får snabbt sitt första ljud.

**Mätning live efter rättningen** (`scripts/k55-live.py`, `reports/eval/k55-live-2026-11-13.json`): röst A, hela flödet som appen kör det.

| Steg | Historia (3 foton, 15 frågor) | Geografi (PDF-text, 12 frågor) |
|---|---|---|
| Skapa frågor → frågorna på skärmen | 7,9 s | 5,0 s |
| → alla svar klara | 21,4 s | 14,0 s |
| Starta prov → **första frågans ljud spelbart** | 15,8 s, men kön innehöll då 15 gamla filer som gjordes först | **2,0 s** |
| Starta prov → allt ljud klart | 44,9 s (30 egna och 15 gamla filer) | **19,8 s** (24 filer) |
| Misslyckade filer | 0 | 0 |

- **R1 klaras:** första ljudet ska vara spelbart inom 20 s efter Starta prov, och det tog 2,0 s med fri kö. Med prioriteringen kommer ett nytt provs första fråga före andra provs filer.
- **Kapacitet:** med 2 samtidiga filer gör servern cirka 1,2 filer per sekund. Ett prov med 20 frågor (40 filer) blir klart på cirka 35 s när inget annat genereras samtidigt. **Antagande, ej testat:** flera användare samtidigt delar på samma 2 platser. Det kräver en större ElevenLabs-plan eller kö-uppskattning i appen.

**Verklig kostnad per prov, Claude och ElevenLabs var för sig:**

| | Historia, 15 frågor | Geografi, 12 frågor | Uppskattat för 20 frågor |
|---|---|---|---|
| Claude (frågor och svar) | 0,050 USD | 0,032 USD | cirka 0,065 USD |
| ElevenLabs, tecken | 9 281 | 5 405 | cirka 12 400 |
| ElevenLabs, **debiterade krediter** (`character-cost`) | **3 713** | **2 163** | **cirka 5 000** |
| Krediter per tecken | 0,40 | 0,40 | 0,40 |
| Lagring | 5,2 MB | 3,0 MB | cirka 7 MB |

Krediterna i kronor beror på vad en kredit kostar i Arons plan. Det ser han i elevenlabs.io › Subscription. Räknat som listpriset 0,08 USD per 1 000 blir det cirka 0,40 USD per prov med 20 frågor och röst A, och cirka 0,20 USD med C (Flash).

## Krock: 20 frågor som standard men 15 per månad
Ett nytt konto som skapar ett prov med standardinställningen 20 frågor (D146) får 402 vid Starta prov, eftersom gränsen är 15 per månad (D155). Det första provet kan alltså inte sparas med standardinställningen. Jag mätte därför med 15 frågor. Förslag:
- Appen föreslår högst det som finns kvar av månadens frågor.
- Alternativt gör servern så många frågor som ryms och säger det.

Beslutet är Deangelos. Frågan står på tavlan, och Angela har fått en anteckning.

## Tester
`deno task test`: 551 gröna och `check` ren. Nya tester täcker inledningar (görs om, godtas vid sista försöket) och 429 (tillbaka i kön utan försök, fem 429 i rad och ändå klart; ett tidigare misslyckat ljud görs om).

## Kostnad i natt
- **Claude:** cirka 0,6 USD för K54-mätningen och 0,13 USD för K55.
- **ElevenLabs:** cirka 23 200 tecken, ungefär 9 300 krediter, för tre prov i K55, inklusive den första misslyckade körningen.
