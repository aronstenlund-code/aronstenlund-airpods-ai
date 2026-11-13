# Oscar O55a, O55 och O56: domaren kalibrerad, repetitionsläget på servern testat, Publicera prov testat

Datum 2026-11-13 21:36. Testbanken är `scripts/qa/repetition_bank/`, med 10 påhittade prov och ingen elevtext.
Allt nedan är **verifierat live** mot driftsatta `/exam` (K45), `/drill` (K46, K47) och K49, om inget annat står.

## Kort
| Del | Resultat |
|---|---|
| O55a domaren | **20/20** (10 bra mot 10 dåliga par, ett fel var) |
| R1 tid | **godkänt**: 10 sidfoton + PDF ger frågor på 9,2 s och alla svar på 20,0 s (krav 30/90 s); längsta prov 33,8 s |
| R2 analys | täckning **64/64 mål efter genomgång för hand** (koden: 92 %); **2 frågor utanför materialet av 198**; ämne 10/10, **årskurs 5/10** |
| R3 frågor | **≤ 5 ord 148/198 = 75 %** (krav 80 %), alla ≤ 8 ord 198/198, förståelse 131/198 = 66 % (krav 70 %) |
| R4 svar | långa A-nivå 194/198 = 98 %; korrekta långa 194/198 och korta 197/198 efter genomgång för hand; **3 små faktafel, 1 tomt svar, 1 grammatikfel** |
| R5 / R5b / R5c | **33/33**: RLS håller, aldrig samma ljud två gånger (även mellan konton), delning 409 tills ljudet är klart, import 1,1 s och 0 tecken |
| R10 kostnad | Claude **0,063 USD per prov med 20 frågor** (krav ≤ 0,30); ElevenLabs uppskattat 11 759 tecken = **0,94 USD per prov till listpris** |
| O56 R12 | **41/42**, plus 3/3 i omtestet av ämnesregeln; avvikelsen är en designfråga, se nedan |

## O55a: domaren (`scripts/qa/o55_grade.py`)
- **Kodkontroller:** högst 8 och högst 5 ord, ja/nej-frågor, förståelsefrågor, "utanför materialet", D145, långt svar 40–108 ord.
  En fråga räknas som utanför när den har ett innehållsord som saknas i materialet **och** det korta svaret till under 35 % bygger på materialets ord.
- **Domare:** `/provlage-eval grade` med Sonnet, samma domare som D87-natten. Den bedömer om långa svar är korrekta och på A-nivå, och om korta svar är korrekta.
- **Kalibrering:** 10 bra och 10 dåliga par som jag skrev för hand (`repetition_bank/o55_calibration.json`). De dåliga har var sitt fel: faktafel i kort eller långt svar, 14 ord, utanför materialet (två fall), under A-nivå, D145, ja/nej, utfyllnad till 165 ord och svar på en annan fråga. Resultat: **20/20**, domaren kostade 0,12 USD.
- **Begränsning på riktiga data (verifierat):** domaren ser inte materialet. Av 18 svar den underkände var 5 verkliga fel. Resten var domarens misstag:
  - "fönster" och "språk" som lågtyska lån stämmer med materialet
  - brytpunkten vid 6 månader är rätt uträknad
  - korta svar underkändes för att de inte var på A-nivå, vilket de inte ska vara
  
  Detsamma gäller "utanför"-kontrollen i kod: 11 av 13 utslag var fel, eftersom tal skrivs ut i ord ("sexton") och det engelska materialet besvaras på svenska. Täckningen enligt nyckelorden missade 6 mål som faktiskt täcks. **Därför gäller siffrorna efter min genomgång för hand.** Verktyget sorterar ut kandidaterna, men varje underkännande läses av en människa, som R4 kräver ("Deangelos stickprov").

## O55: K45 `/exam drill` på alla 10 prov (en körning, 198 frågor)
Rådata: `reports/qa/data/2026-11-13-203623-o55-drill-full.json`. Materialet skickades som appen skickar det: foton som bilder, .docx via `doc_text`, PDF och text som text. Ämne och årskurs skickades inte med.

| Prov | Ämne/årskurs | Frågor | Svar | ≤ 5 ord | Förståelse | Långa A | EL-tecken | Claude USD |
|---|---|---|---|---|---|---|---|---|
| bio (10 foton + PDF) | rätt | 9,2 s | 10,8 s | 45 % | 80 % | 20/20 | 11 113 | 0,065 |
| hist (3 foton) | rätt | 6,5 s | 27,3 s | 100 % | 75 % | 19/20 | 11 776 | 0,081 |
| ma1b (PDF) | rätt | 7,1 s | 13,9 s | 58 % | 58 % | 19/19 | 10 761 | 0,063 |
| ke1 (.docx) | rätt | 7,1 s | 12,7 s | 30 % | 90 % | 20/20 | 12 111 | 0,063 |
| fy (text) | **åk 8 (är åk 9)** | 5,5 s | 11,9 s | 100 % | 70 % | 20/20 | 12 193 | 0,062 |
| eng6 (2 foton + text) | **åk 8 (är Engelska 6)** | 6,5 s | 11,2 s | 95 % | 42 % | 17/19 | 10 803 | 0,052 |
| sv1 (.docx) | **åk 8 (är Svenska 1)** | 6,8 s | 12,6 s | 75 % | 70 % | 19/20 | 12 312 | 0,061 |
| ge (PDF) | **åk 8 (är åk 7)** | 7,0 s | 11,9 s | 55 % | 75 % | 20/20 | 11 160 | 0,058 |
| sh1b (text) | **åk 8 (är Samhällskunskap 1b)** | 5,2 s | 13,1 s | 95 % | 60 % | 20/20 | 13 539 | 0,065 |
| re (2 foton + .docx) | rätt | 5,2 s | 13,5 s | 95 % | 40 % | 20/20 | 11 823 | 0,060 |

