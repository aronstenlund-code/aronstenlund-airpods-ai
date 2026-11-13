# Repetitionsläget: Earminds nya standardläge (D142)

Ägare: Aron (produktbeslut 2026-11-13 17:05, uppdaterat 17:23 med delning och ljud per konto, D143). Spec och teknik: Deangelo. Märkning per påstående: **Möjligt / Möjligt med begränsningar / Inte möjligt med nuvarande teknik / Ej verifierat**. "Verifierat i docs" eller "verifierat på enhet" anges när det finns.

## 1. Vad som ändras
- **Nytt standardläge:** Repetitionsläget. Det lyssnar inte på tal och har ingen taligenkänning. Allt styrs med knapptryck (AirPods i första hand, telefonen för att avsluta).
- **Alla lyssnande lägen** (Standardläge, Provläge med röst, Intervju, Socialt, Rizz, Sömn) märks **BETA**. De behålls och utvecklas vidare (A72, A75, A76, K43, K44 fortsätter), men de är inte längre det första användaren möter.
- **"Starta prov"** betyder från och med nu: starta repetitionsläget. Det gamla röstförhöret byter namn till **"Förhör med rösten (BETA)"** inne i Provläge.
- Skälet (Aron på enhet 2026-11-13): lyssningen reagerade aldrig. Repetitionsläget gör att produkten fungerar även medan lyssningen mognar.

## 2. Flödet för användaren
1. **Nytt prov → Material.** Flera foton direkt med kameran, flera bilder från bildbiblioteket, fri text och dokument (PDF, Word, text).
2. **Earmind analyserar** allt tillsammans och visar en sammanfattning: ämne, årskurs och vad provet omfattar. Användaren kan rätta den med en rad text.
3. **Frågor.** Föreslagna provfrågor, helst högst 5 ord, som testar förståelse ("Varför behövs klorofyll?", inte "Vad är klorofyll?" när det räcker med en definition). Användaren kan godkänna, ta bort, redigera, lägga till egna och ändra ordning.
4. **Svar.** Varje fråga får ett **långt A+-svar** (ett riktigt provsvar på A-nivå för årskursen med begrepp, förklaring och samband; årskursen sänker aldrig kvaliteten, den styr bara vilka begrepp som är rimliga) och ett **kort svar** (1–2 meningar). Båda kan redigeras. Mina svar (D126) återanvänds för redigering.
5. **Kontrollerna förklaras** på en skärm före start, med en provknapp ("Tryck en gång på AirPods nu") som visar att trycket kommer fram.
6. **Starta prov.** Uppspelningen börjar i AirPods och fortsätter tills användaren avslutar på telefonen.

## 3. Uppspelning och kontroller
Rösten är ElevenLabs med hög kvalitet, inte Turbo eller Flash (Arons beslut). Ljudfiler för alla frågor, korta svar och långa svar tas fram **automatiskt i bakgrunden när provet sparas**, lagras **på servern kopplade till konto och prov** och laddas ner till telefonen. De återanvänds vid varje repetition och delning, så samma text betalas aldrig två gånger. Appen visar förloppet ("Ljud: 54 av 90 klara").

**Flödet (beslutat):** fråga → betänketid → nästa fråga. Betänketiden är 6 s för prov med högst 20 frågor och minskar till 4 s vid 40 frågor eller fler (linjärt däremellan, kan ändras i inställningar). Trycker man under frågan eller betänketiden spelas valt svar, och sedan nästa fråga. När listan är slut börjar den om **i exakt samma ordning**. Under paus fortsätter **alla** tryck från samma ord.

