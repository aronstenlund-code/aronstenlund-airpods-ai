# T56: webbetan i WebKit och Chrome (lokalt och live), med A158

Toby (moln), 2026-11-21 12:00–15:10. Uppdrag från Deangelo 11:58 (T56, D249), och Angelas A156 del 1 (rad i min kö 11:52). **0 ElevenLabs.** Bara Linux-maskiner i GitHub Actions (ubuntu-latest), ingen macOS (D217). **Webbläsarmotorer i CI, inte en iPhone.** Playwright WebKit räknas inte som Safari på en iPhone, och ingenting här är provat med AirPods.

## Vad som finns
- **`scripts/apptest/t56/beta.mjs`** (Playwright 1.63.0, DECISIONS "T56"):
  - Flödet: första skärmen med skärmraden (10 m, D250) → Säg (text, kostnad, röstbladet) → Spela → mening för mening → paus och fortsätt → Stoppa → Senaste → Prov från text (Ser det rätt ut → Starta prov → fråga 1 → kort svar → fråga 2 → paus → Avsluta) → Krediter (inga köp på webben) → Inställningar › Svenska. Därefter en svensk webbläsare (D251) och 320 punkters bredd.
  - Motorerna: **WebKit 26.6 som iPhone 15** och **Chromium 153 som Pixel 7**.
  - Lokalt används `site/` mot en låtsasserver med tyst ljud, byggd på Angelas `web/scripts/smoke.mjs`. Ingenting lämnar maskinen, och det kontrolleras.
  - **Live** (`--live`) används den publicerade sidan och den riktiga servern.
- **`.github/workflows/apptest-t56.yml`** (för hand: `live` true/false, `url`): en matris med webkit och chromium. Bilderna läggs i artefakten `apptest-t56-<motor>`.
- **Wake Lock**: ett init-skript räknar sidans egna `navigator.wakeLock.request` utan att ändra svaret. Testet kontrollerar att Spela begär låset och att raden "The screen stays on while it plays." syns. Om motorn saknar Wake Lock ska skärmraden synas i stället.

## D180 i live-körningen (0 ElevenLabs)
- Servern räknar varje anrop från GitHub Actions IP-intervall som testtrafik: falskt ljud, och en vakt stoppar ett testanrop före ElevenLabs-klienten. **Verifierat i koden** (`backend/supabase/functions/_shared/testmode.ts`, `detectTest`, med en reservtabell `ci_ranges`).
- Dessutom skickar live-körningen telefonens egen user agent med "Playwright/1.63" på slutet. Serverns `SCRIPT_UA` läser det som ett skript, så trafiken är test även om IP-listan skulle vara tom.
- Skriptet stoppar varje anrop till en ElevenLabs-värd (även röstprov). **Verifierat i CI:** 0 sådana anrop. Sidan frågade bara `earmind.vercel.app` och `xjczbzfkmbjdebwlccki.supabase.co`.
- Skriptet vägrar `--live` utanför GitHub Actions.
- Sidan öppnas live utan `?test`. `x-earmind-test` är ännu inte tillåten i CORS (A156 §4.1, Kevins kö), så med den rubriken skulle webbläsaren få nej redan i förfrågan före anropet.

## Resultat
| Körning | WebKit lokalt | Chromium lokalt | WebKit live | Chromium live |
|---|---|---|---|---|
| 44916238141 | 37/37 | 37/37 | röd: stannade efter skärmraden | 27/28 (ljudklockan efter 0,8 s) |
| 44916619787 | 37/37 | 37/37 | röd: ingen kostnad visades | röd: ingen kostnad visades |
| **44917033998** | **37/37** | **37/37** | **29/29** | **29/29** |

Rött i de två första körningarna var **testfel**:
- **Samma text två gånger.** Servern säger 0 krediter för en text den redan har gjort ljud till (även från ett annat konto), och sidan visar då "Free. The sound already exists." utan `data-testid=cost`. Live-texterna har nu ett ord som är unikt för varje körning. Den första körningens Chromium betalade 103 krediter, och alla senare med samma text var gratis.
- **Ljudklockan.** Den fick 0,8 s på sig, vilket är för kort över nätet. Nu får den 5 s.

