# Historik – hitta tillbaka till ett svar, och spela upp det igen

Angela Schrute (moln, Opus 5.5), 2026-11-27. Uppdrag: Deangelo 01:52: "historiken – gör den lätt att hitta tillbaka till ett svar (sök, senaste överst, spela upp igen i AirPods med ett tryck) och se att den fungerar utan nät och utan krediter. Test först, hela sviten grön, bilder."

## Kort

- **Senaste överst, under sin dag.** Raderna grupperas under "I dag", "I går" och sedan datumet, nyast först. Raden visar klockslaget.
- **Sök** finns sedan D269. Varje ord ska finnas i frågan, svaret eller sammanfattningen; stor eller liten bokstav spelar ingen roll, och inte heller accenter.
- **Spela upp igen med ett tryck.**
  - Varje rad har ▶ och svaret har "Spela upp i AirPods". Trycket läser svaret i AirPods på svarets eget språk, med den valda rösten.
  - ■ stoppar. En annan rad tar över.
  - Uppspelningen fungerar också när talade svar är avstängda, eftersom det är ett eget tryck.
- **Utan nät och utan krediter.**
  - Historik ligger bara på telefonen.
  - När den valda rösten inte kan svara (inget nät, 402 utan krediter, 503 `tts_quota`) läser telefonens egen röst. Efter `tts_quota` gör den det direkt i 10 minuter (K124).
- Historik nås från ⋯ på Lyssnar (D269) och från Inställningar.
- Inte provat på telefon.

## Avvägning

Uppspelningen använder **den valda rösten**, alltså samma röst som svaret hade. Med en ElevenLabs-röst kostar det tecken som en vanlig uppläsning. Ett alternativ var att alltid läsa med telefonens röst: gratis och direkt, men en annan röst än svaret hade. Jag valde den valda rösten med telefonens som reserv, eftersom det är samma svar som ska höras igen. Säg till om Aron hellre vill att uppspelning från Historik alltid är gratis.

## Teknik

- `Speaker.readAgain(_:language:)`: avbryter det som sägs och lägger svaret i kön med den valda rösten. Reserven till telefonens röst är densamma som för vanliga svar (`wantsFallback`, K124:s paus).
- `ListeningModel.readAgain(_:)`, `stopReadingAgain()`, `readingAgain` (raden som läses, för ▶/■). Svarets språk tas fram med `NLLanguageRecognizer` (svenska eller engelska); annars används språket appen lyssnar på.
- `HistoryEntry.days(_:now:calendar:)` och `dayTitle`: raderna per dag, nyast först.
- `HistoryView(store:listening:search:)`:
  - en sektion per dag;
  - `ReadAgainButton` på varje rad och i `HistoryDetailView`, med identifierarna `history.play` och `history.detail.play`;
  - att svepa bort en rad tar den rad man ser.
- Nya texter:
  - "Spela upp i AirPods" / "Play in AirPods"
  - "Spela upp igen" / "Play again" (VoiceOver)
  - "I går" / "Yesterday"
- Bildscener: `history`, `historySearch`, `historyDetail` (demosvar på appens språk).

## Testresultat

- **iOS build 45919332021 grön** på `angela/historik` (30232cf7): enhetsbygge med varningar som fel, hela sviten (1 207 gröna testrader, 0 röda), Release-arkivet och Release-kontrollen. `HistoryReplayTests` (9) gröna. *Verified in CI.*
- På main slogs grenen ihop med K124; textfilerna (`en.json`, `skip.json`) slogs ihop nyckel för nyckel, och `sync.py`/`check.py` är rena. Main-bygget skrivs in i STATUS.

- `LumenTests/HistoryReplayTests.swift`, 9 tester:
  - ett tryck läser svaret, och knappen går tillbaka till ▶ när det är läst;
  - den valda rösten används;
  - utan nät läser telefonen, och likaså utan krediter (402);
  - uppspelningen fungerar också med talade svar avstängda;
  - en annan rad eller stopp avbryter;
  - ett engelskt svar läses på engelska;
  - dagarna kommer med nyast först;
  - Historik finns kvar efter en omstart utan nät och går att söka i.
- **Test först:** testerna skrevs före koden men använder nytt API (`readAgain`, `days`), så de kunde inte köras röda. Det enda med befintligt API (Historik efter omstart) är redan grönt på main, så det skyddar bara att det fortsätter fungera.

### Bilder (Fable screens 45919415872, iPhone 17 Pro-simulatorn, ljust och mörkt, engelska och svenska)

- Grenen `fable/screens-historik`: `history`, `historySearch`, `historyDetail`.
- Sett på bild: dagarna "Today/I dag" och "Yesterday/I går" med nyast överst och klockslag, ▶ på varje rad, sökningen "photosynthesis"/"fotosyntes" som lämnar två rader, och svaret med "Spela upp i AirPods" överst.
- Bilderna togs strax efter midnatt (UTC), så ett av demosvaren "för 1,5 timme sedan" hamnade under I går. Det visar att dagarna följer klockan.

## Kända begränsningar

- Svar på frågor som ställdes utan "Lumen" sparas utan frågetext (D56). De syns med svaret eller sammanfattningen som rubrik och hittas genom ord i svaret.
- Uppspelning medan EarMind lyssnar: svaret läses i AirPods och taligenkänningen är stängd medan det låter, som för vanliga svar.

## Nästa steg

Aron på telefon:
1. Inställningar › Historik, eller Lyssnar › ⋯ › Historik.
2. Tryck ▶ på en rad: svaret ska höras i AirPods.
3. Slå på flygläget och tryck igen: telefonens röst ska läsa.