| Tryck på AirPods | Ägarens önskan | iOS-kommando som kommer till appen | Status |
|---|---|---|---|
| 1 tryck | Långt A+-svar | `togglePlayPauseCommand`, eller `play`/`pause` beroende på läget i Now Playing | **Möjligt.** Appen tar redan emot det (`RemoteCommandHub`, D74). Ej verifierat på enhet för repetitionsläget. |
| 2 tryck | Kort svar | `nextTrackCommand` | **Möjligt med begränsningar.** AirPods Pro, AirPods 3 och 4: dubbeltryck = nästa spår, som en app kan ta över (Pocket Casts låter användaren ändra det). AirPods 2 och äldre har bara dubbeltryck per lur, inställt i iOS. Ej verifierat på enhet. |
| 3 tryck | Paus / fortsätt | `previousTrackCommand` | **Möjligt med begränsningar.** Trippeltryck = föregående spår på AirPods Pro, 3 och 4. Finns inte på AirPods 2 (där ger inställningen vänster/höger lur). Ej verifierat på enhet. |
| Fortsätt från samma ord | Exakt position | `AVAudioPlayer.pause()` / `play()` på en sparad fil fortsätter från samma sampel | **Möjligt.** Kräver att talet spelas från en fil och inte strömmas (nuvarande `ElevenLabsTTSProvider` strömmar pcm och behöver en filväg). |

Regler i appen (så att varje tryck alltid betyder samma sak):
- Appen läser **vilket kommando** som kom och bryr sig inte om iOS tror att den spelar eller är pausad. `play`, `pause` och `togglePlayPause` är alla "1 tryck".
- `skipForward`/`skipBackward`/`seek` stängs av, så att iOS skickar nästa/föregående spår och inte "hoppa 15 s".
- iOS väntar en kort stund för att skilja 1, 2 och 3 tryck åt. Det betyder ungefär en halv sekunds fördröjning på ett tryck. **Ej verifierat** hur lång tid det tar på Arons AirPods.
- Under paus fortsätter uppspelningen med **vilket tryck som helst** (beslutat).
- **Framtida knapp (högst 75 kr):** all inmatning går via ett protokoll `RepetitionInput` (händelserna `.long`, `.short`, `.pauseToggle`). AirPods är den första källan. En Bluetooth-fjärr eller en penna blir en till källa utan att spelaren ändras. Byggs inte nu.

### Alla AirPods-modeller (användaren behöver inte veta sin modell)
| Modell | Vad som finns | Hur repetitionsläget styrs | Status |
|---|---|---|---|
| AirPods 3, AirPods 4, AirPods Pro 1/2/3 | Tryck på skaftet 1, 2 och 3 gånger | Som specen: 1 = långt, 2 = kort, 3 = paus | Möjligt med begränsningar, ej verifierat på enhet |
| AirPods Max | Digital Crown 1, 2 och 3 tryck | Som ovan | Möjligt med begränsningar, ej verifierat |
| AirPods 1 och 2 | Bara dubbeltryck, en funktion per lur (Siri, spela/pausa, nästa, föregående eller av), inställt i iOS | Två funktioner om lurarna har olika inställningar. Appen visar vilka inställningar som ger alla tre: vänster = nästa (kort svar), höger = spela/pausa (långt svar och paus). Paus blir då "spela/pausa medan ett svar spelas". | Möjligt med begränsningar, ej verifierat |
| Alla modeller | Låsskärmens och Kontrollcentrets spelarknappar skickar samma kommandon | Reserv när en tryckvariant saknas | Möjligt |
| AirPods Pro, 3, 4, Max | Huvudrörelser (nick/skak) finns redan (`HeadGestures`, D83) | Möjlig extra reserv senare, inte i första versionen | Möjligt med begränsningar |

**Automatisk kontroll i stället för att fråga om modell:** på kontrollskärmen gör användaren "Tryck en gång", "två gånger" och "tre gånger". Appen ser vilka kommandon som faktiskt kommer fram och visar bara de kontroller som fungerar på just de lurarna, med instruktion för det som saknas. Ingen modellfråga. **Möjligt.** Appen kan inte läsa ut modellen säkert (bara namnet på ljudvägen), så kontrollen bygger på vad som faktiskt kommer fram. Ej verifierat på AirPods 1/2: Toby har bara Arons lurar, så andra modeller testas i beta.

