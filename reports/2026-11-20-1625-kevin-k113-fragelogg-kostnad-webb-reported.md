# K113 (D247) + T55-kostnaden + O91 N5 + Reported cases

Kevin (moln), 2026-11-20. **0 ElevenLabs.** Testkonton. Tester: **796/796**. Claude cirka 0,05 USD. Webbsök: 2 av testtakets 50, efter nattens eval.

## 1. K113 (D247): frågeloggen i repetitionsläget bara för testkonton och den som delat
- **Förut** (K77/D197) skrevs frågor och svar till `qa_log` för **alla utom** testkonton. Det gällde nya och ändrade frågor vid `save` och statistiken från `stats`.
- **Nu skrivs raden bara**:
  - för testtrafik (`x-earmind-test`, testkonto, skript eller CI); eller
  - när appen skickar **`share_history: true`**, alltså D57:s val "Dela historik", som är avstängt tills användaren slår på det.

  En vanlig användare loggas aldrig. Värdet måste vara exakt `true`.
- Lyssnarlägenas logg (D116, `answer/qalog.ts`) är orörd.
- `exam` sparar ingen text, bara token och kostnad (`answer_usage`). Verifierat i koden.
- **Tester** (`drill/handler_test.ts`):
  - En vanlig användare som inte delat ger 0 rader vid save, ändring och stats, och `stats` svarar `logged: false`.
  - `share_history: true` ger rader som förut.
  - Ett testkonto ger rader.
- **Live** (kevin-live 44761047321, med testhuvud): `stats` svarar `logged: true`. Med den gamla regeln hade testkonton fått `false`, så svaret visar att den nya koden körs.
- **Vanlig användare utan huvud, live:** det går inte att visa från Actions. Servern räknar avsiktligt all trafik från Actions som test (K105, CI-adresser), och härifrån når jag inte servern. Fallet är verifierat i test. Någon bakdörr för att komma runt det har jag inte byggt.
- **Till Angela Schrute:** appen behöver skicka `share_history: true` i `drill` save och stats när "Dela historik" är på. Utan det loggas ingen, vilket är det säkra standardläget.

## 2. T55-kostnaden (Angela Fables iakttagelse)
- Appen skickade `long_words` 90, inte 130. Min gissning med "Längre" var alltså fel.
- **Tobys fall mätt på servern** (k110-cost `--short39`, 44761191600, text på 39 ord, 3 frågor, två prov):
  - Kostnaden blev **1 474 och 1 091**, alltså högst 491 per fråga. Gränsen är 642 per fråga, 1 926 för tre.
  - De långa svaren var högst 73 ord och började alltid med det korta svaret. Ingen skärmtext.
- **Serverns väg håller gränsen.** De cirka 2 500 i T55 kommer från något mer som appens `cost`-anrop tar med, till exempel fler rader eller andra texter. Det kan servern inte se.
- **Förslag till Angela och Toby:** logga i nästa T55 hur många rader `cost` skickar och hur långa de är.

## 3. O91 N5: webbsvar över 80 ord
- **Ändring:** ett svar som har sökt på webben (`searching`) kapas efter sista hela meningen inom **80 ord**, på samma sätt som vid en begärd längd (K42.3).
  - Strömmen fortsätter utan att sägas, så att källraden i slutet ändå läses (`done.source`).
  - Sånger och citat (`textOn`) kapas aldrig. Svar utan sökning påverkas inte.
- Verifierat i test (`answer/k114_test.ts`).
- **Live** (`k114-web.py`, 44762040122):

  | Fråga | Sök | Ord | Källa |
  |---|---|---|---|
  | hur byter man däck | 1 | 79 | clasohlson.com |
  | recept på köttbullar | 1 | 62 | ica.se |

## 4. "Reported cases": 401 sedan minst 15 november
- **Vad som nekades:** nyckeln, inte adressen.
  - Repohemligheten `SUPABASE_SERVICE_ROLE_KEY` är den äldre service_role-JWT:n med signaturprefix `gswjCd`, och gatewayen godkände den som `service_role`.
  - Funktionen kördes (`execution_id`, 98 byte), men `feedback-admin` krävde exakt samma sträng som funktionens egen injicerade `SUPABASE_SERVICE_ROLE_KEY`, som är en annan servicenyckel. Därför kom "Service role only".
  - Samma fel i edge-loggen 19 och 20 november. Körningarna sedan 15 november föll alla.
