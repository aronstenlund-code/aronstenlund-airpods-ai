# O58c: importen med 16 nya fall och hjälpfrågorna igen efter Kevins rättning 13:20 (Oscar, 2026-11-14 13:34)

Status för varje påstående: **verifierat live** (mot driftsatt `/drill import_text` och `/help`), **verifierat i docs** eller **antagande, ej testat**.
Ingen app eller enhet. 0 ElevenLabs-tecken. Kostnad cirka 0,06 USD (Haiku i `/help`). Importen kostar inget.
Förra rapporten: `reports/qa/2026-11-14-1304-oscar-o58-omtest-k60.md`.

## Kort
- **Importen 34/36.** Kevins tre rättningar håller: avslutning på sista raden, Fråga och Svar på samma rad, och tankstreck.
  - Fallen 01–26 ger 26/26. Av dem var 21–26 mina nya fall från förra gången, som då gav 3/6.
  - Fallen 27–36 är 10 nya varianter som ChatGPT kan tänkas skriva. De ger 8/10.
- **De 2 nya felen:**
  - prio 2: emoji-numrering, `1️⃣ Fråga:`. Fråga och svar läses in, men frågan blir "1️⃣ Fråga: Vad är magma?", så etiketten läses upp.
  - prio 3: kursiv med `*…*` och `_…_` blir kvar i svarstexten.
- **Hjälp-AI:n 30/30 för hand i två körningar** (var 29/30). Utanför appen 10/10, knepiga 4/4, påhittade funktioner 0. **Krav klarat.**

## Importen (`reports/qa/data/2026-11-14-133236-o58-import.json`)
Fallen 01–26 är beskrivna i de två förra rapporterna, och alla ger rätt. Fall 23 ("Hoppas det hjälper!" direkt efter sista svaret) läses nu inte in, och appen får en varning.

De nya fallen 27–36 finns inte i Kevins och Angelas fixtur. "Ok med 422" betyder att ett tydligt `import_unreadable` också räknas som rätt, eftersom formatet är så långt från mallen.

| Fall | Resultat | |
|---|---|---|
| 27 emoji-numrering `1️⃣ Fråga:` | 6/6, men **frågan blir "1️⃣ Fråga: Vad är magma?"** med varningen "Frågan saknade Fråga:.". Etiketten och emojin läses upp | **prio 2** |
| 28 markdowntabell `\| Fråga \| Svar \|` | 422 med tydligt meddelande (ok med 422) | ok |
| 29 etiketten ensam på raden (`Fråga:` ny rad, frågan) | 6/6 hela | ok |
| 30 rubrik överst och `---` mellan paren | 6/6. Rubriken och `---` hoppas över | ok |
| 31 kursiv `*smält berg*`, `_Hawaii_` och ”citattecken” | 6/6 och alla ord är kvar, men **`*` och `_` står kvar i texten**. Om rösten läser upp dem är **antagande, ej testat** | prio 3 |
| 32 `Fråga 1.` och `Svar.` med punkt i stället för kolon | 422 med tydligt meddelande (ok med 422) | ok |
| 33 mellanslag före kolon (`Fråga :`) och efter raden | 6/6 | ok |
| 34 numrerad lista `1) 2) 3)` inne i svaret | 6/6. Siffrorna tas bort och alla ord är kvar | ok |
| 35 25 frågor | 25/25 | ok |
| 36 emoji-inledning och avslutningsfrågan "Vill du att jag gör flashcards också?" direkt efter sista svaret | 6/6. Avslutningen läses inte in och ger en varning | ok |

**Förslag till Kevin och Angela:**
- Fall 27: ta bort `1️⃣`–`🔟` (och `#️⃣`) före etiketten på samma sätt som `1.`.
- Fall 31: ta bort `*` och `_` runt ord i fråga och svar på samma sätt som `**`.
- Lägg gärna 27–36 i `testdata/import/o58-cases.json`.

## Hjälp-AI:n (`reports/qa/data/2026-11-14-133320-o58-help.json`, `…-133356-o58-help.json`)

| | Körning 1 | Körning 2 | Krav |
|---|---|---|---|
| Hur gör jag (30, för hand) | **30/30** | **30/30** | 30/30 |
| Nyckelordskontrollen | 29/30 | 30/30 | |
| Utanför appen (10) | 10/10 | 10/10 | 10/10 |
| Knepiga (4) | 4/4 | 4/4 | |
| Funktioner som inte finns (10) | inget påhittat | inget påhittat | |
| Förbjudna ord, för långa svar, fel | 0 | 0 | 0 |

Nyckelordskontrollen underkände i körning 1 min tvetydiga fråga "vad händer när alla frågor är slut". Svaret gällde månadskvoten och var rätt, så jag räknar den som godkänd.

Rättat sedan förra gången:
- **Det korta svaret** är nu "första meningen, eller de två första, i det långa A-svaret", och det står att man får det med 2 tryck. Rätt 2/2.
- **Premium** ger igen "kommer senare, priser finns inte än".
- **Samtal** rätt 2/2.

**Att uppdatera snart (prio 3, till Kevin):** HJALP.md rad 93 säger att "en egen röst till svaren" inte finns. Angela bygger nu A98 "Spela in eget svar" (D173). När A98 finns i appen blir hjälp-AI:ns "Nej, det går inte att spela in din egen röst" fel. HJALP.md behöver då ändras samtidigt.

## Filer
- `scripts/qa/o58_import.py`: fallen 27–36, och `either` (ett tydligt 422 godtas för tabell och punkt)
- `reports/qa/data/2026-11-14-133236-o58-import.json`, `…-133320-o58-help.json`, `…-133356-o58-help.json`

## Nästa
- Kevin och Angela: fall 27 (prio 2) och fall 31 (prio 3).
- Kevin: HJALP.md när A98 är klar.
- Oscar: väntar på kö.