### Dela prov med klasskamrater (D143)
- Varje prov har en **Dela**-knapp. Det delade provet innehåller frågor, korta och långa svar och **samma ljudfiler** (ingen ny generering).
- **Dela går inte förrän alla ljudfiler är klara.** Knappen visar då "Delas när ljudet är klart (54 av 90)". Annars skulle mottagaren behöva generera samma ljud en gång till.
- Delningen sker med en länk (systemets delningsblad: Messages, Snapchat, WhatsApp och så vidare). Länken öppnar Earmind och lägger en kopia i mottagarens konto. Kopian pekar på samma ljudfiler på servern. **Möjligt.** Universal links kräver domänen (earmind.ai) och en apple-app-site-association-fil. Ej verifierat. Fram till dess fungerar en kod eller ett schema-länk.
- Ändrar mottagaren en fråga i sin kopia, görs ljud bara för den frågan, och originalet ändras inte.
- Fotona och dokumenten delas aldrig, bara frågorna och svaren (se fråga till Aron).

### Får aldrig sluta av sig själv
| Risk | Vad appen gör | Status |
|---|---|---|
| Appen i bakgrunden eller låst skärm | Ljudsessionen `.playback` + bakgrundsläget `audio` (finns redan). Pauser mellan frågor hör till uppspelningen. | **Möjligt.** Ej verifierat på enhet för 60 min. |
| Paus (3 tryck) i bakgrunden | Appen förblir Now Playing. iOS väcker appen när nästa tryck kommer, som för en pausad podd. Ingen tyst ljudfil för att hålla appen vaken (App Store-risk, riktlinje 2.5.4). | **Möjligt med begränsningar.** Ej verifierat hur länge iOS behåller en pausad app som Now Playing. Toby mäter efter 5, 30 och 60 min. |
| Samtal, Siri, larm (avbrott) | Pausas av iOS. Appen fortsätter från samma ord när avbrottet är slut (`shouldResume`). Läget avslutas aldrig. | **Möjligt.** |
| En AirPod tas ut ur örat | iOS skickar paus till Now Playing-appen. **Ej verifierat** om det går att skilja från ett tryck. Om inte: uttagning tolkas som paus och ett tryck när den sätts tillbaka. Toby testar. | Ej verifierat |
| AirPods kopplas bort | Pausa (aldrig avsluta). Fortsätt när de är tillbaka och användaren trycker. | **Möjligt.** |
| Annan app börjar spela (Spotify) | Den appen blir Now Playing och får trycken. Repetitionen står pausad och fortsätter med knappen på låsskärmen eller i appen. | **Inte möjligt** att hindra med nuvarande teknik. Dokumenteras i förklaringen. |
| iOS stänger appen (minne, omstart) | Läget och positionen sparas efter varje fråga. Nästa öppning frågar "Fortsätt där du var?". | **Möjligt med begränsningar.** |
| Slutet av listan | Börjar om i exakt samma ordning. Stannar aldrig. | **Möjligt.** |

### Utan mikrofon
Repetitionsläget öppnar aldrig mikrofonen: ljudsessionen `.playback` (inte `.playAndRecord`), ingen Scribe och ingen VAD. Bevis: den orange mikrofonpricken syns aldrig (Toby). **Möjligt.**
Vinst: AirPods spelar då i A2DP med bättre ljud än samtalsläget som de lyssnande lägena använder. **Möjligt**, enligt hur iOS väljer Bluetooth-profil. Ej verifierat i vår app.

