# K104 del 2 igen (D233/D234): Haiku mot Sonnet för sökta svar, omgång 2 mot testtaket

Kevin (moln), 2026-11-19 00:24–00:27 UTC, Actions 44428682870. **0 ElevenLabs.** Testkonton, alltså testtaket (`answer-web-test:global:d`). 28 anrop med webbverktyg, och Claude kostade 0,28 USD. **Verifierat live.**

## Varför 14 frågor och inte 20
- Nattens eval kl. 02:17 UTC behöver cirka 21 av testtakets 50 (Oscars notis i kevin.md, 18:45). 14 frågor gånger 2 modeller blir 28 anrop, och då har natten 22 kvar.
- Alla 14 frågorna har webbverktyg från första anropet, kontrollerat lokalt: texter, "vem vann … 2024/2025", "just nu" och en instruktion.
- Modellen valde ändå att inte söka i några av fallen (`web: 0`). Bara 8 frågor sökte med båda modellerna.

## Resultat
| | Sonnet | Haiku |
|---|---|---|
| Rätt av 14 (facit) | **13** | **11** |
| Rätt av de 8 som sökte med båda | 7 | 7 |
| Första ordet, median (max) | 4 779 (7 030) ms | 2 340 (4 482) ms |
| Kostnad för 14 | 0,142 USD | 0,139 USD |

- **Där de skiljer sig:**
  - **Hej tomtegubbar:** Haiku sökte inte, gav fel text och sa att den är "en modern version med upphovsrätt". Det är fel; sången är traditionell.
  - **Du gamla, du fria:** Haiku avstod från texten ("jag har inte säker tillgång till hela versen ordagrant"). Sonnet gav den.
  - **Eurovision 2025:** Haiku sa "Schweiz med The Code, Nemo", alltså vinnaren 2024, trots att den sökte. Sonnet svarade rätt: Österrike, JJ, "Wasted Love".
  - **Strindbergcitatet:** Sonnet föll tillbaka på "Jag kan inte citera det ordagrant, men Strindberg …" (K11), och facit räknar det som fel. Haiku gav ett citat ur "Utopier i verkligheten". Att citatet är ordagrant är inte kontrollerat (untested assumption).
- **Beslut enligt D233: Sonnet behålls.** Haiku hade lägre andel rätt, 11 av 14 mot 13 av 14. Felen gäller dessutom traditionella sånger och ett faktum efter sökning.
  - Haiku är cirka 2,4 s snabbare till första ordet men kostar inte mindre per sökt svar, eftersom sökningen kostar mest.
  - Även om de sex frågor som är kvar till 20 skulle falla ut till Haikus fördel räcker det bara om Sonnet missar fyra av dem. Jag föreslår därför att inte köra resten, så att testtaket sparas. Deangelo avgör.

## Sökt live samtidigt
- **`searching` (K104):** kom före första ordet i **19 av 19** svar med sökning, i median 1 895 ms före. Rättningen av tidsgränsen (653c3ddb) fungerar. **Verifierat live.**
- **`web_cap_test` (K105):** 0 av 28. Testtaket räckte, och fältet syntes inte i onödan. **Verifierat live.**
- **Delningen av taket (K105):** gäller nu. Anropen räknades mot testtaket, och användarnas tak (100) var orört.
- **Sökprat:** Haikus "Enligt de källor jag hittade är …" (FN-frågan) är en inledning till själva svaret och fångas inte av N1-filtret. Det gäller bara Haiku, som inte används för sökta svar.

## Kvar
- Om Deangelo vill ha 20 frågor: `k104-models.py --set=2`, efter 00:00 UTC, med högst 20 anrop.
- "Det beror på" i webbsvar (K106 N2) är inte provat live i den här körningen. Klimatfrågan var inte med, för att spara taket.
