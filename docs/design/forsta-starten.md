# Första starten i Apple-stil (Kelly, Ke55, D160, 2026-11-13)

Till Angela Fable. Från nedladdning till första frågan i örat, med **högst 3 skärmar innan man fotar**. Reglerna står i
`SYSTEM.md` §0. Bilder: `bilder/apple/fs-*.png`, ljust till vänster och mörkt till höger (källa `_src/apple.html`).
**Det här är skisser. Inget är byggt och inget är provat på telefon.** Det ersätter introt i `FirstStartView` (Elias,
"Fråga högt. Få svaret i örat." och de fyra löftena om lyssning) och vägen Fråga vad som helst → Har du prov snart?.

## Jämförelse
Apples egna introduktioner (Podcaster, Kondition, Anteckningar efter en uppdatering och "Nytt i iOS") är byggda på samma
sätt: appikonen eller en symbol, en rubrik ("Välkommen till …"), tre rader med symbol + fetstil + en mening och en
knapp, **Fortsätt**, längst ner. Datan förklaras med en kort rad och en länk ovanför knappen, inte med en vägg av text.
De frågar om tillstånd (kamera, mikrofon, notiser) först när det behövs, inte i introt. Jämförelsen bygger på vad jag
vet om apparna och är **ej kontrollerad mot iOS 26 på telefon**.

## Vägen (`fs-flode.png`)
| # | Skärm | Bild | Knapp |
|---|---|---|---|
| 1 | **Välkommen** (och samtycke) | `fs-1-valkommen.png` | **Fortsätt** |
| 2 | **Nytt prov**, öppnas direkt efter Fortsätt | `fs-2-nytt.png` | raden **Fota sidor** |
| 3 | **Kameran**, systemets dokumentskanner | `fs-3-kamera.png` | **Spara** |
| | Nytt prov med sidorna | (som `apple/nytt.png`) | **Skapa frågor** |
| | Läser ditt material | (finns) | – |
| | Stämmer det här? | (finns) | **Ser rätt ut** |
| | Frågelistan | `apple/fragor.png` | **Starta prov** |
| | Styr med dina AirPods (bara första gången) | `apple/kontroller.png` | **Starta prov** |
| | **Första frågan i örat** | `apple/spelar.png` (med N1-raden) | – |

**I första starten finns inte:** lyssnande lägen, mikrofonfrågan, notisfrågan, konto, inloggning, röstningen på
loggan, flamman eller tips. Det som är BETA nås först via Fler lägen.

## Skärm 1: Välkommen
| Del | Text |
|---|---|
| Bild | Appikonen (exakt D, D139), 72 pt med iOS-hörn |
| Rubrik (`.largeTitle.bold()`, centrerad) | Välkommen till EarMind |
| Rad 1 (symbol `camera`) | **Fota materialet** · EarMind gör provfrågor med A-svar. |
| Rad 2 (symbol `waveform`) | **Lyssna i dina AirPods** · Frågorna läses upp. Tryck för svaret. |
| Rad 3 (symbol `book.closed`) | **Plugga utan mobilen** · Telefonen kan ligga i fickan. |
| Rad ovanför knappen (`.footnote`, `.secondary`) | Fotona och texten skickas en gång för att göra frågorna och sparas inte. Starta prov använder aldrig mikrofonen. **Läs mer** |
| Knapp (`.borderedProminent`, `.large`, fast nederst) | Fortsätt |
| VoiceOver-tips på Fortsätt | Godkänner att materialet skickas för att göra frågorna. |

Symbolerna har accentfärgen, och raderna står vänsterställda under en centrerad rubrik, som Apples. Ingen hörlursbild
(granskningsrisk 5.2.5, Ke12).

