# K109 (D239): inget prov som inte kan sparas, välkomsten före Team ID och par med samma svar

Kevin (moln), 2026-11-19. **0 ElevenLabs.** Testkonton, inga webbsök. Tester: **773/773**. Claude cirka 0,75 USD (två provmätningar och tre korta prov).
Commits 685999e9, 76a3e0cc, 7a86fbfd, 0cb72a1d, b6576ffe och 2281b9b2.
- Deploy-backend 342, 344, 346 och 347 är gröna.
- 345 stoppades av testgrinden, eftersom ett test fallerade. Rättat i 346.

## 1. Kostnaden före provet (Oscar O90)
- **`exam drill` och `drill_answers` räknar kostnaden innan Claude gör något.** Räcker krediterna inte svarar servern **402 `quota_exceeded`** direkt, så att inget prov görs som sedan inte kan sparas. Ingen kredit dras.
- **Uppskattningen** räknas som `action: "cost"`: visade tecken för frågan och det långa svaret.
  - Texten finns inte än. En fråga räknas därför som 60 tecken och ett långt svar som 4,8 tecken per ord (`estimatedCostPerQuestion` i `exam/drill.ts`).
  - Vid 90 ord blir det **492 per fråga**. Oscar mätte 490 (12 frågor = 5 882).
  - `drill_answers` räknar de riktiga frågornas längd plus det långa svaret.
- **402-svaret har nya fält**, utöver de gamla `unit`, `remaining`, `left`, `limit`, `used`, `resets` och `per`:

  | Fält | Betydelse |
  |---|---|
  | `fits` | hur många frågor krediterna räcker till (`floor(remaining / per_question)`) |
  | `cost`, `needed` | den uppskattade kostnaden |
  | `estimated: true` | talet är en uppskattning; det exakta talet ger `cost` före sparandet |
  | `per_question` | uppskattad kostnad per fråga |
  | `questions` | begärt antal frågor |

- **Texten (live):** "Ett prov med 12 frågor kostar cirka 5 904 krediter. Du har 1 500 kvar, det räcker till 3 frågor. Nya krediter den 1 december."
  - För `drill_answers` börjar den "Svaren på 12 frågor …".
  - Räcker krediterna inte till en enda fråga står det "det räcker inte till någon fråga".
- **Admin (obegränsat)** påverkas inte.
- **Verifierat live** (run 44579879236, nytt testkonto med 1 500):
  - `drill` med 12 frågor och `drill_answers` med 12 frågor ger 402, `fits: 3`, svar på cirka 1 s, inga frågor i svaret, och kvoten är oförändrad.
  - Ett prov med 3 frågor går som förut.
  - Verifierat också i test (`exam/k109_test.ts`, ett test som fallerade före ändringen).

### Risk för Deangelo: uppskattningen kan ligga under det verkliga talet
- **Ett prov med 3 frågor kostade live 1 668 och 1 841.** Det är 556 och 614 per fråga (`action: "cost"`), mot uppskattningen 492.
  - Korta prov får alltså längre långa svar än Oscars prov med 12 frågor.
  - Med 1 500 krediter blir `fits: 3`, men ett prov med 3 frågor kan ändå nekas vid sparandet.
- **Förslag:**
  - (a) Uppskattningen sätts till cirka 620 per fråga. Den håller, men då ryms bara 2 frågor på 1 500, och det går inte att göra ett prov.
  - (b) Koden kortar de långa svaren till `long_words`, så att uppskattningen håller.
  - (c) Appen visar `cost` före sparandet, vilket A154 redan säger.
- **Jag rekommenderar (b) och (c).** (b) blir en egen punkt om du vill. Gratismängden är Arons beslut (D239).

### QA-mätningar (Oscar O91, samma runda)
Utan ändring skulle varje nytt testkonto (1 500) få 402 på alla prov, och då går Oscars `o79_quality.py` och min `k102-measure.py` inte att köra.
- **Lösning:** uppskattningen hoppas över när anropet har testhuvudet **och** kommer från GitHub Actions (`fromCi`, samma IP-lista som K105).
  - Huvudet räcker inte ensamt, eftersom vem som helst kan skicka det och då få Claude-prov utan krediter.
  - Mätningarna sparar inget, och `save` drar krediterna som vanligt.
- **`user-path` i testhuvudet** (`x-earmind-test: … user-path`) ger användarens väg med uppskattning och 402, för QA som vill testa just det. Det är fortfarande ett testanrop (D180).
- Verifierat i test och live: ett prov med 12 frågor från Actions gav 200, och vägen med `user-path` gav 402.