**Verifierat i CI (live, riktiga servern, falskt ljud) i båda motorerna:**
- Engelska som standard och "1.5k credits left".
- Skärmraden med 10 m (33 ft) och den svenska med 10 meter.
- Serverns kostnad, 122 krediter (en ny text).
- Röstbladet med 19 röster.
- Spela: "Playing in AirPods". Ljudet spelar på sidans enda `<audio>`-element (serverns signerade mp3 från `drill_audio`), och klockan går.
- **Spela begär Wake Lock** (1 begäran, granted), och raden "The screen stays on while it plays." syns.
- Media Session visar EarMind och playing.
- Nästa mening visas när den läses. Paus, fortsätt och Stoppa fungerar, och texten hamnar under Senaste.
- Krediter visar talet (1 378 efter Säg) och "Purchases come with the iOS app.".
- Inställningar › Svenska ger svensk sida, och en svensk webbläsare ger "1,5k krediter kvar".
- 320 punkter bred sida utan sidled, och inga skriptfel.

**Prov från text live:**
- Servern säger 402 före genereringen: "An exam with 12 questions costs about 7 704 credits. You have 1 378 left, not enough for an exam (at least 3 questions). New credits on 1 December."
- Sidan visar serverns ord och "Purchases come with the iOS app." utan köp. Det är rätt beteende.
- Provspelaren går därför inte att nå live med ett nytt webbkonto. Den är grön lokalt i båda motorerna: Starta prov, 2 tryck kort svar, nästa fråga, 3 tryck paus, Avsluta och "Continue · question 2".

## Fynd
1. **Ett nytt webbkonto kan inte göra något prov från text** (verifierat live, båda motorerna). 1 500 krediter räcker inte till tre frågor. Det är Angelas produktfråga i A156 §4.2 till Deangelo och Aron, nu sett mot riktiga servern. Inget fel i webbkoden.
2. **"Free. The sound already exists."** visas för en text som **ett annat konto** redan har gjort ljud till. Servern återanvänder ljudet över konton. Det är troligen avsiktligt (ljudcachen), men värt att veta för Kevin och Deangelo: ett nytt konto ser "gratis" för en känd text. Untested assumption att det är avsiktligt.
3. I WebKit gav den första hämtningen av den signerade ljudfilen status 0, och nästa gav 200. Ljudet spelade ändå. Det är troligen ett avbrutet intervallanrop när elementet byter källa. Ofarligt i körningen, men inte sett på en iPhone.

## Inte testat
- Safari på en riktig iPhone: autoplay i trycket, Wake Lock-reglerna i iOS, skärmlås och låsskärmen.
- AirPods-trycken via Media Session.
- `?test=…` från en riktig webbläsare, som väntar på Kevins CORS-rad.
- Lyssnarlägena (A156 del 2) och A158 (Ladda ner ljudet).
- Bilderna i artefakten har jag inte sett, för proxyn nekar blob-värden.

## Nästa
- Kör `apptest-t56.yml` igen när A158 eller del 2 är ute. Raderna för Ladda ner ljudet och lyssnarlägena läggs till då.
- Om Deangelo vill: lägg T56 (lokalt och live) i nattflödet T31. Det tar cirka 2 min per motor på Linux.

## Tillägg 15:25: A158 (D253) live
Angelas A158 är publicerad (EN | SV syns live). Testet följer den nu:
- Betan startar alltid på engelska, och EN | SV finns överst (`lang-en`/`lang-sv`, `aria-pressed`).
- Valet finns kvar efter omladdning, och det man skrivit följer med vid bytet.
- Gratisraden heter `cost-free`.
- Ladda ner ljudet: `download` → `download-save`. Filen hämtas med `fetch(href)`, och därefter sparar webbläsaren den (Playwrights `download`-händelse).

| Körning | WebKit lokalt | Chromium lokalt | WebKit live | Chromium live |
|---|---|---|---|---|
| 44918272697 | 43/44 | 44/44 | 35/36 | 36/36 |
| **44918589255** | **44/44** | **44/44** | **36/36** | **36/36** |

Röd i 44918272697 var bara testet: Playwrights WebKit föreslår filnamnet med `_` i stället för mellanslag (`EarMind_-_Photosynthesis_….mp3`), medan sidans `download`-attribut har mellanslag. Nu jämförs namnet utan det.

**Verifierat i CI live, båda motorerna:**
- **Ladda ner ljudet fungerar mot riktiga lagringen.** De signerade länkarna hämtas utan CORS-fel, och felraden "couldn't be downloaded" syns inte.
- Filen är **en äkta MP3**: den börjar med en MP3-ram eller ID3, är 40 866 byte stor och heter "EarMind - Photosynthesis ….mp3".
- WebKit och Chromium sparar den med samma antal byte.
- Inga krediter dras för nedladdningen (krediterna efter är samma som efter Spela).

**Inte verifierat:** att Safari på en iPhone sparar till Filer, och att filen spelar med skärmen av.

