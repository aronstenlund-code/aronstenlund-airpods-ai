# Demosidan redo för publicering, Kelly Kapoor

Underlag: Oscars godkännande (`reports/qa/2026-11-07-1830-oscar-demo-d72.md`) och Kevins tak-texter (`reports/2026-11-07-2100-kevin-d77-interview-demo-caps.md`, rad 118–120).

## Gjort
1. **Integritetstext:** kontaktadressen `stenlundaron@gmail.com` finns som mejllänk i väntelistans text, för borttagning och frågor om uppgifterna. Ingen ansvarig namnges, enligt Arons beslut.
2. **Serverns text vid alla demotak:** `demo_limit_*` visas med serverns egen text från `/answer`, `/stt-token` och `/tts`.
   - **Rösttaket (`/stt-token`):** texten visas under skivan och lyssnandet slutar. Senare tryck visar texten direkt utan nytt anrop. Textrutan fungerar som vanligt. Safari-igenkänningen tar inte över, eftersom serverns text säger "Skriv frågan i stället".
   - **Uppläsningstaket (`/tts`):** texten visas under svaret och inget mer läses upp i dag. Inga fler `/tts`-anrop görs, och Apples röst tar inte över, eftersom texten säger att svaren visas som text. Andra `/tts`-fel använder Apples röst som förut.
   - Fixat på köpet: att släppa knappen direkt kunde stänga ljudkontexten två gånger (ohanterat fel i konsolen).
3. **Pages-arbetsflöde:** `.github/workflows/pages.yml`.
   - **`check`** körs alltid. Det kontrollerar att `index.html` finns, att `APP_NAME` står överst, att alla lokala filer som sidan pekar på finns, att inga absoluta sökvägar finns (de går sönder under `/aronstenlund-airpods-ai/`), att inga hemligheter finns och att mappen är under 2 MB. Sedan frågar det GitHubs API om Pages är på med källan "GitHub Actions".
   - **`deploy`** körs bara om Pages är på: `configure-pages`, `upload-pages-artifact` (mappen `site/`) och `deploy-pages`.
   - Körs vid push till `main` som rör `site/**` eller arbetsflödet, och manuellt.
   - Medan Pages är av blir körningen grön och skriver i sammanfattningen att inget publicerades.
4. **iOS-bygget hoppas över** för ändringar i `site/**` och `pages.yml` (`paths-ignore` i `ios-build.yml`), så att sidan inte startar macOS-bygget.

| Uppläsningstaket | Rösttaket |
|---|---|
| ![](assets/2026-11-08-kelly-demo-publish/tts-tak-morkt.jpg) | ![](assets/2026-11-08-kelly-demo-publish/stt-tak.jpg) |

## GDPR
GDPR artikel 13.1 a kräver normalt att den som samlar in personuppgifter anger den personuppgiftsansvariges identitet och kontaktuppgifter. Sidan anger bara en kontaktadress, inget namn, enligt Arons beslut 2026-11-08. Det är dokumenterat här som en känd avvikelse, inte som en juridisk bedömning (**untested assumption**: ingen jurist har läst texten).

## Aron: slå på GitHub Pages
1. Öppna https://github.com/aronstenlund-code/aronstenlund-airpods-ai/settings/pages (repot > **Settings** > **Pages** i vänstermenyn, under "Code and automation").
2. Under **Build and deployment** > **Source**: välj **GitHub Actions**. Inget mer behöver sparas, och välj inte "Deploy from a branch".
3. Öppna https://github.com/aronstenlund-code/aronstenlund-airpods-ai/actions/workflows/pages.yml och klicka **Run workflow** > **Run workflow** (grenen `main`). Det behövs bara den här första gången, eftersom tidigare körningar hoppade över publiceringen. Därefter publiceras sidan av sig själv vid varje ändring i `site/`.
4. Vänta tills körningen är grön (cirka en minut). Sidan finns då på:

**https://aronstenlund-code.github.io/aronstenlund-airpods-ai/**

Adressen är redan tillåten i backendens CORS, enligt Oscars test.

## Testresultat
| Vad | Resultat | Status |
|---|---|---|
| Uppläsningstaket (429 `demo_limit_visitor` från `/tts`) | Serverns text under svaret, ingen Apple-röst, inga fler `/tts`-anrop | mockat, Chromium |
| Annat `/tts`-fel (500) | Apples röst tar över, ingen tak-text | mockat, Chromium |
| Rösttaket (429 från `/stt-token`) medan man håller in | Serverns text, lyssnandet slutar, andra trycket gör inget anrop | mockat, Chromium |
| Rösttaket när man släpper efter 0, 150 och 300 ms | Serverns text, inga JS-fel | mockat, Chromium |
| Integritetstext | Adressen visas, `mailto:`-länken fungerar | **verified, Chromium** |
| `check`-steget lokalt (bash) på riktiga `site/` | Godkänt, 76 kB | **verified** |
| `check`-steget med saknad fil, absolut sökväg och inplanterad `sb_secret_` | Stoppar med fel för var och en | **verified** |
| YAML för `pages.yml` och `ios-build.yml` | Kan läsas | **verified** (js-yaml) |
| Arbetsflödet på GitHub med Pages av | Se "Körning på GitHub" | se nedan |
| `deploy`-jobbet | Kan inte köras förrän Pages är på | **untested assumption** |

Ingen riktig iPhone, Safari eller AirPods har använts. Riktiga tak-texter från servern har inte visats i sidan; Oscar och Kevin har verifierat texterna mot servern.

## Körning på GitHub
Fylls i nedan efter pushen.

## Kända begränsningar och risker
- `deploy`-jobbet är otestat tills Pages slås på. Om det fallerar visar körningen felet, och sidan kan publiceras igen med **Run workflow**.
- GitHub Pages har ingen egen åtkomstkontroll. Sidan blir offentlig och sökbar direkt.
- Oscars punkt 1 kvarstår för Aron: demotaken gäller bara anrop som skickar `source:"demo"`. Utgiftstak hos Anthropic och ElevenLabs är skyddet mot den som anropar backend direkt.
- Oscars provrader (`oscar-qa-…`) ligger kvar i väntelistan.

## Nästa session
1. Aron: punkterna under "slå på GitHub Pages".
2. Oscar eller Kelly: testa den riktiga adressen i Safari på iPhone och i Chrome: en fråga, uppläsning, håll in, väntelista.
3. Kevin: radera Oscars provrader i väntelistan.
