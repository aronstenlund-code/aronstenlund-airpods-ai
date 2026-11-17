# A136 (D220): "Hur ska det låta?", röster och Skriv i takt (Angela Fable, moln)

Klart 2026-11-18 00:17. **Verifierat i CI (bygge och tester) och på bild i Simulatorn. Inget på enhet, och inget
riktigt ljud med stil eller vald röst har gjorts.** 0 ElevenLabs (D180).

## Vad som är byggt
### 1. Skriv i takt (på telefonen, kostar inget)
- Tempo-menyn på Säg-kortet har valet **Skriv i takt** överst. Kapseln visar då **I takt**. Valet sparas.
- Texten läses i **0,85×** och ljudet **stannar efter varje fras på 3–6 ord**. Fraserna räknas ur serverns ordtider
  (`audio.text.words`, Kevin): en mening delas i fraser, en paus mellan två ord (ett komma) avslutar frasen när båda
  sidor har minst tre ord, annars delas den vid sex ord; sju och åtta ord delas i två så att ingen fras blir under
  tre. En mening på ett eller två ord är en egen fras.
- **Ljud utan ordtider** (gjort före Kevins ändring): paus efter varje mening.
- Sista frasen i ett stycke får också sin paus, före nästa stycke och före nästa varv.
- Inget nytt ljud görs och inget räknas: samma fil spelas, bara med pauser. Under pausen spelas tystnad (som
  tänketiden i proven), så det fortsätter med låst skärm.
- **Pausens längd är mitt antagande:** 1 sekund + 0,6 sekund per ord i frasen (3 ord = 2,8 s, 6 ord = 4,6 s, högst
  8 s). D220 säger bara "en paus". Det är ett tal på ett ställe (`WritingPace.pause`) om Aron vill ha längre.

### 2. "Hur ska det låta?"
- En **stilrad** i kortet, bara när fältet har text (Kellys Ke75): fältet "Hur ska det låta?", fri text, högst 80
  tecken. Ovanför tangentbordet finns förslagen **Tydligt · Lugnt · Glatt · Viskande**; ett tryck skriver ordet, efter
  ett kommatecken om det redan står något.
- Stilen skickas som `drill.style` i både `save` och `cost` (K95), så **kostnaden från servern visas före Spela** och
  räknas om när stilen ändras. Appen räknar inget själv.
- Stilen hör till texten: töms fältet töms stilen.

### 3. Röstväljaren
- **Röstkapseln** ("Astrid ▾") står till vänster om stilfältet och öppnar bladet **Röst** (Klar). Bladet har sökfältet
  "Sök bland alla röster", avsnittet SVENSKA RÖSTER med ▶ provlyssna, namn, beskrivning och bock på vald röst, och
  fotnoten "Provlyssning kostar inget. En ny röst blir nytt ljud."
- Rösterna kommer från `GET /voices` → `catalog` (K96). Provlyssningen spelar röstens `preview_url` direkt; inget
  ljud görs. Sökningen frågar `/voices?library=1&search=…` 0,6 s efter sista tangenten (servern tar 10 i minuten);
  en röst som inte finns i katalogen går att lyssna på men inte välja ("Går inte att välja än").
- **Katalogen är tom i dag** (Kevin: tills Aron lagt in 12–20 röster). Då visas **ingen röstkapsel**, bara
  stilfältet i full bredd. Kapseln kommer av sig själv när katalogen har röster. Utan vald röst står det "Röst ▾".
- Vald röst skickas som `drill.voice_id` vid första sparningen och är sedan låst (K96). Valet sparas till nästa text.

### 4. Samma text med annan röst eller stil
- Rösten och stilen låses per prov på servern, så **samma text med en annan röst eller stil blir ett eget prov** hos
  oss (och nytt ljud, som kostnaden visar). Samma text, röst och stil igen är samma prov och kostar 0.
- **Senaste** sparar texten med röst och stil: ett tryck lägger tillbaka alla tre. Samma ord med två olika ljud står
  som två kapslar (de ser lika ut; se Otestat).
- Ljud som redan finns på telefonen återanvänds bara när röst och stil är desamma.
- Serverns nej för en röst som inte längre finns (400 `voice_unavailable`) visas med serverns egna ord, inte som
  "Uppläsningen är tillfälligt avstängd" (koden krockade med en äldre lista i appen).

## Teknik
- `Lumen/Core/Repetition/ReadingPlayer.swift`: `WritingPace` (ren funktion: fraser, plan, paus) och `ReadingPlayer.inPace`;
  spelaren spelar till frasens slut (`play(until:)`), väntar med samma timer som tänketiden och går vidare.
