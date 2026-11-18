# O82: välkomstkrediter och inbjudan (K98, D224), Oscar (moln)

**Resultat:** Inbjudningskoderna och alla nekanden fungerar live. Välkomstkrediterna är avstängda live tills `APPLE_TEAM_ID` finns (503 `attest_unconfigured`, som Kevin skrev). Logiken håller lokalt i 6 av 7 fall. **Fel (medel): månadstaket på 10 är inte skyddat mot samtidiga spelningar.** Dessutom en risk: ominstallation ger nya välkomstkrediter, och via inbjudan kan det bli upp till 20 000 i månaden per inbjudare. 0 ElevenLabs, inga riktiga köp.

## Live (Actions 44264382928, 2026-11-18 08:09 UTC, testkonton P och Q, **verifierat live**)
| Anrop | Svar |
|---|---|
| `attest_challenge` | 200, en utmaning |
| `welcome` med falsk attestering | 503 `attest_unconfigured` "Välkomstkrediterna är inte på än." |
| `welcome` med fel utmaning | 503 `attest_unconfigured` (kontrolleras inte förrän Team ID finns) |
| `invite_code` två gånger | 200 och samma kod båda gångerna: `b6k9636p`, `url https://earmind.vercel.app/i/b6k9636p`, `app_url earmind://invite/b6k9636p`, `month_rewarded 0`, `month_max 10`, `invite_credits 2000` |
| `invite_claim`, egen kod | 409 `invite_self` "Du kan inte bjuda in dig själv." |
| `invite_claim`, Q utan enhet | 409 `invite_needs_device` "Öppna appen på din telefon först." |
| `invite_claim`, okänd kod | 404 `invite_not_found` |
| `invite_claim`, `'; drop table x; --` | 404 `invite_not_found` |
| P:s plånbok efteråt | `purchased 0`, `gift {left 0, welcome 0, invite 0}`, `monthly_free 1500`; veckotaket syns bara med en aktiv prenumeration |

## Lokalt (`scripts/qa/o82_rewards_test.ts` mot `_shared/rewards.ts`, 6/7, **verifierat i test**)
1. Välkomst 5 000 ges en gång per konto och en gång per nyckel. Samma konto och nyckel igen ger 0; ett annat konto med samma nyckel ger 0 (`key_used`); samma konto med ny nyckel ger 0 (`already`).
2. Ominstallation betyder ny nyckel och nytt konto, och då ges 5 000 igen. Det är en känd gräns utan DeviceCheck.
3. Inbjudan ger samma kod, och 2 000 kommer **först vid den inbjudnas första spelning** och bara en gång (2 000, sedan 0). Inbjudarens saldo går 5 000 → 7 000, och en andra inbjudan nekas.
4. Nekas: egen kod `invite_self`, ingen nyckel `invite_needs_device`, ett konto i samma installation (nyckeln hör redan till inbjudaren) `invite_needs_device`, okänd kod och `../etc` `invite_not_found`.
5. Taket 10 i månaden: 12 inbjudna gav 10 × 2 000 och sedan 0, 0.
6. **FEL:** samtidiga första spelningar går över taket. Med taket 3 belönades 6 av 6 när de spelade samtidigt.
7. Ett gammalt konto som redan har spelat kan ta en inbjudan, och nästa start ger inbjudaren 2 000.

## Fynd
**F1 (medel): månadstaket är inte atomiskt.** `onFirstPlay` räknar `invitesThisMonth` och lägger sedan till en rad. Flera inbjudna som spelar samtidigt ser alla att taket inte är nått. Lokalt belönades 6 av 6 med taket 3. I databasen är det samma mönster, om inte `credit` själv kontrollerar taket (**otestat** live). Förslag: kontrollen och insättningen i en SQL-funktion (`select … for update` på inbjudaren, eller en räknare med villkor).

**F2 (medel, risk till Deangelo/Aron): ominstallation ger nya krediter.** Det redan kända i Kevins rapport får en konsekvens: en person kan installera om appen, skapa ett nytt konto (5 000 välkomst), ta sin egen kod från huvudkontot och spela en gång. Det ger huvudkontot 2 000. Tio gånger i månaden blir 20 000 till huvudkontot, och 50 000 välkomstkrediter i engångskonton. App Attest stoppar skript och simulatorer, inte en riktig telefon med ominstallation. DeviceCheck (TILL-ARON) stoppar det. Tills dess är taket 10 det enda skyddet.

**F3 (låg): ett gammalt konto kan ta en inbjudan.** D224 talar om nya användare. Förslag: tillåt `invite_claim` bara för konton som inte har spelat, eller som är yngre än till exempel 7 dagar.

**F4 (låg):** samma konto och nyckel igen svarar `reason: key_used` i stället för `already`. Appen kan då visa fel text.

## Inte testat
- En riktig App Attest från en iPhone, eftersom Team ID saknas (A141, TILL-ARON).
- Att belöningen ges live vid `/drill start`. Det kräver en kontrollerad nyckel, och därmed en iPhone.
- Veckotaket 20 000 live, eftersom det kräver en aktiv prenumeration och därmed ett riktigt köp. Plånbokens logik med 20 000 är testad lokalt i O78 (fall 8).

## SQL för Deangelo (läs)
```sql
select key, value from drill_settings where key in ('welcome_credits','invite_credits','invite_month_max','subscription_week_chars');
```
