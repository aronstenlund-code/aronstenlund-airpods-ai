# Röstkommandon (A6/A7): den enda listan

**Källa i koden:** `Lumen/Core/Commands/CommandRegistry.swift` (`CommandAction`). Inställningar › Röstkommandon visar
samma lista, och där kan användaren lägga till och ta bort fraser per åtgärd.

**Andra sessioner:**
- Ändra inte en åtgärd här utan att ändra koden, och tvärtom.
- Backend-delen längst ner skriver Kevin (K9).

## Så matchas en fras
- **Hela yttrandet ska matcha frasen**, efter normalisering: små bokstäver, ingen interpunktion. Ord mitt i en mening
  räknas aldrig.
- **Med "Lumen" först** fungerar alla åtgärder i alla lägen.
- **Utan "Lumen"** fungerar bara de som står som "utan namn" nedan (musik och "det där var fel").
- **Universella ord utan "Lumen":**
  - Orden: "upprepa", "viska", "högre", "kortare", "snabbare" och "utveckla".
  - De gäller bara som hela yttrandet och bara i Provläge och Frågor, där den som pratar är användaren.
  - Inställningen `voice.universalCommands` styr dem och är på från början.
  - I Socialt läge, Rizzläge och Intervjuläge krävs alltid "Lumen".
- **Användarens egna fraser:**
  - En fras som redan tillhör en annan åtgärd nekas.
  - Vanliga ord eller en frasstart som låter som en fråga ger en varning.
  - Egna fraser blir keyterms till Scribe.
- **Lägesbyte:** "byt till", "byta till", "växla till", "gå till", "starta", "lyssna efter" och "switch to", följt av
  lägets namn. Lägets namn ensamt fungerar också ("Lumen, provläge"). Det fungerar från alla fem lägen och bekräftas
  med lägets namn i AirPods (D74).

## Nivå 1: i telefonen (inget API-anrop, < 50 ms)
| Åtgärd (`id`) | Standardfraser | Utan namn | Lägen | Bekräftelse | Beteende |
|---|---|---|---|---|---|
| Pausa Lumen och spela musik (`musicHandOff`) | pausa, pausa lumen, spela musik, pause, pause lumen, play music (+ "paus", "pausa dig" bara efter namnet) | ja | alla | "Pausar." | Släpper ljudet med `notifyOthersOnDeactivation`, och musiken fortsätter (D58). |
| Tillbaka till Lumen (`backToLumen`) | tillbaka till lumen, lyssna igen, fortsätt lyssna, back to lumen | nej | alla | "Jag lyssnar." | När musiken spelar hör Lumen inget. Vägen tillbaka är Siri "Starta Lumen", kontrollen eller låsskärmen (A6). |
| Nästa låt (`nextTrack`) | nästa låt, hoppa över låten, skippa låten, next song, skip song | ja | alla | "Nästa låt." | Lumen släpper ljudet och byter låt i Spotify om den är kopplad, annars i Apple Music, annars "tryck två gånger på AirPods". |
| Förra låten (`previousTrack`) | förra låten, föregående låt, spela förra låten, previous song | ja | alla | "Förra låten." | Som nästa låt. |
| Pausa musiken (`pauseMusic`) | pausa musiken, stoppa musiken, pause the music, stop the music | ja | alla | "Musiken är pausad." | Medan Lumen lyssnar är musiken redan pausad. |
| Byt läge (`switchMode`) | se ovan | nej | alla | lägets namn | D74. |
| Avsluta (`stop`) | sluta lyssna, sluta, avsluta, stäng av, stop listening | nej | alla | "Slutar lyssna." | Stänger av mikrofonen. |
| Det där var fel (`wrong`) | det var fel, det där var fel, fel svar, stämmer inte … (22 fraser) | ja | alla | – | Senaste turen går till /feedback (D80). |
| Upprepa (`repeatAnswer`) | upprepa, upprepa svaret, säg det igen, repetera, vad sa du, kan du upprepa, repeat, say that again | universellt "upprepa" | alla | – | Spelar upp ljudet från senaste svaret igen ur minnet (högst 120 s, inget TTS-anrop). Igenkänningen är stängd under tiden. |
| Viska (`whisper`) | viska, tystare, prata tystare, lägre, sänk volymen, whisper, quieter | universellt "viska" | alla | "Tystare." | Lumens volym på uppspelningsnoden × 0,6 (minst 0,25), sparas. Inte telefonens volym. |
| Högre (`louder`) | högre, prata högre, höj volymen, louder | universellt "högre" | alla | "Högre." | ÷ 0,6, högst 1,0. Vid högsta volym: "Höj på telefonen." |
| Kortare svar (`shorter`) | svara kortare, kortare, kortare svar, snabbare, kortare tack, shorter | universellt "kortare", "snabbare" | alla | "Kortare." | `length: short` resten av passet. |
| Längre svar (`longer`) | svara längre, längre svar, längre, utförligare svar, longer answers | nej | alla | "Längre." | `length: long` resten av passet. |
| Spara svaret (`saveAnswer`) | spara det, spara svaret, spara det där, spara i anteckningar, save that | nej | alla | "Sparat." | Senaste svaret läggs i Anteckningar. |
| Nästa prov (`nextExam`) | vilket prov har jag härnäst, när är nästa prov, nästa prov, vilket är nästa prov, next exam | nej | alla | provets namn och dag | Läses ur provplanerna i telefonen. Ingen LLM. |
| Kom ihåg (finns, D49/D80) | kom ihåg (att) …, glöm inte (att) …, remember that … | nej | alla | "Sparat." | Sparas i Minne. "Glöm …" tar bort. |