## 4. Arkitektur (återanvänd före nytt)
| Del | Finns i dag | Ändring |
|---|---|---|
| Foton och sidor | `/exam parse` (sidbilder, D84), `PagePhoto` (Vision på telefonen), `ExamMaterials` | Återanvänd. Flera bilder i en batch (redan högst 10 per anrop). |
| Dokument | `DocumentText` (PDF och text på telefonen) | Word (.docx) läses på servern (K45). **Möjligt med begränsningar:** iOS kan inte läsa .docx med inbyggda verktyg (`NSAttributedString` med `.officeOpenXML` finns bara på macOS). Ej verifierat. |
| Profil och årskurs | `/study-profile` | Återanvänd för årskurs och ämne. |
| Frågor och svar | `/study-cards` (Haiku, kort), `/my-answers suggest` (A-svar), Provläges A-svar (D97) | **Ny åtgärd** `/exam` `drill`: material → sammanfattning + frågor + kort och långt svar (Sonnet för svaren, Haiku för frågorna, mäts). Enstaka fråga kan göras om vid redigering. |
| Lagring | `MyAnswers` och provet sparas på telefonen | **Provet sparas på servern per konto** (tabell `drills`, `drill_items`, RLS per användare) och cachas på telefonen. Ljudet ligger i en privat Storage-bucket `drill_audio/<drill>/<item>-<kind>-<hash>.mp3`. Hashen av text, röst och modell gör att samma text aldrig genereras två gånger. Materialet (foton, dokument) sparas inte (B4). |
| Röst | `/tts` strömmar pcm (D16) | **Ny serverjobbkö:** när provet sparas genererar servern alla filer med ElevenLabs högkvalitetsmodell (Multilingual v2 eller nyare, inte Turbo/Flash) och tidsstämplar per ord. Arbetet sker i spelordning, med status per fil. Appen laddar ner det som är klart. |
| Uppspelning | `PlaybackService` (AVAudioEngine, strömmat) | **Ny** `RepetitionPlayer` (AVAudioPlayer per fil, tillståndsmaskin, positionen sparas). Inget från lyssningskedjan. |
| Knappar | `RemoteCommandHub` (bara play/pause/toggle) | Utöka med next/previous, stäng av skip/seek, `RepetitionInput`-protokollet. |
| Test utan ElevenLabs | – | Spelaren tar en `AudioSource`. Testerna använder tysta filer med kända längder och simulerade tryck. Inga ElevenLabs-tecken i CI. |

## 5. Acceptanskriterier
| # | Krav | Mäts av |
|---|---|---|
| R1 | **Tid till färdig lista:** 10 sidfoton + 1 PDF → sammanfattning och frågor på skärmen inom 30 s, alla svar inom 90 s, första ljudet spelbart inom 20 s efter Starta prov. | Oscar (server), Toby (enhet) |
| R2 | **Analys:** på 10 testprov (egna, påhittade, aldrig elevtext i repot) täcker frågorna minst 90 % av lärandemålen enligt en facit-lista. 0 frågor utanför materialet. Ämne och årskurs rätt 10/10. | Oscar |
| R3 | **Frågor:** minst 80 % har högst 5 ord och alla högst 8. Minst 70 % är förståelsefrågor (varför, hur, jämför), bedömt mot rubrik. | Oscar |
| R4 | **Svar:** långa svar bedöms A-nivå 18/20 och korta svar korrekta 20/20 (domare: Sonnet + Deangelos stickprov). 0 faktafel i stickprovet. | Oscar |
| R5 | **Sparas rätt per användare:** redigera, ta bort, lägg till, ändra ordning, stäng appen, starta om, logga in på annan telefon → allt kvar 10/10. En annan användare kan aldrig läsa provet eller ljudet utan delning (RLS-test). | Toby, Oscar |
| R5b | **Ljudfiler:** alla 3 × N filer finns och spelas, status stämmer, en ändrad fråga ger bara nya filer för den frågan, samma text genereras 0 gånger två gånger (räknas i jobbloggen). | Oscar |
| R5c | **Delning:** Dela är avstängd tills 100 % ljud är klart. Mottagaren får frågor, svar och ljud på högst 10 s utan ett enda ElevenLabs-anrop. Originalet ändras inte av mottagarens ändringar. | Oscar, Toby |
| R5d | **Samma ordning:** efter sista frågan kommer fråga 1, och ordningen är identisk i 3 varv av 3. | Toby |
| R6 | **Knappar 20/20** på riktig iPhone + AirPods per kontroll: 1 tryck → långt svar, 2 → kort, 3 → paus, 3 igen → fortsätt. Skärmen låst och appen i bakgrunden. | Toby (verified on device) |
| R7 | **Paus och fortsätt:** fortsätter inom ±1 ord från pausen 20/20 (jämför ordets tid i ElevenLabs tidsstämplar med spelarens position). | Toby |
| R8 | **Avslutas aldrig:** 60 min låst skärm med pauser på 5, 15 och 30 min, ett samtal, Siri, en AirPod ut och in, AirPods ur och i. Läget är aktivt efteråt och fortsätter från rätt fråga 1/1 körning per scenario. | Toby |
| R9 | **Ingen mikrofon:** den orange pricken syns aldrig under 60 min, ingen Scribe-token hämtas och inget `stt-token`-anrop i loggen. | Toby |
| R10 | **Kostnad:** per skapat prov (30 frågor) Claude ≤ 0,30 USD, ElevenLabs-tecken och USD redovisade per prov, lagring per prov i MB. Repetitionssession och delning = 0 ElevenLabs-anrop. | Kevin räknar, Oscar mäter |
| R11 | **Kontrollskärmen** hittar rätt uppsättning kontroller på Arons AirPods 5/5 och visar instruktion när ett tryck inte kommer fram. | Toby |

