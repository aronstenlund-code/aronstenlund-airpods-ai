# Angela: A102 – visningstext och uppläsningstext (K66 punkt 4)

Datum: 2026-11-14 21:16. Roll: Angela (app); Angela Fable gjorde vyerna. Inget är **verifierat på enhet**. Inga tester
mot ElevenLabs (D180).

## Vad som är gjort
- **Bakgrund:** Kevins K66 lade till ett valfritt fält `screen` på varje fråga, med bara de delar som skiljer sig från den
  talade texten. Skärmen visar siffror och formler som i en lärobok ("1856", "a² + b² = c²", "A = π · r²").
  Rösten läser `question`, `short` och `long` med talen som ord, som förut.
- **Modellen (b793ea6):**
  - `DrillItem.screen` (`DrillScreenText`).
  - `shownQuestion`, `shownShort` och `shownLong`, och `shownAnswer` för redigeraren.
  - Ett gammalt prov utan fältet visar samma text som i dag.
- **Från /exam:** `drill`, `drill_answers` och `drill_one` läser `items[].screen`. Det visade långa svaret börjar med det
  visade korta, precis som det talade gör.
- **Sparas och hämtas:**
  - `/drill save` skickar med `screen`, bara de delar som finns.
  - `get`, `status` och `list` läser tillbaka det (`Drill.from`).
  - En kopia av ett hämtat prov tar med sig fältet. Det gör servern.
- **Granska (`DrillItem.edited`):**
  - Ett fält som eleven inte ändrar behåller både sin talade text och sin visningstext.
  - Ett ändrat fält läses upp och visas som eleven skrev det, och dess gamla visningstext tas bort, som Kevin sa.
  - Ljudet görs om bara för text som ändrats.
- **Förhandsvisningen av ett publicerat prov (d73eb3d):** `Preview.screen`, `shownQuestion` och `shownShort`. Kevin
  skickar fälten sedan 57343bd.
- **Vyerna (Angela Fable, b653069 och a22868b):** visningstexten används i
  - frågelistan;
  - uppspelningen;
  - redigeraren, som sparar med `edited`;
  - importen, Hjälp och "Stämmer det här?";
  - förhandsvisningen.

  VoiceOver läser den talade texten, eftersom den låter rätt uppläst.

## Test
- `A102ScreenTextTests`:
  - ingen visningstext ger den talade texten;
  - ett oförändrat fält behåller båda texterna;
  - ett ändrat svar mister sin visningstext och får nytt ljud;
  - det visade långa svaret byggs från /exam;
  - `save` skickar bara visningsfälten, och `get` läser dem.
- **CI:** iOS build 43632730806 (a22868b, innehåller b793ea6, d73eb3d och Angela Fables vyer) är grön, med ipa.
  `A102ScreenTextTests`, `A87PublicationPreviewTests` och `A79A81RepetitionTests` gick igenom.
- **Bilder:** simulatorbilderna 43632631870 (iPhone 17 Pro, ljust och mörkt) är gröna.
  - `repNumbers` visar "a² + b² = c².", "A = π · r²." och "1856." under frågorna.
  - `repNumbersEdit` visar "A = π · r². π är ungefär 3,14.".
  - `repList`, `repEdit` och `repPlayAnswer` ser ut som förut.
- **Live:** Kevin har provat `save` och `get` och förhandsvisningen med ett testkonto, 0 krediter. Appen mot servern är
  **inte testad på enhet**.

## Kvar
- Kelly granskar `repNumbers` och `repNumbersEdit` (lagt i hennes kö).
- A3 väntar på K6.
