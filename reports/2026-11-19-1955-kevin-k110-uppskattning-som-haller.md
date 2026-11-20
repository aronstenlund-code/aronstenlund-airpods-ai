# K110 (D241): uppskattningen håller, Lübeck och printing

Kevin (moln), 2026-11-19. **0 ElevenLabs.** Testkonton, inga webbsök. Tester: **779/779**. Claude cirka 0,35 USD (en kostnadsmätning med 10 prov, plus kontroller). Commits cb79fb5a (kapningen, Lübeck, påfyllningen), 2af40840 (gränsen) och 049ab7bc (skriptet). Deploy-backend 348 och 349 gröna.

## 1. De långa svaren kapas i koden till `long_words`
- **`capLong`** behåller det korta svaret och sedan de hela meningar av resten som ryms. Skärmtexten (`screen.long`) kapas efter samma meningar, så att det som syns och det som hörs stämmer.
- **Svarsprompten** sa förut att svaret fick gå över med "högst en femtedel". Nu står det "about <long_words> words and never more", och viktigast först.
- **Svaren görs inte kortare än `long_words`** (D241 punkt 3), och `long_words` är oförändrat.
- **Live** (k110-cost, run 44588946481):
  - De långa svaren har högst 89 ord vid gränsen 90.
  - Kapningen behövdes bara en gång på tio prov (93 ord → 90). Det var promptändringen som tog bort överlängden, och kapningen är garantin.
- Verifierat i test (`exam/k110_test.ts`).

## 2. Uppskattningen är en övre gräns
- **Mätt live** på Oscars fem material (Vasa är Lübeck-materialet, och printing är med), med 3 och 12 frågor, som appen gör och med serverns `action: "cost"`:

  | Material | 3 frågor: kostnad (per fråga) | 12 frågor: kostnad (per fråga) | Tecken per ord, långa svaret | Fulla |
  |---|---|---|---|---|
  | ekosystem | 1 643 (548) | 5 617 (468) | 6,18 / 6,06 | 3/3, 12/12 |
  | printing | 1 566 (522) | 5 623 (469) | 5,76 / 5,72 | 3/3, 12/12 |
  | ljud | 1 446 (482) | 4 854 (404) | 5,90 / 5,81 | 3/3, 12/12 |
  | Vasa (Lübeck) | 1 612 (537) | 5 504 (459) | 6,07 / 5,98 | 3/3, 12/12 |
  | inflation | 1 619 (540) | 5 403 (450) | 6,21 / 6,23 | 3/3, 12/12 |

- **Gränsen räknas som 75 tecken per fråga plus 6,3 tecken per ord i det långa svaret.**
  - Kapningen garanterar högst `long_words` ord.
  - Uppmätt är högst 6,23 tecken per ord, och frågan är i snitt högst 72 tecken.
  - Vid 90 ord blir det **642 per fråga**. Den högsta verkliga kostnaden var 548, så gränsen ligger 17 % över.
- **Verklig kostnad ≤ uppskattning i alla tio prov:**
  - 3 frågor: högst 1 643 mot 1 926.
  - 12 frågor: högst 5 623 mot 7 704.
- **`fits` räknas på gränsen.** Med 1 500 krediter blir `fits` 2.
  - Ett prov har minst 3 frågor, så texten säger "det räcker inte till ett prov (minst 3 frågor)".
  - Det nya fältet `min_questions: 3` gör att appen kan säga det med Fyll på (D241 punkt 2).
- **Det betyder att ett nytt konto inte kan göra något prov på gratiskrediterna** förrän välkomsten är på, eftersom den kräver Team ID (D241 punkt 4, TILL-ARON #31). Det är den ärliga följden av en gräns som håller.
- **Live** (run 44591156654):
  - `drill` med 12 frågor: 402, "Ett prov med 12 frågor kostar cirka 7 704 krediter. Du har 1 500 kvar, det räcker inte till ett prov (minst 3 frågor).", `fits` 2, cirka 1 s, ingen Claude-körning, och kvoten är oförändrad.
  - `drill_answers`: 402, `fits` 2, 618 per fråga, eftersom de riktiga frågornas längd används.
  - Delen med 3 frågor i samma körning fick 429, eftersom skriptet gjorde för många provanrop per minut på samma konto. Skriptet har rättats, och omkörningen (run 44591573467) gav alla kontroller gröna: 3 frågor kostade **1 594** mot gränsen 1 926, `attest_challenge` svarade 503, och QA-anrop från Actions gick igenom.
- `drill_answers` räknar de riktiga frågornas längd plus 6,3 tecken per ord.

## 3. Lübeck och printing: roten
- **Lübeck, verifierat i koden: exemplet i sista kontrollens prompt skapade frågan.**
  - Där stod ordagrant: skriv "Varför hade kronan skulder till Lübeck?".
  - Vasa-materialet säger bara "Kronan hade stora skulder till Lübeck efter kriget", utan orsak.
  - Prompten lärde alltså modellen en varför-fråga som materialet inte kan besvara. Därför kom den tillbaka tre gånger, trots rättningarna i svarssteget.
  - Exemplet är nu neutralt ("skatten höjdes efter kriget mot Ryssland" → "Vad hände med skatten efter kriget mot Ryssland?"). Det har en ny regel: skriv aldrig om till en varför-fråga vars orsak materialet inte anger.
- **"framgår inte" i det långa svaret** (Oscars Vasa 4) ger nu också ett nytt försök. Förut kontrollerades bara det korta svaret.
  - Live: Vasa `drill_unanswered {"found":2,"fixed":2}`.
  - Oscars `o79_quality.py` skickar inte `may_fix`, så där görs inga nya försök. Appen skickar `may_fix`.
- **Live efter ändringen:** 0 Lübeck-frågor och 0 "framgår inte"/"inte känt" i tio prov.
- **Printing 11/14:**
  - Loggen för Oscars körning 18:02 visar `drill_refill_short {"wanted":3,"got":0,"repeats":0}`. Båda påfyllningsförsöken gav alltså noll frågor, och ingen av dem var en upprepning.
  - Frågorna föll bort i ett annat steg: tolkningen, för korta eller "the text".
  - Den troligaste roten är att modellen svarade med frågor som objekt (`{"i","q"}`), som i sista kontrollens format. Koden läste bara strängar. Det är en untested assumption.
  - Påfyllningen läser nu båda formerna (verifierat i test), och loggen anger orsaken (`parse`, `empty`, `material`), så att nästa fall syns.
  - I mätningen var printing 12/12 med både 3 och 12 frågor.

## Till Oscar
Omtest av K110:
- 402 med `fits` 2, `min_questions` 3 och texten, på ett nytt konto med `user-path`.
- Verklig kostnad ≤ uppskattning.
- Lübeck och "framgår inte" (gärna med `may_fix: true`, som appen).
- Printing fullt.

Se oscar.md.

## Till Angela Fable (A154)
- `fits` är nu en övre gräns: ett prov med `fits` frågor kan alltid sparas.
- `min_questions: 3`. Är `fits` < 3, säg det före genereringen med Fyll på (D241 punkt 2).
- På 1 500 krediter blir `fits` 2.
