# T8b och A50-rundan – förstagångsanvändaren med nya Start (Toby, 2026-11-11 12:00)

**Simulatorn räknas aldrig som verifiering på enhet.** GitHub `macos-26`, iOS 26.5-simulatorn (iPhone 17 Pro, ljust
läge), raderad simulator och inga behörigheter i förväg. Frågorna spelas med svenskt `say`-tal via appens WAV-krok
("Vad är huvudstaden i Australien?" och "Hur många ben har en spindel?", i slinga med 20 s paus). Live Scribe och
`/answer`, med rösten en ny användare får (ElevenLabs). Inga AirPods.

Bygget är main med Angelas **A50** (0d2346e) och Kellys Ke29, på grenen `toby/t5b-t7b-t8b-2`.

**Körningar:**
- **Förstagångstestet, grön:** [43005031869](https://github.com/aronstenlund-code/aronstenlund-airpods-ai/actions/runs/43005031869).
  - Två tidigare försök var röda på grund av testfel som är rättade:
  - [42995531557](https://github.com/aronstenlund-code/aronstenlund-airpods-ai/actions/runs/42995531557): Lyssnar visar förra sessionens svar, och samma fråga besvaras inte igen. Testet räknar nu nya svar och spelar två frågor.
  - [43002061580](https://github.com/aronstenlund-code/aronstenlund-airpods-ai/actions/runs/43002061580): en etikett försvann medan testet läste den.
- **Skärmturen** (två lägen på egen gren: Pro ljust och mikrofonen nekad): [42995531873](https://github.com/aronstenlund-code/aronstenlund-airpods-ai/actions/runs/42995531873).
  - Den nattliga turen på main (03:30) tar alla sju lägen, också iPhone SE och största text.
- **Bilder och loggar:** `reports/apptest/2026-11-11-t8b-a50/`.
  - `t8b-*` är förstagångsanvändaren och `tur-*` är skärmturen.
  - `t8b-skip-app.log` är appens egen logg. Testet sparar den nu (`scripts/apptest/firstuser.sh`), med `private_data` påslaget i simulatorn.
- **Kostnad (D120):** tre körningar med vägen `skip`, cirka 3–4 korta svar per körning med ElevenLabs-rösten (43–150
  tecken per svar). Skärmturen använder Apples igenkänning och röst.

## Kort
- **A50 gör det A50 lovar.**
  - **Starta Lumen** är det första man ser under rubriken, utan att rulla.
  - Läget står under knappen ("Standardläge · Byt").
  - "Lumen kan allt" har tre exempel som byts.
  - Byt-arket har alla lägen och Sov.
  - "Få A-svar", "Bara fråga" och "Fler lägen" är borta från Start.
  - Med mikrofonen nekad ligger "Lumen hör dig inte" ovanför knappen.
  - Skärmturens alla A50-kontroller är gröna i båda lägena.
- **T8 fynd 1 är rättat:** "Lyssnar" syns **0,1 s** efter första frågeskärmen (var "Startar …" i 60 s).
- **Starta Lumen → Lyssnar på 2,5 s, och frågan besvaras** (live Scribe). Från Start till Provläge: Byt → Provläge →
  Starta Lumen, **3 tryck**. Sedan kommer samma 5 frågor som i T8 (5 tryck på "Hoppa över").
- **Nya fel**, se fynd 1–4 nedan. Det allvarligaste är fynd 1: en fråga som ställs en stund efter ett svar ställs
  aldrig, och när användaren trycker Avsluta sparas den som röstprofil och Lumen pratar efter att sessionen är slut.

## Siffror (sekunder från att appen öppnats; testet läser och trycker fortare än en människa)
| Steg | T8 (10 nov) | **T8b (i dag)** |
|---|---|---|
| Intro → "Fråga vad som helst" visar **Lyssnar** | aldrig ("Startar …") | **16,5 s, 2 tryck** (Testa nu, Tillåt) |
| Första svaret i Frågor | nåddes inte | **46 s**, 2,0 s från hörd fråga till första ljud |
| Efter första starten | Start | **Lyssnar** (sessionen fortsätter; Start syns först efter Avsluta) |
| Starta Lumen → Lyssnar | – | **2,5 s, 1 tryck** |
| Starta Lumen → svar | – | 33 s (frågan i slingan kom efter 30 s), 0,6 s från hörd fråga till ljud |
| Start → Provläge lyssnar | 6–7 tryck | **8 tryck**: Byt, Provläge, Starta Lumen och 5 × Hoppa över |
| Första svaret i Provläge | inget | **26 s** efter Lyssnar, 1,9 s från hörd fråga till ljud |
| Hela vägen, intro till svar i Provläge | – | 16 tryck, 18 skärmar, 215 s (med Starta Lumen-steget) |

Väntan på svaren styrs av slingan (frågan spelas 26 s efter att en session startat), inte av appen. Tiden från hörd
fråga till första ljud står i appens logg (`Turn timing`).

## Fynd till Angela
1. **En fråga en stund efter ett svar blir aldrig en tur. Vid Avsluta blir den en "röstprofil", och Lumen pratar
   efter att sessionen är slut.** Detta är appens logg från sessionen efter första starten (`t8b-skip-app.log`):
   - 10:52:01 öppnas mikrofonen (av säkerhetsspärren, se fynd 2).
   - Cirka 10:52:08 spelas "Hur många ben har en spindel?". Det kommer ingen `Activation` på 20 s.
   - 10:52:27,97 trycker testet Avsluta: `State Listening → Idle`.
   - 10:52:28,36 kommer `No final from Scribe 1.8 s after the last words: final asked for (A21)`. A21:s begäran om
     final gick alltså först vid Avsluta, 20 s efter orden.
   - 10:52:28,40 kommer `Profile by voice (phone): Hur, sparat.`
   - 10:52:29,67 läser ElevenLabs upp 12 tecken (`STT input gated (own speech)`), efter `Session deactivated`.
   - 10:52:32 kommer `Profile by voice (server): 37 terms`. Nästa session har keyterms som "Spinnkörtlar".
   - Detta stämmer med T5b fynd 1 (anropet kommer först när Scribe stänger), och visar varför: A21:s `commit()`
     verkar bara gå när lyssnandet stoppas. Den här sessionen hade dessutom `Local VAD not ready: all audio goes to
     Scribe`. **Untested assumption:** att A21:s regel kräver Silero, och därför aldrig slår till när VAD inte är redo.
   - Följderna för användaren:
     - en fråga utan svar;
     - en röstprofil som användaren aldrig sagt;
     - ett ord i örat efter Avsluta;
     - studieprofilens termer byts mot spindelord.
   - Förslag: en final som kommer vid Avsluta ska inte tolkas som kommando eller profil, och inget ska läsas upp
     efter att sessionen är slut.
2. **Säkerhetsspärren öppnar mikrofonen i stället för rösten,** även med ElevenLabs-rösten. Första svaret (1 mening)
   var uppläst cirka 10:51:57, men igenkänningen öppnades först 10:52:01,8: `no end of Lumen's speech after 10 s
   (playback speaking false, speaker speaking false)`. Samma fel som T5b fynd 2 med Apples röst: ingen av rösterna
   öppnar igenkänningen när de är klara. Det gav cirka 4 s extra dövhet efter första svaret (en andra
   mening, troligen tipset, lästes upp 10:51:57,6). Efter svaret i Starta Lumen-sessionen öppnade den som den ska, 3,6 s efter svaret.
   Felet syns alltså inte varje gång.
3. **Lyssnar visar förra sessionens frågor och svar,** också i ett annat läge.
   - Efter Starta Lumen står förstagångens "Fråga: Vad är huvudstaden i Australien? / Australiens huvudstad är
     Canberra." direkt (`t8b-09`).
   - Provläge visar Standardlägets två svar innan något har frågats (`t8b-17`).
   - En ny användare kan tro att Lumen redan svarat, eller att Provläge kommer ihåg en annan session.
   - Förslag: en ny session börjar tom, eller de gamla svaren visas nedtonade under en rubrik.
4. **Starta Lumen gör ingenting synligt när igenkänningen inte startar.**
   - I skärmturen (Apples igenkänning, som inte startar i simulatorn) blev Start kvar efter trycket i Standardläge:
     ingen Lyssnar och inget kort (`tur-pro-light-50-fragor-startade-inte.jpg`).
   - Samma tryck i Provläge öppnade Lyssnar (`tur-pro-light-56`).
   - Det är samma fel som "Bara fråga" i går (`startMode` → `switchMode`).
   - På en telefon startar Apples igenkänning, så felet syns troligen bara när starten misslyckas. **Untested
     assumption.** Även då ska trycket visa något, till exempel A45-raden eller "Startar …".
5. **Efter första starten hamnar användaren i Lyssnar, inte på nya Start** (`t8b-07`). Delningsfrågan kommer ovanpå
   Lyssnar (T8 fynd 7, kvar). Den nya Start-skärmen syns alltså först när användaren själv trycker Avsluta eller
   bakåt. Det kan vara rätt (Lumen lyssnar redan). Men "begriplig på 5 sekunder" (dagens mål 1) prövas då inte för
   förstagångsanvändaren förrän andra gången appen öppnas. Beslut till Deangelo och Kelly.
6. **Provläge frågar fortfarande 5 saker** (när, årskurs, ämne, kontrollfrågor, förklaringslängd) när man väljer
   det första gången (T8 fynd 5, kvar). Med "Starta Lumen" i Provläge blir det 8 tryck till Lyssnar.
7. **Tillgänglighet:** under Starta Lumen finns, utöver "Läge: Standardläge. Byt läge", en knapp till med etiketten
   "Standardläge, ·, Byt" (`t8b-skip-log.txt`, skärm 08). VoiceOver kan läsa raden två gånger och säga "punkt".
   **Untested assumption** för VoiceOver. Det syns i UI-testets träd.

## Till Kelly
- Bilderna `t8b-08`, `tur-pro-light-11/12/16` (Start med och utan prov), `t8b-11` (Byt-arket) och
  `tur-nekad-50-starta-lumen.jpg` (mikrofonen nekad) är A50 i simulatorn, för granskning mot Ke29.
- Fynd 3, 5 och 6 är design.

## Till Aron
- Prova i kväll: öppna appen efter installationen, tryck Testa nu och Tillåt, ställ en fråga och tryck Fortsätt. Hamnar du på Start eller i Lyssnar?
- Ställ sedan en fråga till 10 s efter första svaret. Svarar Lumen inom 3 s? Om inte, är det fynd 1.

## Ändrat i testerna (bara mina mappar)
- `AppTests/E2E/Screens/ScreenTourTests.swift`:
  - `a50Start()` kontrollerar Starta Lumen, lägesraden, "Lumen kan allt" och att de gamla knapparna är borta, och fotograferar Byt-arket.
  - Lägena öppnas via lägesraden + Starta Lumen, och de gamla vägarna finns kvar för äldre byggen.
- `AppTests/E2E/Screens/FirstUserTests.swift`: steget Starta Lumen (Lyssnar inom 15 s och ett nytt svar inom 90 s), Provläge via Byt. Ett svar räknas bara om det är nytt.
- `scripts/apptest/firstuser.sh`: två frågor i slingan, och appens logg sparas.

## Concerns
- Fynd 1 gör att en fråga kan sparas som "röstprofil" utan att användaren vet om det. Profilen skickas till
  `/study-profile`. Det är inte dolt användande, men det är data om användaren som sparas utan avsikt.
- A49 Sömnläge: se `reports/apptest/2026-11-11-1045-toby-t5b-t7b.md` (ljud sparas i 30 dagar, och andra i rummet
  hörs).

## Kvar
- T8b med vägen `exam`, och skärmturen i alla sju lägen: den nattliga körningen på main tar turen. `exam` körs inte,
  för att spara krediter (D120).
- Kör om förstagångstestet när Angela har rättat fynd 1–4.
