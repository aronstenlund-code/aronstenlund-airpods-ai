# A52 "Vad kan Lumen?" (D125) och A54 röstning på loggan (D127)

Angela, 2026-11-11. Kö: `prompts/queue/angela.md` A52 och A54. Ingen Angela 2 fanns på tavlan, så båda gjordes här.

Underlag:
- Kellys Ke29 (`docs/design/start-vadkan.md`);
- Kellys Ke31 (`docs/design/logo/rostning/vektor/README.md`);
- Kevins K39 (D131).

## A52 – Vad kan Lumen?
- **Vägen dit (Ke29 S1, Ke33 G1):** den blå textknappen "Allt Lumen kan ›" står sist i rutan "Lumen kan allt" på Start.
  Den öppnar "Vad kan Lumen?" som en vanlig push-skärm.
- **Skärmen** är en grupperad iOS-lista.
  - Ingressen lyder "Som Siri, fast den förstår vad du frågar och svarar direkt i dina AirPods.", följd av en rad om
    hur man gör.
  - Raderna står i fyra grupper med Ke29:s 13 rader:
    - **Plugg:** Förhör, Svar på frågor, Mina svar.
    - **Vardag:** Kalender, Påminnelser, Timer, Larm, Anteckningar, Träning.
    - **Musik och samtal:** Spotify, Ring.
    - **Mer:** Intervju, Sömn.
  - Varje rad har en ikon, ett namn, vad man säger och en statusrad.
- **Statusen är verklig (Ke29):**
  - Kalender och Påminnelser läses från EventKit. Timer och Larm läses från AlarmKit.
  - Raden visar "✓ Tillåtet", "Behöver tillgång till …" med knappen **Tillåt**, eller "Avstängt i Inställningar"
    med Tillåt som öppnar Inställningar.
  - Statusen läses om när man kommer tillbaka till appen.
  - Spotify och Ring står som **"Kommer snart"** utan knapp. Kevins K36 finns på servern sedan 10:58, men appens del
    saknas.
- **Avvikelse från Ke29:** Timer står som "Behöver tillgång till Alarm", inte "Inget att ställa in". Timern går genom
  AlarmKit, och iOS frågar om det första gången (A48).
- **Bladet efter första svaret** visas en gång med rubriken "Lumen kan mer än svara".
  - Det har tre exempel som fungerar utan att man kopplar något (förhör, kalender och timer), och knappen "Visa allt
    Lumen kan".
  - Klar eller svep stänger bladet för alltid. VoiceOver får fokus på rubriken.
  - Bladet kommer på Start när Lumen har svarat minst en gång, alltså efter första starten eller för den som redan
    använt appen.
  - Det kommer aldrig samtidigt med ett annat blad, och aldrig medan Lyssnar visas.

## A54 – Rösta på loggan
- **När:** när appen öppnas, eller kommer tillbaka från bakgrunden, och Lumen har svarat minst en gång. Då har nya
  användare sett introt och första svaret (D127).
  - Bladet efter första svaret i A52 kommer först. Röstningen kommer nästa gång appen öppnas.
- **Arket:**
  - Rubriken "Hjälp oss välja logga" och raden "Vilken tycker du bäst om? Tryck på en.".
  - De tre kandidaterna är lika stora, 96 pt med iOS-maskens hörn (0,2237, continuous). Under varje står Kellys namn:
    Klotet, Den gröna formen och Den orange ringen.
  - Det valda alternativet får en blå ram och ✓.
  - Knapparna är **Rösta** (blå) och **Senare**.
  - Arket kan inte svepas bort, eftersom "Senare" säger vad det betyder att stänga.
- **Senare:** arket kommer tillbaka efter 2 dagar, högst 3 gånger, och sedan aldrig mer. Efter en röst kommer det aldrig mer.
- **Ordningen slumpas en gång per användare och sparas (Ke31).**
  - Ordningen skickas inte med rösten. K39 har inget fält för den.
  - Behövs ordningen i analysen kan Kevin lägga till fältet.
- **Efter rösten:** "Tack för din röst".
  - Med minst 20 röster visas procent per logga som staplar. Det avgör servern (K39).
  - Med färre röster visas "Vi visar hur alla har röstat när fler har hunnit rösta.".
- **Bilderna** är Kellys mörka versioner (Ke31), visade i både ljust och mörkt läge.
  - De är nedskalade till 300 px PNG (48–52 kB styck i stället för 520 kB): `Lumen/Resources/Images/LogoVote{A,B,C}.png`.

## Tekniskt
- `Features/Listening/CapabilitiesView.swift`:
  - `LumenCapability.all` (data);
  - `CapabilityAccess` (behörigheter, statusrad);
  - `CapabilitiesView` och `CapabilitiesIntroSheet`.
- `Features/Onboarding/LogoVoteView.swift`:
  - `LogoVoteSchedule` (ren, sparas i UserDefaults);
  - `LogoVoteClient` (`POST /logo-vote`);
  - `LogoVoteSheet` och `LogoTile`.
- I `HomeView.showSheetOnOpen()` visas högst ett blad när Start öppnas.
- Skärmbildsscenerna `canDo`, `canDoIntro`, `logoVote` och `logoVoteDone` är nya. Tack-bilden visar påhittade siffror.
- **CI:** `ios-build.yml` hoppar över pushar som bara rör `deploy-backend.yml` och QA- och eval-arbetsflödena, se A50-rapporten.

## Testresultat
- **Enhetstester:**
  - `LumenTests/A52Tests.swift` har 4 tester: grupperna, Kommer snart, statusraden och de tre i bladet.
  - `LumenTests/A54Tests.swift` har 5 tester: inte före första svaret, Senare 2 dagar och 3 gånger, aldrig efter röst,
    ordningen sparad, och namnen.
- **iOS-bygge med alla tester (A50–A54):** CI-körning 42999877208: device-bygget utan varningar och alla enhetstester gröna, också A50Tests, A52Tests, A53Tests och A54Tests. Körningen avbröts sedan i arkiveringssteget av nästa push, så ipa:n kommer från en senare körning.
- **Simulatorbilder:** körning 42999887377 (grön), bilder i `reports/2026-11-11-a50-a54-skarmbilder/` (före A55, därför "Lumen").
- **Ej verifierat på enhet:**
  - behörighetsfrågorna;
  - att röstningen når servern från appen. Oscar har provat K39 med curl (O40, 22/22).

## Kända begränsningar
- "Som Siri …" kan ge en fråga i App Store-granskningen, eftersom Siri är Apples varumärke. Det är Kellys **ej verifierade
  bedömning**. Hennes reservtext finns i `start-vadkan.md`.
- Visningsnamnet är fortfarande Lumen. Earmind kommer med A55 (D128).

## Nästa
- Kelly granskar bilderna:
  - `canDo`, `canDoIntro`;
  - `logoVote`, `logoVoteDone`;
  - `myAnswers`, `myAnswersEmpty`, `myAnswerEdit`.
- Toby: T9-rundan.
- Angela: A55 (Earmind), sedan A3 när K6 är klar.