## 2. Välkomsten före Team ID
- **`attest_challenge` svarar nu 503 `attest_unconfigured`** när App ID saknas, som `welcome` redan gjorde. Appen förbrukar då inget av sina tre försök (A154 del 2).
- Verifierat i test (`purchase/rewards_test.ts`) och live: 503 `attest_unconfigured`, ingen utmaning.

## 3. Par med samma svar (mitt K108-förslag)
- **Den sista kontrollen skriver nu svaret på varje fråga i en mening** (`sources[].a`).
  - Koden jämför svaren med k102-measures mått (minst 4 gemensamma ordstammar, och 60 % av det kortare svaret) innan listan visas.
  - En senare fråga med samma svar tas bort, även när meningarna skiljer sig.
  - Samma gränser som förut: högst en tredjedel tas bort, och varje del behåller en fråga.
  - Det görs i samma anrop, utan extra kostnad. Verifierat i test (`exam/k109_answer_test.ts`).
- **Påfyllningen** frågar en gång till om den första omgången bara gav upprepningar.
  - Live 17:35 fick printing 11 av 14, eftersom alla förslag var upprepningar.
  - Det andra anropet görs bara när provet annars blir kort. Verifierat i test.
- **Mätt live** på Oscars fem material (`k102-measure.py --answers`):

  | | K108 körning 1 | K108 körning 2 | K109 körning 1 (44578553942) | K109 körning 2 (44580848349, med påfyllningen) |
  |---|---|---|---|---|
  | Par med samma korta svar | 8 (4, 2, 0, 1, 1) | 8 (3, 0, 2, 3, 0) | **4** (1, 0, 0, 2, 1) | **7** (1, 1, 1, 4, 0) |
  | Fulla prov mot mål | 5 av 5 | 5 av 5 | 4 av 5 (printing 11/14) | **5 av 5** |
  | Förståelse | 0,57–0,86 | 0,50–0,92 | 0,43–0,75 (Vasa 0,43) | **0,64–0,71** |
  | "framgår inte" | 0 | 0 | 0 | 0 |

- **Ärligt resultat: paren gick från 8 och 8 till 4 och 7, alltså en liten förbättring.** Det mesta är brus mellan körningar.
  - Loggen visar att `drill_same_answer` bara tog bort **en** fråga på tio prov.
- **Var paren kommer ifrån nu (verifierat i loggen och i frågelistorna):** de flesta uppstår **efter** den sista kontrollen, när svarssteget skriver om en fråga (`may_fix`).
  - Vasa körning 1: fråga 6 skrevs om till "Vad var Gustav Vasas skäl …?" med svaret "skulder till Lübeck", som är svaret på fråga 5.
  - Fråga 8 skrevs om till samma sak som fråga 9.
  - Den sista kontrollen ser inte de omskrivningarna.
  - Vasa når dessutom taket på en tredjedel med enbart samma-källa-borttagningar (4 av 14).
- **Förslag till Deangelo** (svarssteget är ditt beslut, K107):
  - Svarssteget ändrar ingenting.
  - När alla svar finns jämför koden de korta svaren, och en omskriven fråga som fick samma svar som en annan får **tillbaka sin ursprungliga fråga och sitt svar**, utan nytt anrop.
  - Svarssteget skriver alltså inte mer. Det som jämförs är bara om dess omskrivning skapade en dubblett.

## 4. Testtaket
50 står kvar (D239 punkt 5). Inget i K109 sökte på webben. `k108-now.py` körs 00:20 UTC som planerat, med 3 av 50.

## Till Angela Fable (A154)
- **402 från `exam drill`/`drill_answers`:**
  - Använd `fits` för att föreslå antalet frågor.
  - `estimated: true` betyder att det exakta talet kommer från `cost` före sparandet.
  - Se risken ovan: visa `cost` före sparandet även när `fits` räckte.
- **`attest_challenge` 503 `attest_unconfigured`** ska inte räknas som ett försök.

## Till Oscar
Omtest av K109:
1. 402 och `fits` på ett nytt testkonto med `x-earmind-test: … user-path`.
2. `attest_challenge` 503.
3. Dina provmätningar från Actions går igen (O91:s provdel).
4. Paren.

## Kvar
- Deangelos val om uppskattningen (a/b/c) och om paren (förslaget ovan).
- 00:20 UTC: `k108-now.py`.
