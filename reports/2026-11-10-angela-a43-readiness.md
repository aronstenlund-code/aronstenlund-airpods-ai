# A43 – Framsteg per prov: "Så redo är du" (N1) (Angela, 2026-11-10)

Underlag: kön och Kevins K33 (`reports/2026-11-10-2027-kevin-k31-k32-k33-streak-fun-ready.md`).
**Det här är kod, enhetstester och simulatorbilder. Inget är provat på telefon** mot den riktiga `/study-plan`.

## Vad som gjordes
1. **Ringen på provkortet:** "68 %" står i en ring till höger om provets namn. Ringen är blå på `soft`, med en enda
   accentfärg enligt SYSTEM.md. Den fylls en gång när den visas, på 0,6 s med ease-out, och direkt med "Minska rörelse".
   - Ringen syns bara när K33 har räknat fram ett värde, alltså när provet har begrepp.
   - VoiceOver säger "68 procent redo. Visar vad du kan och vad du ska öva på."
2. **"Så redo är du"** öppnas med ett tryck på ringen:
   - Överst finns den stora ringen, "redo för biologiprovet" och K33:s mening: "Räknat på 12 begrepp, 7 övade. Ett
     begrepp räknas fullt när du har haft rätt tre gånger i rad."
   - **Öva på:** K33:s tre svagaste begrepp med skälet, till exempel "Fel senast", "Inte övat än" eller "Dags att
     repetera".
   - **Det här kan du:** begrepp som haft rätt de två senaste gångerna, högst sex. Listan räknas på telefonen från
     samma historik som skickas till K33.
   - **Dagens pass:** raden från studieplanen (A19).
   - Längst ner finns knappen "Förhör mig" ("Lumen börjar med det du behöver öva på"). Den startar förhöret för provet.
3. **Minitestets svar räknas nu i planen**, på samma sätt som vändkorten (A46). Kevin bad om det i K33. Begreppet blir
   provets ämnesord om kortet nämner det, annars frågan.

**Kod:**
- `Lumen/Features/Listening/ReadinessView.swift` är ny och innehåller `ReadinessRing` och `ReadinessView`.
- `ListeningModel` har fått `readiness(for:)`, `knownConcepts(for:)` och `known(_:)`. Den har också
  `stageStudyPlanForScreenshot`, men bara i Debug.
- `HomeView` visar ringen och sidan.
- `ScreenshotStage` har fått scenen `readiness`. Start visar ringen och streaken från demosvaret.

## Tester
`LumenTests/A43Tests.swift`:
- "Det här kan du" tar med begrepp som haft rätt de två senaste gångerna, högst sex, sorterade på namn;
- skälet visas med stor bokstav.

K33-svaret med `readiness` testas i A38Tests.

## Rättat efter bilderna
De första bilderna visade "0 %" på Start. Simulatorn har nät och hämtade den riktiga planen, och den skrev över demon.
Det ledde till två ändringar:
- **Ringen visas inte förrän något begrepp är övat** (`practiced` > 0). Ett nytt prov på "0 %" säger inget och tar
  bara modet ur eleven.
- Skärmbildsläget hämtar inte planen, så demon står kvar.

Rättningen (`5acf752`) är grön i CI: iOS build 42906464623. Bilderna är tagna efter den, i körning 42906482012.

## CI
Grönt i CI: iOS build 42896654570 (`036775c`). Det gäller körning 2. I körning 1 avslutades testerna direkt efter
"Testing started" utan något fel i loggen, och det var simulatorn på maskinen. Bygget för enhet räknar varningar som
fel, och alla LumenTests är gröna, A43Tests inräknade.

## Bilder
Simulatorbilder från iPhone 17 Pro ligger i `reports/2026-11-10-a38-a43-skarmbilder/`:
- `readiness`;
- `home` med ringen och streaken.

## Kända begränsningar
- "Det här kan du" räknas på telefonen, eftersom K33 bara skickar de svagaste. Två rätt i rad är min gräns. K33 ger
  0,75 för det.
- Ringen visas först när något är övat och planen har hämtats, alltså inte utan nät eller innan Start har frågat.

## Till Kelly
Granska ringen på provkortet och sidan "Så redo är du" (`readiness`).
