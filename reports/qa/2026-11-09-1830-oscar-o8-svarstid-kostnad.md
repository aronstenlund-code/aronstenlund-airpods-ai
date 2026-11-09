# Oscar: O8, svarstid och kostnad efter bytet till Sonnet (D90)

Datum 2026-11-09 18:05–18:22 · Uppgift: `prompts/queue/oscar.md` O8 · Krav (Aron): högst 5 s från fråga till svar, helst under 3 s.
Skript: `scripts/qa/o8_latency.py` (mätning) och `scripts/qa/o8_report.py` (tabeller). Data: `reports/qa/data/2026-11-09-1812-o8.json` (Provläge) och `…-1819-fragor-o8.json` (Frågor).
Kostnad **0,46 USD** av 0,50.

**Verified live** mot den driftsatta backend: `/answer` med SSE och `/tts` med `pcm_24000`, samma format som appen. Mätt från den här Windows-datorn i Sverige mot eu-north-1, över internet. **Inte på telefon.** Tiden från att eleven slutar tala tills Scribe bekräftar frågan ingår inte. Den uppskattas nedan med siffror från O6.

## Hur det mäts

- **Första text** = tid från anropet till första `delta` i svaret.
- **Första ljud** = tid till första hela meningen, plus `/tts` för den meningen till första ljudbyte. Det är så appen gör (D26).
- **Hela svaret** = tid till `done`.

## Resultat

| Grupp | n | Första text p50 / p90 / max (s) | Första ljud p50 / p90 / max (s) | Hela svaret p50 / p90 (s) | > 5 s till ljud | > 30 s | Kostnad per fråga (USD) |
|---|--:|--:|--:|--:|--:|--:|--:|
| Provläge: ämnesord | 10 | 1,7 / 2,4 / 2,7 | 2,7 / 3,7 / 4,0 | 4,8 / 5,7 | 0 | 0 | 0,0095 |
| Provläge: provfrågor | 6 | 1,5 / 1,8 / 1,9 | 2,2 / 2,4 / 2,8 | 4,5 / 4,9 | 0 | 0 | 0,0095 |
| Provläge: följdfrågor | 12 | 1,3 / 1,9 / 1,9 | 2,0 / 2,7 / 3,2 | 4,0 / 4,6 | 0 | 0 | 0,0091 |
| Provläge: textuppgifter (tänkande, K7.6) | 11 | 2,0 / 4,3 / **6,6** | 2,5 / 4,7 / **7,0** | 3,5 / 6,2 | **1** | 0 | 0,0116 |
| Provläge: "vad är en derivata" ×6 (O5-hänget) | 6 | 1,2 / 1,6 / 1,7 | 2,0 / 2,2 / 2,6 | 3,6 / 4,0 | 0 | 0 | 0,0102 |
| **Provläge, alla (Sonnet)** | **45** | **1,6 / 2,4 / 6,6** | **2,2 / 3,2 / 7,0** | 4,1 / 5,7 | **1** | **0** | **0,0100** |
| **Frågor (Auto, Haiku)** | **40** | **1,4 / 2,0 / 2,6** | **1,9 / 2,7 / 3,6** | 2,1 / 3,7 | 0 | 0 | **0,0002** |

- `/tts`, första ljudbyte för första meningen: p50 0,5 s, p90 1,4 s, max 2,0 s (n = 85). Långa första meningar ger de höga värdena.
- Första text och första hela mening kommer nästan alltid samtidigt, eftersom servern skickar hela meningar.

**Mot kravet**, utan tiden för talets slut:
- Provläge: 44 av 45 under 5 s, 37 av 45 under 3 s (82 %).
- Frågor: 40 av 40 under 5 s, 37 av 40 under 3 s.

**Med tiden för talets slut:** Scribe bekräftar frågan cirka 1,1 s (p50) och 1,3–1,5 s (p90) efter att eleven tystnat (O6, tyst rum). Från tystnad till första ljud blir det ungefär:
- Provläge: **3,3 s p50 och 4,6 s p90**;
- Frågor: 3,0 s p50 och 4,1 s p90.

Det håller 5 s i de flesta fall, men inte "helst under 3 s" (untested assumption on device; svar i förväg enligt D80 kan korta tiden).

### Hänget från O5

