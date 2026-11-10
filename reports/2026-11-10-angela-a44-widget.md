# A44 – Hemskärmswidget (N2) (Angela, 2026-11-10)

Underlag: kön (A44, som bygger på A38). **Det här är kod och enhetstester. Widgeten är inte fotad**: skärmbildsflödet
fotar appens skärmar, inte hemskärmen. Den är inte heller provad på telefon (untested assumption, se risken med
appgruppen nedan).

## Vad som gjordes
1. **Widgeten "Nästa prov"** finns i två storlekar, liten och mellan. Den ligger i det befintliga tillägget
   `LumenControls`, bredvid Live Activity och kontrollerna.
   - **Liten:**
     - loggan överst, och streaken (låga och siffra) när den lever;
     - provets namn;
     - brickan "5 dagar kvar", "I morgon" eller "I dag";
     - knappen "Förhör mig".
   - **Mellan:** samma innehåll, plus ringen "68 % redo" från A43 till höger.
   - **Utan prov:** "Har du prov snart? Lägg till det i Lumen." och knappen.
   - Färgerna och typsnittet är appens (SYSTEM.md). Bakgrunden är `background`.
2. **"Förhör mig"** är en App Intent (`StartQuizIntent`) som öppnar Lumen. Förhöret startar för närmaste prov, eller
   Provläget om det inte finns något prov. Mikrofonen startar alltså bara med appen öppen, som D58 säger.
3. **Data:** appen skriver en liten ögonblicksbild (`ExamWidgetSnapshot`) till appgruppen
   `group.com.rsolutions.lumen`. Bilden innehåller provets namn och datum, streaken, om dagens fråga är gjord och "%
   redo". Inga frågor, inga svar och inget ljud delas.
   - Bilden skrivs när planen hämtas, efter dagens första förhörsfråga och när ett prov sparas. Widgeten laddas om
     bara när något den visar har ändrats.
   - **Dagar kvar** byts vid midnatt utan appen, eftersom tidslinjen har en post per dag.
   - **Streaken** visas bara medan den lever, med samma regel som i appen.

**Kod:**
- `Shared/ExamWidgetSnapshot.swift` är ny och innehåller ögonblicksbilden och `StartQuizIntent`.
- `LumenControls/ExamWidget.swift` är ny.
- `ListeningModel+Widget.swift` är ny och innehåller `updateWidget`, `widgetChanged` och `quizFromShortcut`.
- `ListeningRemote.quiz` är ny.
- `Entitlements/Lumen.entitlements` och `Entitlements/LumenControls.entitlements` är nya.
- `CODE_SIGN_ENTITLEMENTS` finns i `project.yml`.

## Tester
`LumenTests/A44Tests.swift`:
- dagar kvar byts vid midnatt och försvinner efter provet;
- streaken på widgeten dör som i appen;
- widgeten laddas om bara vid en ändring, eller när det har blivit en ny dag;
- ögonblicksbilden kan sparas och läsas tillbaka.

## CI
Grönt i CI: iOS build 42903038141 (`50937a9`). Både appen och tillägget med widgeten byggs för enhet med varningar som
fel, och alla LumenTests är gröna, A44Tests inräknade.

## Risker och begränsningar
- **Appgruppen och Sideloadly (untested assumption):** CI bygger utan signering (D70). Därför följer appgruppens
  rättighet inte med i `Lumen-unsigned.ipa`, och Sideloadly signerar utan den.
  - På Arons telefon kan widgeten därför visa "Har du prov snart?" fast det finns ett prov. Knappen öppnar ändå
    Lumen.
  - Med ett Apple Developer-konto och TestFlight fungerar appgruppen som den ska.
  - Om Sideloadly vägrar installera för att tillägget har en rättighet ska jag ta bort raden.
- Widgeten visar bara närmaste prov.
- Med Sideloadly räknas tillägget redan som ett eget app-id på det gratis kontot, så det blir inget nytt id.

## Till Aron
- Prova: lägg till widgeten "Nästa prov" på hemskärmen och tryck på "Förhör mig".
- Säg till om den visar "Har du prov snart?" trots att du har ett prov. Då är det appgruppen, och den kräver
  utvecklarkontot.

## Till Kelly
Widgeten är inte fotad. Säg till om du vill ha en bild ritad i appens skärmbildsflöde, som en egen scen med widgetens
vy.
