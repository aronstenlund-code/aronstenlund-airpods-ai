# Kevin K22: Lär av riktiga användare, och K18 del 2 och K6 redo att köras

Datum 2026-11-10 10:50 · Uppdrag från Aron: bara arbete som inte kostar API (dagens budget är använd och ElevenLabs saknar krediter) · Inga modellanrop har gjorts för det här.

## 1. K22: Lär av riktiga användare (BACKLOG)
**Byggt:** `scripts/real_users.py` och det veckovisa flödet `.github/workflows/real-users.yml` (måndagar 04:23 UTC, kan också startas för hand). Det sker inga modellanrop och ingen API-kostnad.
1. **Hämtar** de senaste 7 dagarnas delade frågor ur `shared_history`.
   - Där finns bara användare som har slagit på "Dela historik" (D57, opt-in), och den som stänger av får sina rader raderade.
   - Bara frågan (`fragment`), läget och det pseudonyma installations-id:t läses. Svar, sammanfattning och användar-id läses aldrig.
2. **Tar bort personuppgifter:**
   - e-post, telefon- och personnummer, adresser, länkar och långa sifferserier;
   - förnamn i personliga sammanhang ("jag heter …", "min kompis …") och vanliga svenska förnamn, men inte historiska personer som "Gustav Vasa";
   - skolnamn.
3. **Hoppar över känsliga rader helt:**
   - kris och självskada, hälsa och diagnoser, egen tro, politik eller sexualitet, våld och mobbning;
   - rader från Socialt, Rizz och Intervju (där kan andras ord finnas med).
4. **Grupperar utan modell:** väckord och fyllnadsord tas bort, en lätt stamning görs, och grupperna byggs på ordöverlapp (Jaccard ≥ 0,6). **En fråga sparas bara om minst två olika installationer har ställt den** (k-anonymitet). En fråga som bara en person har ställt hamnar aldrig i repot.
5. **Lägger in grupperna:**
   - i live-eval som `scripts/real-user-cases.json` (läses nu av `scripts/live-eval.py`, med `expect: "either"`, så att fel och tomma svar syns);
   - i verklighetsbanken som `scripts/real-user-bank.json`, i Oscars O15-format med grupp 7 = riktiga användare. Oscars egen fil rör jag inte, så han kan läsa in den här.
6. **Raderar** fall som är äldre än 12 månader, samma gräns som tabellen har (D57).

**Testat mot påhittade data** (`scripts/test_real_users.py`, 4 tester, gröna lokalt och i CI-körningen 42793197521):
- Personuppgifter tas bort ("jag heter Elin och går på Rinkebyskolan" blir "jag heter [namn] och går på [skola]", telefon- och personnummer, adress).
- Krisraden och adhd-raden hoppas över, liksom raden från Socialt.
- "fotosyntes", "fotosyntesen" och "Lumen vad är fotosyntes" blir en grupp med 3 installationer.
- Frågor från en enda installation hamnar aldrig i filerna.
- En vecka senare uppdateras bara räknarna, och efter 12 månader är fallen borta.

**Status:** flödet körs men hoppar över hämtningen tills hemligheten finns. **Till Aron:** lägg in `SUPABASE_SERVICE_ROLE_KEY` som GitHub-hemlighet (samma som K4.3). Klickväg: Supabase → Project Lumen → Project Settings → API Keys → kopiera `service_role`. Sedan GitHub → repot → Settings → Secrets and variables → Actions → New repository secret → `SUPABASE_SERVICE_ROLE_KEY`.

**Risk:** frågorna från riktiga användare hamnar i git, även om de är rensade och ställda av minst två. Rensningen bygger på mönster och kan missa något, till exempel ett ovanligt namn som inte står i listan. **Oscar granskar** (enligt BACKLOG) de första filerna innan de används brett.

## 2. K18 del 2 och K6: ett kommando när krediterna finns
**Kommandot** (körs av en agent; Aron behöver inte göra något):

```bash
python scripts/dispatch.py credits-ready.yml
```

Det startar flödet "Credits ready (K18 + K6)" (`.github/workflows/credits-ready.yml`), som gör tre saker:
1. **Kontrollerar krediterna** med ett anrop till /tts på 4 tecken. Är de fortfarande slut stannar flödet utan kostnad. Provkört i dag (körning 42793897667): "/tts 503 provider_quota … nothing run, nothing spent".
2. **K18:** uttalsmätningen (`scripts/k18-pronunciation.py`). 30 meningar med ämnesord läses upp av /tts och skrivs ut av Scribe. Ord som blir fel listas i `reports/eval/k18-before-<datum>.json`.
   - Nästa steg: alias för de orden läggs in i /tts, och sedan körs `python scripts/dispatch.py credits-ready.yml tag=after`.
3. **K6:** förhandsprov (Voice Design) för fem påhittade rollfigurer i `scripts/k6-voices.json`: självsäker säljcoach, dramatisk sportkommentator, lugn viskare, gammaldags radioröst och sagoberättare.
   - Provtexterna är lästa och 187–212 tecken långa.
   - Ljudet blir artefakten `k6-voice-previews`, som Aron lyssnar på.
   - **Ingen röst sparas i kontot.** Att spara en vald röst är en kontoändring som Aron godkänner först.

**Byggt för K6:** den nya funktionen `voice-lab`, som bara tjänstenyckeln får använda (svarar 401 utan nyckel, kontrollerat live).
- Den gör bara förhandsprov.
- Den vägrar beskrivningar som härmar riktiga personer ("sounds like", "imitat…", kända namn, ägarbeslut). Det är unit-testat, och de fem rollfigurerna godkänns.
- Kostnad när det körs: ungefär 7 000 ElevenLabs-tecken (30 meningar i K18 och 5 förhandsprov). Förhandsproven i K6 kräver också hemligheten `SUPABASE_SERVICE_ROLE_KEY`, och utan den hoppas de över.

## Tester och driftsättning
- `voice-lab` har 2 nya tester. Hela `answer` är fortfarande grön (300).
- Deploy backend 42793713242 lyckades, med `[skip eval]`.

## Kostnad
0 USD API (inga modellanrop). CI-minuter för tre korta körningar.
