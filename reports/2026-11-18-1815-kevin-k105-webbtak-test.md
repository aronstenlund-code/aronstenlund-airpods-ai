# K105 (D234): eget webbtak för testtrafik; K93 avslutat

Kevin (moln), 2026-11-18. 0 ElevenLabs och 0 Claude, eftersom inga liveanrop gjordes. Tester: **739/739**. Commit 4be7dc3b, deploy-backend 44355766934.

## K105: taket delat, summan 150 som förut
- **Testanrop**, det vill säga anrop med huvudet `x-earmind-test`, räknas mot `answer-web-test:global:d` med **50 per dygn**. **Övriga anrop** räknas mot `answer-web:global:d` med **100 per dygn**.
  - Användartaket räknas fram som hela taket minus testtakets andel, så summan blir alltid hela taket. Hela taket är `WEB_GLOBAL_PER_DAY`, 150 som förut. Testtakets andel är `WEB_TEST_GLOBAL_PER_DAY`, 50.
  - Om miljövariabeln för hela taket är satt ändras alltså bara fördelningen. Testtaket kan aldrig bli större än hela taket.
- **Taken per användare** (5 per minut, 20 per dygn) gäller som förut, för testkonton under namnet `answer-web-test:u:…`.
- **Alla fyra ställen som tar webbtaket** använder samma regel: textbegäran, webbfråga, `[[SÖK]]`-omförsöket och länksökningen (K19).
- **Fältet `done.web_cap_test: true`** kommer bara när ett testanrop nekas för att testtakets globala dygnstak är slut. Svaret kommer då ur minnet som vid ett fullt användartak. Fältet kommer aldrig på vanliga anrop.
- **Dagens räknare är orörda (D234):** delningen gäller från **2026-11-19 00:00 UTC**. Fram till dess delar alla anrop som förut på `answer-web:global:d` med 150, som redan är fullt.
  - Om delningen hade gällt direkt hade testerna fått 50 nya sökningar i dag, alltså 200 i dag i stället för 150.
  - Att slå på webbsvaren för användarna i dag är Arons beslut (TILL-ARON #33).
- **Tester** (`answer/k105_test.ts`, verifierat i test):
  - Taken summerar till hela taket. Före 19 november delar alla på ett tak.
  - Ett testanrop rör inte användartaket, och ett vanligt anrop rör inte testtaket.
  - Båda taken stoppar vid sin gräns, och `web_cap_test` kommer bara på testanrop.
- **Inte verifierat live:** det kan provas först efter 00:00 UTC.

## K93: avslutat som avtalat
- Run 44303031581 (12:20–14:05 UTC): `became_admin` ja och `admin_no_402_no_charge` ja, men `admin_removed` nej.
  - Testraderna togs inte bort inom de 100 minuterna, eftersom borttagningen väntade på Arons ja.
  - **Admin-delen är verifierad live** (runs 44294239066 och 44303031581). Att ett konto som tas bort ur `credit_admins` räknas och nekas igen är **verifierat bara i tester**.
- Testraderna 61e59f02 och d4dda596 ligger kvar i `credit_admins` tills Deangelo tar bort dem.
- Detaljerna står i K93-avsnittet i `reports/2026-11-18-1240-kevin-k102-forstaelse-fulla-prov-warm.md`.

## Till Oscar (O89)
`done.web_cap_test: true` betyder att testtaket är slut och att fallet ska räknas som överhoppat, inte som fel. Det gäller från 2026-11-19 00:00 UTC.

## Nästa
- **Efter 00:00 UTC:** mät Haiku mot Sonnet igen (K104), nu mot testtaket. Mätningen ska ha minst 20 frågor som verkligen söker och får ta högst cirka 48 av testtakets 50. Samtidigt kontrollera `searching` live och Oscars N1 (sökprat i svaret).
- Två saker från Oscars O88 är inte gjorda: "Det beror mest på" och "ett och en halv tesked" (N2–N4).
