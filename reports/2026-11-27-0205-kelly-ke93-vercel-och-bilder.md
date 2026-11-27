# Ke93: varför Vercel dröjde, och bilderna från A167, första gången och D269 (Kelly (moln))

## 1. Vercel och sajten
- **Sajten är ute med alla rättelser.** kelly-site-check 45919130134 (00:51 UTC): `/` 200 med 42 226 byte, samma som Ke92 på main; `/sv` och `/beta` svarar 200, och ingen sida rullar i sidled vid 393 px. Ingen ny publicering behövdes. **Verifierat i Actions.**
- **Varför det dröjde** (sett i Vercel-verktyget): produktionen byggs från `main`, inte längre från `kelly/ke66-earmind-site`, som bara ger förhandsversioner. De senaste produktionsbyggena är kl. 22:33, 23:36 och 00:51 UTC, ungefär ett i timmen, fast main får en push med några minuters mellanrum. Vercel bygger också commits med `[skip ci]`.
  En sajtändring kan alltså ta upp till cirka en timme att komma ut. Orsaken är troligen Vercels gräns på byggen per tid för planen (**untested assumption**; ingen felrad i byggena, alla är READY).
- **Förslag till Aron** (en projektinställning, hans ja): Vercel › earmind › Settings › Git › Ignored Build Step med `git diff --quiet HEAD^ HEAD -- site/`. Då bygger bara pushar som ändrar sajten, och de kommer ut direkt.

## 2. Bilderna, rader i köerna (högst fem var, viktigast först)
**Angela Fable** (`fable/screens-first-time`, iPhone 17 Pro; `fable/screens-a167-after-se-ax5`, iPhone SE med största text):
1. Raden om låst skärm på Säg-kortet visas för varje ny användare. Den är inte provad (D209), och med största text tar den hela kortet.
2. I mörkt läge har "New quiz" vit text på ljus accent, så kontrasten är svag.
3. På tom Start ligger tre lösa länkar. De bör ligga i ett kort med rader, som på Start med prov.
4. I Spela in själv med största text tar den fasta foten en tredjedel av skärmen.
5. Lanseringsbladet säger rabatten två gånger ("-65%" och "65% off").

**Angela Schrute** (egna bilder från D269 och första starten, körning 45919279852 från main `0b9be227`, en/sv):
1. Aktiveringsraden är bruten ("so our AI activates." står ensam). Fältet bör ligga under meningen.
2. Första lyssnandet visar aktiveringsraden innan man har frågat något.
3. Välkommens fotrad säger "never uses the microphone" precis före mikrofonfrågan.
4. Felkortet säger "Try again" två gånger.
5. Lyssnarscenerna har svensk demodata på engelska.

Svar på hennes D269-frågor: (a) ja till grå löpande text under "● Listening"; (b) ingen "jag hörde dig"-ton.

Allt är sett i Simulatorn och inget på telefon. Historik under ⋯ finns inte i någon scen, så den har jag inte sett. 0 ElevenLabs.
