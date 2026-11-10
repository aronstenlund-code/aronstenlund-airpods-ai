# Kevin K16: Hitta aldrig på, och ändra dig aldrig utan skäl

Datum 2026-11-10 · Uppgift: `prompts/queue/kevin.md` K16 (ägarkrav 2026-11-09 21:58) · Driftsatt i flera omgångar, den sista är Deploy backend 42770162764 (commit de2fd5f) plus 47d1e2e. Allt nedan är **verified live** (anrop mot driftsatt /answer i Frågor med tryck för att fråga, `scripts/k16-eval.py`) där inget annat står. **Inte testat på telefon.**

## Resultat
| Krav | Resultat |
|---|---|
| 10 recept och instruktioner: söker och tar mängder ur källan | **10 av 10 söker** och anger källa: ica.se (5), support.apple.com (2), msb.se, support.google.com och koket.se. Mängderna stämmer mot källan i de fall jag läste för hand (ICA:s tunna pannkakor: två och en halv deciliter mjöl, en halv tesked salt, sex deciliter mjölk, tre ägg). Att alla stämmer är en **untested assumption**, eftersom jag inte läste alla källsidor |
| 10 följdfrågekedjor om 3 steg: inga motsägelser | **0 motsägelser** i 30 steg, läst för hand i två körningar. Exempel: pannkakor "sex deciliter mjölk" i både steg 1 och 2, ägg 7 och 11 minuter i steg 1 och samma i steg 2 och 3, köttbullar "en och en halv deciliter ströbröd" i steg 1 och 2 |
| Följdfrågor söker i samma källa | Fungerar i unit-test, men i den live-mätning som gick att köra stoppades sökningarna av webbtaket (20 per användare och dag). Se "Kvar" |
| 10 frågor som modellen inte vet: söker eller säger att den inte vet, gissar aldrig | Före ändringen 3 av 10. Efter tredje omgången **10 av 10 söker**: Ockelbo 5 773 invånare (ne.se), KTH:s rektor (kth.se), Ölandsbron (ne.se), Kebnekaises sydtopp med den senaste mätningen (gp.se), Ludvika (svt.se, säger att källorna är blandade) och fem till |
| Kostnad per svar med sökning | **0,0103 USD** (Haiku och en sökning) |

Filer: `reports/eval/k16-2026-11-10-first.{json,md}` är första körningen (A, B och C), `reports/eval/k16-2026-11-10-C.{json,md}` är C efter ändringarna, och `reports/eval/k16-2026-11-10.json` är den sista B-körningen.

## Vad som ändrats (DECISIONS D98)
1. **Fler frågor söker** (`answer/web.ts`):
   - Recept och mängder ("recept på", "hur mycket mjöl", "hur länge i ugnen") söker på ica.se, arla.se, koket.se, coop.se, tasteline.com och livsmedelsverket.se.
   - Steg-för-steg-instruktioner ("hur återställer man", "steg för steg") söker på tillverkarnas supportsidor och msb.se.
   - Regler ("är det lagligt", "vad är åldersgränsen") söker på myndigheter och lagen.nu.
   - Fakta som ändras ("hur många invånare", "vem är rektor på …") söker också.
   - Inte i Auto och inte i demon, eftersom webben inte används där (D46). Taken per svar och per dag är oförändrade.
2. **Modellen bestämmer sig först** (Frågor, utan webbverktyg):
   - Varje svar börjar med `[[VET]]` eller `[[SÖK]]`. Vid `[[SÖK]]` sägs ingenting, och samma fråga ställs en gång till med webbsökning, inom webbtaket. Är taket nått säger svaret att det inte vet säkert.
   - Markörerna läses aldrig upp.
   - Varför: i första versionen skrev modellen ibland ett svar först och markören efteråt ("… femtusen invånare. [[SÖK]]"), och en gång rättade den sig själv högt ("Nej, jag är osäker … så jag söker det"). Ett obligatoriskt beslut i början tog bort båda.
3. **Konsekvens:**
   - `recent_qa[]` tar emot `source`, alltså svarets `done.source`. Följdfrågor som "hur länge i ugnen?" och "och sen?" söker i samma källa.
   - Prompten säger att mängder, steg och fakta från förra svaret behålls, och att ett tidigare påstående bara ändras om det var fel, då med "Jag sa fel nyss: …".
4. **Uppläsning:**
   - Bråk i recept läses som ord: "2 1/2 dl" blir "två och en halv deciliter", "½ tsk" blir "en halv tesked", "3/4 dl" blir "tre fjärdedels deciliter". Före ändringen lästes det live "två ett/två deciliter".
   - tsk, msk och krm läses som ord.
   - En engelsk mening ("The sources don't give …") stoppas av språkfiltret, och webbregeln ger en svensk formulering när källorna inte svarar.

## Tester
Lokalt finns 12 nya tester i `answer/k16_test.ts`:
- frågetyper, följdfrågor och domäner;
- markörerna (`[[SÖK]]` ger ett nytt anrop med sökning, `[[VET]]` läses aldrig upp, även efter relationstaggen);
- bråk;
- engelska meningar.

Actions med typkontroll är grönt.

## Kvar och risker
- **Följdfrågor i samma källa live:** när B-körningen gick hade testanvändarna nått webbtaket (20 per dag). Nya testanvändare stoppades av Supabases gräns för anonyma inloggningar per IP-adress. Om det ändå hinns körs `--only B` om. **Untested assumption** live, verified i unit-test.
- **Till Angela:** skicka `done.source` med som `recent_qa[].source`. Annars kan följdfrågan inte veta vilken källa förra svaret kom ifrån.
- Markören kostar några token och någon tiondels sekund till första ord i Frågor. Svar med `[[SÖK]]` tar 3–5 s, eftersom de söker.
- Moderna museets öppettider fanns inte i sökresultaten. Svaret sa det och hänvisade till museets webbplats. Det är ett ärligt svar, men inget svar på frågan.
- Bråk som "3/4" kan i sällsynta fall vara ett datum (3 april). Då läses det som "tre fjärdedelar".
- **Fel i hur jag arbetade:** en commit (de2fd5f) tog med filer som Kelly hade lagt i det delade indexet. Innehållet är intakt. Från och med nu committar jag bara mina egna sökvägar (`git commit -- <paths>`).

## Kostnad
Ungefär 0,6 USD (cirka 60 anrop med sökning).
