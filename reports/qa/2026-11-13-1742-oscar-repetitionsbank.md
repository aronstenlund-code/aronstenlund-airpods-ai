# Oscar: testbank för repetitionsläget (10 påhittade prov med facit), O52/O53 väntar på underlag

Datum 2026-11-13 17:42. Kostnad: 0 USD API, 0 ElevenLabs-tecken, 0 Scribe-sekunder.

## Vad som gjordes
- **Testbanken är byggd:** `scripts/qa/repetition_bank/build_bank.py` → `scripts/qa/repetition_bank/exams.json`.
  10 prov som jag själv har hittat på, 53 uppgifter, i 10 ämnen (Biologi åk 8, Historia åk 9, Matematik 1b, Kemi 1,
  Fysik åk 9, Engelska 6, Svenska 1, Geografi åk 7, Samhällskunskap 1b, Religionskunskap åk 8). **Ingen elevtext,
  inga riktiga prov.**
- Varje prov har:
  - `exam_text`: provet som text med poäng (E/C/A), facit, bedömningsanvisning och betygsgränser. Det kan skickas
    direkt till `/exam {"action":"parse","text":…}` (K15).
  - `key`: uppgifterna i samma form som `/exam` (`no`, `text`, `points`, `answer`, `assessment`, `topic`),
    gränser och maxpoäng. Sedan finns också `accept` (68 andra sätt att säga rätt svar, bland annat talade tal som
    "elva" och "två ampere") och `wrong` (67 vanliga felsvar som inte får räknas som Rätt, jfr O43d).
- Skriptet kontrollerar strukturen: 10 prov, unika id, gränser ≤ maxpoäng, min_a ≤ A-poäng, facit och topic finns,
  /exam-gränserna 3 000 och 40 000 tecken. **Verifierat offline: OK** (ett fel hittat och rättat: Historias A-gräns
  12 var större än maxpoängen 11).

## Det som inte gick att göra
- **Underlaget för repetitionsläget saknas i repot.** Uppdraget pekar på `docs/design/repetitionslage.md`,
  D141–D145, O52, O53 och Kevins K45. Inget av det finns på main, på någon gren eller i historiken (kontrollerat
  med `git ls-remote` och `git log --all` 17:40). D141 på main gäller `Shared/capabilities.json`, inte
  repetitionsläget. O52 och O53 i min kö är redan klara (K44 och K43, 2026-11-11). Kevin såg samma sak och skrev
  Till Aron #11.
- Därför: **ingen ny O52, ingen O53**. Jag gissar inte vad de ska testa (CLAUDE.md: rapportera i stället för att gissa).

## Risker och antaganden
- **Untested assumption:** att repetitionsläget läser prov i samma form som `/exam` (D84/K15). Om designen säger
  något annat räcker det att ändra `main()` i skriptet; innehållet (frågor, facit, felsvar) går att återanvända.
- Facit är skrivet av mig och kontrollerat mot läroboksfakta (**verified in docs** för de vanliga faktapunkterna:
  riksdagen 349 ledamöter, fyraprocentsspärren, 1914–1918). Matte-, kemi- och fysikuppgifterna är uträknade för
  hand och dubbelkollade.

## Nästa session
1. `git pull`. När `docs/design/repetitionslage.md`, D142–D145 och K45 finns: läs dem, anpassa formatet i
   `build_bank.py` om det behövs och gör den nya O52.
2. O53 när Kevins K45 är klar. Kör bara text mot `/exam` och repetitionsflödet; inga ElevenLabs-tecken behövs för
   facit och rättning (PLAN 2d).
3. En billig baslinje som kan göras redan nu om Deangelo vill: skicka de 10 `exam_text` till `/exam parse` och
   jämför uppgifter, poäng och facit mot `key` (cirka 10 Sonnet-anrop, under 0,10 USD).
