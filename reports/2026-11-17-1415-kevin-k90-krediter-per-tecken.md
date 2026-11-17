# K90 (D213) + K89: krediter per tecken, 1 500 i månaden (Kevin, moln)

2026-11-17 14:15 UTC. 0 ElevenLabs (D180): enhetstester med fejk och livetest med testkonto och teströst.

## K89: varför Spela gav 402 kl. 13:48 (svensk tid) (verified in docs = databas och loggar)
Arons Säg-text "HISTORIA – 1880–1918" (`bddfc4eb`, `196454b4`) har 14 delar och **764 tecken som visas**, men
**948 tecken till rösten** (siffror och årtal blir ord, till exempel "1880" → "artonhundraåttio"). Servern räknade
läslägets kvot på rösttexten, där varje påbörjat 800-tal tecken var en fråga. Med en del som redan hade ljud blev det
cirka 930 tecken, alltså **2 frågor**. Kapseln och raden "Räknas som 1 fråga" räknade på de 764 visade tecknen, så
det blev 1, och Aron hade 1 fråga kvar. Dessutom sparade appen provet med `defer_audio` före varje start. Servern
godtog det och nekade sedan starten, så varje tryck lämnade ett nytt ostartat prov.

## Vad som är byggt (K90, D213)
- **1 kredit = 1 tecken av den visade texten som får nytt ljud.** För en textdel räknas dess text, för en fråga
  frågan och det långa svaret. Ljud som redan finns, på vilket konto som helst (D144: delade, publicerade och
  importerade prov), kostar 0, och upprepningar kostar 0. Den visade texten räknas, inte rösttexten, så att
  kapseln, raden och servern räknar likadant (Aron: "764 tecken kostar 764 krediter").
- **1 500 krediter per kalendermånad** (svensk tid), `drill_settings.free_chars_per_month`, går att ändra utan kod.
  **Räknaren började på 0** när migreringen kördes (ny kolumn `drill_quota.chars`). Gamla frågeräkningar räknas inte om.
- **Kostnaden räknas innan något sparas.** Räcker krediterna inte blir det 402 `quota_exceeded` med `cost`,
  `remaining`, `limit`, `used`, `resets` och texten "Det här kostar N krediter. Du har M kvar. Nya krediter
  1 december." Inget sparas eller startas. Ett **nytt** prov som sparas för senare (`defer_audio`) nekas redan vid
  spara om kostnaden är större än det som finns kvar. Då blir inget ostartat prov liggande (D212 punkt 3). Ett prov
  som redan finns ändras inte.
- `cost` och `unit: "chars"` finns i varje svar på save, start, get och status, och `audio.cost` säger vad Starta prov
  kostar nu. `quota` svarar `{unit:"chars", limit, used, remaining, resets, resets_day}`, och `/exam` svarar likadant.
  `/exam read` ger `cost`.
- **Gamla fält finns kvar** för äldre appar: `left`, `suggest`, `per`, `prices.classes`, `generated_questions`,
  `needed` och `refunded_questions`. Ingen äldre app ska krascha, men talen är nu krediter.
- **Återbetalning vid kvotfel hos ElevenLabs** (D200) sker i krediter och aldrig med mer än provet debiterades i
  krediter (`drills.charged_chars`, `refunded_chars`). Prov som startades före K90 räknades i frågor och ger inget
  tillbaka i krediter.
- **`/help try` är gratis.** Det görs inget ljud, och D213 säger att bara nytt ljud kostar. Hastighetsgränsen finns kvar.

## Arons tidigare prov
Ingenting är raderat eller ändrat. De ostartade kopiorna `196454b4`, `bddfc4eb` och `6c6633c3` ligger kvar. Med
K90 kostar Säg-texten nu **744 krediter** (764 minus rubriken, som redan har ljud), och Aron har 1 500.

## Tekniskt
- Migrering `20261117140000_drill_credits_chars.sql` (körd via Supabase MCP): `drill_quota.chars` och
  `chars_period`, `drills.charged_chars` och `refunded_chars`, RPC:erna `use_drill_chars` och `refund_drill_chars`.
  `use_drill_quota` finns kvar men används inte.
- `drill/handler.ts`: `creditCost`, `displayChars`, `creditsRefused`, `resetsDay`, räkningen i `saveDrill`,
  `refundUnavailable`, `view` (`audio.cost`) och `quota`. `exam/handler.ts`, `exam/read.ts`, `help/handler.ts` och
  index-filerna pekar på RPC:erna för tecken.
- Kontrakt: `backend/README.md` (save och quota).

## Tester
- `deno task test`: **671 av 671 gröna**. Nya eller omskrivna: gränsen i krediter (402 med fälten, inget sparat,
  befintligt ljud och import gratis), nytt prov för senare som inte räcker (inget sparat), kostnad före start,
  quota i tecken, text och lång text (delar med ljud gratis), återbetalning i krediter, `/help try` gratis och
  `/exam` 402.
- **Livetest grönt, 5 av 5** (`kevin-live.yml` körning 44095203779, testkonto med teströst, 0 ElevenLabs).
  Driftsatt med deploy-backend 44094568221 (grön). Resultat: quota `{unit:"chars", limit:1500, used:0, remaining:1500,
  resets_day:"1 december"}`; en text på 2 011 tecken gav 402 "Det här kostar 2011 krediter. Du har 1500 kvar. Nya
  krediter 1 december." och inget sparat prov; en liten text kostade 72 före start (`cost` och `audio.cost`) och 72
  vid start (used 72); samma text igen kostade 0. Första körningen (44094970169) var röd på mitt eget test: den
  stora texten kortades till exakt 1 500 tecken (gränsen för en del) och rymdes därför. Rättat i skriptet.

## Beslut (D213 lämnade detaljerna åt mig)
- Räknat på **visade** tecken, inte rösttexten. Det är det Aron ser, och det fel som K89 handlade om.
- `/help try` kostar 0.
- Ett nytt prov för senare som inte går att betala nekas vid spara.

## Kvar
- Appen (A131): visa kapseln och raderna från `cost` och `remaining`, och visa 402-texten under fältet.
- Oscar (O76) testar.