### Fynd till Kevin
1. **(prio 2) Årskursen gissas till "åk 8" när materialet inte anger den** (5/10), även för gymnasiekurser som Svenska 1, Engelska 6 och Samhällskunskap 1b. Mina material anger med avsikt ingen årskurs, som ofta är fallet med riktiga anteckningar. Antingen ska `grade` vara tom eller "okänd" när den inte går att läsa ut, så att appen frågar, eller så ska kursnivån läsas från innehållet. Användaren kan rätta med en rad, men R2 kräver 10/10.
2. **(prio 2) R3 når inte målen:** frågor med högst 5 ord 75 % (krav 80 %), förståelsefrågor 66 % (krav 70 %). Kemi har 30 % korta frågor och Religion 40 % förståelsefrågor. Exempel på 7 ord: "Varför är balanserad formel viktig vid beräkning?".
3. **(prio 2) Frågor som bara går att förstå med materialet framför sig**, vilket prompten förbjuder: "Hur bygger man gymmodellen?", "Varför drar vattenkokaren tre kilowattimmar?", "Varför ritar man båda linjerna?", "Skillnad mot past simple?", "Betyder lie, lay, lain?". Dessutom en felformulerad fråga: "Vad jämför man nysvenska och fornsvenska?".
4. **(prio 2) Tecken i frågor som ska läsas upp:** "Hur löser du 3x + 5 = 20?" och "Varför ger 2 mol O2 64 gram?".
5. **(prio 1) Tomt svar:** "Vad är imperialism?" (hist) fick både kort och långt svar tomma (`""`). Det blir en tyst fil eller ingen fil alls. `drill_answers` bör göra om frågan, eller returnera fel, när ett svar är tomt.
6. **(prio 3) Små faktafel som inte kommer från materialet (R4 kräver 0):**
   - stäppgräs har "korta, täta rötter" (fel, de har ofta djupa rotsystem)
   - kaktusar har "djupa rötter" (oftast grunda och vida)
   - "Ofta har det billigare alternativet först en hög startavgift" (blandar ihop vilket alternativ som är billigast)
   - grammatikfelet "kungen har ett statsöverhuvud"
   
   Alla fyra finns i det långa svarets andra del, där modellen lägger till egna fakta.
7. **(prio 3) Utanför materialet (R2 kräver 0):** "Varför hade yngre futharken färre runor?" (materialet säger bara att den hade 16) och "Varför har Sverige kungahus?" (svaret lägger till historia som inte står i materialet). 2/198.
8. **Fungerar bra:** D145 gäller för 197/198 (det enda undantaget är det tomma svaret). Långa svar är cirka 90 ord (p50 84–99, max 118). Täckningen är 64/64 mål efter genomgång för hand. Tiderna ligger långt under R1.

## R5, R5b, R5c: `/drill` och delning (`scripts/qa/o55_drill_server.py`, 33/33)
Testet använde två av mina egna par som ingen hade genererat förut, så ljudet gjordes på riktigt.

| Kontroll | Resultat |
|---|---|
| Första sparningen | new_chars 998 = frågor + långa svar; 4/4 filer klara på 4 s; `eleven_multilingual_v2` |
| D145 | `short_end_ms` 6 629 av 30 372 och 8 568 av 33 483 ms (det korta svaret är cirka 22 % av ljudet, som texten) |
| Samma sparning igen | 0 tecken |
| Konto B sparar samma texter | 0 tecken, klart direkt (hashen gäller alla konton) |
| En ändrad fråga | 37 tecken = bara den nya frågan |
| Konto B mot A:s prov | get, status, delete, share, unshare ger 404; PostgREST som B ger `[]`, som anonym 401; ljudfilen utan signatur ger 400 |
| Delning | dela före klart ljud ger 409 "Delas när ljudet är klart (0 av 4)"; samma kod igen; share_info; import 1,1 s, 0 tecken, alla filer klara |
| Mottagarens ändring | kostar bara den frågan (36 tecken), originalet är oförändrat |
| Behörighet | mottagaren kan inte stänga delningen; efter unshare ger import 404 |
| Lagring | 544 562 byte för 2 frågor, alltså cirka 5,4 MB per prov med 20 frågor |

