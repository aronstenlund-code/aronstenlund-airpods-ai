# Två prov efter en ChatGPT-import (Tobys fynd T27/T31)

Angela Schrute (moln), 2026-11-16 00:44–01:20. Commits ba36504 och 86fa5b2. Fyndet:
`prompts/queue/angela.md` (Toby moln, 2026-11-16 00:55), körningarna 43676559643, 43678562025 och 43773402041.

## Orsaken (hittad innan något rättades)
1. Spara frågorna sparar provet på telefonen och skickar det till servern (`prepare` → `save`).
2. Testet lämnar importen efter cirka 3 s. Start öppnas och kör `refresh()`, som hämtar serverns lista.
3. Servern har redan sparat provet, men svaret med serverns id har inte kommit tillbaka till telefonen.
4. `refresh()` lade till varje prov i listan som ingen telefonkopia hade id för, efter ett `status`-anrop. Den
   kontrollerade inte heller igen efter anropet. Serverns prov blev därför ett nytt prov på telefonen.

Då står samma prov två gånger på Start:
- telefonens eget, ostartat (D190);
- serverns kopia med "ljud klart".

Servern har bara ett. Med 8 s väntan hinner svaret tillbaka före Start, och därför syntes det inte i A107 och T30.
Samma sak kan hända om appen stängs efter att servern har sparat men innan svaret har kommit.

*Verifierat i docs* (koden och Tobys körningar). Inte återskapat i simulatorn.

## Rättningen
- Efter `status` kontrollerar `refresh()` igen om provet redan har kommit in.
- Har telefonen ett prov utan server-id med samma typ och samma frågor och svar i samma ordning
  (`RepetitionModel.unsavedTwin`, orden jämförs utan blanksteg och skiftläge), får det serverns id. Det blir ingen
  ny kopia.
  - Telefonens prov behålls, med ändringar och plats, och skickas igen med id:t. Det blir en uppdatering, aldrig ett
    andra prov.
- Ett prov med andra frågor, till exempel från en annan telefon, läggs till som förut.

## Testresultat
- `DuplicateAfterImportTests` (2 tester) skrevs före rättningen:
  - ett prov vars sparning är på väg läggs inte till två gånger, och telefonens prov får serverns id;
  - ett annat prov läggs fortfarande till.

  Med den gamla koden blir det två prov i det första testet. Det är spårat i koden, inte kört.
- **CI: iOS build 43776526245 grön** (86fa5b2), med `DuplicateAfterImportTests`. *Verifierat i CI.*
- 0 ElevenLabs. Ej provat på telefon.

## Kända begränsningar
- Dubbletter som redan finns på en telefon slås inte ihop. Bara nya förhindras. I testerna försvinner de med nya
  simulatorer.
- Kraschloggen från T24 (43766804245, krasch vid första starten) ligger i en artefakt som molnsessionen inte kan
  hämta, eftersom nätet stoppar nedladdningen. Den är inte undersökt. Toby eller den lokala sessionen behöver lägga
  loggen i repot.

## Nästa
- Toby kör om T27/T31 med väntan på cirka 3 s.
