# O83: det integritetspolicyn lovar (Ke78), och omtest av mina fynd, Oscar (moln)

**Resultat:**
- **Del 1, foton raderas:** stämmer live. Ett använt foto går inte att läsa igen, och ett foto i ett nekat anrop raderas direkt.
- **Del 2, sammanfattningen:** den sparas på telefonen, och på servern bara när användaren slagit på delning. Men **policyutkastet nämner inte att lyssnarlägenas fråga och svar går till analysloggen** (`qa_log`, med samtycke), och inte heller den delade historiken (F1, till Kelly/Deangelo).
- **Del 3, radera kontot:** väntar på K101.
- **Omtest:** Kevins rättelser av O78, O80, O81, O82 och K91 håller.

0 ElevenLabs. Claude cirka 0,02 USD (två exam drill på ett foto) plus Haikus röstval. Actions 44270428584, 2026-11-18 08:50–08:52 UTC.

## Del 1: foton och dokument ligger inte kvar
**Kod (verifierat i kod):**
- Foton laddas upp till den privata lagringen `drill_material` med signerade adresser (`exam` `upload_urls`, giltiga i 2 h).
- `exam/drill.ts` läser dem och tar bort dem i `finally` efter analysen, och i `catch` när läsningen misslyckas (K53, B4).
- `drill-purge` (pg_cron var 15:e minut) tar bort filer äldre än en timme, till exempel foton som laddades upp men aldrig användes.
- Word-filer (`doc_text`) och text sparas aldrig, eftersom de bara läses i anropet.

**Live (verifierat live):**

| Steg | Svar |
|---|---|
| `upload_urls` count 3 | 200, 3 adresser, `expires_in 7200`; PUT 200, 200, 200 |
| exam drill med foto 1 | 200, 4 frågor ("Fotosyntesen: hur växter tar energi från solljuset …") |
| **samma foto igen** | **422 `material_missing` "1 av 1 bilder kom inte fram. Ladda upp dem igen."**, alltså raderat |
| foto 3 tillsammans med ett annat kontos path | 403 `forbidden` "Bilden tillhör inte det här kontot." |
| **foto 3 igen** | **422 `material_missing`**, alltså raderat också vid nekande |
| foto 2 laddades upp men användes aldrig | purge-jobbet ska ta det; kontrolleras med SQL nedan |

## Del 2: var sammanfattningen från lyssnarlägena sparas
**Kod (verifierat i kod, inte på enhet):**
- Sammanfattningen görs av servern i `/answer` och sparas **på telefonen** i historiken (`Lumen/Core/History/HistoryStore.swift`, en fil i appens katalog).
- Den skickas till servern (`shared_history`) **bara om användaren har slagit på delning** (D57, `FeedbackClient.sync`, som också raderar på servern när delningen stängs av). Den sparas högst 12 månader (daglig rensning enligt `shared-history/handler.ts`).
- **Dessutom:** lyssnarlägenas fråga (det användaren sa) och svaret skickas till `qa_log` för Arons analys, med siffror maskerade. Det sker när samtycket version 5 är godkänt (D116, `answer/qalog.ts`, `ListeningModel.swift:2597`). Raderas efter leverans, högst 14 dagar.

**F1 (medel, till Kelly via Deangelo): policyutkastet (grenen `kelly/ke78-integritet`) säger bara "Det som sparas är en kort sammanfattning".** Det stämmer inte helt:
- (a) sammanfattningen sparas på telefonen, och på servern bara om delningen är på (12 månader);
- (b) frågan och svaret i lyssnarlägena går till analysen (`qa_log`) efter samtycke, och raderas efter leverans eller högst 14 dagar. Avsnittet "Analys av frågor och svar" nämner bara frågor och svar som skapas i appen.

Förslag till text: "Det du säger och svaret sparas i historiken på telefonen. Delar du historiken (Inställningar) sparas den också hos oss i högst 12 månader. Om du godkänt analysen skickas frågan och svaret till utvecklaren och raderas efter leverans, högst 14 dagar." Den gula punkten "om sammanfattningen sparas på telefonen eller på servern" kan då strykas, och den om foton likaså (del 1 är verifierad live).

## Omtest av mina fynd från i morse
| Fynd | Resultat |
|---|---|
| O78 F1 (hög): återbetald prenumeration återaktiveras | **rättat**: lokalt 8/8 (`scripts/qa/o78_purchase_test.ts`) |
| O78 F2: andra REFUND | rättat (Kevin: `refunded: 0, already: true`) |
| O80: hakparenteser | rättat; 7/7 lokalt |
| O80 F1: inga taggar live | inte omtestat live ännu (väntar på Kevins svar från loggen) |
| O82 F1: inbjudningstaket | **rättat i SQL** (`invite_reward`, migrering 20261118100001 för Deangelo); 7/7 lokalt mot reservvägen; den atomiska SQL-vägen är otestad tills migreringen är körd |
| O82 F3/F4 | rättat (Kevin: `invite_not_new`, `already`); 7/7 lokalt |
| O81 F1: Blanda och samma text | **rättat**: två prov med samma text fick samma fyra röster (Sam, Bertil, Elin, Ale). Kostnaden 300 i prov 2 är mitt skripts fel, eftersom prov 1 aldrig startades och därför inte hade något ljud att återanvända |
| O81 F2: voice_reason | **rättat**: "med kinesisk brytning" → Karin, "Ingen röst med kinesisk brytning finns, så en stadig, jämn och tydlig röst." |
| K91: testspärren gällde inte konto B | **rättat**: efter fejkat kvotfel och borttaget prov fick både A och B `audio_unavailable: true` och `used 0 → 0` |

## SQL för Deangelo (läs; kör den första tidigast 10:06 UTC)
```sql
-- 1) de tre testfotona ska vara borta (väntat 0 rader); det oanvända tas av purge-jobbet
select name, created_at from storage.objects where bucket_id = 'drill_material' and name in ('6f4e4694-1769-4194-90d2-68bb5bd5da2a/cae80169-2d74-4f5f-b856-e080978e0d41.jpg', '6f4e4694-1769-4194-90d2-68bb5bd5da2a/dc067f13-39d4-4cc5-9d82-f7a38f776853.jpg', '6f4e4694-1769-4194-90d2-68bb5bd5da2a/b66b87bd-c56c-440f-8bad-ac6d746ae100.jpg');
-- 2) inga gamla filer kvar i lagringen (väntat 0)
select count(*) as filer, min(created_at) as aldsta from storage.objects where bucket_id = 'drill_material' and created_at < now() - interval '90 minutes';
-- 3) purge-jobben finns och är på
select jobname, schedule, active from cron.job where command ilike '%drill-purge%' or command ilike '%shared_history%' or command ilike '%qa_log%';
-- 4) hur länge det delade och analysen faktiskt ligger kvar (väntat: shared_history högst 12 mån, qa_log högst 14 dagar)
select 'shared_history' as tabell, count(*), min(created_at) from shared_history union all select 'qa_log', count(*), min(created_at) from qa_log;
```

## Kvar
- Del 3, när K101 är klar: att radera kontot tar bort kontots eget och lämnar delat ljud.
- O80 F1 live, när Kevin har svarat.
