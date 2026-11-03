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
    Diagnostikskärmen (alla mätningar i Del 3) öppnas med vågform-ikonen uppe till höger; *Start capture*
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
3. Gör samma sak med Siri (håll in sidoknappen, fråga något).

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
2. Gå in på diagnostikskärmen medan den lyssnar: står den röda raden kvar högst upp? Tryck *Stopp* **i den
   röda raden** – lyssningen ska sluta direkt och raden försvinna.
3. Tryck *Börja lyssna* igen, ta ut AirPods: skärmen ska visa *Pausad* och knappen *Fortsätt lyssna*.
   Sätt i AirPods, tryck *Fortsätt lyssna*.
4. Tryck på handikonen uppe till höger (*Integritet och samtycke*). Längst ner står när samtycket lämnades.
   Tryck *Ta tillbaka samtycke* → *Sluta lyssna och ta tillbaka*. Lyssningen ska sluta och samtyckesskärmen
   visas igen. Tryck *Jag förstår …* på nytt.
5. Avsluta appen helt (svep upp) och öppna igen: den ska **inte** fråga om samtycke igen.
6. Kolla språket: är telefonen på svenska ska knappar och texter vara på svenska. Skriv ner engelska
   texter som dyker upp där svenska borde stå.

### 3j. Transkription live (MVP-del 2, 10 min)
1. På lyssnarskärmen: välj **Svenska** i språkväljaren och tryck *Börja lyssna*. Under statusraden ska det stå
   *Förbereder talmodellen …* (första gången laddas Apples svenska modell ner – kräver internet, kan ta en
   minut) och sedan *Transkriberar på den här telefonen · SpeechTranscriber* (eller *DictationTranscriber*).
   **Skriv ner vilket av de två som står** – det avgör vilken Apple-motor som finns för svenska.
2. Prata normalt i rummet. Under *Transkription live* ska grå kursiv text dyka upp medan du pratar och bli
   svart när meningen är klar. Säg tre av de korta meningarna i `testdata/scripts/sv-short-prompts.md` och
   skriv ner vad som faktiskt kom ut (bokstavligt).
3. Låt en annan person säga tre meningar på 2 m avstånd. Skriv ner resultatet på samma sätt.
4. Byt till **English** medan den lyssnar. Statusraden ska gå via *Förbereder …* till *Transkriberar …* igen.
   Säg två meningar på engelska. Byt tillbaka till Svenska.
5. Står det *Svenska finns inte för taligenkänning på den här telefonen*: det är ett viktigt resultat (R2).
   Tryck på diagnostikskärmen → *Check SpeechTranscriber locales* och kopiera texten.
6. Ta ut AirPods (paus) och sätt i dem igen → *Fortsätt lyssna*. Transkriptionen ska starta om själv
   (statusraden visar *Transkriberar …* igen).

### 3k. Aktivering: håll för att fråga och auto (MVP-del 3, 10 min)
Svarsmotorn kommer i nästa steg – här testas bara att rätt mening fångas som fråga.
1. *Börja lyssna*, Svenska. Lämna *Aktivering* på **Håll för att fråga**. Håll in den stora knappen
   *Håll för att fråga* (den blir orange: *Lyssnar på dig … släpp för att fråga*), säg "vad är fotosyntes",
   släpp. Inom ca 2 s ska kortet **Upptäckt fråga** visa exakt det du sa. Skriv ner om något ord fattades
   (särskilt det sista) – det styr hur lång väntetiden efter släpp ska vara.
2. Säg något lågt (nästan viskande) medan du håller. Fångades det?
3. Låt någon annan säga en mening, tryck *Fråga om det senast sagda*: kortet ska visa den meningen.
4. Byt *Aktivering* till **Auto**, känslighet *Mellan*. Låt någon läsa tre vanliga påståenden
   ("idag ska vi prata om …") och sedan tre frågor ur `testdata/scripts/sv-short-prompts.md` (t.ex. 5, 12, 29).
   Skriv ner vilka som gav *Upptäckt fråga* och vilka som inte gjorde det (både falska träffar och missar).
5. Ställ två frågor inom 5 sekunder: bara den första ska fångas (8 s väntetid mellan automatiska svar).
6. Sätt känslighet *Hög* och säg bara "fotosyntes": nu ska det fångas. På *Mellan* ska det inte fångas.

## Del 4 — Skicka in resultaten (5 min)

1. I appen: tryck **Copy results as Markdown**. Öppna Anteckningar på iPhone, klistra in, dela till
   dig själv (mail/AirDrop till Macen).
2. Skicka mig (Angela/Arkitekten via repot eller chatten):
   - den inklistrade texten (en per AirPods-modell, eller en lång),
   - iPhone-modell och iOS-version (står högst upp i texten),
   - AirPods-modell + firmware (från steg 11),
   - dina anteckningar från 3b (ljudkvalitet), 3d, 3e, 3f, 3h, 3i, 3j (bokstavliga transkriptioner) och 3k (fångade/missade frågor),
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
