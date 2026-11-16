# T27: ett nedladdat prov utan nät (efter A103)

Toby (moln), 2026-11-15 03:20–06:25. Simulatorn i GitHub Actions (iPhone 17 Pro, iOS 26, Xcode 26.6). **Inte verifierat på enhet.**
Falskt ljud via `LUMEN_TEST_HEADER` (x-earmind-test, D180). **0 ElevenLabs.**

## Vad som gjordes
- Nytt test: `AppTests/E2E/Screens/OfflineFlowTests.swift`, `scripts/apptest/offline.sh` och `.github/workflows/apptest-offline.yml`.
  Det startar på varje push till `toby/**` som rör de tre filerna, eller manuellt.
- **Nätet av på riktigt.** Simulatorn har ingen egen nätknapp, den använder Macens nät. Testet ber skriptet om att slå av
  runnerns nättjänster (`networksetup -setnetworkserviceenabled Ethernet off`). `NWPathMonitor` i appen ser då att
  nätet är borta, så det här är "ingen anslutning" och inte bara ett anrop som misslyckas. En vakthund slår på nätet
  igen efter 5 minuter, och det gör också EXIT-fällan.
- **Två korta fönster utan nät** (cirka 2 minuter vardera, med nätet på emellan). I körning 43672420846 avbröt GitHub
  jobbet när runnern hade varit utan nät i cirka 4,5 minuter. Med två korta fönster har jobbet klarat sig varje gång.
- **Provet** görs online med Gör med ChatGPT (3 frågor). Ljudet görs av servern, och testet väntar tills Start säger
  "3 frågor · ljud klart". Bildbiblioteket gav ingen bild i 43674425294, och fotovägen testas redan i T24.

## Resultat, körning 43678562025 (c96289e, på main ec54ced + A105): grön, 12/12 steg
| Steg | Resultat |
|---|---|
| Online: provet med ljud på telefonen | OK, 152 s, 7 tryck |
| Utan nät: Start | OK, provet och Starta prov finns |
| Utan nät: Nytt prov | OK, "Ingen internetanslutning. Du kan lägga till material nu …", Skapa frågor grå |
| Utan nät: provets skärm | OK, "Ingen internetanslutning. Dela och Publicera fungerar när du är uppkopplad.", Dela och Publicera grå |
| Utan nät: Prov från din skola | OK, säger "Ingen internetanslutning" |
| Utan nät: Starta prov, 35 s | OK, 3 av 3 frågor och ett helt varv från filerna, 0 väntan på ljud, inga fel |
| Utan nät: appen startas om, sedan Fortsätt | OK, Start säger "Du var på fråga 3 av 3". Loggen visar `Repetition: start at 3 of 3`, sedan två varv |
| Nätet på | OK, raden utan nät försvinner och Dela går att trycka igen |
| Ta bort provet | OK |

Appens logg vid omstart utan nät: `drill list: Answers need an internet connection` och `Drill list: Ingen
internetanslutning …`. Provet ligger ändå kvar och spelas. Det stämmer med D186.

Tidigare röda körningar var testets fel: 43667435958, 43669922306 och 43676559643 letade efter **Starta prov** efter
omstarten. Där visar appen **Fortsätt** när man har avslutat mitt i ett prov. **Inget fynd i appen.**

## Inte täckt
- **1, 2 och 3 tryck utan nät.** AirPods-tryck går inte att skicka från ett UI-test. Appen har ingen krok för det, och
  VoiceOvers egna åtgärder ("Långt svar", "Kort svar", "Paus") går inte att nå från XCUITest. Spelaren gick ändå
  igenom frågorna utan tryck. Trycklogiken är T18 (`RepetitionE2ETests`, 5/5, utan nät inblandat), och A103:s
  `aDownloadedExamPlaysWithoutANetwork` täcker alla spår. Att svaren spelas utan nät efter ett tryck är alltså
  *untested assumption* i appen som helhet.
- **Låst skärm, riktig telefon, flygplansläge:** bara på Arons telefon.

## Behöver av Angela Schrute (testkrok)
En krok **bara i Debug** som gör att ett UI-test kan skicka 1, 2 och 3 tryck till `RepetitionSession.press` (och
`ReadingPlayer` för T28). Två förslag:
- miljövariabeln `LUMEN_TEST_PRESSES=1` och en Darwin-notis `earmind.test.press.1/2/3`;
- eller en dold knapp i Debug med `accessibilityIdentifier` `test-press-1/2/3`.

Det behövs för T27:s tryck och för hela T28 (paus, fram och bak i läsläget).

## Iakttagelser (inte fel)
- Vid start utan nät försöker appen värma upp svar och tal (`warm answer failed`, `warm tts failed`), också när man
  bara använder repetitionsläget. Det gör ingen skada. Med testhuvudet blir det falskt ljud.

## Nästa
- T28 när A106 (Angela Fables vyer för läsläget) är grön, helst med tryckkroken ovan.
- Kör `apptest-offline` igen efter ändringar i nedladdningen eller i `NetworkStatus`.

## Tillägg 2026-11-15 08:25: 1, 2 och 3 tryck utan nät (Angela Schrutes krok 60d83ce)
Körning 43687277086 (toby/t27b): **grön 13/13.** Testet startar appen med `LUMEN_TEST_PRESSES=1` och skickar trycken
som Darwin-notiser (`earmind.test.press.N`) från testprocessen i simulatorn. Kroken når appen, så `notifyutil` från runnern behövs inte. Det sker i det andra fönstret utan nät, före omstarten.

| Tryck | På skärmen | Appens logg |
|---|---|---|
| 1 | "Långt svar" | `Test press …1 → long`, `Repetition: long answer 1` |
| 2 | "Kort svar" | `Test press …2 → short`, `Repetition: short answer 2` |
| 3 | "Pausad" | `Test press …3 → pauseToggle`, `Repetition: paused` |
| 1 (pausat) | "Pausad" borta | `Repetition: go on (press long)` |

- Svaren spelas från de nedladdade filerna utan nät. *Verifierat i simulatorn, inte på enhet.*
- Det andra trycket kom 3,6 s efter det första. Det långa svaret till fråga 1 var då slut och fråga 2 hade börjat, så
  "short answer 2" stämmer med D142.
- Riktiga AirPods-tryck (fjärrkommandon från lurarna) är fortfarande bara på Arons telefon.

## Tillägg 2026-11-16 01:20: anpassat till A107 (grön igen, 43776390542)
Sedan A107 görs ljudet först vid Starta prov, och ett ostartat prov öppnas inte utan nät (D193). Nattkörningen
43762930539 var därför röd. Testet startar nu provet en gång medan nätet finns, väntar 8 s efter Spara frågorna och
svarar Inte nu på påminnelsefrågan (A109).
- Fynd till Angela Schrute: två prov efter en ChatGPT-import om man lämnar importen inom cirka 3 s (se kön).
