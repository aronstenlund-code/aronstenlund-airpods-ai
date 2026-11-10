# A38 – Streak och notiser som Duolingo (C2 + C3) (Angela, 2026-11-10)

Underlag: D115 (C2, C3), kön och Kevins K31 (`reports/2026-11-10-2027-kevin-k31-k32-k33-streak-fun-ready.md`).
**Det här är kod, enhetstester och simulatorbilder. Notiserna på en riktig telefon är inte provade**, varken tiden,
texten på låsskärmen eller att dagens notis försvinner när frågan är gjord (untested assumption).

## Vad som gjordes
1. **Förhörsdagar på telefonen** (`QuizDays`): varje dag med minst en besvarad förhörsfråga sparas, högst 400 dagar.
   Det räknas som en förhörsfråga när man:
   - svarar på Lumens kontrollfråga i "Förhör mig", alltså ett svar direkt efter ett svar från Lumen som slutar med "?";
   - får en uppgift rättad i övningsprovet eller provet;
   - svarar i minitestet;
   - svarar ja eller nej i det tysta förhöret;
   - markerar ett vändkort (A46).
2. **Streaken på Start:** en liten bricka bredvid inställningarna med en låga och siffran, till exempel "🔥 3". Den
   följer SYSTEM.md: `soft` som bakgrund och blå text.
   - Lågan är ihålig tills dagens fråga är gjord.
   - VoiceOver säger "Svit: 3 dagar i rad" och "Gör en förhörsfråga i dag, annars börjar sviten om".
   - Brickan syns inte när sviten är 0.
   - Regeln är K31:s: sviten är dagarna i rad som slutar i dag, eller i går om dagens fråga inte är gjord än. En
     missad dag nollställer sviten, utan frysning. Appen räknar själv, så brickan stämmer också utan nät och direkt
     efter första frågan.
3. **`quiz_days` skickas till `/study-plan`.** Svaret har nu `streak`, `notification` och `readiness` (K33, A43). Ett
   svar utan dem går fortfarande att läsa. Planen hämtas också när eleven inte har något prov men har förhörsdagar.
4. **En notis om dagen** ersätter A19:s notis per plandag:
   - **I dag:** K31:s text, till exempel "3 dagar kvar till Biologiprovet" och "5 snabba frågor på cellandning håller
     din svit på 2 dagar vid liv." Det blir ingen notis när dagens fråga redan är gjord.
   - **De kommande sex dagarna:** nedräkning till närmaste prov med samma ord som K31: "2 dagar kvar till …",
     "I morgon är det …" och "I dag är det …. Lycka till!". Texten under är "5 snabba frågor på mitos. Det tar två
     minuter.", med planens begrepp för den dagen. Utan prov blir rubriken "5 snabba frågor".
   - **Dagens första förhörsfråga tar bort dagens notis direkt.**
   - Notiserna läggs om varje gång Start öppnas.
5. **Eleven slår på dem och väljer tid:**
   - **Inställningar › Påminnelser:** "Påminn mig varje dag" och "Tid" (timme och minut). Klockan 16:00 gäller tills
     Aron väljer.
   - **Start:** knappen heter "Påminn mig kl. 16:00", med den valda tiden. iOS frågar om lov bara när knappen
     trycks, aldrig av sig själv.

**Kod:**
- `QuizDays`, `StudyPlanAPI.Streak`, `Note`, `Readiness` och `countdown` finns i `Lumen/Core/Study/StudyPlan.swift`.
- `LumenNotifications` har fått `days`, `scheduleDaily`, `cancelToday`, `reminderMinutes`, `timeText` och
  `fireDate(minutes:)`.
- `ListeningModel` har fått `streak` och `noteQuizAnswer()`, och `refreshStudyPlan` har skrivits om.
- `StreakBadge` finns i `HomeView`.
- Tidsväljaren finns i `SettingsView`.

## Tester
`LumenTests/A38Tests.swift`:
- sviten slutar i dag eller i går, och en missad dag nollställer den;
- bara dagens första svar räknas, och det finns ett tak för antalet dagar;
- `quiz_days` skickas, och K31:s och K33:s svar går att läsa, också ett gammalt svar utan dem;
- veckans sju notiser stämmer:
  - i dag kommer backendens text;
  - de andra dagarna har nedräkningen, "I morgon", "I dag" och "5 snabba frågor" efter provet;
  - det blir ingen notis i dag när frågan är gjord;
- den valda tiden används, och en tid som redan passerat ger ingen notis;
- texten "16:00" och "07:05" visas rätt.

## CI
Grönt i CI: iOS build 42893505069 (`7f5b37b`). Bygget för enhet räknar varningar som fel, och alla LumenTests är gröna, A38Tests inräknade.

## Bilder
Simulatorbilder från iPhone 17 Pro ligger i `reports/2026-11-10-a38-a43-skarmbilder/` (körning 42906482012).
`settings` visar "Påminn mig varje dag" och "Tid". Start visar brickan "3" bredvid inställningarna
(tre förhörsdagar i demon).

## Kända begränsningar
- Om en kontrollfråga räknas avgörs av ett frågetecken i Lumens förra svar. Ett svar som slutar med en fråga som inte
  var en förhörsfråga räknas också. Det gör det lätt att behålla sviten, och det tycker jag är rätt.
- Notiserna för de kommande dagarna skrivs i appen, så sviten nämns inte i dem. Bara dagens notis har K31:s text med
  sviten.
- Sviten finns bara på den här telefonen. Den följer inte med till en ny telefon.

## Till Aron
- Välj standardtiden för påminnelserna. Nu är den 16:00, och eleven kan ändra den i Inställningar.
- Prova på telefonen: gör en förhörsfråga, och kontrollera att lågan blir fylld och att ingen påminnelse kommer i dag.

## Till Kelly
Granska brickan med lågan på Start. Den är blå på `soft`, eftersom SYSTEM.md har en enda accentfärg. Duolingos
orange låga är inte med. Säg till om lågan ska ha en egen färg.
