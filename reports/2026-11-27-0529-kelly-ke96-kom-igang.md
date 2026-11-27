# Ke96: Kom igång-guiden /start (Kelly (moln))

## Gjort
- **`earmind.vercel.app/start`** (engelska) och **`/sv/start`** (svenska) har fem steg med en skärmbild per steg ur bildflödet (grenen `kelly/screens-ke96`, körning 45938725946, main `0c2dc075`, iPhone 17 Pro Max):
  1. **Installera och öppna** (`fsWelcome`). Sidan säger ärligt att iPhone-appen kommer snart till App Store; ingen länk.
  2. **Koppla dina AirPods** (`repControls`, Styr med dina AirPods, 1, 2 och 3 tryck, utan AirPods i högtalaren).
  3. **Ställ din första fråga** (`firstListening`, samtycket "I understand, start EarMind", "● Listening", "Later" för den som bara vill plugga med prov).
  4. **Välj dina aktiveringsord** (`listeningActivation`, Arons mening, "Help me" / "Hjälp mig").
  5. **Spela in själv – helt gratis** (`repOwnDeck`).

  Knappnamnen är kontrollerade mot appens String Catalog. Inget om låst skärm (D209).
- Sidorna genereras av `scripts/site/start-page.py`, med samma stil som sajten och `/support`. Bilderna ligger i `site/img/start/`, 600 px breda i webp.
- **Länkar:**
  - från startsidan: "Step by step: Get started" under How it works, och "Get started · Help and support" längst ner;
  - på svenska: "Kom igång" på samma ställen;
  - från `/support`: "New to EarMind? Get started in five steps".
- Båda sidorna i sitemap och `pages.yml`. kelly-site-check provar nu också `/start` och `/sv/start`.
- En liten rad till Fable: första raden på Styr med dina AirPods börjar med liten bokstav.

## Test (393 px och mörkt läge, punkt 3)
**Lokalt, Chromium:** alla sju sidor (`/`, `/sv`, `/support`, `/sv/support`, `/start`, `/sv/start`, `/beta`) svarar 200. Ingen har vågrät rullning vid 393 px, i ljust eller mörkt läge, och inte heller vid 1280 px. Inga trasiga bilder. Mörkt läge är sett på bild för `/start`, `/sv/start`, `/` och `/sv/support`.

**Live** (kelly-site-check 45942350917, 04:51 UTC, efter Vercels bygge från main):
- `/start` svarar 200 med 9 793 byte och `/sv/start` 200 med 9 768 byte;
- `/support` och `/sv/support` svarar 200;
- `/` svarar 200 med 42 464 byte, med länkarna;
- `/sv` och `/beta` svarar 200.

Alla sju har 0 platshållare och ingen vågrät rullning vid 393 px. Storlekarna är samma som lokalt. **Verifierat i Actions.** Mörkt läge är bara provat lokalt, eftersom live-kontrollen inte tar bilder.

0 ElevenLabs. Inget i appen är ändrat.
