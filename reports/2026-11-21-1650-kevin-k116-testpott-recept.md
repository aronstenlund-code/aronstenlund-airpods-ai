# K116 (D254): testtrafiken utanför webbens tak, och sökta recept hålls inne tills källan finns

Kevin (moln), 2026-11-21. **0 ElevenLabs.** Testkonton.

- **Tester:** **836/836**.
- **Commit:** ec8ffe00, deployad av deploy-backend 367.
- **Inga tal är ändrade**, eftersom kapaciteten väntar på Aron (#37).

## 1. Testtrafiken och webbens tak (Oscars O94)
- **Krediter och lyssning:** med `x-earmind-test` räknas varken krediter (prov och `/tts`) eller lyssning (`/stt-token`) mot webbens tak (`web-credits:*`, `web-stt:*`).
  - Testerna får falskt ljud och falsk text (D180), så de kostar inga ElevenLabs-krediter, och det är dem taken skyddar.
- **Konton:** testkonton från webben räknas i en egen pott, `web-acct-test:ip`, med samma tal: 5 per nät och dygn, sedan 429 `too_many_accounts`.
  - En riktig besökare på samma nät har alla sina 5 platser kvar.
- **Sämsta fallet** om någon sätter huvudet själv: falskt ljud, och 10 konton per nät och dygn i stället för 5. Det kostar bara Claude, inom de vanliga gränserna per konto och nät (D79). Samma sätt som D234.
- **Verifierat i test** (`_shared/webguard_test.ts`). LIVE1

## 2. Sökta recept och instruktioner
- **Vilka svar som hålls inne:** när servern känner igen ett recept eller en instruktion (`need.lookup` = recipe eller howto, K16) och svaret söker, läses inget upp förrän hela svaret finns.
  - Söktonen (D233) spelas medan appen väntar.
  - Andra svar strömmar som förut, och det gäller även andra sökta svar.
- **Med källrad** skickas hela svaret i ett stycke.
- **Utan källrad** görs svaret om en gång. Modellen får sidan som sökningen hittade (`wantSources`, första träffen) och verktyget `web_fetch`, med "svara bara från den här sidan och avsluta med källraden". Hittade sökningen ingen sida söker den igen.
- **Saknas källan ändå** blir svaret en fast mening:
  - "Jag hittade inget recept med en säker källa." (en: "I couldn't find a recipe with a reliable source.")
  - För en instruktion: "Jag hittade ingen instruktion med en säker källa." (en: "I couldn't find instructions with a reliable source.")
  - `done` får då `source_fallback: true` i stället för `source_missing`, eftersom ett svar utan källa aldrig sägs.
- **Logg:** `held_no_source` (omförsöket) och `held_fallback` (den fasta meningen), för Oscars och evalens räkning.
- **Kostnad:** ett extra anrop, och kanske en sidhämtning, men bara när källraden saknas (i natt 2 av cirka 60 frågor).
- **Väntan:** att hålla inne ett svar på högst 70 ord ger cirka 1–2 s mer efter tonen (untested assumption om exakta tal; mäts live nedan).
- **Ett äldre test ändrades:** O93-testet i `answer/k114_test.ts` gick på ett recept utan källa. Det testar nu ett vanligt sökt svar, som fortfarande markeras `source_missing`. Receptfallet ligger i `answer/k116_held_test.ts`.
- **Verifierat i test** (`answer/k116_held_test.ts`, 4 fall: med källa, omförsök från sidan, fast mening på sv och en, vanligt sökt svar strömmar). LIVE2

## Till Oscar
Omtest:
- (1) Webbetan med `?test=…` tar inget av webbtaket och har en egen pott av konton.
- (2) Köttbullar och ris i nattens eval ska ge antingen en källa eller den fasta meningen, aldrig ett svar utan källa. Räkna `source_fallback` som rätt beteende och inte som fel.

## Kända begränsningar
- Bara den första sidan som sökningen hittade används vid omförsöket.
- Igenkänningen av recept och instruktioner är densamma som för källistorna (K16, ordmönster). Ett recept som inte känns igen strömmar som förut.
- Kapaciteten (90 000 tecken i månaden, och att 1 500 per webbkonto inte räcker till ett prov) väntar på Aron (#37). Inga tal är ändrade.