**Återskapades inte.** "vad är en derivata" (Åk 8) sex gånger i rad med samma användare gav första ljud efter 2,0–2,6 s och hela svaret efter 3,3–4,1 s. Inget av de 85 anropen tog över 30 s, och inget fel uppstod.

Det exakta O5-anropet var:
- POST `/functions/v1/answer`;
- body `{"fragment":"vad är en derivata","mode":"tutor","language":"sv","persona":"tutor","persona_setup":"Prov i Matte imorgon. Årskurs: Åk 8.","context":{}}`;
- det tredje i rad efter sex förhörsfrågor och två derivatafrågor med samma anonyma användare, 2026-11-09 cirka 17:49:45.

Klienten gav "read timed out" efter 90 s utan att något hade kommit. Kevin kan söka i loggen på den tiden.

### De långsammaste

1. **Textuppgift** "En tröja kostar fyrahundra kronor och sänks med tjugofem procent. Vad kostar den nu?": första text 6,6 s, första ljud 7,0 s ("Tröjan kostar nu trehundra kronor."). Tänkandet tar tiden för en uppgift som koden kan räkna själv.
2. **Textuppgift** Lisa och Tom: första text 4,3 s, ljud 4,7 s ("Tom är åtta komma fem år nu …", rätt svar).
3. **Ämnesord** "novell": text 2,7 s, ljud 4,0 s. Den första meningen är lång, så `/tts` tar 1,3 s.
4. **Ämnesord** "andragradsekvation": text 1,7 s, ljud 3,7 s. Första meningen är cirka 150 tecken, så `/tts` tar 2,0 s.

## Kostnad

| | Per fråga | Per timmes plugg (30 frågor) | 100 USD per månad räcker till |
|---|--:|--:|--:|
| Provläge (Sonnet 5.5) | 0,0100 USD | 0,30 USD | **cirka 330 pluggtimmar** (≈ 11 h om dagen i en månad) |
| Frågor (Haiku 5.5) | 0,0002 USD | 0,006 USD | cirka 16 000 timmar |

- Provläge-anropen har i snitt 6 700 inputtokens, varav 4 400 (66 %) läses från cachen, och 350 outputtokens.
- Textuppgifter med tänkande kostar 0,012 USD per fråga.
- Kostnaden räknas från tokens (snarare för högt än för lågt) med D87-priserna (Sonnet 2/10 USD per M, cacheläsning 10 %).
- TTS ingår inte i USD-siffran: ElevenLabs räknar tecken. Första meningarna var 8 621 tecken på 85 svar, och hela svar är cirka 500–900 tecken. En pluggtimme blir då ungefär 15 000–27 000 tecken ElevenLabs. Det är troligen mer begränsande än Claude-kostnaden (planens kvot är oläst).

## Förslag till Kevin

1. **Textuppgifter som koden kan räkna** (procent, rabatt, pris gånger antal) ska räknas i koden som D82, inte med tänkande. Tröjan tog 6,6 s till första text. Tänkande bara för de uppgifter koden inte klarar (Lisa/Tom, ålder, möten, logik).
2. **Kortare första mening** i Provläge, högst cirka 80 tecken. Den sägs då snabbare och `/tts` svarar efter cirka 0,5 s i stället för 1,4–2,0 s. Det sparar upp till 1,5 s för ämnesord som "novell" och "andragradsekvation". Alternativ: dela den första meningen vid första komma till `/tts`.
3. **Ett tak för Sonnet-strömmar:** ingen första token på 8 s ska ge avbrott och ett nytt försök (gärna på Haiku). O5-hänget gav ingenting på 90 s, och appen skulle ha stått tyst.
4. **Större cachedel** i Provläge (66 % nu): om profilen och de senaste turerna ligger efter en fast och längre cachad del sjunker kostnaden per fråga. Det märks över hundratals timmar.

## Inte gjort / begränsningar

- 45 Provläge och 40 Frågor; budgeten tog slut efter 11 av 12 textuppgifter.
- En körning från en dator, inte från en iPhone på mobilnät. 4G/5G lägger troligen till 50–200 ms per anrop (untested assumption).
- Svaren rättades inte här (O6 och D87 gör det). Jag noterade bara att de långsamma svaren var rätt.
