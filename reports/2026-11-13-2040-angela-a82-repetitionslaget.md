# Angela A82: repetitionsläget tas över från Tobys utkast (A78–A81, D148, D154)

Datum: 2026-11-13 20:40. Roll: Angela (app). Uppdrag: A82 (D148), som omfattar A78–A81, Kellys R1–R12 och Ke50-texterna.

## Sammanfattning
- **CI:** det röda bygget 43490256034 (6d35e76) är rättat. Felet var `struct Progress` inuti en generisk funktion
  i Tobys `DrillShareClient`, och den klienten är nu ersatt. CI-resultatet för A82 står under "Test".
- **Mocken är bytt mot Kevins driftsatta server:**
  - K45 `/exam drill` i två steg;
  - K46 `/drill` (provet per konto och serverns ElevenLabs-filer);
  - K47 delning och import.
  - Mocken finns kvar bara i Debug (`-RepetitionMock YES` och skärmbildsläget), med 0 modellanrop och 0 ElevenLabs-tecken.
- **Kellys R1–R12 är rättade**, och Ke50-texterna är inlagda där skärmarna finns (undantagen står under "Kvar").
- **A80:** första passet går direkt till Start med "Plugga med AirPods" och Nytt prov, utan frågan om mikrofonen.
- **Ej verifierat på enhet.** Inget i den här rapporten är provat på iPhone med AirPods.

## Granskning av Tobys kod (D147 punkt 1, oberoende)
Tobys utkast var en bra grund. Tillståndsmaskinen, `RepetitionInput`, `RemoteCommandHub`-övertagandet och avbrotten
behölls som de var. Jag hittade följande, och allt är rättat:

| # | Fynd | Följd | Rättat |
|---|---|---|---|
| G1 | `struct Progress` i generisk funktion | Bygget rött (43490256034) | Klienten omskriven mot `/drill` share/import |
| G2 | `doc_text` skickade fältet `docx`, men K45 läser `data` | Word-filer skulle aldrig läsas (400) | `data` |
| G3 | En rättelse skickade fotona igen | Mot K45:s kontrakt (rättelsen ska bara skicka `notes`) och mot B4; dubbel kostnad | Rättelsen skickar `{"text": notes, "correction"}` |
| G4 | Delningen pekade på `/drill-share` och `/drill-import`, som inte finns | 404 = "Delning kommer snart" för alltid | `/drill` `share` / `import` (K47) |
| G5 | Ljudet var iPhonens röst, och provet låg bara på telefonen | Ingen ElevenLabs-röst, R5 (annan telefon) omöjligt | `CloudDrillAudio` + `DrillCloudClient` (K46) |
| G6 | Betänketiden var en `Task.sleep` utan ljud | Med låst skärm stänger iOS en ljudapp kort efter att ljudet tystnat. Då kommer nästa fråga aldrig (R8). **Ej verifierat på enhet.** | D154 (1): en tyst fil spelas under betänketiden (inte under paus) |
| G7 | Starta prov krävde att allt ljud var klart | Mot R1 ("första ljudet inom 20 s") och Kellys R6 | Spelaren väntar tyst på ljud som saknas (`waitingForAudio`) |
| G8 | AirPods 1/2: 1 tryck startade alltid om det långa svaret | Paus fanns inte med dubbeltryck per lur (specen §3) | Kontrollskärmen sparar läget, och 1 tryck under ett svar pausar då |
| G9 | Kontrollskärmen väntade 10 s | Kelly säger 8 s | 8 s |

Kvar från granskningen (inte rättat, se "Risker"): när en AirPod tas ur örat skickar iOS troligen `pause`. Appen
räknar alla tre kommandona som 1 tryck, så uttagningen kan starta det långa svaret i stället för att pausa. Specen
säger "Ej verifierat, Toby testar". Loggraden "Remote command pause → long" visar vad som kommer.

## Det som byggdes
### A78: spelaren
- `RepetitionPlayer(count:track:…)`: spåret efterfrågas vid varje fråga. Ljud som laddas ner medan listan spelar
  används direkt. Saknas ljud, står spelaren i `.waitingForAudio(i)` och försöker igen varje sekund. Ett tryck där
  betyder inget, utom paus.
- `TaskRepetitionTimer(keepsPlaying: true)`: en tyst WAV loopar medan betänketiden eller väntan pågår (D154). Den
  stoppas vid paus.
- Now Playing har titeln = frågan, artist = "Earmind · {prov} · 7 av 20" och album = provet (Ke50 §9).
- `onePressPausesAnswer`: AirPods 1/2, styrt från kontrollskärmen.

### A79: material och frågelista
- K45 i två steg: `answers:false` visar sammanfattningen och frågorna på ungefär 5 s. `drill_answers` skriver svaren
  medan användaren läser "Stämmer det här?", och "Ser rätt ut" väntar på dem ("Skriver svar …").
