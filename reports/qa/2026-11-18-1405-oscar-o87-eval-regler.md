# O87: evalens regler och konton (D232), Oscar (moln)

**Resultat: de fyra falsklarmen från O86 tabell C är borta, inget annat fall ändrade utfall, och evalen återanvänder sina konton.** Det är visat offline på nattens 388 svar (exakt 6 ändrade turer, alla väntade) och live i två omgångar (0 falsklarm, 6 inloggningar i stället för 12). 0 ElevenLabs. Claude cirka 0,02 USD.

## Ändringar (uppdraget från Deangelo, D232)
- `scripts/live-eval-cases.json`:
  - `allow_question: true` i socialt-01, -02 och -03 samt minne-01, med `max_words` kvar;
  - praktiskt-04 `expect_any: ["färs"]`, tidigare `["köttfärs"]`.
- `scripts/live-eval.py`:
  - "det beror på" räknas bara som brasklapp när "att" inte följer direkt efter;
  - `Backend` har en delad lista med konton per process (`_shared_tokens`). En andra `run()` i samma process, alltså en omkörning, loggar inte in på nytt. Nattens körning påverkas inte: den gör en `run()` och loggar in som förut.
- `scripts/test_live_eval.py`: 4 nya kontroller:
  - "Det beror på att virus …" ger ingen brasklapp;
  - "Det beror på." ger en brasklapp;
  - "Det beror på vad du menar." ger en brasklapp;
  - kontona delas mellan `Backend`-objekt.

  **Alla gröna** (`python3 -I scripts/test_live_eval.py`).

## Bevis 1: offline, nattens 388 svar (**verifierat i test**)
`scripts/qa/o87_eval_rules_diff.py` kör `reports/eval/latest.json` (388 lagrade svar) genom `run()` två gånger utan nät, en gång med de gamla reglerna och fallen och en gång med de nya. Samma svar går in i båda. Skillnaden är alltså bara regeländringen.
- Gamla regler: 80 turer med anmärkning. Nya regler: 75. (Det är fler än nattens 22 i båda fallen, eftersom de lagrade svaren är kapade till 300 tecken och saknar `done`. Det påverkar båda körningarna lika.)
- **Exakt 6 turer ändrade utfall**, och alla är de väntade:

| Fall | Förut | Nu |
|---|---|---|
| ämnesbyte-10 tur 2 | brasklapp: 'det beror på' | – |
| praktiskt-04 | väntat svar saknas (köttfärs) | – |
| socialt-01 | fråga tillbaka, för långt (24 ord) | **för långt (24 ord)**, alltså fortfarande en anmärkning |
| socialt-02 | fråga tillbaka | – |
| socialt-03 | fråga tillbaka | – |
| minne-01 | fråga tillbaka | – |

## Bevis 2: live, två omgångar (**verifierat live**, Actions 44309785375, testkonton)
`scripts/qa/o87_live.py` kör de sex fallen med nya `live-eval.py`, två omgångar i samma process.
- **Inga falsklarm i någon omgång.** Exempel:
  - socialt-02 "Hej! Vad roligt att du hörde av dig, hur har din dag varit?"
  - socialt-03 "Gärna! Vilken tid passar dig?"
  - minne-01 "Jag åkte skidor, du då?"
  - praktiskt-04 "… femhundra gram nöt- eller blandfärs …"
  - ämnesbyte-10 "Det beror på att antibiotika bara fungerar mot …"
- Kvar, och riktigt: socialt-01 "för långt (25 ord, max 16)", och praktiskt-04 långsamt i en omgång (2 860 ms).
- **Inloggningar: 6** för sex fall och två omgångar. Utan återanvändning blir det 12, och tredje omgången i O86 fick 429.

## Obs till Deangelo (inget ändrat)
fakta-05 och de andra webbfrågorna i natt fick budgeten 2 500 ms. `generic_checks` ger 8 000 ms bara när fallet har `"web": true`, och de fallen saknar det. Om webbsvar ska ha en högre budget behöver de flaggan. Det är ditt beslut, eftersom det ändrar vad som räknas som långsamt.