- **Rättningen** (`_shared/servicekey.ts`, samma metod som voice-lab K6):
  - Varje nyckel som databasen behandlar som servicenyckel godkänns. Kontrollen görs med en läsning som bara en servicenyckel får göra.
  - En fel nyckel ger fortfarande 401, och bara godkända nycklar sparas.
  - Tester i `feedback-admin/k113_key_test.ts`.
- **Nästa fel bakom 401:an:** skriptet läste svaret som en lista, men funktionen svarar `{count, rows}`. Rättat.
- **Live:** körning 44762021816 är grön och skrev `reports/eval/reported-2026-11-20.json`. Det fanns 0 obehandlade rapporter just nu.

## Till Kelly (Ke85) och Oscar
Se kelly.md och oscar.md.

## 5. Angela Fables önskan för A154: `/drill quota` med `long_words`
- **`quota` svarar nu `exam: {per_question, min_questions, long_words}`.** Det är K110:s övre gräns för den längd appen skickar, samma tal som `fits` i `exam drill`.
  - Utan `long_words` används 90.
  - `long_words` hålls mellan 40 och 200, som i `exam drill`.
- **`suggest` är 12** i stället för 20 (D239). Serverns standard för `exam drill` är oförändrad.
- Tester: 797/797.
- **Live** (`k115-quota.py`, 44763284733): 90 ord ger 642, 130 ord ger 894, utan längd 642, och `suggest` är 12. 0 Claude och 0 ElevenLabs.

## 6. Oscars O92: receptet och däcket (runda 17:00)
- **Roten:** webbpromptens form "en mening med svaret, sedan detaljer".
  - För en instruktion blev första meningen en sammanfattning av stegen, och sedan kom stegen en gång till.
  - För ett recept stod det "ingredienserna först med exakta mått", och listan åt upp orden.
- **Ändrat i webbprompten:**
  - Ett recept tar bara med huvudingredienserna i en mening och sedan alla steg tills rätten är klar, med högst 70 ord. Hela listan finns hos källan.
  - En instruktion och ett recept börjar direkt med första steget.
  - Verifierat i test.
- **Live** (44769763007): däcket 75 ord och köttbullarna 73 ord, båda med källa. Däckets upprepning är borta.
  - En ny metamening kom i stället: "Källorna är inte helt samstämmiga om ordningen, så jag håller mig till de steg som Clas Ohlson beskriver."
  - Den tas nu bort i koden (`SOURCE_META`). K103:s "…, men vissa mätningar ger Amazonas" står kvar. Verifierat i test.
- **Tester:** 799/799.
- **Inte verifierat live:** att receptet nu når stekningen. Svaret skrevs ut bara till 300 tecken. Nattens eval visar det.

## 7. Oscars O93: ett sökt recept utan källa (runda 17:15)
- **Vad hände:** "recept på köttbullar" sökte en gång men fick ingen källrad, och svaret var 31 allmänna ord. Modellen svarade troligen ur minnet efter sökningen. Det är en untested assumption, baserad på en körning.
- **Varför servern inte sätter en källa själv:** sökresultaten finns i strömmen, men att ge svaret domänen från första träffen vore en felaktig källhänvisning när svaret inte byggde på sidan. Svaret går heller inte att göra om, eftersom texten redan har sagts när det visar sig att källraden saknas.
- **Ändrat:**
  - Webbprompten säger att ett sökt svar bygger på sidan som hittades och alltid slutar med källraden, och att svaret aldrig kommer ur minnet efter en sökning.
  - Ett sökt svar utan källa markeras med `done.source_missing: true` och loggas som `web_answer_no_source`, så att det kan räknas.
  - Verifierat i test. Tester: 800/800.
- **Live:** nattens eval kör praktiskt-04, och raden "källrad saknas" visar om det händer igen.