- "Läser ditt material" visar fyra steg med bockar och en rad om vad som skickats ("6 foton, 1 PDF och 1 text.").
- Fota sidor använder Apples dokumentkamera (`VNDocumentCameraViewController`), som tar flera sidor i följd. I
  Simulatorn används bildväljaren i stället.
- Fyra rutor (Fota sidor, Välj bilder, Skriv text, Dokument), miniatyrer med ×, "TILLAGT · {n} saker", högst 10
  bilder åt gången.
- Redigeraren har två fält, Fråga och Svar, och första meningen är det korta svaret (D145). Den visas markerad under
  fältet. "Nytt förslag" / "Låt Earmind skriva svaret" använder `drill_one`.
- K46: `DrillCloudClient` (save, status, list, delete, share, import, download) och `CloudDrillAudio`:
  1. sparar på servern när provet sparas;
  2. följer `status` var 3:e sekund;
  3. laddar ner varje klar mp3 till `Application Support/drill_audio/<hash>.mp3`. Filnamnet är serverns hash, så
     en fil som finns i två prov hämtas en gång.
  4. En ändrad fråga tappar bara sitt eget ljud.
  5. Vid start hämtas kontots prov från servern (R5, en annan telefon), och prov som tagits bort på en annan
     telefon försvinner.
- Felen följer Ke50 §13:
  - dagens gräns för nytt ljud (429 `rate_limited`);
  - inget nät;
  - för lite material;
  - ljud som inte kunde göras.

### A80: Starta prov, Hem och BETA
- Hem med prov: kortet "NÄSTA PROV" med **Starta prov** som enda blå knapp, 72 pt. Det är ett tryck när
  kontrollskärmen är gjord och inget finns att fortsätta från. Under knappen finns "Frågor och svar" och "Dela".
  "ANDRA PROV" har ▶, som startar direkt, och raden öppnar provet.
- Hem utan prov: "Plugga med AirPods" och Nytt prov.
- Uppspelningen (Kelly R1–R5):
  - Avsluta är neutral (`secondary`, 64 pt), och frågan står i `text(34, .bold)`.
  - Inga svarsknappar. De tre trycken finns som VoiceOver-åtgärder på frågan.
  - En ring räknar ner betänketiden ("Tänk"), med en stapel per fråga och "Varv" från varv 2.
  - Paus är grå, och ett tryck var som helst fortsätter.
  - "Gör ljud …" visas medan spelaren väntar.
  - Efter Avsluta står "Sparat på fråga {7}."
- "Fortsätt där du var?" är ett blad med Fortsätt, Börja från fråga 1 och Inte nu (R11).
- BETA har grå kontur och VoiceOver säger "Beta, under utveckling" (R8). Grönt finns bara i de nya färgerna
  `LumenColor.ok`/`okSoft` för bockar.
- Första passet: "Testa nu" går direkt till Start (A80). `FirstQuestionView` finns kvar men används inte när
  repetitionsläget finns.

### A81: dela och kontroller
- Dela är avstängd med "Delas när ljudet är klart (36 av 40)". Därefter ger `/drill share` länken
  `https://earmind.ai/p/<kod>`, och delningsbladet får texten "Plugga {prov} med mig i Earmind: {länk}".
