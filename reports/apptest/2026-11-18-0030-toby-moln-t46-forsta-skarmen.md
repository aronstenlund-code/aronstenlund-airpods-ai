# T46 – Första skärmen (A132, D215) och T51 – A137-grenen

Toby (moln), 2026-11-18 00:30. Simulatorn (iPhone 17, iOS 26, Xcode 26.6), falskt ljud (`LUMEN_TEST_HEADER`), 0 ElevenLabs (D180). **Allt nedan är verifierat i Simulator, inte på enhet.**

## Vad som gjordes
- T36-testet (`AppTests/E2E/Screens/SayFlowTests.swift`) följer A132: Spela i 10 min spelar på kortet på Start, Stoppa i stället för Avsluta, texten på kortet öppnar spelaren, Senaste i stället för Nästa prov, borttagning med långt tryck i Senaste.
- Nya kontroller för T46:
  - tid kvar på kortet
  - Pausa/Fortsätt på kortet ("· pausad")
  - raden om låst telefon före och efter första Spela
  - inga provrubriker efter en Säg-text
  - kapseln lägger tillbaka texten utan att spela
  - fältets höjd: "Hej" och sedan 1, 3, 8 och 14 meningar med tangentbordet uppe
- Kapselns kredittal läser också A139:s korta form ("5,3k krediter kvar").
- Alla app-tester (T24, T27, T28, T29, T30, T36): om en knapp inte går att trycka på tar testet en annan knapp med samma namn som går att trycka på. Skäl: A132:s egen "Klistra in" på Start (tomt fält, text i urklippet) står bakom bladet med ChatGPT-svaret och har samma namn. Testet tog den knappen först, och därför var alla sex röda i T51-körningen 44163428569.
- Nattflödet har två nya val: `only` (kör bara några tester) och `tests_ref` (testerna från en annan gren än main). Dagens fil får då `-tester-<gren>` i namnet.

## Testresultat
T36-körning 44168262433 på toby/t46 (main-app med A132), alla tio delar OK:
- Huvudknappen heter "Spela i 10 min". Kostnaden står vid knappen ("78 krediter"), och vid en lång text "526 krediter".
- "Du kan låsa telefonen. Det hörs i AirPods ändå." syns före första Spela och är borta efter.
- Start ligger kvar när texten spelar. Kortet visar "Spelar i AirPods", "9:45 kvar", Pausa och Stoppa. Pausa ger "9:40 kvar · pausad", och sedan Fortsätt.
- Texten på kortet öppnar spelaren, och Varv 2 kommer.
- Inga rubriker Nästa prov eller Andra prov efter en Säg-text. Senaste har en kapsel "Klorofyllet i bladen få…". Kapseln lägger tillbaka texten utan att spela den.
- Fältets höjd med tangentbordet uppe: "Hej" 64, en mening 64, tre meningar 88, åtta meningar 108 och fjorton meningar 108. Fältet växer alltså och stannar vid fem rader.
- Långt tryck och Ta bort tar bort kapseln. Den kommer inte tillbaka efter 10 s.
- "Högst en fylld blå knapp" kan inte läsas ur trädet. Det syns bara på skärmbilderna (untested assumption).

## Kända saker och risker
- "Vill du ha en påminnelse?" (A109) kommer upp några sekunder efter första Spela och täcker kortet medan texten spelar. Testet svarar Inte nu. För användaren betyder det att Pausa och Stoppa är dolda tills bladet stängs. Möjligt fynd till Angela Fable (vy), skrivet i hennes kö.
- I spelaren hittade testet ingen "Mening N av M", så det kan inte se om 2 tryck hoppar till nästa mening (UNCLEAR, inte rött).
- Krediterna går inte ner med x-earmind-test (1500 → 1500). Den frågan ligger fortfarande hos Kevin (T44).

## T51 (A137)
Den första körningen 44163428569 var röd i alla sex tester, med A132:s "Klistra in" som orsak (se ovan) och inte A137. Main har ingen körning efter A132. Omkörning med de rättade testerna: 44198544586 (`tests_ref=toby/t46`). Beskedet kommer i angela.md.

## Nästa session
- Slå ihop toby/t46 med main när T51-omkörningen är grön och inget iOS-bygge på main kör.
- Sedan T49 (A135, spela utan nät) och T50 (A136, stil, röster och Skriv i takt). Båda finns på main.