- `Drill.style`, `Drill.voiceID`, `DrillItem.wordTimesMs`, `SaySound` (röst + stil, det som skiljer två Säg-texter åt).
- `DrillCloud.swift`: `style`/`voice_id` i `saveBody` och ur `get`, `words` per fil, `SayVoice`, `voices()` och
  `voiceLibrary(search:)` i `DrillCloudSyncing`.
- `RepetitionModel`: `say(_:repeatMinutes:sound:inPace:)`, `sayCost(_:sound:)`, `saidDrill(for:sound:)`,
  `sayVoices`/`loadSayVoices()`/`searchVoices(_:)`. `RepetitionSession.SayOptions.inPace`.
- `Lumen/Features/Repetition/SayViews.swift` (stilraden, tempo-menyn) och ny fil `SayVoiceViews.swift` (bladet Röst
  och provlyssningen).
- Scener: `repSayStyle`, `repSayVoices`.

## Tester
- **iOS build 44194852679 grön på min gren** (enhetsbygge, varningar som fel, LumenTests).
- Nya tester i `LumenTests/A136StyleVoicePaceTests.swift` (fejkade svar och tysta låtsasfiler):
  fraser på 3–6 ord för 3–60 ord, komma-pauser, planen ur ordtider och utan ordtider; uppläsaren i takt (0,85×, paus
  efter varje fras och efter sista, paus-tryck under pausen, inget stannar utan takt); stil i varje sparning och röst
  bara i den första; serverns `style`, `voice_id` och `words` läses; katalogen och biblioteket läses, bara https
  provlyssnas; Kellys ord; samma text med annat ljud är ett annat prov och samma ljud samma prov; kostnaden frågas
  med stil och röst; ljud på telefonen återanvänds bara för samma röst och stil; tom katalog ger inga röster.

- Första bygget (44191509168) föll på ett av mina nya testvillkor, inte på appen: testets låtsasmoln har ingen
  textfil, så ingen uppläsare startar när samma text spelas en tredje gång. Villkoret är borttaget.
- Main-bygget för A139 (44189517199) avbröts i Mac-kön utan att ha startat (0 steg). Samma kod byggs nu med A136.

## Bilder
`reports/2026-11-17-a136-bilder/` (Simulatorn, flödet fable-screens 44191549702 och 44191554740):
- `stil-ljust.jpg`: kortet med röstkapsel, stil och "I takt" · bladet Röst · kortet som det ser ut i dag med tom
  katalog (bara stilfältet).
- `stil-morkt.jpg`: samma i mörkt.
- `stil-se-storsta-text.jpg`: iPhone SE med största text. Stilraden staplas (röstkapseln, sedan stilen). I bladet
  Röst bryts beskrivningen i smala rader ("riks-svens-ka"); det har jag inte rättat, Kelly får säga hur raden ska stå.

## Det här ska Aron prova på telefonen
1. Skriv en text på Start. Under fältet kommer raden "Hur ska det låta?". Tryck i den: förslagen står ovanför
   tangentbordet. Skriv t.ex. "Lugnt" och se att kostnaden vid knappen ändras.
2. Tryck Spela. Hör om rösten låter lugnare. (Kevin har inte kunnat prova v3 med svenska; det här är första provet.)
3. Välj **Skriv i takt** i tempo-menyn (kapseln visar "I takt") och tryck Spela på en text som redan har ljud:
   det ska kosta 0, gå lite långsammare och stanna efter varje fras. Säg om pauserna är för korta eller långa.
4. Lås telefonen under Skriv i takt: det ska fortsätta.
5. Röstkapseln syns först när Kevin och Aron lagt in röster i katalogen.

## Otestat (antaganden)
- Inget på enhet. Pausernas längd och att tystnaden håller appen vid liv med låst skärm under Skriv i takt är otestat
  (tänketiden i proven gör samma sak och är provad av Aron).
- Ordtiderna har jag bara sett som fält i Kevins kod; inget riktigt svar med `words` har gått genom appen.
- Adressen i `preview_url` är ElevenLabs egen. Att den går att spela direkt i appen (https, mp3) är otestat; bara
  https-adresser spelas.
- Tangentbordets förslag syns inte på bilderna (tangentbordet är inte uppe där).
- Två Senaste-kapslar för samma ord med olika ljud ser lika ut. Kelly får säga om rösten eller stilen ska stå i kapseln.
- Stil med eleven_v3 på svenska är inte provad av någon (Kevins rapport, TILL-ARON #28).

## Farhågor
Inga nya. Inget här döljer appen eller lyssnandet; Skriv i takt och rösterna gäller bara uppläsning av egen text.

## Kvar / nästa
- A140 (blanda röster, AI:s röstval), A141 (välkomstkrediter, inbjudan, 79 kr) och sist A134 (köpbladet).
- Kelly granskar bilderna; Toby testar (T50).
