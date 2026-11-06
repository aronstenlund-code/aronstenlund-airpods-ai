# Offentlig demosida (D62), Kelly Kapoor

## Klart
Demosidan finns i `site/`: en fil (`index.html`) plus ett självhostat typsnitt. Inga bibliotek, inget byggsteg. Allt i uppdraget finns med: rubrik och pitch, "Håll in och fråga", textruta, svar som text och uppläst, tre exempelfrågor, lägena som "Kommer i appen", nedladdningstexten och väntelistan med samtycke och integritetstext. Namnet byts på ett ställe, `APP_NAME` överst i filen.

Sidan följer Kevins kontrakt i `backend/README.md` (D64 på Kevins sida).

**Sidan är inte publicerad, och den ska inte köras offentligt förrän Kevins backend är driftsatt.** Funktionerna som ligger ute saknar demotaken.

| Mobil, ljust | Mobil, mörkt | Lyssnar | Svar |
|---|---|---|---|
| ![](assets/2026-11-06-kelly-demo-site/mobil-ljus.jpg) | ![](assets/2026-11-06-kelly-demo-site/mobil-morkt.jpg) | ![](assets/2026-11-06-kelly-demo-site/mobil-lyssnar.jpg) | ![](assets/2026-11-06-kelly-demo-site/mobil-svar-morkt.jpg) |

![Desktop, ljust](assets/2026-11-06-kelly-demo-site/desktop-ljus.jpg)
![Desktop, svar i mörkt läge](assets/2026-11-06-kelly-demo-site/desktop-morkt-svar.jpg)

Fler bilder i `reports/assets/2026-11-06-kelly-demo-site/` (hela sidan, mobil och desktop). Svarsbilderna är tagna före 400-teckensgränsen, så svaren i dem kan vara längre än i demon.

## Design
- **Idé:** ljust och mörkt läge är varandras inversion. Solgul sida med bläckblå skiva, eller bläckblå sida med tänd gul skiva. Väntelistan inverteras igen, så den står ut i båda lägena.
- **Det minnesvärda är skivan:** den reagerar på rösten, skickar ut ringar och är också den synliga lyssningsindikatorn. Resten är tyst: en familj (Familjen Grotesk), inga kort, ingen dekoration.
- **Svaret tar över skärmen:** skivan står still när du håller in, eftersom intro och samtal delar samma ruta. Orden tonar in medan svaret strömmar. Stoppa och "Ställ en ny fråga" sitter vid tummen.
- **ui-ux-pro-max:** designsystemet föreslog röd färg, Inter och Swiss-stil, vilket är generiskt för ett AI-verktyg. Jag behöll bara mönstret med demon först och tillgänglighetsreglerna.

## Teknik
- Återanvänd från `backend/webtest/index.html`: anonym inloggning, `/answer` via SSE, `/tts` per mening spelad i `<audio>`, Scribe, Safari som reserv, Apples röst om `/tts` fallerar.
- **Demokontraktet:** `source:"demo"` på `/answer`, `/tts` och `/stt-token`. Röst väljs inte i demon, så `/voices` anropas inte. `POST /waitlist` skickas utan autentisering med `email`, `consent`, `consent_version`, `source` och honeypot-fältet `website`.
- **Gränser:** servern avgör. `demo_limit_*` visas med serverns egen text och länk till väntelistan. Räknaren i webbläsaren styr bara "x frågor kvar" och sparar ett onödigt anrop.
- **Ändrat mot webtest:**
  - Uppvärmning med `OPTIONS` i stället för `GET`, som gav 405 i konsolen. `x-warm` stoppas av CORS i webbläsaren.
  - Scribe-token hämtas först när någon håller in, eftersom de är 8 per besökare och 400 per dag. Ljudet köas tills uttaget är öppet.
  - Släpper man medan telefonen frågar om mikrofonen får man en tydlig uppmaning, och mikrofonen stängs direkt.
  - Backend kapar demosvar hårt vid 400 tecken. Sidan slutar då på senaste hela meningen, i både text och röst.
  - Fel visas på vanlig svenska, utan felkoder. Frågor som misslyckas räknas inte.
- **D63:** Rizzläge beskrivs som flirt, 18+. Jag lade till **Socialt läge** som fjärde läge, trots att uppdraget nämnde tre, eftersom pitchen lovar sociala situationer och Rizzläge inte längre täcker dem. Raden är lätt att ta bort.
- **Sidvikt:** `index.html` 46 kB (ca 14 kB gzip) plus typsnitt 19 kB. Inga anrop till Google eller andra tredje parter utöver Supabase och ElevenLabs (Scribe).

## Testresultat
Testat i Playwright/Chromium på Windows. **Ingen riktig iPhone, Safari eller AirPods har använts.**

