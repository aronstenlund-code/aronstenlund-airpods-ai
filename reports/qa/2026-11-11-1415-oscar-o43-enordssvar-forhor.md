# Oscar O43: Enordssvar i förhör, före och efter K40/A62

Datum: 2026-11-11, 12:44–14:15 (svensk tid)
Uppgift: O43 i `prompts/queue/oscar.md` (Deangelo, efter Arons telefontest: "Nilen" hördes som "Nilan" / "om ni har redan svarat", "Seine" sagt "sän" hördes som "såg en"). 40 korta svar som cachat tal, i tyst rum och i klassrumsprat, genom Scribe till `/answer` med förhörsfrågan som sammanhang. Mål ≥ 38/40.

## Upplägg
**Fallen:** `scripts/qa/o43_short_answers.py`.
- 40 kontrollfrågor med enordssvar: 20 geografi som Arons prov (floder, sjöar, kuststäder), 10 biologi och 10 historia.
- **Skrivna 12:44, före K40-koden.** Alternativen (`ALTS`) är mina egna, inte Kevins `k40-quiz-sound.json`.
- Utländska namn sägs som en svensk elev säger dem ("Sän", "Loar", "Marsej").

**Ljud:**
- `/tts` (ElevenLabs) **en gång**: 367 tecken, i `scripts/qa/audio-cache/o43/` (git-ignorerat, D120). Eftermätningen och O43d använde 0 nya tecken.
- Klassrumsprat: fyra espeak-ng-röster som pratar i mun på varandra (gratis), 10 dB under svaret. AirPods-mikrofonen sitter nära munnen. 5 dB dränkte svaret helt i röktestet.

**Kedjan:**
- **Scribe v2 Realtime som appen**: `stt-token`, Provlägets VAD, 16 kHz. Keyterms som appen skickar för provet: ämne, provets ord och `/study-profile`-termer, högst 20 termer på högst 20 kodpunkter.
- **`/answer` som elevens svar på Lumens kontrollfråga**: `mode: tutor`, `persona: tutor`, sist i `recent_qa` ligger frågan, `last_answer_age_sec` är 6.
- **"Rätt betyg"** betyder att svaret börjar med "Rätt" eller säger "Rätt i så fall".

**Efter (A62):**
- Svaret plus 4 alternativ först bland keyterms, som `quizKeyArrived` i `ListeningModel.swift` gör.
- `context.quiz_key` skickas tillbaka.
- Nya `/study-profile`-termer från K40.

**Kostnad:**
- **≈ 1,6 USD** i API: förmätning 0,76, eftermätning 0,77, plus O43b–e cirka 0,1. Provläge kör Sonnet, så det blir cirka 0,02 USD per svar.
- **367 ElevenLabs-tecken.**
- **≈ 480 Scribe-sekunder** ljudtid: förmätningen 151, eftermätningen 151, O43d cirka 175 (två hela körningar plus den avbrutna), röktestet 7. Omanslutningstestet skickade inget ljud.

**Rådata:**
- `reports/qa/data/2026-11-11-124741-o43-smoke.json`, `…-124957-o43-fore.json` och `…-131539-o43-efter.json`
- `…-125754-o43b-quizkey.json`
- `…-135247-o43d-babble.json` (den avbrutna `…-134247-…` sparad också) och `…-140528-o43d-noa62-babble.json`
- `…-141400-o43c-reconnect.json` och `…-141457-o43e-alt-right-form.json`

**Förbehåll om "före":**
- K40 driftsattes 12:52 (Deploy backend för `259f3f8`), tre minuter efter att förmätningen startat. Därför är bara de **4 första raderna** (g01 och g02, plus röktestet) helt före K40.
- Resten av förmätningen mäter **K40 på servern med appen utan A62**: inget `quiz_key`, och de gamla studieprofiltermerna (frysta 12:49). Det är läget på Arons telefon fram till nästa bygge.
- Scribe-delen ("hörde Scribe rätt ord") påverkas inte av K40 och gäller som förmätning för alla 80.

## Resultat
| | Före (K40-prompten utan A62, gamla termer) | **Efter (K40 + A62 + nya termer)** |
|---|---|---|
| **Tyst rum: rätt betyg** | 38/40 (2 "Nästan": "Säng" = Sän, "Loar") | **40/40** ✅ målet nått |
| Tyst rum: Scribe hörde rätt ord | 35/40 | 39/40 |
| **Klassrumsprat: rätt betyg** | 32/40 | 36/40, men **5/40 var listuppläsningar** (se BUGG). **34/35** på de vanliga fallen |
| Klassrumsprat: Scribe hörde rätt ord | 30/40 | 33/35 utan listuppläsningarna |
| Arons två fall | "Nilen" rätt i tyst rum. "Sän" hördes "Säng" och fick "Nästan" eller "Inte riktigt" | "Sän" hörs fortfarande "Säng", men K40 jämför ljud och ger **"Rätt"**. "Loar" hörs som "Loire" tack vare A62 och ger **"Rätt"** |
| Per prov, tyst | geografi 18/20, biologi 10/10, historia 10/10 | geografi 20/20, biologi 10/10, historia 10/10 |
| Per prov, sorl | geografi 13/20, biologi 10/10, historia 9/10 | geografi 16/20, biologi 10/10, historia 10/10 |