## Läs mer: Data och integritet (`fs-1b-lasmer.png`)
Ett blad (`NavigationStack` + `List`) med rubriken **Data och integritet** och **Klar** uppe till höger.
| Sektion | Text |
|---|---|
| DET HÄR SKICKAS | Foton, dokument och text du lägger till skickas en gång till vår server och vår AI-leverantör för att göra frågorna. De sparas inte. |
| | Frågorna och svaren skickas till vår röstleverantör för att bli ljud. |
| | Använder du Gör med ChatGPT skickar du filerna till ChatGPT själv. |
| DET HÄR SPARAS | Dina prov, med frågor, svar och ljud, sparas hos EarMind tills du tar bort dem. |
| MIKROFONEN | Starta prov använder aldrig mikrofonen. Lägena som lyssnar finns under Fler lägen och frågar först. |
| Fotnot | Du behöver inte skapa något konto. Du kan ta bort allt under Inställningar. |

## Skärm 2: Nytt prov (första gången)
Samma `Form` som `apple/nytt.png`, med tre skillnader första gången:
- En rad överst: "Börja med materialet till ditt nästa prov."
- **Fota sidor** är första raden och den enda med fet text i accentfärgen.
- Uppe till vänster: **Senare** (inte Avbryt). Den leder till Hem utan prov (`apple/hem-tom.png`).
Fotnot under materialet: "iOS frågar om kameran första gången. Fotona sparas inte." Sektionen PROV: Provets namn
(valfritt), **Vilken årskurs?** (A88, med Hoppa över i menyn) och Antal frågor. Inget val av svarslängd (D162). Röst
(D151): standardrösten används och syns först i frågelistan ("Röst · ändra innan ljudet görs") om A84 kräver ett val.

## Skärm 3: Kameran
`VNDocumentCameraViewController` (VisionKit): den hittar sidan, rätar upp den och tar flera i följd. **Spara (n)**
leder tillbaka till Nytt prov med sidorna som miniatyrer. Ingen egen kamera. Säger iOS nej till kameran:
"EarMind får inte använda kameran. Tillåt den i Inställningar, eller välj bilder ur bildbiblioteket." med knappen
Öppna Inställningar (Ke50 §2).

## Samtycket (godkänt: D170, Deangelo 2026-11-14 14:15)
I dag godkänns lyssningen i introt ("Testa nu betyder att du godkänner punkterna ovan"). Med D142 lyssnar första
starten aldrig. **Förslag:**
1. **Välkommen** är samtycket för repetitionsläget: material och text skickas för att göra frågor och ljud, och prov
   sparas på kontot. Raden ovanför Fortsätt säger det, och Läs mer har allt. Ny samtyckesversion.
2. **Lyssningens samtycke** (dagens `ConsentView` med D138-texten och lyssningsindikatorn) visas första gången ett
   lyssnande läge startas under Fler lägen, och mikrofonfrågan kommer då. Skyddsräckena i CLAUDE.md gäller oförändrat
   för lyssningen (samtyckesskärm, synlig indikator, inget ljud sparat som standard).
3. Den som redan har godkänt i dag behöver inte godkänna igen för lyssningen. Välkomstsamtycket visas en gång vid nästa
   start.
Det här ändrar var samtycket ges, inte vad det säger om lyssning. **Godkänt i D170** och byggt i A94.

## Till Angela Fable
1. Ersätt `IntroView` med Välkommen enligt tabellen ovan (fast knapp nederst, `.footnote`-raden och Läs mer-bladet).
2. Efter Fortsätt öppnas Nytt prov direkt (inte Fråga vad som helst eller Har du prov snart?), med "Senare" uppe till
   vänster.
3. Fota sidor öppnar `VNDocumentCameraViewController`.
4. `FirstStartView.Step` behöver bara `welcome` och `newDrill`. `firstQuestion` och `addExam` hör till lyssningen och
   flyttas till första starten av ett lyssnande läge (efter Deangelos ja om samtycket).
5. Skärmbildsscener: `fsWelcome`, `fsReadMore`, `fsNewDrill` (ljust, mörkt, SE och största text).
