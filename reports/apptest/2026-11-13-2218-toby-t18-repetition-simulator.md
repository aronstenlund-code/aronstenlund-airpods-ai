# T18 – Repetitionsläget i simulatorn (Toby 2, 2026-11-13 22:18)

**Simulatorn räknas aldrig som verifiering på enhet.** Det som kräver Arons iPhone och AirPods står i
`docs/TEST-ARON-REPETITION.md` (högst 10 min). Aron testar på telefonen samtidigt, och hans svar är inte inlagda här.

## Vad som testades
- **Bygget:** main 1363518, med Angelas A82 (iOS-bygge 43501199803 på 10bf4a0 grönt). Kellys B2 (270b0a0, "Fler lägen" på
  Start) kom efteråt och är inte med.
- **Körning:** [43507025903](https://github.com/aronstenlund-code/aronstenlund-airpods-ai/actions/runs/43507025903). Den
  gick grönt med 5 av 5 tester på 171 s.
- **Rådata:** `reports/apptest/2026-11-13-t18/`. Där finns händelser per fil med position och spelarens steg.
- **Uppsättning:**
  - `AppTests/E2E/Repetition/RepetitionE2ETests.swift`, `scripts/apptest/repetition.sh` och `apptest-repetition.yml`
    (manuellt och vid push till `toby/**`).
  - Det riktiga `RepetitionSession` med `FileRepetitionAudioSource` (AVAudioPlayer) och
    `TaskRepetitionTimer(keepsPlaying: true)`.
  - Tryck skickas genom `RemoteCommandHub.route` med samma kommandon som AirPods ger.
  - Ljudet är mockljud: svaga toner med kända längder. Frågan är 2,0 s, det långa svaret 6,0 s med kortsvarets slut vid
    2,5 s, och den egna kortsvarsfilen 2,5 s.
  - Kostnad: 0 ElevenLabs-tecken, inga nätverksanrop.

## Resultat (alla verifierade i simulatorn, inte på enhet)
| Krav | Mätt | Utfall |
|---|---|---|
| R5d samma ordning | 1 2 3 4 1 2 3 4 1 2 3 4 1 | Rätt i 3 varv av 3 |
| Betänketid 6 s (≤ 20 frågor) | 12 gånger, 6,02–6,05 s, medel 6,03 s | Rätt |
| Avslutas aldrig av sig själv | Aktiv under alla 13 frågor (98 s) | Rätt |
| R9 (proxy) ingen mikrofon | Ljudsessionen hela tiden `Playback`, och mikrofonbehörigheten frågades aldrig | Rätt |
| R6-logik: 1 tryck (play) | Långt svar, 6,05 s (filen 6,0 s), sedan nästa fråga utan betänketid | Rätt |
| R6-logik: 2 tryck (nästa spår) | Kort svar ur den långa filen stannade efter 2,62 s (slutet 2,5 s) | Rätt, 0,12 s sent (spelarens kontroll var 40:e ms plus testets 25 ms) |
| 2 tryck med egen kortsvarsfil | 2,56 s (filen 2,5 s) | Rätt |
| toggle och pause från iOS | Båda räknas som 1 tryck (långt svar) | Rätt |
| R7 (proxy) paus → fortsätt | Fortsatte från exakt samma position (hopp 0,000 s) med play, next, previous och toggle. Positionen stod still under 3 s paus. Resten tog 3,12–4,02 s mot väntade 3,09–4,00 s | Rätt |
| R8 (proxy) avbrott | Samtal pausar och kommer tillbaka med `shouldResume`. Utan `shouldResume` väntar det på ett tryck. Bortfallen ljudväg pausar och är aktiv efter 5 s, och ett tryck fortsätter | Rätt |
| Ljud som inte är klart (K46 i spelordning) | `waitingForAudio`, fortfarande aktiv efter 2 s, spelas 0,06 s efter att filen finns, sessionen `Playback` | Rätt |

**Inga fynd i A78/A82-logiken.**

## Vad simulatorn inte kan visa (untested assumption tills Arons svar finns)
- Att AirPods-tryck över huvud taget kommer fram som play, next eller previous. Här skickades de direkt genom hubben.
- Låst skärm i bakgrunden, den orange pricken, riktiga samtal och Siri, en AirPod ur örat, och iOS väntan för att skilja
  1, 2 och 3 tryck åt.
- R7 "samma ord": här mättes samma *position*. Ord kräver ElevenLabs-filer och ordtidsstämplar.
- Skärmarna A79–A81 (Nytt prov, frågelistan, kontrollskärmen, delning) testades inte i den här körningen. De kommer i
  skärmturen när Kellys B2 har landat.

## Mina egna fel under passet
- Testfilen bröt hela E2E-målet på main två gånger (7acfa8c och 1363518 rättade det). Det stoppade Toby 1:s körningar av
  T15b och T17 i ungefär en timme.
- Från och med nu kompileras ny E2E-kod på en `toby/**`-gren innan den går till main.
- Före D148 byggde jag A78 del 1 och ett utkast till A79–A81 (D147), eftersom Angelas uppdrag hamnade hos mig. Angela äger
  koden nu (A82) och har granskat och byggt om den. Det här testet är därför bara delvis oberoende: logiken i spelaren
  började som min.

## Behöver av Angela
- En diagnostikrad vid paus och fortsätt med filen, positionen och, när K46-tidsstämplarna finns, ordet. Då kan R7
  mätas på telefonen och inte bara höras.

## Nästa steg
1. Lägg in Arons svar från checklistan och märk varje rad **verified on device** eller inte.
2. Skärmturen för A79–A81 efter Kellys B2, med `-RepetitionMock YES`.
3. R8 i 60 minuter med låst skärm på telefonen, efter Arons korta runda.