## R10 kostnad (Claude och ElevenLabs var för sig)
- **Claude (verifierat live, `usage.est_cost_usd`):** 0,629 USD för 10 prov, alltså **0,063 USD per prov med 20 frågor**. Med 30 frågor blir det cirka 0,095 USD. Kravet ≤ 0,30 är uppfyllt.
- **ElevenLabs:**
  - **Uppskattat:** frågor + långa svar = 117 591 tecken för 10 prov, i snitt 11 759 per prov. Till listpriset 0,08 USD per 1 000 tecken (**verifierat i docs**, specen §6) blir det **0,94 USD per prov**.
  - **Faktisk debitering:** blindtestet (D151) debiterades med cirka 40 % av listpriset. I så fall blir det cirka 0,38 USD per prov. **Ej verifierat** på riktiga prov.
- **Mitt eget förbrukade i dag:** 1 071 + 83 = **1 154 ElevenLabs-tecken** (budget 2 000), cirka 0,09 USD till listpris. Claude för proven 0,63 USD, domaren cirka 1,45 USD, baslinjen 0,09 USD, kalibreringen 0,12 USD. **Totalt cirka 2,3 USD API.**

## Baslinje: dagens `/study-cards` + `/my-answers suggest` (3 prov)
| Prov | Frågor | ≤ 5 ord | Förståelse | Långa korrekta/A | Korta korrekta | D145 |
|---|---|---|---|---|---|---|
| bio | 12 | 50 % | 25 % | 12/12, 12/12 | 12/12 | 0/12 |
| ke1 | 12 | 8 % | 42 % | 12/12, 12/12 | 12/12 | 0/12 |
| ma1b | 12 | 8 % | 58 % | 11/12, 12/12 | 8/12 | 0/12 |
| hist | – | – | – | – | – | **`/study-cards` 502 `cards_failed` två gånger** |

K45 är tydligt bättre än baslinjen: fler och kortare frågor, förståelse 66 % mot 42 % och D145. `/study-cards` klarar inte historiematerialet (prio 3 och gammal väg, men den används i Provläge).

## O56: Publicera prov (K49, `scripts/qa/o56_publish.py`, 41/42 plus 3/3)
- **R12, publicering nekas när något saknas (4/4):**
  - utan skola eller med tom skola: 409 ["school"]
  - utan datum eller med tomt datum: 409 ["date"]
  - ljudet inte klart: 409 ["audio"]
  - utan ämne: 409 ["subject"] (3/3: utelämnat, tomt och bara mellanslag, på ett prov som sparats utan ämne)
  
  I huvudtestet publicerades provet utan `subject`, eftersom servern tar ämnet från provet. Det är rimligt, eftersom ämnet då redan är ifyllt.
- Ogiltig skolkod och ogiltigt datum ger 409.
- Sökning på skolan hittar provet på **0,3 s** (krav 5 s), och ämnesfiltret fungerar.
- **Inga personuppgifter:** sökresultatet innehåller bara `exam_date, id, items, school, subject, title`. Inget konto-id finns med. `display_name` visas bara med `show_name: true` och försvinner när den stängs av.
  - **Risk (prio 3):** `title` är fritext som eleven skriver, så ett namn i titeln publiceras. Appen kan varna.
- **Hämtning:** 1,4 s och 0 tecken. Mottagarens ändring påverkar inte originalet.
- **RLS:** konto B kan inte publicera eller avpublicera A:s prov (404), och `moderate` ger 403. Tabellerna `drill_publications`, `drill_reports` och `schools` går inte att läsa, ändra eller radera för B (403) eller anonym (401), och `rpc/report_publication` ger 404.
- **Rapporter:** samma konto räknas en gång, 2 rapporter döljer inte, 3 rapporter döljer. Ett dolt prov syns inte i sök, och hämtning ger 404.
- **Avvikelse (prio 3, designfråga):** en okänd rapportorsak ("skräp") godtas och blir "annat" i stället för 400. Det är ofarligt, men README säger fyra värden.

## Risker
- **Banken är inte längre en hållout:** Kevin mäter K45 med samma 10 prov (`scripts/k45-measure.py`). Jag skriver 5 nya prov (O55b) innan Kevin ändrar prompten igen.
- Domarens underkännanden och "utanför"-kontrollen i kod ger många falska utslag på riktiga data, så siffrorna efter genomgång för hand är de som gäller. Förbättring: skicka materialets anteckningar till domaren. Det kräver en ändring hos Kevin i `provlage-eval`.
- Om tryck, uppspelning och tid till första ljud fungerar på enheten testas inte här. Det gör Toby (T18).

## Nästa
1. Kevin: fynd 1–7 (prio 1 är det tomma svaret).
2. Oscar: O55b med 5 nya hållout-prov och omtest av R2–R4 efter Kevins ändring. Kör `python -I -X utf8 scripts/qa/o55_grade.py drill`, cirka 0,6 USD Claude plus domare.