## Nivå 2: i samma /answer-anrop
- Frasen skickas som instruktion i första standardformuleringen, så att en egen fras ("testa mig") når backend med
  orden i K9:s tabell ("förhör mig").
- Ingen extra rundresa.
- Utanför sina lägen går frasen som en vanlig instruktion, precis som förut.

| Åtgärd (`id`) | Skickas som | Standardfraser | Lägen |
|---|---|---|---|
| `quizMe` | förhör mig (+ resten) | förhör mig …, testa mig …, quiz me | Provläge, Frågor |
| `moreDetail` | utveckla | utveckla, utveckla svaret, berätta mer, mer, mer om det, tell me more (universellt "utveckla") | alla |
| `simpler` | förklara enklare | förklara enklare, förklara, enklare, förklara det enklare, simpler | alla |
| `example` | ge ett exempel | ge ett exempel, ge mig ett exempel, exempel | alla |
| `summary` | sammanfatta det viktigaste | sammanfatta, summera, summarize | alla |
| `aLevel` | förklara på a-nivå | a-nivå, som för ett a | Provläge, Frågor |
| `harderQuestion` | ställ en svår fråga | en svårare fråga, svårare fråga | Provläge, Frågor |
| `quickQuiz` | snabbförhör | fem snabba frågor, snabbförhör mig | Provläge, Frågor |
| `weakAreas` | testa mina svagaste områden | hur bra kan jag det här, vad kan jag sämst | Provläge, Frågor |
| `careful` | var säker | dubbelkolla, var noggrann | alla (starkare modell, kostar mer) |
| `catchUp` | vad missade jag | vad har jag missat, vad sa de | alla (D61: bara sessionens transkript) |
| `discreet` | hjälp mig diskret | diskret, kort och diskret | alla (bara en längdstil) |
| `asUsual` | svara som jag brukar | som vanligt | alla (D80-regler och minnen) |
| `interviewHelp` | hjälp mig svara professionellt | vad borde jag säga, hjälp mig svara | Intervju |
| `interviewBetter` | bättre svar | ge mig ett bättre svar | Intervju |
| `interviewConfident` | mer självsäkert | låt mer säker | Intervju |
| `interviewCounter` | motfråga | ge mig en motfråga | Intervju |
| `interviewStuck` | hjälp jag fastnar | jag fastnar, hjälp | Intervju |
| `socialReply` | vad ska jag svara | vad svarar jag | Socialt, Rizz |
| `funnier` / `moreNatural` / `changeTopic` / `followUp` / `whatMeant` | roligare / mer naturligt / byt ämne / smart följdfråga / vad menade personen | se koden | Socialt, Rizz |
| `rizz` / `moreConfident` / `flirtier` / `subtler` / `cockier` / `rescue` / `lessCringe` | ge mig lite rizz / mer självsäker / flirtigare / mer subtil / kaxigare / rädda mig / mindre cringe | se koden | Rizz, Socialt |
| `threeOptions` | tre alternativ | ge mig tre, tre förslag | Socialt, Rizz (ett förslag är standard) |

**Utgår (dubbletter, A7):**
- "lyssna efter frågor" är "byt till Frågor".
- "förklara" är "förklara enklare".
- "snabbare" är "kortare".

## Backend (K9, Kevin)
_Kevin fyller i: regeltabellen i `answer/` som översätter instruktionerna ovan till `task`._