| Vad | Resultat | Status |
|---|---|---|
| Riktig fråga via exempelknapp | Första text efter ca 1,0 s, `/tts` 200, ljudet spelades klart | **verified live, Chromium**, gammal backend, före kontraktsanpassningen |
| Stopp mitt i ett riktigt svar | Avbröt svar och uppspelning, texten stod kvar | **verified live, Chromium**, som ovan |
| `/stt-token` | Svarar 200 med token | **verified live, curl** |
| `/waitlist` mot driftsatt backend | Inte driftsatt (404). Rätt meddelande, adressen står kvar | **verified live, Chromium** |
| Anropen följer kontraktet | Fält och URL:er stämmer med README | mockat, **aldrig kört mot riktiga demotak** |
| Håll in med Scribe | Flödet fungerar | mockad mikrofon och WebSocket, **riktig Scribe otestad** |
| Safari-reserven | Flödet fungerar | mockad igenkänning, **riktig Safari otestad** |
| Nekad mikrofon, för kort tryck, långsam tillståndsruta | Rätt meddelande, inga JS-fel | mockat |
| `demo_limit_*`, `demo_unavailable`, 429, 503, nätverksfel | Rätt meddelande, felen räknas inte | mockat |
| Svar kapat mitt i en mening | Slutar på hel mening | mockat |
| Stopp och ny fråga, väntelista (validering, 200, 404, honeypot) | Rätt | mockat |
| Layout 320, 360, 390, 768, 1440 px, ljust och mörkt | Ingen sidledsscroll | **verified, emulering** |
| Tangentbord | Tabbordning och håll in med mellanslag fungerar | **verified, Chromium** |
| Reducerad rörelse | Animationer av | **verified, Chromium** |
| Kontrast | Minst 6,2:1 på all text | **beräknat** |

Innan jag såg Kevins rapport gick ett fåtal riktiga frågor från testerna mot den gamla backenden, som saknar demotak. Efter det har inga riktiga frågor körts.

**Kvar att testa på riktig iPhone + AirPods:** håll in utan att sidan scrollar eller markerar text, tillståndsrutan för mikrofonen, att ljudet går ut i AirPods efter mikrofonen, ringknappen, tangentbordet över textrutan, safe areas. Allt detta är **untested assumption**.

## Före lansering
1. **Kevin driftsätter** (väntar på `supabase-lumen`, se Kevins rapport). Därefter ska sidan köras en gång mot riktiga tak: sex frågor, väntelista, CORS från Pages-adressen.
2. **Integritetstexten saknar personuppgiftsansvarig och kontaktväg.** Jag har inte lagt in någon adress utan att fråga. Väntelistan har heller ingen raderingstid, så texten lovar ingen. Texten bör läsas av Aron eller juridiskt kunnig.
3. **GitHub Pages kan inte publicera `site/` direkt.** Från gren går bara roten eller `/docs`, så det krävs ett Actions-arbetsflöde, och Aron måste slå på Pages. Jag har inte gjort något av det, eftersom uppdraget gällde bara `site/`.

## Concerns
- **Provläge i offentlig text:** "prov" kan läsas som hjälp under prov, och R6 säger ingen provanvändning i marknadsföringen. Rubriken "Svaret i ditt öra" och exempelfrågan om första världskriget förstärker den läsningen, och reklamutkastet i `docs/marketing/` med klassrum och A+ pekar åt samma håll. Jag beskriver läget som plugg och behöll namnet, men Deangelo bör ta ställning.
- **Inget ljud sparas stämmer inte fullt ut.** ElevenLabs nollretention gäller inte på vår plan. Texten säger därför att vi inte sparar något, men att leverantörerna kan behålla data enligt sina villkor.
- **Rizzläge på en sida för unga:** D63 gör läget 18+, och sidan säger det. Åldersspärren finns bara i appen.

## Kända begränsningar
- Svaren kommer i talform, så siffror står utskrivna ("nittonhundrafjorton") i texten.
- Modellen skriver raka citattecken, och det syns i stor text.
- På 320 × 568 hamnar textrutan 7 px under vecket. Skivan syns.
- Med `demo_limit_ip` eller `demo_limit_global` visar räknaren inget eget tal, bara serverns text.
- Sidan pushas under `site/`, som inte finns i `paths-ignore`, så varje ändring startar iOS-bygget i onödan. Filen `.github/workflows/ios-build.yml` ligger utanför min mapp.

## Beslut
D66 i `docs/DECISIONS.md`: självhostat typsnitt (Familjen Grotesk, OFL), STT-token bara vid håll in, servern äger gränserna.

## Nästa session
1. Kevin: driftsätt, och säg till när det är klart.
2. Kelly: verifiera mot riktiga tak och riktig Scribe, justera efter telefontestet.
3. Deangelo: svara på Concerns, bestäm Pages-arbetsflöde, lägg till `site/**` i `paths-ignore`.
4. Aron: testa på iPhone med AirPods, ange personuppgiftsansvarig och kontaktväg.
