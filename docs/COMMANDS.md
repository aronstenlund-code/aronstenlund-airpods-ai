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
| Igen (A17, `AgainRule`) | igen, en gång till, säg det igen, va, hörde inte, jag hörde inte, again, pardon … | ja, med eller utan "Lumen" | alla | – | **Exakt samma svar** (samma ljud, inget nytt anrop). Bara bärarens röst (D81). Som hela yttrandet: om Lumen svarade för högst 15 min sedan. Sist i ett yttrande med brus eller andra ord: högst 45 s. Mitt i en mening ("gör det igen sen"): aldrig. Ljudet äldre än 120 s: samma text läses upp igen. |
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
Källa: `backend/supabase/functions/answer/commands.ts` (`FAMILIES`), tester i `answer/k9_test.ts`.

**Så tolkas en instruktion (inget extra modellanrop):**
- Appen skickar instruktionen som `fragment`, som i dag. Backend normaliserar texten: små bokstäver, ingen interpunktion, "Lumen" och artighetsord ("kan du", "snälla", "tack") tas bort.
- Hela yttrandet ska matcha en uttrycksfamilj. Ord mitt i en vanlig fråga räknas aldrig: "ge ett exempel på en exoterm reaktion" är en fråga.
- En träff blir `<task>` + `<task_rule>` i användarmeddelandet. Den cachade systemprompten ändras inte.
- Ingen träff: som förut. Med `voice_instruction: true` i anropet får modellen texten som en instruktion att utföra. **Angela: skicka den för `.instruction(text)`.**
- Socialt och Rizz: familjerna läses ur `social.calibrate`. Önskemål om nya repliker räknas som förslag (antal 1, "tre alternativ" = 3). Stilord är kalibreringar med sin betydelse.

| `task` | Lägen | Exempel på fraser (3 per task i live-eval) | Beteende |
|---|---|---|---|
| `continue_more` / `continue_simpler` | Provläge, Frågor | mer, utveckla, förklara enklare | finns sedan D35 |
| `example` | Provläge, Frågor | ge ett exempel, har du något exempel | ett nytt konkret exempel på senaste ämnet |
| `summary` | Provläge, Frågor | sammanfatta det viktigaste, summera, vad är det viktigaste | 3–4 meningar om ämnet i `recent_qa` |
| `a_level` | Provläge, Frågor | förklara på a-nivå, som ett A-svar, hur får jag ett A | ett fullt A-svar, utan att säga "A-nivå" |
| `harder_question` | Provläge, Frågor | ställ en svår fråga, en svårare fråga, utmana mig | en resonerande fråga, bara frågan |
| `quick_quiz` | Provläge, Frågor | snabbförhör, fem snabba frågor | "Fråga ett: …" (bara frågan) |
| `yes_no_quiz` | Provläge, Frågor | ja eller nej frågor | en ja/nej-fråga |
| `quiz_topic` (+ `task_arg`) | Provläge, Frågor | förhör mig på X, testa mig om X, fråga ut mig om X | en fråga om X |
| `weak_areas` | Provläge, Frågor | testa mina svagaste områden, vad kan jag sämst | fråga om begreppet med flest fel i `context.concept_stats` |
| `self_assessment` | Provläge, Frågor | hur bra kan jag det här, hur ligger jag till | lägesbild ur `concept_stats` och rättade svar, aldrig påhittade siffror |
| `careful` | Provläge, Frågor | var säker, dubbelkolla det, är du säker på det | Sonnet med tänkande för just det svaret ("Rättelse: …" vid fel); kostnaden loggas per svar |
| `catch_up` | Provläge, Frågor | vad missade jag, vad sa läraren | sammanfattning av `context.transcript` (D61: inget sparas) |
| `brief_style` | Provläge, Frågor | hjälp mig diskret, bara en mening | en mening |
| `interview_help:professional\|better\|confident\|counter_question\|stuck` | Intervju | vad borde jag säga / bättre svar / mer självsäkert / ge mig en motfråga / jag fastnar | jag-form; motfrågan sägs som fråga |
| `social:reply\|change_topic\|follow_up\|what_meant`, `rizz:more\|rescue`, `alternatives:3` | Socialt, Rizz | vad ska jag svara, byt ämne, smart följdfråga, vad menade hon, mer rizz, rädda mig, tre alternativ | nya repliker (`<request>`) |
| `social:funnier\|natural`, `rizz:confident\|flirty\|subtle\|cocky\|less_cringe` | Socialt, Rizz | roligare, mer naturligt, mer självsäker, flirtigare, mer subtil, kaxigare, mindre cringe | kalibrering (D69) med betydelsen |

**Nya fält i `/answer` (valfria, appen behöver inte skicka dem):**
- `context.concept_stats: [{concept, right, wrong}]`: högst 30, från förhörsresultaten i provprofilen.
- `voice_instruction: boolean`.

**Stående regler (D80) utan "Lumen", i Provläge och Frågor:**
- Gäller "i framtiden ska du …", "från och med nu …", "svara alltid …", "… det är minnet", när det handlar om svaren.
- Besvaras lokalt med en kort bekräftelse ("Okej, korta svar.").
- Kommer tillbaka som `done.memory_add` = "Regel: …" (appen lagrar det som i dag och skickar det med bland minnena, och prompten följer "Regel:"-rader) och som `done.rule_add` (regeltexten, för Minne › Regler).
- En fråga om framtiden ("vad händer med klimatet i framtiden") blir aldrig en regel.