**Det som K40 och A62 löste:**
- **Hörfel som nu blir rätt:** "Femsen" och "Fem i sömnen" blir "Menade du Themsen? Rätt i så fall." (K40-prompten). "Mellans" blir "Menade du meios?". "Bajkarlsjön", "Hamurabi" och "Dunau" får "Rätt".
- **Sådant som Scribe nu hör rätt med svaret bland keyterms:** "Göta älv" blir Donau, "By Karlstjärn" blir Bajkalsjön, "När har du det?" blir Neapel och "Loar" blir Loire.
- **Gamla keyterms drog åt fel håll:** `/study-profile` gav **svenska** sjöar och floder (Vänern, Vättern, Klarälven …) till provet "de 50 mest kända sjöarna, floderna och kuststäderna". Därför blev "Nilen" i sorl "**Vänern**". De nya termerna har världens sjöar (Ladoga, Bajkalsjön, Viktoriasjön), men floderna (Nilen, Seine, Rhen …) ryms inte bland de 20. A62 löser det för den fråga som ställs.

## BUGG (prio 2): falskt "Rätt" när eleven är tyst i klassrumsprat
**Scribe läser upp keyterm-listan i ordning när det bara hörs sorl eller otydligt tal.** Exempel:
- "Rhen, Donau, Elbe, Main, Rhône, Geografi, de 50 mest kända, sjöarna, floderna, kuststäderna, Vättern, Vänern, …"
- "Kongo, Niger, Niger,"

Med A62 ligger **rätt svar först** i listan.

| O43d (`scripts/qa/o43d_false_right.py`), 20 geografifrågor i sorl | Med A62 | Utan A62 (kontroll) |
|---|---|---|
| **Eleven säger ingenting** | **2/20 falskt "Rätt"**: Scribe hörde "Viktoriasjön, Tanganyikasjön, Malawisjön, …" och Lumen sa "**Rätt**, Viktoriasjön är Afrikas största sjö". "Vänern, Vättern, Mälaren, …" gav "**Rätt**, Vänern är Sveriges största sjö" | 0/20 (2 listuppläsningar, men de börjar med Mälaren/Vänern, inte med facit) |
| **Eleven säger fel svar** (ett annat cachat klipp, till exempel "Vänern" på Nilen-frågan) | **0/20 falskt "Rätt"**. K40 godkänner inte fel svar | – |

Listuppläsningen kommer från Scribe, och syns 2/20 utan A62. A62:s ordning gör den till ett falskt "Rätt". I eftermätningen gav samma sak "Rätt" för g09 och b05, och "Inte riktigt" för g01 (listan började med alternativet "Kongo"). **Mönstret är bara mätt i sorl.** I tyst rum hände det 0/80.

**Rättning (förslag):**
- **Appen eller servern:** ett yttrande som till största delen är keyterms separerade med kommatecken (3 eller fler i rad, i samma ordning som de skickades) räknas som "inget hört". I svarsfönstret frågar Lumen då "Vad sa du?" i stället för att betygsätta.
- **K40 `gradeReply`:** om fragmentet innehåller rätt svar **och** två eller fler av alternativen, betygsätt inte. Säg "Jag hörde flera svar, vilket menar du?".
- **Alternativ:** lägg inte alternativen i keyterms, bara svaret, eller blanda ordningen. Det minskar inte uppläsningen, så de två första är viktigast.

## Mindre fynd
1. **`quiz_key` från servern** (O43b, 4 "förhör mig"): finns 4/4, och `[[SVAR]]` lästes aldrig upp. Men **alternativen innehåller ibland en form av rätt svar**: "Kloroplast" som fel alternativ till "Kloroplasten", "Celldelning" och "Mitos och cytokines" till "Mitos".
   - Offline ger `matchAnswer("kloroplast", …)` därför `alternative` (verified in code).
   - Live räddar modellen det ("Rätt."), och "celldelning" får "Nästan." (O43e).
   - **Till Kevin (prio 3):** ta bort alternativ med samma `svKey`-stam som svaret eller som innehåller svaret.
2. **Omanslutningen i A62** (O43c, 10 gånger från molnet): `stt-token` plus websocket plus `session_started` tar **median 1,5 s, som mest 2,1 s**, och nästan allt är `stt-token` (1,3 s). Själva anslutningen tar 0,17 s. Det ryms medan Lumen läser upp frågan, som tar 2–4 s. Ingen orsak att avstå. Mätt från molnet, inte från en telefon på 4G.
3. **Min betygsmall** missade "Rhen är rätt" och "Amazonas stämmer". Det är rätt i sak, och jag har graderat dem för hand ovan.

## Bedömning
- **Tyst rum: mål nått (40/40).**
- **Klassrumsprat: 34/35 på vanliga svar**, men **falskt "Rätt" när eleven är tyst (2/20)**. Det ska rättas innan A62 når elever i klassrum.

Märkning:
- Servern: **verified live** med syntetiskt tal och syntetiskt sorl.
- Appens del av A62: **verified in code** (`quizKeyArrived`, `applyQuizKeytermsNow`), inte på telefon.
- Riktig röst och riktigt klassrum: **untested assumption**.

## Till Aron
- Prova "Förhör mig" på ditt flodprov i kväll, i tyst rum. Både "Nilen" och "sän" ska nu få "Rätt".
- I ett stökigt rum kan Lumen säga "Rätt" fast du inte sagt något. Kevin och Angela har fått fyndet.

## Nästa
- Omtest av O43d (cirka 0,4 USD, 0 tecken) så fort listuppläsningen hanteras.
- Cachen ligger bara i den här molnsessionen. En ny session måste generera ljudet igen (367 tecken), eller köra där cachen finns.
