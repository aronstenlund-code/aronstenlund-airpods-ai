# Checklista: första testet på riktig iPhone + AirPods

Skriven för Aron (produktägare) inför första sessionen på Macen. Du behöver: en Mac med macOS 26, internet,
din iPhone (iOS 26) med kabel, dina AirPods (alla modeller du har), en annan person som läser högt, och
cirka 2 timmar.

Allt som står här är **inte verifierat på riktig enhet** förrän du har gjort det. Koden är byggd och
testad i GitHub Actions (CI), inte på en iPhone.

---

## Del 1 — Installera och öppna projektet (ca 30–60 min, mest väntan)

1. **Installera Xcode 26** från Mac App Store (sök "Xcode"). Det är stort (10+ GB). Starta Xcode en gång
   och godkänn licensen. Välj att installera **iOS 26**-stödet när Xcode frågar ("iOS 26 platform").
2. **Logga in med ditt Apple-ID i Xcode**: Xcode → Settings → Accounts → `+` → Apple Account.
   Ett vanligt (gratis) Apple-ID räcker för att köra på din egen iPhone. Betalt Developer Program behövs
   först för TestFlight.
3. **Installera XcodeGen** (verktyget som skapar Xcode-projektet ur `project.yml`). Öppna Terminal
   (Program → Verktygsprogram → Terminal) och klistra in en rad i taget:
   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```
   (Homebrew. Följ anvisningarna, det kan be om ditt Mac-lösenord.) Sedan:
   ```bash
   brew install xcodegen
   ```
4. **Hämta koden**:
   ```bash
   cd ~/Desktop && git clone https://github.com/aronstenlund-code/aronstenlund-airpods-ai.git lumen && cd lumen && xcodegen generate
   ```
   Det skapar `Lumen.xcodeproj` på Skrivbordet i mappen `lumen`.
   **Reservplan om XcodeGen inte går att installera:** gå till repots sida på GitHub → fliken *Actions*
   → senaste gröna körningen → *Artifacts* → ladda ner `Lumen.xcodeproj` och lägg mappen i `lumen/`.
5. **Öppna projektet**: dubbelklicka `Lumen.xcodeproj`.
6. **Välj ditt team**: klicka på *Lumen* (blå ikon högst upp i vänsterspalten) → välj target *Lumen* →
   fliken *Signing & Capabilities* → bocka i *Automatically manage signing* → *Team*: välj ditt namn
   (Personal Team). Om Xcode klagar på bundle-ID, byt `com.rsolutions.lumen` till något eget,
   t.ex. `se.dittnamn.lumen`. (Detta ändras bara lokalt; kör du `xcodegen generate` igen måste du välja
   team på nytt.)

## Del 2 — Kör på iPhone (ca 15 min)

7. **Anslut iPhone med kabel.** På iPhone: *Inställningar → Integritet och säkerhet → Utvecklarläge* →
   slå på, starta om, bekräfta. (Menyn syns först när telefonen varit ansluten till Xcode en gång.)
8. I Xcode, högst upp i mitten: välj din iPhone som destination (inte en simulator).
9. Tryck **▶ (Run)**. Första gången: på iPhone *Inställningar → Allmänt → VPN och enhetshantering* →
   lita på ditt utvecklarcertifikat. Tryck ▶ igen.
10. Appen öppnar först **samtyckesskärmen** (*Innan du börjar*). Läs igenom punkterna och tryck
    *Jag förstår – börja använda Lumen*. Du landar på lyssnarskärmen *Lumen*. Tryck **Börja lyssna** en gång
    och **tillåt mikrofonen**. En röd rad *Lyssnar* ska visas högst upp (den följer med på alla skärmar).
    Tryck *Sluta lyssna*.
    Diagnostikskärmen (alla mätningar i Del 3) öppnas via menyn (⋯) uppe till höger → *Diagnostik*; *Start capture*
    där och *Börja lyssna* på lyssnarskärmen styr **samma** mikrofon.
11. **Koppla ihop AirPods** med iPhone (ha dem i öronen). Kontrollera i *Inställningar → Bluetooth → (i)
    bredvid AirPods → Om* och skriv ner **modell** och **firmware-version**. Gör detta för varje
    AirPods-modell du testar.

## Del 3 — Själva testerna (ca 60 min per AirPods-modell)

Alla tester görs i appen. Varje gång du trycker *Start capture* ska den gröna raden ("Active capture")
visa vilken mikrofon och vilket läge som faktiskt är aktivt, t.ex.
`AirPods Pro 2 · HFP · mode=default · 16 kHz · HQ supported=false enabled=false`.
**Skriv aldrig ner ett resultat utan att titta på den raden** — den säger vilken mick som användes.

### 3a. Mikrofonkontroll (per config, 1 min)
1. Välj config i listan (börja med **B-HQ**).
2. Tryck *Start capture*. Läs den gröna raden. Vänta 2 sekunder (raden kan ändras, det loggas).
3. Tryck *Run mic-source check*. Håll iPhone en armlängd från huvudet och **knacka hårt 3 gånger på
   baksidan** inom 5 sekunder. Resultatet säger om iPhone-micken eller AirPods-micken verkar vara aktiv.
   För B-HQ och C-HFP-\* ska det stå *External (AirPods) mic likely*. För A-ref-\* ska det stå *iPhone
   built-in mic is LIKELY active*. Står det fel: skriv ner det, det är ett viktigt resultat.
4. Tryck *Stop capture*.

### 3b. Ljud i AirPods under inspelning (per config, 1 min)
1. *Start capture* med samma config.
2. Tryck *Play test tone* — hörs tonen **i AirPods** (inte i iPhone-högtalaren)?
3. Tryck *Speak 🇸🇪* och sedan *Speak 🇬🇧*. Bedöm kvaliteten: **bra / sämre / telefonkvalitet**.
   (HFP förväntas ge telefonkvalitet. Det är ett resultat, inte ett fel.)
4. Tryck *Play test tone* 10 gånger med en sekunds mellanrum. Raden *Play → first buffer* visar
   medianen. Skriv ner den.
5. *Stop capture*.

### 3c. Avståndstest (huvudmätningen; per config: 3 avstånd × 2 ljudmiljöer + 1 egen inläsning)
Förberedelse: den andra personen har `testdata/scripts/sv-paragraphs.md` (P1) på en skärm. Mät upp
1 m, 2 m och 4 m från den som har AirPods. Tyst rum först.
För varje config och varje avstånd:
1. *Start capture*. Kontrollera gröna raden.
2. Under *Speaker-distance test*: välj **Distance** (1/2/4 m), **Noise** (quiet), **Speaker** (other person).
3. Tryck *Start run*. Personen läser P1 (ca 20 s). Tryck *Stop run and save*.
   En rad med SNR dyker upp och en WAV-fil sparas i appens dokumentmapp.
4. Upprepa för 2 m och 4 m.
5. Byt **Speaker** till *wearer* och läs själv P1 på plats (du som har AirPods). Tryck Start/Stop run.
6. **Viskning och låg röst (Track D1):** byt Speaker till *wearer whisper* och **viska** de första 10
   korta fraserna i `testdata/scripts/sv-short-prompts.md` med 2 sekunders paus mellan varje; Start/Stop
   run. Gör sedan samma sak med *wearer low voice* (tyst "biblioteksröst"). Detta behöver bara göras
   för B-HQ, C-HFP-default och C-HFP-measurement, i tyst rum.
7. *Stop capture.*
Gör sedan om allt med **Noise = noisy**: starta bakgrundsljudet från en högtalare (se
`testdata/noise/README.md` — fyll i vilken fil, var högtalaren står och ljudnivån med en dB-mätarapp).
Configs att köra, i ordning: **B-HQ, C-HFP-default, C-HFP-measurement, C-HFP-voiceChat, A-ref-default,
A-ref-measurement.** Ja, B-HQ körs även i Sverige: om HQ inte går på är själva loggen (`HQ enabled=false`)
resultatet.

### 3d. Bakgrund med låst skärm (10 min, en gång per Mac-session)
1. *Start capture* (C-HFP-default). Lås skärmen. Prata lite i rummet med jämna mellanrum. Vänta
   **10 minuter**.
2. Lås upp. Tryck *Export last 60 s as WAV*. Står det ett filnamn under knappen och är *Chunks*-räknaren
   mycket högre än innan? Då fortsatte inspelningen.
3. **Öppen fråga som du testar här:** fungerar bakgrundsljud med gratis-Apple-ID-signering? Om appen
   tystnar/pausar när skärmen låses, skriv ner exakt vad som hände och efter hur lång tid.

### 3e. Avbrott (5 min)
1. *Start capture*. Be någon ringa dig. Svara, prata 10 s, lägg på.
2. Titta på *State* och eventloggen: står det *Paused — interrupted* under samtalet och går den tillbaka
   till *Listening* själv efteråt (shouldResume=true), eller står det *tap to resume*? Skriv ner det.
3. Gör samma sak med Siri (håll in sidoknappen, fråga något). D74: efter samtalet och efter Siri ska Lumen lyssna igen av sig självt, i samma läge. Om du har pausat själv innan ska Lumen förbli pausad.

### 3f. AirPods av och på (3 min)
1. *Start capture*. Ta ut **båda** AirPods ur öronen / lägg dem i etuiet.
2. Appen ska vibrera och visa *Paused — AirPods disconnected — tap to resume*. Skriv ner om ljudet
   hoppade till iPhone-högtalaren innan dess.
3. Sätt i AirPods igen, tryck *Tap to resume*. Kontrollera gröna raden igen.

### 3g. Språkstöd för Apples taligenkänning (1 min)
Tryck *Check SpeechTranscriber locales*. Texten visar om **sv-SE** finns för `SpeechTranscriber` och
`DictationTranscriber`. Den kopieras med i resultatet.

### 3h. Apples egen "studiokvalitet"-inspelning (manuell koll, 2 min per AirPods-modell)
Detta är **inte** vår app utan Apples systemfunktion, och rapporteras separat:
1. *Inställningar → Bluetooth → (i) vid AirPods*: finns någon inställning för inspelning i hög kvalitet?
2. Öppna *Röstmemon*, spela in 10 s med AirPods i. Lät det som telefonkvalitet eller "riktig" kvalitet?
Skriv ner svaren.

### 3i. Lyssnarskärmen och samtycket (MVP-del 1, 5 min, en gång)
Gå tillbaka till lyssnarskärmen (pilen uppe till vänster). Transkription och svar kommer i nästa
sprintsteg; här testas bara skärmen, indikatorn och samtycket.
1. Tryck **Börja lyssna**. Kontrollera: röd rad *Lyssnar* högst upp, mikrofonikonen röd, en nivåmätare som
   rör sig när du pratar, raden under rubriken visar vilken mikrofon som används (t.ex. *AirPods Pro · HFP*).
   Jämför med gröna raden på diagnostikskärmen – det ska vara samma mick.
2. Gå in på diagnostikskärmen (meny ⋯ → Diagnostik) medan den lyssnar: står den röda raden kvar högst upp? Tryck *Stopp* **i den
   röda raden** – lyssningen ska sluta direkt och raden försvinna.
3. Tryck *Börja lyssna* igen, ta ut AirPods: skärmen ska visa *Pausad* och knappen *Fortsätt lyssna*.
   Sätt i AirPods, tryck *Fortsätt lyssna*.
4. Meny ⋯ → *Integritet och samtycke*. Längst ner står när samtycket lämnades.
   Tryck *Ta tillbaka samtycke* → *Sluta lyssna och ta tillbaka*. Lyssningen ska sluta och samtyckesskärmen
   visas igen. Tryck *Jag förstår …* på nytt.
5. Avsluta appen helt (svep upp) och öppna igen: den ska **inte** fråga om samtycke igen.
6. Kolla språket: är telefonen på svenska ska knappar och texter vara på svenska. Skriv ner engelska
   texter som dyker upp där svenska borde stå.

### 3j. Transkription live (MVP-del 2, 10 min)
1. På lyssnarskärmen: välj **Svenska** under Inställningar (kugghjulet uppe till höger → Språk), stäng och tryck *Börja lyssna*. Under statusraden ska det stå
   *Förbereder talmodellen …* (första gången laddas Apples svenska modell ner – kräver internet, kan ta en
   minut) och sedan *Transkriberar på den här telefonen · SpeechTranscriber* (eller *DictationTranscriber*).
   **Skriv ner vilket av de två som står** – det avgör vilken Apple-motor som finns för svenska.
2. Prata normalt i rummet. Under *Transkription live* ska grå kursiv text dyka upp medan du pratar och bli
   svart när meningen är klar. Säg tre av de korta meningarna i `testdata/scripts/sv-short-prompts.md` och
   skriv ner vad som faktiskt kom ut (bokstavligt).
3. Låt en annan person säga tre meningar på 2 m avstånd. Skriv ner resultatet på samma sätt.
4. Byt språk till **English** i Inställningar medan den lyssnar. Statusraden ska gå via *Förbereder …* till *Transkriberar …* igen.
   Säg två meningar på engelska. Byt tillbaka till Svenska i Inställningar.
5. Står det *Svenska finns inte för taligenkänning på den här telefonen*: det är ett viktigt resultat (R2).
   Tryck på diagnostikskärmen → *Check SpeechTranscriber locales* och kopiera texten.
6. Ta ut AirPods (paus) och sätt i dem igen → *Fortsätt lyssna*. Transkriptionen ska starta om själv
   (statusraden visar *Transkriberar …* igen).

### 3k. Frågor (Auto) – handsfree (D72, 10 min)
Det finns ingen "håll in"-knapp längre: alla lägen lyssnar själva.
1. Avinstallera appen och installera om. Efter samtycket ska lägesväljaren stå på **Frågor (Auto)**.
2. Tryck *Börja lyssna*, Svenska, känslighet *Mellan* (Inställningar → *Questions*). Låt någon läsa tre vanliga påståenden
   ("idag ska vi prata om …") och sedan tre frågor ur `testdata/scripts/sv-short-prompts.md` (t.ex. 5, 12, 29).
   Skriv ner vilka som besvarades och vilka som inte gjorde det, både falska träffar och missar.
3. Ställ två frågor inom 3 sekunder: bara den första ska besvaras (minst 5 s mellan automatiska svar, D78). Säg en fråga i två delar med en kort paus ("Vad är skillnaden mellan mitos … och meios?"): den ska besvaras **en** gång, som hel fråga.
4. Sätt känslighet *Hög* och säg bara "fotosyntes": nu ska det besvaras. På *Mellan* ska det inte besvaras.
5. Låt någon annan säga en mening och tryck *Fråga om det senast sagda*: den meningen ska besvaras.
6. Skriv en fråga i skrivrutan: den ska besvaras även utan mikrofon.
7. Välj **Intervjuläge** i väljaren, stäng appen helt och öppna igen: väljaren ska stå kvar på Intervjuläge.

### 3l. Riktiga svar från servern (MVP-del 4, 10 min)
Backend är igång sedan 2026-11-03 22:38 (Deangelos test: svenska svar fungerar, men långsamt – 2–3 s till första
ljud; Kevin jobbar på det). Telefonen behöver internet. Om något ändrats i Supabase: klickvägar i `backend/README.md`.
1. *Börja lyssna*, Svenska, läget *Frågor (Auto)*. Säg "vad är roten ur hundra?". Under *Svar* ska det
   först stå *Tänker …* och sedan strömma in text. När svaret är klart visas det i listan med tid, källan
   `cloud` och latens i ms (från släpp till första ord). **Skriv ner latensen** för fem frågor
   (t.ex. nr 1, 5, 12, 23, 29 i `testdata/scripts/sv-short-prompts.md`) och om svaren är korrekta och korta.
2. Står det en orange rad under svaren i stället, skriv ner texten exakt. Vanliga fall:
   `anonymous_provider_disabled` = anonym inloggning är inte påslagen; `provider_unconfigured` = nyckeln saknas;
   *Answers need an internet connection* = telefonen är offline.
3. Byt *Aktivering* till **Auto** i Inställningar. Låt någon säga ett påstående och sedan en fråga: påståendet ska ge raden
   *Not a question — no answer (auto mode)* eller inget alls, frågan ska ge ett svar.
4. Ställ en ny fråga medan ett svar strömmar: det gamla svaret ska försvinna och det nya börja direkt.
5. Slå på flygplansläge, ställ en fråga: raden *Answers need an internet connection* ska visas. Slå av igen.
6. (Debug-bygge) Slå på *Låtsassvar (debug, utan nätverk)* under Inställningar → Felsökning och ställ en fråga: ett låtsassvar ska strömma in
   utan nätverk. Slå av igen.

### 3m. Röst i AirPods (MVP-del 5, 10 min)
1. Inställningar → *Röst*: *Läs upp svaren* på, röst **Apple-röst (på telefonen)**. Tryck *Provlyssna*: en svensk
   provmening ska höras **i AirPods** (inte i telefonens högtalare), även medan den lyssnar. Skriv ner
   kvaliteten (bra / sämre / telefonkvalitet) – över HFP förväntas telefonkvalitet.
2. Ställ en fråga i läget *Frågor (Auto)*. Svaret ska läsas upp **mening för mening medan texten strömmar in**,
   inte först när hela svaret är klart. Skriv ner tiden från släpp till första ordet (ungefär, sekundvisare).
3. Ställ en ny fråga mitt i ett uppläst svar: uppläsningen ska tystna direkt och det nya svaret börja.
4. Dra *Hastighet* till 1,5× och provlyssna: snabbare utan att rösten blir ljusare.
5. Om rösttjänsten är igång (STATUS: backend live, hemligheterna `ELEVENLABS_API_KEY`/`ELEVENLABS_VOICES` inlagda):
   välj en av de tre premiumrösterna, *Provlyssna*, och jämför kvalitet och fördröjning med Apple-rösten. Slå på
   flygplansläge och ställ en fråga: raden *Premium voice unavailable — using Apple's voice …* ska visas och
   svaret ändå läsas upp med Apple-rösten.
6. Stäng av *Läs upp svaren*: svaret ska bara visas som text (tyst läge, MVP-del 6).

### 3n. Textläge (MVP-del 6, 3 min)
1. Utan att lyssna (mikrofonen av): skriv "vad är pi" i fältet *Skriv en fråga* längst ner och tryck
   pappersflygplanet (eller retur). Svaret ska strömma in under *Svar* och läsas upp i AirPods.
2. Stäng av *Läs upp svaren* i Inställningar och skicka en ny fråga: bara text, inget ljud (tyst läge).

### 3o. Latensrutan (MVP-del 7, 2 min, debug-bygge)
Inställningar → Felsökning → *Latensruta* på. En liten ruta uppe till höger visar för senaste svaret
*text N ms · voice N ms* (från släpp/fråga till första textordet respektive första upplästa meningen) och
p50/p95 över sessionen. Ställ fem frågor och **skriv ner raden** – det är R4-mätningen (mål < 1,5 s p50).

### 3p. Anteckningar och förberedelsematerial (MVP-del 8–9, 5 min)
1. Efter ett par frågor: tryck *Spara anteckning* (rubriken *Svar*). Meny ⋯ → *Anteckningar*: anteckningen ska
   finnas med frågor, svar och transkriptionsrader. Öppna den, tryck dela-ikonen och skicka Markdown-texten
   till dig själv. Radera den sedan (papperskorgen).
2. Meny ⋯ → *Förberedelsematerial*: klistra in ett stycke ur `testdata/scripts/sv-paragraphs.md`, tryck
   *Lägg till text*. Under *Aktiva termer* ska rimliga ämnesord stå (inga småord som "och", "att").
   Importera också en PDF från Filer och kontrollera att termer kommer ut.
3. Börja lyssna och säg en mening med ett ovanligt ord ur materialet: blev det rätt stavat oftare än utan
   material? (Jämför med materialet avstängt.) Skriv ner intrycket – det är Track D-prioritet 3.

### 3q. Växla till musik (D33, 10 min)

Signering: **båda** targets (`Lumen` och `LumenControls`) behöver ditt team i Xcode. Skriv ner om gratis-Apple-ID:t klarar tillägget.

1. Börja lyssna, starta Spotify och spela något. Tryck **Pausa för musik** i Lumen. Fortsätter musiken i full kvalitet utan att du gör något mer i Spotify? Skriv ner vad du hör.
2. Tryck **Fortsätt lyssna**. Stannar musiken och lyssnar Lumen igen?
3. Börja lyssna och starta musik direkt i Spotify, utan att pausa. Visas "Pausad"? Stoppa musiken och skriv ner om Lumen börjar lyssna igen av sig själv (D74: det ska den göra när avbrottet tar slut, men en musikapp avslutar kanske aldrig sitt avbrott).
4. Ring ett samtal till telefonen medan du lyssnar och avsluta det. D74: Lumen ska börja lyssna igen **av sig själv**, i samma läge som förut (prova i Provläge).
5. Lås telefonen medan du lyssnar. Syns Lumen på låsskärmen? Tryck Pausa och sedan Fortsätt där. Skriv ner om Fortsätt fungerar utan att låsa upp.
6. Lägg till kontrollen *Lumen lyssnar* i Kontrollcenter (eller på Åtgärdsknappen). Händer något när du trycker? Händer inget alls är det ett viktigt resultat.
7. Ställ en skriven fråga medan du är pausad: svaret ska synas men inte läsas upp, och musiken ska inte störas.

### 3r. Provläge – handsfree lärarsession (D36, 10 min)
1. Tryck **Provläge** (lila knappen). Raden *Provläge · din tur – prata bara* ska visas (mikrofonen startar om den
   var av). Säg "förklara fotosyntes" och **var tyst**. Efter ca 1 s ska *Provläge · tänker …* visas, sedan
   *Provläge · talar – prata för att avbryta* medan svaret läses upp, och sedan tillbaka till *din tur* utan att du
   trycker något. Skriv ner: fångades hela frågan (eller klipptes början/slutet)? Hur lång tyst paus krävdes?
2. Ställ en följdfråga ("och varför är det viktigt?"): svaret ska bygga på det förra (sessionens minne).
3. Börja prata mitt i ett svar (minst en halv sekund): uppläsningen ska tystna och din nya fråga tas emot.
   Skriv ner om första ordet i din fråga saknas i transkriptionen (väntat: ja, ca 0,4 s).
4. Lyssna efter eko: står det egna svarets ord i transkriptionen medan den talar? (Ska inte hända – ingången stängs.)
   Prova sedan Inställningar → Provläge → *Ekodämpning (voiceChat)* på, avsluta och starta Provläge igen och
   jämför ljudkvalitet i AirPods och fångade frågor.
5. Var tyst (ställ ner *Avsluta automatiskt* till 1 min för testet): efter en minut ska raden *Provläget avslutades
   efter 1 min tystnad; mikrofonen stängdes av* visas och den röda *Lyssnar*-raden försvinna. Ställ tillbaka till 10.
6. Tryck *Avsluta provläge* mitt i en session: vanlig lyssning ska fortsätta (röda raden kvar).

### 3s. Kursmål och egna kommandon (D37, 5 min)
1. Meny ⋯ → *Förberedelsematerial* → *Kursmål*: klistra in en målbeskrivning (gärna lång), *Spara mål*. Raden under
   visar hur många tecken som skickas komprimerat (max 1 500). Ställ en fråga inom ämnet: blev svaret på kursens nivå?
2. Meny ⋯ → *Kommandon*: lägg till nyckelord `fusion` med en instruktion (t.ex. "förklara och jämför med fission").
   Skriv sedan bara "fusion" i skrivrutan: svaret ska följa instruktionen. Säg det lite otydligt
   ("fusjon") – matchas det ändå? Skriv ner.
3. Säg "spara kommando fotosyntes: förklara steg för steg": raden *Sparade kommandot "fotosyntes"* ska visas, en kort
   bekräftelse höras i AirPods, och kommandot finnas i listan. Ingen fråga ska ha skickats.

### Första testet: gör i den här ordningen (ca 90 min)

Punkterna 3t–3z är det viktigaste. Har du ont om tid: hoppa över 3c–3h och börja här. Du behöver en annan person i rummet.

Signering: **båda** targets (`Lumen` och `LumenControls`) behöver ditt team i Xcode.

### 3t. Kärnflödet från början till slut (10 min)
1. Radera appen och installera om. Godkänn samtycket och läs texten: den ska säga att talet går till ElevenLabs. Svara *Dela inte* på frågan om historik.
2. Tryck *Börja lyssna*. I statusraden ska det stå **Skriver ut med Scribe i molnet**. Står det *iPhone*: gå till Inställningar → Språk och läs den orange raden, och skriv ner den exakt.
3. I läget *Frågor (Auto)*: säg "vad är roten ur hundra?". Skriv ner tiden från att du slutat tala till första ljud, fem gånger. Hörs svaret i AirPods?
4. Säg "kom ihåg att jag går trean". Ställ sedan en fråga och kontrollera att svaret tar hänsyn till det.
5. Slå på flygplansläge medan du lyssnar. Byter appen till iPhonens taligenkänning? Slå av igen.

### 3u. Mikrofonjämförelsen (20 min)
Diagnostik → *Mikrofonjämförelse*. Fem meningar, fyra omgångar:
| Omgång | Mikrofon | Talare |
|---|---|---|
| 1 | AirPods | Din egen röst |
| 2 | AirPods | Annan person på 1,5 m |
| 3 | iPhone (på bordet) | Din egen röst |
| 4 | iPhone (på bordet) | Annan person på 1,5 m |

Tryck *Börja läsa*, läs meningen som visas, tryck *Klar, nästa mening*. Fel-andelen (WER) per omgång visas i rutan. Den följer med i *Copy results as Markdown*.
Lyssna också: låter svaret bättre i AirPods med iPhone-mikrofonen än med AirPods-mikrofonen? Då fungerar A2DP-uppspelningen. Skriv ner vad du hör.

### 3v. Provläge (5 min)
1. Tryck på kortet **Få A-svar till provet** högst upp på huvudskärmen. Provläge ska starta direkt, utan startskärm eller inställningar emellan.
2. Ställ en fråga, pausa, lyssna, ställ en följdfråga. Prata medan svaret spelas: svaret ska avbrytas. Säg "rapportera": du ska höra "Skickat".
3. Var tyst i minst 15 minuter med telefonen låst (D71): Provläge ska fortfarande vara igång efteråt. Det slutar bara när du trycker *End session* eller pausar för musik.

### 3w. Intervjuläge (10 min)
1. Välj **Intervjuläge**. Startskärmen ska säga att läget är för träning och inte för riktiga intervjuer utan att den andra vet. Skriv en roll och tryck *Förbered frågor och svar*: texten ska visas, inte läsas upp.
2. Starta *övningsintervju* med kompisen som ställer frågorna, med AirPods-mikrofonen. Efter varje fråga ska du höra **ett färdigt svar och inget annat**: inga följdfrågor, ingen återkoppling, ingen sammanfattning.
3. Säg svaret högt själv. Lumen ska **inte** svara på det. Händer det: skriv ner nivån i Diagnostik-loggen ("own turn at … dBFS") och justera *Din röst är starkare än*.
4. Säg "ge mig feedback": först då ska återkoppling komma. Säg "klar" (eller "sammanfatta"): då ska en sammanfattning komma.

### 3x. Rizzläge (10 min, med en kompis som vet om det)
1. Välj **Rizzläge (18+)**. Första gången ska rutan "Rizzläge är bara för dig som är 18 år eller äldre" komma. Tryck *Avbryt*: du ska vara tillbaka i väljaren. Välj igen och tryck *Jag är 18 år eller äldre*. Välj sedan *Förbered Rizzläge*: startskärmen med samtycket ska komma först. Starta.
2. Prata med kompisen. Skriv ner tiden från att kompisen slutat tala till att förslaget hörs. Hörs det någonsin över någon som pratar? Det får inte hända.
3. Exakt **ett** förslag ska visas och läsas upp (D72). Lås telefonen: syns det på låsskärmen? Tryck *Nästa*, och säg sedan "nästa": ett nytt förslag ska komma.
4. Var tyst i 4 sekunder: kommer ett förslag? Är ljudnivån lagom låg?
5. Justera *Din röst är starkare än* i Inställningar → Rizzläge. Loggen i Diagnostik visar nivå och vem appen trodde pratade. Hur ofta blir det rätt, med telefonen på bordet och med AirPods?

### 3x2. Socialt läge (5 min, med samma kompis)
Välj **Socialt läge** (väljaren: Frågor, Provläge, Intervjuläge, Socialt läge, Rizzläge), tryck *Förbered Socialt läge*. Ingen åldersfråga ska komma, men startskärmen med samtycket ska göra det. Gör samma test som i 3x steg 2–4: exakt ett förslag åt gången. Förslagen ska vara skämt, repliker, småprat och följdfrågor, aldrig flirt.

### 3x3. Kalibrering och fler förslag (D69, 10 min, med kompisen)
1. I Socialt läge, säg "Lumen, mer skämt". Du ska höra "Okej", och **inget** förslag ska komma på just det. Blir nästa förslag roligare? Mät tiden till "Okej".
2. Säg en mening till kompisen som slutar med "… Lumen, hon gillar fotboll". Början ska räknas som samtal och slutet som instruktion: syns fotbollen i nästa förslag?
3. Säg "Lumen, ge mig tre pickup lines" i Rizzläge. Alla tre ska visas och läsas upp, **bara den gången**. Nästa förslag ska vara ett igen. Prova också "Lumen, fler förslag".
4. Inställningar → *Kalibrering*: står det du sa under rätt läge? Tryck *Återställ*. Säg sedan "Lumen, återställ" i ett läge: kalibreringen ska försvinna där också.
5. Säger kompisen ordet "Lumen" i en vanlig mening: blir det felaktigt en instruktion? Skriv ner hur ofta det händer.

### 3y. Historik och minne (5 min)
1. Inställningar → *Historik*: dina egna frågor ska stå ordagrant med svar och sammanfattning. Rizz-passet ska ha förslag men **inget** av det kompisen sa.
2. Radera en rad. Tryck *Radera all historik*: appen ska fråga först.
3. Inställningar → *Minne*: minnet från 3t ska finnas. Ändra det, lägg till ett, radera ett, tryck *Radera allt minne*.
4. Stäng av och starta appen: det raderade ska vara borta.

### 3z. Siri, kontroller och musik (10 min)
1. Säg "Hej Siri, starta Lumen". Prova också "Fråga Lumen", "Starta provläge med Lumen" och "Pausa Lumen". Svarar inte Siri på svenska? Testa fraserna på engelska ("Start Lumen") och skriv ner vad som fungerar.
2. Lägg till kontrollerna *Start Lumen* och *Lumen lyssnar* i Kontrollcenter och på låsskärmen. Händer något när du trycker?
3. Spela Spotify, börja lyssna, säg "pausa": Spotify ska fortsätta i full kvalitet. Säg "spela musik" på samma sätt.
4. Inställningar → *Feedback & förslag*: skicka en text. Slå på och av *Dela historik*.

### 3z4. Svarstid, minne och feedback med rösten (D80, 25 min)
**Latens per läge.** Diagnostik-loggen skriver för varje tur: *Turn timing · heard→call · call→first token · call→done · heard→pause over · pause over→first sound*, samt hur många anrop som kastades per minut. Målet är **under 0,3 s från att pausen gått till första ljud** när svaret redan är klart.
1. Frågor: ställ fem korta frågor med normal paus. Skriv ner *pause over→first sound* för var och en. Gör samma sak i Provläge, Intervjuläge (kompisen frågar) och Socialt läge.
2. **Lägg till en mening innan pausen:** säg "Vad är roten ur hundra …", vänta en halv sekund och fortsätt "… delat med fem?". Svaret ska gälla **hela** frågan, och svaret på bara första halvan får aldrig läsas upp. I loggen ska det stå "Answer ahead discarded (the words went on)".
3. Inställningar → *Paus innan Lumen svarar*: sätt Frågor till 0,6 s och sedan 2,0 s. Märks skillnaden? Skriv ner vad som känns naturligt i ett samtal.
4. Socialt läge med en kompis som pratar länge utan paus: ett förslag ska finnas på låsskärmen redan när kompisen tystnar. Under en lång replik ska förslaget uppdateras högst var tredje sekund.

**Minne.**
5. Säg "Lumen, kom ihåg att jag har biologiprov fredag 14 nov". Du ska höra "Sparat.", och under Inställningar → *Minne* → *Om dig* ska det stå med datum och "sagt".
6. Säg "Lumen, regel: svara alltid kort". Den ska synas under *Regler*, och nästa svar ska vara kort. Säg "Lumen, glöm biologiprov": den raden ska försvinna.
7. I Provläge: säg något om dig själv i en fråga ("Jag går i trean, vad är fotosyntes?"). Hamnar "Går i trean" i Minne av sig självt (markerat "hittat av Lumen")? Det kräver att Kevins minnesextraktion är driftsatt. Säg något känsligt om dig själv: det får **inte** sparas av sig självt.
8. Hörs ämnesord rätt? Fråga om "fotosyntes" tre gånger i rad. Står det "fotosyntes" i transkriptet och inte "få tes"?

**Feedback med rösten.**
9. Direkt efter ett svar: säg "Det där var inte riktigt rätt". Du ska höra "Skickat", och inget nytt svar ska komma. Prova också "det var fel", "dåligt svar" och "det stämmer inte".
10. Säg mitt i ett samtal "jag tror att det var fel tåg vi tog": det får **inte** skickas.

### 3z3. Taluppfattning före och efter (D78, 15 min)
Det här är mätningen. Gör samma sak två gånger med samma text och samma avstånd. Läs till exempel tio meningar ur `testdata/scripts/sv-short-prompts.md` med pauser mitt i några av dem.
1. **Före:** Inställningar → Språk → slå av *Lokal röstdetektor före Scribe*. Börja lyssna i läget Frågor. Diagnostik → *Jämför taligenkänning* → *Spela in 2 minuter* och läs. Tryck sedan *Kör iPhone-igenkänning på inspelningen* och *Dela WAV + transkript*.
2. **Efter:** slå på *Lokal röstdetektor*. Första gången står det "Hämtar röstdetektorn…" en stund. Gör om steg 1 med samma meningar.
3. Gör samma sak i Provläge (din egen röst) och Intervjuläge (kompisen läser).
4. Titta i transkriptfilerna: klipps meningar fortfarande ("Det är en annan . Ja, obrutet.")? Hur många sekunder står det att röstdetektorn höll tillbaka? Skicka alla filer.

### 3z2. Röststyrning, AirPods-knappen och avbrott (D74, 20 min)
Målet: du ska aldrig behöva ta upp telefonen efter att du har startat.
1. Under lägesväljaren ska det stå "Säg 'Lumen, byt till provläge' för att byta utan att ta upp telefonen." Lägg telefonen i fickan.
2. Säg "Lumen, byt till provläge". Du ska höra "Provläge." i AirPods och Provläge ska vara igång. Säg sedan "Lumen, byt till frågor", "Lumen, byt till intervjuläge" och "Lumen, byt till socialt läge". Skriv ner vad du hör efter varje kommando och hur lång tid det tar.
3. Socialt läge och Rizzläge startas med rösten först när deras startskärm har bekräftats en gång i appen. Innan dess ska du höra "Socialt läge startas i appen första gången." Rizzläge utan 18-årsbekräftelse ska svara "Rizzläge kräver att du bekräftar 18 år i appen."
4. Säg "Lumen, pausa": du ska höra "Pausar.", och sedan ska mikrofonen släppas. Säg "Lumen, sluta lyssna" i ett annat test: då ska lyssnandet sluta helt.
5. Säg "Lumen, vad är fotosyntes?" i läget Frågor: det ska besvaras som en fråga.
6. **AirPods-knappen:** tryck en gång på AirPods (eller klämma på skaftet) medan Lumen lyssnar. Pausar Lumen? Tryck igen: lyssnar Lumen igen, i samma läge? Skriv ner exakt vad som händer.
7. Pausa Lumen, starta musik i Spotify och tryck sedan på AirPods. Troligen styr trycket nu Spotify och inte Lumen, eftersom Spotify har tagit över "Spelas nu". Skriv ner vad som händer. Reserven är "Hej Siri, starta Lumen".
8. Låt telefonen ligga med Provläge, Socialt läge och Frågor igång i 20 minuter vardera med låst skärm. Inget läge får sluta av sig självt. Titta i Diagnostik-loggen efteråt: står det "Scribe session ended … reconnecting" någon gång, och fortsatte det fungera?
9. Diagnostik-loggen visar för varje tur vilken taligenkänning som användes (Scribe eller iPhone) och vilken mikrofon. Klipps meningar fortfarande i Provläge, nu med 1,2 s väntan efter att du slutat prata? Säg "äh" eller "ja": det ska inte skickas.
10. Indikatorn ska ligga ovanför rubriken "Lumen", inte över den. Under en session ska det bara finnas en stoppknapp (*Stop listening*).

## Del 4 — Skicka in resultaten (5 min)

1. I appen: tryck **Copy results as Markdown**. Öppna Anteckningar på iPhone, klistra in, dela till
   dig själv (mail/AirDrop till Macen).
2. Skicka mig (Angela/Arkitekten via repot eller chatten):
   - den inklistrade texten (en per AirPods-modell, eller en lång),
   - iPhone-modell och iOS-version (står högst upp i texten),
   - AirPods-modell + firmware (från steg 11),
   - dina anteckningar från 3b (ljudkvalitet), 3d, 3e, 3f, 3h, 3i, 3j (bokstavliga transkriptioner), 3k (fångade/missade frågor), 3l (latenser, feltexter), 3m (röstkvalitet), 3n (textläge), 3o (latensraden), 3q (musik), 3t–3z (första testet) och 3p (anteckningar/material),
   - noise-uppgifterna från `testdata/noise/README.md`.
3. **WAV-filerna**: anslut iPhone till Macen → Finder → iPhone → *Filer* → *Lumen* → dra alla
   `lumen-*.wav` till en mapp, t.ex. `~/Lumen-recordings/<datum>/`. **Lägg dem inte i git.** Skriv
   mappens namn i meddelandet. De blir testdata för taligenkänningen i nästa fas.

## Om något går fel

- *"Could not configure the audio session"* eller röd text under State: kopiera texten (Copy results)
  och skicka. Prova nästa config.
- Appen startar inte på telefonen: oftast signering (Del 1 steg 6) eller Utvecklarläge (steg 7).
- Inga AirPods i listan *Inputs*: AirPods måste vara anslutna **innan** du trycker Start capture.
- Hör ljud i iPhone-högtalaren i stället för AirPods: skriv ner vilken config, det är ett resultat.
