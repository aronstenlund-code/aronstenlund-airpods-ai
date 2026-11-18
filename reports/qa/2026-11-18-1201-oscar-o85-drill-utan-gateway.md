# O85: drill utan gatewayens JWT-kontroll (Kevin 6ff8914e, K100 warm), Oscar (moln)

Kevin driftsatte `drill` med `--no-verify-jwt`, så att `{"action":"warm"}` kan köras av pg_cron utan token. Gatewayen kontrollerar alltså inte längre token, och bara koden skyddar. Jag tog den här kontrollen på eget initiativ (säkerhet, D218 punkt 1).

**Resultat: inget hål. Allt utan giltig token nekas med 401 live, `warm` svarar 204 utan innehåll, och en riktig token fungerar som förut (3/3).** Ett lågt fynd: `warm` har ingen gräns. 0 ElevenLabs, 0 Claude. Actions 44289905433, 2026-11-18 10:55 UTC.

## Kod (verifierat i kod)
- `drill/handler.ts` (cirka rad 1154) anropar `deps.authenticate(req)` först, före varje åtgärd. Det finns ingen åtgärd som går förbi.
- `warmable()` (`drill/index.ts`) tar bara `POST` **utan** `authorization`-huvud, med en kropp under 64 byte och `action: "warm"`. Den läser inställningar, röstkatalog, CI-listan och JWKS, läser inget konto och svarar 204 utan kropp. Med en token går anropet vidare till den vanliga autentiseringen.
- `withTestMode` läser token-claims utan kontroll före autentiseringen (`detectTest`). Det påverkar bara loggningen och teständen: ett förfalskat `app_metadata.test` når aldrig handlern, eftersom autentiseringen nekar först.

## Live (**verifierat live**, testkonto)
| Token | list | quota | save | warm med token |
|---|---|---|---|---|
| ingen | 401 "Missing bearer token" | 401 | 401 | (warm utan token, se nedan) |
| skräp `abc.def.ghi` | 401 "Invalid or expired token" | 401 | 401 | 401 |
| `alg: none` med `role: service_role` och `app_metadata.test` | 401 | 401 | 401 | 401 |
| HS256 med fel nyckel, samma påhittade innehåll | 401 | 401 | 401 | 401 |
| riktig token med ändrat innehåll (gammal signatur) | 401 | 401 | 401 | 401 |
| den publika nyckeln som token | 401 | 401 | 401 | 401 |

- `warm` utan token, tre gånger: **204, tom kropp**, på 386, 126 och 98 ms.
- Riktig token: `list` 200 som förut.

## Fynd
**F1 (låg, till Kevin): `warm` har ingen gräns, och anrop utan apikey når nu funktionen.** Gatewayen stoppade förut anrop utan giltig JWT (anon-nyckeln räckte, och den är publik i appen). Nu går alla anrop till funktionen och debiteras som anrop. `warm` gör dessutom arbete varje gång, men det mesta är cachat (inställningar och katalog 60 s, CI-listan 12 h). Det är ingen dataläcka, men den som vill kan generera debiterade anrop och databasläsningar utan nyckel. Förslag: kräv apikey-huvudet (den publika nyckeln) också för `warm`, eller en hemlig rubrik som bara pg_cron skickar, och ge `warm` en enkel gräns per minut.

## Inte testat
- Att pg_cron-jobbet verkligen kör `warm` var 5:e minut, eftersom migreringen 20261118120001 väntar på Deangelo. SQL: `select jobname, schedule, active from cron.job where command ilike '%"warm"%';`
- En utgången men i övrigt giltig token. Det kräver att man väntar ut tokenens livstid.