- Import:
  - `earmind://prov/<kod>`, en länk till `earmind.ai/p/` eller en inklistrad kod ("Har du fått ett prov? Klistra in
    länken" på Hem) lägger till kopian och öppnar den.
  - Ljudet är detsamma, alltså 0 nya tecken.
- Kontrollskärmen:
  - raderna enligt Ke50 §7, en sak i taget och raden som testas i blått;
  - "Kom inte fram" efter 8 s, och "Hoppa över" uppe till höger;
  - instruktionen för AirPods 1/2 och låsskärmsraden.

### Skärmbilder till Kelly (`repetition.md` §7)
`screenshots.yml` har fått scenerna:
- `repHome`, `repHomeEmpty`, `repMaterial` och `repList`;
- `repEdit` och `repControls` (läget "väntar");
- `repPlayThink`, `repPlayAnswer`, `repPaused` och `repWaiting`;
- `repResume`, `repShare` och `moreModes`.

Skärmbildsläget använder mocken (inget nät). I scenerna är ljudet 0 av N, så Starta prov är grå ("Gör ljud …").
Kontrollskärmens lägen "klar" och "saknas" har inga egna scener än.

## Tekniska detaljer
- Nya filer:
  - `Lumen/Core/Repetition/DrillCloud.swift` (K46/K47-klient, `CloudDrillAudio`, `Drill.from(view)`);
  - `Lumen/Features/Repetition/PageScanner.swift`;
  - `Lumen/Features/Design/RepetitionScreenshots.swift` (bara Debug).
- `Drill` har fått `serverID` och `needsUpload`. `DrillItem` har fått `serverID`, `questionAudio`, `longAudio` och
  `shortEndMs`. Alla är valfria, så en gammal `drills.json` öppnas fortfarande (test).
- `AppContainer`: K45, K46 och K47 används på riktigt. Mocken (`MockDrillMaker`, `DeviceVoiceDrillAudio`, bara
  telefonen) används med `-RepetitionMock YES` eller `-LumenScreenshot`, och bara i Debug.
- Inga nya beroenden.

## Test
- **Enhetstester (verifierade i CI 43501199803):** 16 nya.
  - **A78:**
    - en fråga utan ljud väntar och spelas när ljudet finns;
    - paus under väntan;
    - AirPods 1/2-läget;
    - `.infinity` som slut på det korta svaret;
    - sessionen med spårleverantör.
  - **A79–A81:**
    - K46 sparar, följer kön och laddar ner 4/4 filer, och kort svar = `short_end_ms`;
    - 429-texten;
    - en ändring behåller de andra frågornas ljud;
    - `saveBody` behåller ordning och id;
    - serverns felmeddelande visas;
    - R5: ett prov från en annan telefon läggs till och tas bort;
    - `share` ger webblänken och 409-texten;
    - koder ur länkar och inklistrad text;
    - första meningen;
    - en gammal `drills.json` öppnas.
  - Tobys 20 + 11 tester är kvar (anpassade till `DrillShareResult` och koder på 8–16 tecken).
- **CI (verifierat):** iOS build **43501199803 grön** på 10bf4a0, och efter rättningarna av skärmbilderna **43505582385 grön** på 4623bc7. Det omfattar device-bygget, alla enhetstester och
  arkivet, och `Lumen-unsigned.ipa` (15,5 MB) är uppladdad. A78RepetitionTests (25) och A79A81RepetitionTests (22)
  gick igenom. Fyra rundor behövdes före grönt:
  1. `DrillCloudError.code`;
  2. `cloud` deklarerat två gånger i `AppContainer` och `tileLabel` i PhotosPickers etikett (Tobys fynd);
  3. `RepetitionDemo` utan `@MainActor` och en `var` i en sendable closure i testerna;
  4. `SpeakerFlowTests.autoAnswersSomeoneElse` föll på tid, troligen för att mina tester gjorde tal med iPhonens
     röst i bakgrunden, så att sviten tog 98 s. Nu gör testerna inget ljud (`makesSound: false`), och sviten tar
     0,3 s.
- **Inte provat:** något på telefon (ingen iPhone + AirPods i den här sessionen), K45–K47 från appen mot den riktiga
  servern (bara kontraktet i `backend/README.md` och Kevins tester) och dokumentkameran.

## Risker och kända begränsningar
- **Ej verifierat på enhet:**
  - om den tysta filen under betänketiden räcker för att iOS inte ska stänga appen med låst skärm i 60 min (R8);
  - hur länge iOS behåller en pausad app som Now Playing;
  - vad som händer när en AirPod tas ur örat (se G-raden ovan).
- **App Store-risk (D154):** en tyst fil under betänketiden räknas troligen som en del av innehållet (frågan och
  tiden att tänka). Under paus spelas den aldrig. Riktlinje 2.5.4 är inte prövad.
- `earmind.ai/p/<kod>` är en webblänk som ännu inte öppnar appen (det finns inga universal links och ingen sida på
  sajten). Mottagaren kan klistra in länken under "Har du fått ett prov?". Kelly eller Kevin behöver en sida
  `/p/<kod>` som visar koden och en knapp `earmind://prov/<kod>`.
- Ordtidsstämplarna (`words`) skickas inte till appen av K46, så Kellys "det som lästs upp är fullfärgat" är inte
  byggt. Svaret visas som grå text.
- Polling: `status` var 3:e sekund i högst 20 min per prov och öppning.

## Kvar
- Ke50-texter som inte är byggda:
  - "Inga AirPods anslutna";
  - "Avbrutet av en annan app" med appens namn;
  - "AirPods bortkopplade";
  - notisen när frågorna är klara;
  - "Spara ändringarna?" vid osparade ändringar;
  - "Lyssna" i redigeraren;
  - "Sluta dela";
  - mottagaren utan konto;
  - kontrollskärmens lägen "klar" och "saknas" som egna skärmbildsscener.
- A83 (Publicera prov, D149) är nästa punkt i kön.
- Toby: T18 på enhet och i Simulatorn. Hans E2E-test av första passet väntar på "Fråga vad som helst", som inte
  visas längre (A80). Han är meddelad.

## Nästa session
1. Läs Kellys granskning av skärmbilderna från `Simulator screenshots` och rätta.
2. Prova på telefon (Toby T18 eller Aron): Nytt prov med 3 foton → Starta prov → 1, 2 och 3 tryck med låst skärm i
   minst 5 min. Läs loggraderna "Repetition:" och "Remote command".
3. A83.
