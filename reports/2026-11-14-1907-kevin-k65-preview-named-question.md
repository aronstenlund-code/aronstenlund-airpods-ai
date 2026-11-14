# K65: förhandsvisning av publicerade prov, och Tobys "not a question" (Kevin, 2026-11-14 19:07)

## Kort
- **K65 (Kellys P1, A87 punkt 5): klart och verifierat live.**
  - Svaren på `search` och `publish` har nu `preview` (de fyra första frågorna som `[{question, short}]`) och `first_audio_url` (en signerad länk till första frågans färdiga ljud, eller `null`).
  - Inget nytt ljud görs och ElevenLabs anropas inte.
  - Angela Fable är meddelad.
- **Toby T17c w43: klart och verifierat live.** "Lumen, hur länge har han funnits?" var "not a question" i Standardläget (auto). Nu besvaras en fråga som nämner assistentens namn direkt, också om ett ord är felhört ("han" för "hajar"). Utan namnet är Standardläget tyst som förut.

## K65
- **Var:**
  - `publicView` i `drill/handler.ts` tar en `PublicPreview`.
  - `search` hämtar provets frågor, i ordning efter `position`, och signerar första frågans ljud i ett anrop för alla träffar. Bara filer som är `done` signeras.
  - `publish` tar samma uppgifter ur provets vy.
- **Länken** gäller 1 timme, som andra ljudlänkar.
- **"och N frågor till":** `items` − `preview.length` (`items` fanns redan).
- **Test:** K49-sökningen kontrollerar nu `preview` och `first_audio_url`.
- **Live med ett testkonto:**
  - 6 frågor med tyst testljud, publicerat på en riktig skolkod
  - `publish` gav 4 rader i `preview` och en länk
  - `search` gav likadant
  - provet togs bort efteråt

## T17c w43
- **Återskapat live:** i `auto` blev frågan `is_question false` med säkerhet 0,3–0,5 i 6 körningar av 6, med och utan "Lumen,". I `text` blev den en fråga.
- **Orsak:** i Standardläget avgör modellen själv om något är en fråga. "han" pekar inte på någon, så modellen tror att det är prat som inte riktas till appen.
- **Rättat (`answer/handler.ts`):** i `auto` gäller två villkor. Fragmentet innehåller namnet (Lumen, EarMind eller användarens namn för assistenten), och resten frågar något (`askLike`, samma regel som förut). Då går frågan den direkta vägen, som när man trycker för att fråga.
- **Live efter driftsättning:** "Lumen, hur länge har han funnits?" gav två gånger "Det beror på vem du menar … Säg namnet så svarar jag". Samma fråga utan namn gav inget svar.
- **Test:** `k16_test.ts` "Toby T17c w43".
- **Risk:** en mening med namnet och ett frågetecken som inte var riktad till appen besvaras nu. Med namnet i meningen är det rimligt att tolka den som riktad till appen.

## Tester och kostnad
- **Tester:** 609 gröna, och `check` är ren.
- **Kostnad Claude:** cirka 0,01 USD.
- **Kostnad ElevenLabs:** 0, eftersom alla anrop hade testhuvud.
