# K102 (D230): förståelsefrågor, fulla prov och gräns för warm; K93-livetestet startat

Kevin (moln), 2026-11-18 12:40. 0 ElevenLabs. Mätningen kostade 0,03 USD före och 0,05 USD efter, bara Claude. Tester: 720/720.

## 1. Varför utan orsak i texten blir en förståelsefråga, minst hälften förståelse
- **Den sista kontrollen:**
  - En varför-fråga som texten inte ger någon orsak till görs om till en förståelsefråga som texten bär: "Förklara hur X hänger ihop med Y", "Vad blev följden av X?", "Jämför X och Y", "Hur påverkade X Y?". Den blir aldrig en vad-, när- eller vem-fråga. Den nya frågan får bara gälla ett samband som materialet själv gör.
  - Är färre än hälften av frågorna förståelsefrågor görs rena minnesfrågor om, de tidigaste först.
- **Nytt i koden:**
  - `isUnderstanding` räknar sådana frågor.
  - "Förklara …" och "Jämför …" slutar med punkt, inte med frågetecken.
  - "materialet", "texten säger/visar" och "the text" räknas som att frågan lutar sig mot materialet, och en sådan fråga avvisas.

## 2. Borttagna dubbletter fylls på
- Tas frågor bort som dubbletter skriver ett anrop till svarsmodellen (Sonnet) lika många nya förståelsefrågor.
- De får inte fråga det de kvarvarande frågar, och inte förutsätta något som inte står i texten.
- De placeras i det avsnitt de handlar om.
- `usage.final_check` visar `{fixed, dropped, refilled, refill_ms, understanding, questions}`.

## Mätt på Oscars fem material
Skriptet `scripts/k102-measure.py` kör exam drill som appen gör (utan svar och utan save). Före = run 44294766224, 11:27, med den förra kontrollen. Efter = run 44295577864, 11:33. **Verifierat live.**

| Material | Frågor före → efter | Förståelse före → efter | Sista kontrollen (ms), efter | Påfyllning (ms) |
|---|---|---|---|---|
| ekosystem | 11 → **14** | 0,73 → **0,86** | 1 200 | 939 (2 nya) |
| printing | 13 → **14** | 0,77 → **0,79** | 2 201 | 678 (1 ny) |
| ljud | 8 → 7 | 0,75 → **0,86** | 1 503 | 2 055 (0 nya) |
| vasa (foto) | 13 → **14** | **0,23 → 0,71** | 3 116 | 783 (1 ny) |
| inflation | 13 → **14** | 0,69 → **1,00** | 2 248 | 1 582 (1 ny) |

- **Målen:**
  - Minst hälften förståelsefrågor nås i alla fem.
  - Fullt prov (14) nås i fyra av fem.
- **Tiden:** den sista kontrollen tar 1,2–3,1 s och påfyllningen 0,7–2,1 s. Ett helt prov utan svar tar 11–14 s.
- **Ljud fick 7 frågor av 10:** påfyllningen gav 0, eftersom de nya frågorna liknade de kvarvarande för mycket och filtrerades bort. Materialet är kort (1 072 tecken). Kvar att lösa: en andra påfyllning, eller ett lägre mål för korta material.
- **Läst för hand (efter):**
  - Inga påhittade samband hittade.
  - Vasa 14 frågade "… och hur visar materialet den skillnaden?". Den hade lutat sig mot materialet, och den sortens fråga avvisas nu (rättat efter mätningen, testat med fejk).
  - Vasa 13 är en dubbelfråga ("Vad var Dackefejden och hur hänger den ihop med …"). Den är godtagbar, men kunde delas.
- **Om kostnaden:** siffrorna är serverns egen uppskattning (`usage.est_cost_usd`) och är lägre än i Oscars skript, som räknar på ett annat sätt.

## 3. Gräns för warm (Oscar O85)
- `{"action":"warm"}` får högst **30 anrop per minut och IP-adress**. Fler ger 429 med `retry-after`. Det rymmer en hel skolklass bakom samma nät, eftersom appen värmer högst en gång per 2 minuter (A147).
- Själva arbetet görs högst en gång per 15 s och instans.
- `warm` fungerar nu även med token, eftersom appens klient kan skicka en. Den läser inga kontodata.
- **Verifierat live** (run 44295583040):
  - 30 anrop gav 204, och anrop 31–36 inom samma minut gav 429.
  - `warm` med token gav 204.
  - `list` utan token gav 401, med falsk token 401, och ett testkonto 200.
- Räknaren gäller per instans. Med flera instanser kan fler än 30 anrop per minut komma igenom, och det räcker mot överbelastning.
- Migreringen `20261118120001_k100_warm_drill.sql` (pg_cron) behövs inte längre, eftersom appen värmer i stället (D230). Den får ligga kvar oanvänd tills Deangelo säger annat.

## K93-livetestet
- **run 44294239066**, 11:23–11:59 UTC. Testkontot är 61e59f02 ("K93 markör 1795001015"), som Deangelo lade in 11:50.
- **Verifierat live:**
  - `became_admin`: ja.
  - `admin_no_402_no_charge`: ja. Med 2 000 tecken gav save och start 200, inget drogs (`used` 0), och `cost` och `list` visade `unlimited`.
- **Borttagningen är inte testad.** Klockan 11:59:33 gav ett quota-anrop 500. En nystartad instans fick "connection reset" mot databasen (`rpc/use_drill_chars`). Skriptet läste felsvaret som "inte längre admin", och efterkontrollen såg därför fortfarande `unlimited` (`after_counted_and_refused: false`). Felet låg i skriptet och i ett tillfälligt nätverksfel, inte i admin-logiken.
- **Rättat:**
  - Läsningar (select och rpc som bara läser: `is_credit_admin`, `credit_balance`, `use_drill_chars` med 0) görs om en gång vid nätverksfel. Skrivningar görs aldrig om. Testat med fejk.
  - `k93-live.py` godtar bara svar med status 200.
- **Ny körning** startad, med ett nytt testkonto och ett nytt markörprov (run-id står på tavlan).

## Nästa
- **Oscar:** O79 igen med D230; mät O84 kallstart när appen värmer (A147).
- **Kevin:** påfyllningen för korta material; resultatet av K93.