## 6. Kostnad (D144: Claude och ElevenLabs redovisas var för sig)
Aron 17:28: cirka 2,6 USD per prov är bara godtagbart för **Claude**. Samma kostnad för ElevenLabs är **inte** godkänd. ElevenLabs med hög kvalitet gäller fortfarande, men ljudet måste bli betydligt billigare.

### Verifierade priser (ElevenLabs API-prissida, hämtad 2026-11-13: https://elevenlabs.io/pricing/api)
- Multilingual v2, v3 och v4: **0,08 USD per 1 000 tecken**. Flash/Turbo: 0,04 USD. **Verifierat i docs.**
- Planerna ger samma pris per tecken: Creator 22 USD = 275 000 tecken, Pro 99 USD = 1 238 000, Business 990 USD = 12 375 000 (v2/v3), alltså cirka 0,08 USD per 1 000 i alla. **En större plan sänker alltså inte priset per tecken.** Verifierat i docs (fördelningen mellan plan och rad är tolkad från sidans ordning).
- Arons faktiska plan och kvarvarande krediter: **ej verifierat** (Kevin kontrollerar i K46).

### Uppskattning per prov (ej verifierat, räknat på cirka 6,5 tecken per svenskt ord)
| Variant | Tecken per fråga | 30 frågor | 20 frågor |
|---|---|---|---|
| Första kalkylen (långt svar ~140 ord, eget kort svar) | ~1 080 | 32 000 tecken = **2,6 USD** | 1,7 USD |
| A: långt svar högst ~90 ord (~600 tecken), eget kort svar (~150) | ~780 | 23 000 = 1,9 USD | 1,25 USD |
| B: som A, men **kort svar = första meningen i det långa**, spelas från samma fil med ordtidsstämplar (0 extra tecken) | ~630 | 19 000 = **1,5 USD** | **1,0 USD** |
| C: som B med Flash (bara om Aron inte hör skillnad i blindtest) | ~630 | 0,75 USD | 0,5 USD |
| Delat i en klass om 5 | | 1/5 per person | 1/5 per person |

### Åtgärder som alltid gäller (inga produktändringar)
1. **Aldrig samma ljud två gånger:** filnamnet bygger på en hash av normaliserad text, röst, modell och inställningar. Finns hashen hos **vilken användare som helst** återanvänds filen (frågor som "Vad är fotosyntes?" delas mellan alla). **Möjligt.**
2. **Inga onödiga tecken:** bort med markdown, parenteser med uttalshjälp, dubbla mellanslag och upprepade rubriker. Tal skrivs ut som det ska läsas, utan extra text. **Möjligt.**
3. **Ändrad fråga = bara den frågans filer.** Ett felstavat ord rättat i ett långt svar genererar bara det svaret. **Möjligt.**
4. **Delning = 0 tecken.** **Möjligt.**
5. **Startup-bidrag från ElevenLabs** (krediter för nya bolag): **ej verifierat** om det finns och om Rothman Solutions kvalificerar. Kevin undersöker.

### Claude (separat)
Cirka 0,2–0,3 USD per prov med 30 frågor (Sonnet för långa svar, Haiku för frågor). Uppskattning, Kevin mäter med D.PRICES i K45.