Två ofarliga rader i WebKit-loggen:
- Den första hämtningen av den signerade mp3:n får status 0, och nästa får 200. Det är troligen ett avbrutet intervallanrop när `<audio>` byter källa.
- `voices` avbryts ("Load request cancelled") när språket byts mitt i en hämtning, och hämtas sedan igen.

## Tillägg 17:10: lyssnarläget (A156 del 2)
T56 har nu körningen `listen`:
- Ordning: More modes → `listen-start` → samtyckesbladet före mikrofonen (D21, nämner ElevenLabs) → `consent-accept` → raden Listening med Stop och skärmraden → testmeningen → svaret på skärmen och uppläst → Listening igen → Stop.
- Andra gången kommer inget samtyckesblad. Spela stoppar lyssnandet. Samtycket tas tillbaka i Inställningar, och därefter kommer bladet igen.
- Chromium har en låtsasmikrofon (`--use-fake-device-for-media-stream --use-fake-ui-for-media-stream`). WebKit får tillstånd till mikrofonen via Playwright.

**D180 i lyssnarläget:**
- Servern ger testtrafik ingen Scribe-token. Det är verifierat i koden: `stt-token/index.ts`, "D180: test accounts never use ElevenLabs", och en vakt kastar om ett testanrop kommer längre.
- Testet läser varje svar från `stt-token` och kräver `fake: true` utan token och utan sockeladress. Annars stoppas lyssnandet direkt och körningen blir röd.
- WebSockets till ElevenLabs stoppas i webbläsaren (`routeWebSocket`).

**Körning 44922296899:**
- **Lokalt:** WebKit 58/58 och Chromium 58/58. **Mikrofonen fungerar i Playwrights WebKit** när tillståndet ges, vilket Angela inte kunde prova. Båda svaren från `stt-token` var fake utan token.
- **Live:** allt utom lyssnandet är grönt, och nedladdningen gav en äkta MP3 i båda motorerna. Den publicerade betan har inget lyssnarkort än, eftersom del 2 inte är publicerad, så live-lyssningen är inte provad. Testet skriver det nu som en anteckning i stället för rött, och provar lyssnandet live när kortet finns.

**Inte provat:** lyssnarläget live mot riktiga `/answer` (väntar på Kellys publicering), och en riktig mikrofon i Safari på en iPhone.

## Tillägg 18:00: lyssnarläget live
Del 2 är publicerad.

| Körning | WebKit lokalt | Chromium lokalt | WebKit live | Chromium live |
|---|---|---|---|---|
| 44925741392 | 58/58 | 62/62 | 46/49 | 47/48 |
| 44926222713 | 61/62 | 62/62 | 47/48 | 47/48 |
| **44926672159** | **58/58** | **62/62** | **49/49** | **49/49** |

**Verifierat live i båda motorerna (0 ElevenLabs):**
- Samtycket kommer före mikrofonen.
- `stt-token` svarar `fake: true`, utan token och utan sockeladress, varje gång.
- Raden Listening syns med Stop och skärmraden.
- Serverns testmening går till riktiga `/answer`.
- Stop fungerar. Andra gången kommer inget samtyckesblad. Spela stoppar lyssnandet, och samtycket kan tas tillbaka i Inställningar.

**Fynd (till Kevin, kevin.md, låg):** testmeningen "Det här är en testtranskription." är inte en fråga. `/answer` svarar då rätt nog `is_question:false` och `answered:false`. Svaret, uppläsningen och "lyssnar igen" går därför inte att nå live, bara mot låtsasservern, där de är gröna i båda motorerna. Live kontrollerar testet nu det man kan kontrollera: att påståendet inte besvaras och att sidan lyssnar vidare utan fel. Förslaget till Kevin är en testmening som är en fråga, eller en variant som testaren väljer.

**30-minutersgränsen** (Angela 17:40): körningen `listen-30` flyttar sidans klocka 30 minuter fram med Playwright. Passet slutar då och säger "Listening stopped after 30 minutes. Start again to go on.", och det är grönt i Chromium. I WebKit startar lyssnandet aldrig med Playwrights låtsasklocka. Det är en begränsning i verktyget, så kontrollen körs bara i Chromium.

**Testfel på vägen:**
- Live väntade testet på ett svar som servern rätt nog inte gav.
- `listen-30` i WebKit, se ovan.
- En 429 från serverns webbgräns (många CI-körningar från samma IP) är nu en anteckning och inget appfel.

**Inte provat:** en fråga live genom hela kedjan (väntar på Kevin), och en riktig mikrofon och AirPods i Safari på en iPhone.
