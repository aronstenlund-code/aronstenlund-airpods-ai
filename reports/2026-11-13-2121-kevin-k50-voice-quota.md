# K50: röstval, gräns 30 frågor och verklig ljudkostnad (Kevin, 2026-11-13 21:21)

Status för varje påstående: **verifierat live**, **verifierat i docs** eller **antagande, ej testat**.

## Kort
- **Röstval:** röst A (`eleven_multilingual_v2`, standard), B (`eleven_v3`) eller C (`eleven_flash_v2_5`) väljs per prov i `/drill` `save` och låses från första sparandet. Ett byte ger 409 `voice_locked`. **Verifierat live**: alla tre rösterna ger ljud med ordtider, och bytet A till B gav 409.
- **Gräns:** högst 30 genererade frågor per konto. Värdet ligger i `drill_settings.free_generated_questions` och kan ändras. Över gränsen kommer 402 `quota_exceeded`, och inget sparas.
  - Prov hämtade från andra, och text som redan har ljud, räknas inte.
  - Live räknades 5 av 30 efter mitt test (3 + 1 + 1). **Verifierat live** och i tester.
- **Verklig kostnad:** ElevenLabs debiterar **0,40 krediter per tecken för v2 och v3 och 0,20 för Flash.** Värdena kommer från `character-cost` och är samma i blindtestet och i K50-körningen. **Verifierat live**.
  - Med röst A blir ett prov med 20 frågor cirka 4 500–5 100 krediter.

## Röstval (D151)
- Rösten sparas i `drills.voice_model` och ingår i ljudfilens hash. Samma text med en annan röst blir alltså en ny fil, medan samma text och samma röst delas mellan alla konton som förut.
- **Låset:** rösten låses vid första sparandet, eftersom ljudet görs direkt. Samma röst igen går bra. En annan röst kräver ett nytt prov ("Rösten är redan vald för det här provet. Gör ett nytt prov för en annan röst.").
- **Kopior:** importerade prov behåller originalets röst.
- **v3:** skickas utan `language_code`, precis som i blindtestet. Det fungerade: kort svar slutar vid 1,9 s av 5,1 s.

## Gränsen
- **Det som räknas:** en fråga räknas när någon av dess två ljudfiler är ny för servern. Det gäller också en ändring som ger nytt ljud.
  - Räknaren minskar inte när ett prov raderas, annars skulle man kunna radera och göra om.
  - Den kontrolleras atomärt i databasen (`use_drill_quota`).
- **Plats för abonnemang:** `drill_quota.extra` finns redan, så att ett abonnemang senare kan lägga till frågor.
- **402-svaret:** `{"error":{"code":"quota_exceeded","message":"Du har gjort N av 30 frågor med ljud. Köp ett abonnemang eller hämta andras prov, de är gratis."},"used","limit","needed"}`. `list` ger `quota: {used, limit}`. Kontraktet står i `backend/README.md`.

## Varför 40 % av listpriset
**Mätning** (`drill_audio_files.credits`, den nya kolumnen; `reports/eval/k50-live-2026-11-13.json`):

| Röst | Tecken | Krediter | Krediter per tecken |
|---|---|---|---|
| A, v2 (3 riktiga frågor från historieprovet) | 1 679 | 672 | 0,40 |
| B, v3 | 70 | 28 | 0,40 |
| C, Flash | 70 | 14 | 0,20 |
| Blindtestet (v2 / v3 / Flash, 496 tecken var) | 496 | 198 / 198 / 99 | 0,40 / 0,40 / 0,20 |

**Förklaring:**
- Förhållandet mellan modellerna stämmer med det andrahandskällor säger: Flash kostar hälften av v2. **Verifierat live.**
- Nivån stämmer inte. Källorna anger 1 kredit per tecken för v2. Kontot debiteras 40 % av det, oavsett modell, hela tiden.
- Det tyder på en rabatt eller ett räknesätt som gäller kontot eller planen, inte provet. Jag hittade ingen officiell förklaring.
- Arons plan går inte att läsa med appens nyckel (401). Det som är **verifierat** är vad som faktiskt dras: 0,40 krediter per tecken.

**Verklig kostnad per prov med 20 frågor:** cirka 560–640 tecken per fråga, alltså fråga plus långt svar.

| Röst | Tecken | Krediter | USD om 1 kredit kostar som 1 tecken i listpriset (0,08 USD per 1 000) |
|---|---|---|---|
| A (v2) | 11 200–12 700 | 4 500–5 100 | 0,36–0,41 |
| B (v3) | samma | 4 500–5 100 | 0,36–0,41 |
| C (Flash) | samma | 2 200–2 500 | 0,18–0,20 |

Kronorna beror på vad en kredit kostar i Arons plan. Det kontrollerar han i elevenlabs.io › profilbilden › Subscription eller Usage, där samma krediter syns.

## Tester
- `deno task test`: 536 gröna och `check` ren. Nya tester visar:
  - röstalias och lås
  - att en annan röst ger andra filer
  - att listpriset för Flash är halva
  - att krediterna sparas
  - 402 med siffrorna, att inget sparas vid nej, och att befintligt ljud och import är gratis
- Livetestet `scripts/k50-live.py` kördes på driftsatt backend, och de testprov det skapade är raderade.

## Kostnad
- **Claude:** 0.
- **ElevenLabs:** 1 819 tecken = 714 krediter.

## Kvar
- **Appen (Angela A84):** röstval A/B/C med Kellys namn, 409 och 402, `quota` i listan.
- **Abonnemang:** byggs senare och lägger till frågor i `drill_quota.extra`.
- Bekräfta kreditpriset i Arons plan, så att USD-raden blir exakt.

## Nästa
K6 (roliga röster). Hemligheten finns nu.