### Lagring
mp3 64 kbit/s ≈ 0,5 MB per minut tal. Variant B med 30 frågor ≈ 19 000 tecken ≈ 20 min ≈ **cirka 10 MB per prov**. Supabase Free 1 GB, Pro 100 GB ingår. Ej verifierat för vår plan.

### Test
CI använder tysta filer och mocks. Riktiga ElevenLabs bara för röstkontroll och blindtestet (högst 3 000 tecken ≈ 0,24 USD). D120.

## 7. Påverkan på roadmap
- Fas "lyssning fungerar" blir BETA-spåret: A72, A75, A76, K43, K44, T15b, T17 och O52 fortsätter, men efter repetitionspunkterna i varje kö.
- Intro och hem: första vägen blir "Nytt prov → Starta prov". "Starta Lumen" ligger under "Fler lägen (BETA)".
- Annonser (Ryan) och demosidan (Kelly): budskapet blir "Plugga med AirPods utan att röra mobilen" tills lyssningen är stabil. Kelly uppdaterar sidan efter A81.
- Lumipen eller knapp för 75 kr: blir en ny `RepetitionInput`-källa senare.

## 8. Beslutat av Aron (17:23)
Namnet "Starta prov". ElevenLabs med hög kvalitet, inte Turbo. Betänketid cirka 6 s, kortare för långa prov. Listan börjar om i samma ordning. Alla tryck fortsätter under paus. Stöd för alla AirPods-modeller. Dela med klasskamrater, bara när ljudet är klart.

## 9. Delning: Deangelos beslut inom Arons ram (17:28, "undersök åtkomst och redigering")
- **Åtkomst:** alla med länken eller koden kan öppna, men det krävs ett gratis Earmind-konto (så att ljudet kan kopplas till kontot och vi kan stänga missbruk). En delning kan stängas av av den som delade.
- **Redigering:** mottagaren får en egen kopia som går att redigera. Bara ändrade frågor får nytt ljud. Oändrade frågor fortsätter använda originalets filer.
- **Foton och dokument delas inte**, bara frågor, svar och ljud (integritet, B4).

## 10. Frågor till Aron (högst tre)
- ~~H1~~ **Beslutat (Aron 17:30): ja.** Det långa svaret börjar alltid med det korta svaret som första mening. Frågan var: Då spelas det från samma ljudfil och kostar 0 extra (sparar cirka 20 %).
- ~~H2~~ **Beslutat (D146):** högst cirka 90 ord som standard (komplett A+-svar går före ordgränsen), 20 frågor som standard, båda går att ändra. Frågan var: Får de långa svaren vara **högst cirka 90 ord** (ett fullt A-svar på en fråga), och standard **20 frågor** per prov (fler går att lägga till)? Med H1 blir det cirka 1 USD i ElevenLabs per prov.
- ~~H3~~ **Godkänt (D146).** Frågan var: Vill du **lyssna blint** på samma tre meningar med Multilingual v2, v3 och Flash (cirka 0,24 USD)? Hör du ingen skillnad med Flash halveras kostnaden.

## 11. Publicera prov (D149, Aron 2026-11-13 20:30)
- Knappen heter **"Publicera prov"**. Ordet "övningsprov" används ingenstans.
- **Krav innan man kan publicera:** skola, ämne och datum för provet ifyllda, och allt ljud klart (samma regel som Dela, så att ingen behöver generera ljudet igen).
- **Vem ser det:** alla. Man hittar prov genom att söka på skolan (och filtrera på ämne och datum). Elever på samma skola får dem först i listan.
- **Vad publiceras:** frågor, korta och långa svar, ljud, skola, ämne och provdatum. Aldrig foton, dokument eller namn (B4, och användarna kan vara minderåriga). **Användarnamnet visas om man själv väljer det** (av som standard, Aron 20:32). Inga andra uppgifter.
- **Den som hämtar** får en egen kopia, som vid delning (0 ElevenLabs-tecken). Ändringar i kopian påverkar aldrig originalet.
- **Skolor:** väljs ur en lista, inte fritext, så att samma skola inte stavas på tio sätt. Källa: Skolverkets skolenhetsregister (öppet API). **Ej verifierat** att API:t går att använda för detta, Kevin kontrollerar.
- **Ordning och skydd:** en rapportknapp på varje publicerat prov (fel innehåll, kränkande, upphovsrätt). Ett prov med 3 rapporter döljs tills Aron eller en moderator har tittat. Den som publicerade kan ta bort sitt prov när som helst. Gamla prov (provdatum mer än 30 dagar bakåt) sjunker i listan men finns kvar.
- **Status:** möjligt. Bygger på K46 (prov per konto) och K47 (kopia med samma ljud).
- **Acceptans:** R12: publicering nekas utan skola, ämne, datum eller färdigt ljud (4/4). Ett sök på skolan visar provet inom 5 s. Att hämta det kostar 0 tecken. Inga personuppgifter i publicerade data (Oscar kontrollerar fälten). Rapport ×3 döljer provet.

