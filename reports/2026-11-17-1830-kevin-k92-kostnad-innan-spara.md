# K92 (D215 punkt 8): kostnaden innan man sparar (Kevin, moln)

2026-11-17 18:30 UTC. 0 ElevenLabs (D180).

## Vad som är byggt
- `POST /drill {"action":"cost", "drill":{…}, "items":[…]}` tar samma kropp som `save` (texten och dess delar, eller
  frågorna, `voice_model` om den är vald, `id` för en ändring) och svarar
  `{cost, remaining, limit, unit:"chars", enough}`.
- **Samma räkning som save:** anropet går genom `saveDrill` med `dry`. Delarna, rösten och texten för uppläsningen
  byggs på samma sätt (samma röst, modell och regler), och ljud som redan finns kostar 0. Anropet stannar innan
  något skrivs: inget prov, inga rader, ingen kö, ingen dragning, inget anrop till ElevenLabs och ingen omköning
  av felade filer. Kontrollen av `client_id` och taket för antal prov hoppas över, eftersom inget sparas.
- **Gräns per konto:** högst 20 i minuten och 300 om dagen (`drill_cost`), sedan 429 `rate_limited`. Det räcker för
  att visa kostnaden medan någon skriver om appen frågar när användaren slutat skriva (cirka 0,6 s). Det räcker inte
  för att systematiskt fråga ut vilka texter som redan har ljud. Samma information gick redan att få genom save, och
  den har sin egen gräns.
- Tempot ingår inte i hashen för ljudet. Det spelas upp i appen och påverkar inte kostnaden.

## Tester
- `deno task test`: 673 av 673 gröna, varav 1 nytt test (samma kostnad som den följande save, inget sparat, köat,
  uppläst eller räknat, befintligt ljud 0, frågor och textdelar, och anrop nummer 21 i minuten ger 429).
- **Livetest grönt, 7 av 7** (`kevin-live.yml` körning 44133608937, testkonto, efter deploy 44133225380): förhandsvisningen
  gav samma `cost` som den följande save/start (72), `remaining` 1500 och `enough: true`, och listan hade fortfarande 0 prov.

## Kvar
- Angela Fable (A132): visa `cost` från `action:"cost"` vid Spela ("120 krediter") och ersätt appens egen uppskattning.
- Oscar (O77) testar.
