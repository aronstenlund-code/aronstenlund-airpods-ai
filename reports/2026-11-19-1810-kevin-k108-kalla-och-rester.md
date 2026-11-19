# K108 (D238): webbsvar med källa, och nattens rester

Kevin (moln), 2026-11-19. **0 ElevenLabs.** Provmätningarna använde testkonton och inga webbsök, eftersom testtaket var fullt i dag (K104 28 och nattens eval 22). Tester: **763/763**. Commits 9ee8478d och 2218b155, båda deployade. Livemätningar: 44570885860 och 44572891559.

## 1. Webbsvar utan källa (Oscar O89 del 2): roten och rättningen
- **Roten, verifierad i loggen:**
  - Nattens eval 10:27–10:32 UTC har flera svar med `"category":"webbsökning"` men en kostnad på cirka 0,0002 USD. Svar som söker kostar cirka 0,010 USD.
  - Modellen hade alltså webbverktygen men valde att svara ur minnet. Därav "Det är cirka det senaste jag vet" för statsministern, och "Källan är SMHI" för vädret, där källan var påhittad eftersom inget sök gjordes.
  - Inget fel i `searching`, D233 eller K104: verktygen fanns, men användes inte.
- **Rättningen:**
  - Frågor om nuläget, uttryckliga "sök" eller "kolla", länkar och priser **måste nu söka** (`mustSearch` i web.ts, `tool_choice: any` som för ordningstal, D72).
  - Undantag: sånger och citat (de har egna regler), svar med tänkande (API:t tar då bara `auto`) och svar med telefonverktyg (där "any" kunde välja fel verktyg).
  - Webbprompten säger nu att ett svar om nuläget anger det källan säger, med datum om källan har ett, och aldrig "cirka det senaste jag vet".
- **webb-05 ("kolla scb.se …", "Källa: scb.se" i texten):** servern tar alltid bort "Källa: X" ur det som läses upp och skickar `done.source` (verifierat i test). Det svaret gick alltså en annan väg, möjligen ett sparat svar (untested assumption). Oscars nya live-eval sparar `web_searches` och `source` per rad, så nästa natt syns vägen.
- **Tester:** `answer/k108_test.ts`. Statsministern ger `tool_choice: any`. Däckbyte och sång ger det inte.
- **Live:** `scripts/k108-now.py` körs 00:20 UTC, med 3 av testtakets enheter. Resultatet fylls i efter körningen.

## 2. praktiskt-03, 80 ord (D238)
Taket på 80 ord står kvar. En instruktion i webbsvar är nu högst de fem viktigaste stegen, i ordning, och högst 70 ord. Verifierat i test (prompten). Live i nattens eval.

## 3. K107-resterna (Oscars omtest K107)
- **"framgår inte" i alla former**, till exempel "framgår inte av detta", och "inte känt" oavsett ordföljd, räknas nu som obesvarat och ger ett nytt försök. Verifierat i test.
- **"…? Ge exempel?"** blir en fråga. Verifierat i test.
- **Samma huvudmening = samma svar:** den sista kontrollen anger nu huvudmeningen först, och två frågor med samma huvudmening räknas som samma fråga.
- **Påfyllningen** får numrerade meningar och en lista över dem som de behållna frågorna redan använder, så att nya frågor tas från andra meningar. Det kostar inget extra anrop.
- **Mätt live** på Oscars fem material (`k102-measure.py --answers`):

  | | Före K107 | Efter K107 | K108 steg 1 (44570885860) | K108 steg 2 (44572891559) |
  |---|---|---|---|---|
  | Par med samma korta svar | 13 | 7 | 8 (4, 2, 0, 1, 1) | 8 (3, 0, 2, 3, 0) |
  | Fulla prov mot mål | 5 av 5 | 5 av 5 | 5 av 5 | 5 av 5 |
  | Förståelse | 0,43–0,86 | 0,64–0,89 | 0,57–0,86 | 0,50–0,92 (Vasa 0,50) |
  | "framgår inte" | – | 0 | 0 | 0 |

- **Resultat:** "framgår inte" och "…? Ge exempel?" är borta, och proven är fulla.
  - Antalet par med samma svar ligger kvar på 7–8 per körning, mot 13 före K107. Varken huvudmeningsregeln eller påfyllningens meningslista gav en mätbar minskning.
  - Två skäl: taket på en tredjedel nås (till exempel 4 av 14 i ekosystem), och svarsstegets omskrivningar (`fixed_by_answers` 1–4 per prov) ger nya par.
  - Vasa föll till 0,50 i förståelse i steg 2, precis på gränsen enligt D230.
- **Förslag till nästa steg (Deangelo):** låt den sista kontrollen också skriva en mening med svaret per fråga. Koden jämför sedan svaren innan listan visas, med k102-measures mått, och då ses parens svar och inte bara deras källmeningar. Det kostar cirka 1 s mer i den sista kontrollen och ändrar inte svarssteget.

## 4. style_failed: texten Haiku vägrade
- **Hittad i loggen:** 2026-11-17 20:21:23 UTC, testkontot cac2e168, Oscars `o78_o80_live.py`.
  - Texten var påhittade stavelser (`word()` ger "bakomu tifera …").
  - Stilen var "Lugnt och tydligt, med pauser så att man hinner skriva".
- **Inga nya vägranden** sedan dess. Loggen 18 nov 16:50 till 19 nov 16:50 visar 0 `style_failed` och 0 `style_words_changed`.
- **Sedan K106:**
  - Prompten säger att det bara handlar om formatering och att påhittade ord är vanliga.
  - Vägrar Haiku ändå sätter koden taggarna utifrån önskan, så stilen går aldrig förlorad.
- **Nytt i K108:** loggen skriver vid ett vägrande längd, antal ord, andelen ord som ser riktiga ut och om koden tog över, men aldrig texten. Nästa fall kan då kännas igen utan att elevens text sparas.

## 5. Nattens evalbehov mot testtaket (förslag till Deangelo)
- **Behov:** natten drar cirka 29 enheter (Oscar O89 del 2, verifierat i koden).
  - needsText och needsWeb ger cirka 21.
  - K16.1, osäker modell som söker en gång till, och K19, resursfrågor, ger cirka 8.
- **Med K108 blir behovet lika stort:** frågor om nuläget hade redan webbverktyg och räknades redan, även när modellen inte sökte. Däremot blir kostnaden per sådan fråga högre, cirka 0,01 USD i stället för 0,0002, eftersom de nu söker.
- **Tak 50:** natten får 29, så 21 blir kvar för dagens mätningar och omtester (Kevin, Oscar, Toby). Det räcker, om mätningarna läggs **efter** evalen (cirka 10:45 UTC) eller hålls under 20 före den.
- **Förslag:**
  - (a) Behåll 50, och flytta de egna mätningarna till efter 10:45 UTC. Det kostar inget extra.
  - (b) Höj testtaket till 70 och sänk användarnas till 80, så att summan blir 150 som förut. Det passar bara om användarna i praktiken använder färre än 80 sökta svar per dygn. Det har jag inte kunnat mäta, eftersom `rate_limits` inte går att läsa för mig.
  - (c) Höj summan till 170. Det kostar högst cirka 0,2 USD per dygn i sökningar, plus tokens.
  - **Jag rekommenderar (a)**, och (c) om omtesterna blir fler. Deangelo eller Aron avgör.

## Till Oscar (O91)
Se oscar.md: K108-punkterna att testa om i natt, och en notis om att `k108-now.py` drar 3 enheter vid 00:20 UTC.