### Senare (Aron 20:32, inte nu)
- **Kreditsystem:** varje användare har krediter så att ingen kan dra obegränsat på Arons konto. Den som publicerar ett prov som andra faktiskt använder får krediter påfyllda. Byggs när betalning och App Store förbereds. Arkitekturen ska inte omöjliggöra det: logga redan nu hämtningar och uppspelningar per publicerat prov (antal, inte vem).
- **Regel mot lärarens riktiga prov och facit** (fusk och upphovsrätt) i villkoren och som rapportorsak: införs inför App Store, inte nu.

## 12. Röst, tempo och gräns (D151, Aron 2026-11-13 20:47 efter blindtestet)
- **Blindtestet:** A = Multilingual v2, B = v3, C = Flash v2.5. Aron gillade A mest. A och C lät nästan likadant och båda snabbt. B har bäst tempo att skriva i, men låter sorgsen.
- **Tre röstval:** användaren väljer rösten (A, B eller C, med namn som Kelly sätter) **innan** ljudet genereras. Efter genereringen är rösten låst för det provet. Den genereras aldrig om (0 extra tecken). Standard: A.
- **Tempo utan kostnad:** uppspelningshastighet 0,50 / 0,65 / 0,70 / 0,75 / 0,85 / 0,90 / 1,0 / 1,5, ändras på telefonen med samma fil. **Möjligt** (`AVAudioPlayer.rate` med `enableRate`, tonhöjden behålls). Vid 0,50–0,65 kan rösten låta konstgjord: **möjligt med begränsningar**, Aron lyssnar.
- **Låga tempon = 0,7 + pauser (Aron 20:49):** rösten spelas aldrig långsammare än 0,70, så att den inte låter konstgjord. Väljer man 0,65 eller 0,50 spelas talet i 0,70, och resten av tiden läggs som pauser mellan meningarna, så att det totala tar lika lång tid som det valda tempot (vid 0,50 dubbelt så lång tid som vid 1,0). Paus per meningsslut = (längd/valt tempo − längd/0,70) / antal meningsslut. Från 0,70 och uppåt: inga extra pauser, vanligt tempo. **Möjligt**, 0 tecken.
- **Pauser mellan meningar (extra val):** ett val "Längre pauser" (till exempel 1, 2 eller 3 s) lägger tystnad vid meningsslut med hjälp av ordtidsstämplarna. Samma fil, 0 tecken. **Möjligt.**
- **Gräns:** högst **15 genererade frågor per användare och månad** (D155, Aron 21:18, "för nu") innan man behöver ett abonnemang. Publicerade och delade prov från andra kostar inget och räknas inte. Räknas på servern. Abonnemang och betalning byggs senare (App Store).
- **Faktisk kostnad i blindtestet:** ElevenLabs debiterade 198 krediter för 496 tecken med v2 och v3, och 99 med Flash (`character-cost`). Det är cirka 40 % av listpriset. Om det håller blir ett prov med 20 frågor cirka 0,4 USD med A i stället för 1,0. **Ej verifierat** varför (plan, rabatt eller räknesätt). Kevin kontrollerar på nästa riktiga prov.
