# K98 (D224): välkomstkrediter 5 000 och inbjudan 2 000 (Kevin, moln)

2026-11-17 21:25 UTC. 0 ElevenLabs. `deno task test`: **698 av 698 gröna**, varav 7 nya för K98.

## Vad som är byggt (i `/purchase`, inloggad)
- `{"action":"attest_challenge"}` → `{challenge}`: en engångsutmaning som gäller i 5 minuter.
- `{"action":"welcome","key_id","challenge","attestation"}` (base64 från `DCAppAttestService.attestKey`, där
  clientDataHash = SHA-256 av utmaningens UTF-8-bytes) → `{ok, added, reason?, wallet}`. Servern kontrollerar App
  Attest med bara WebCrypto:
  - CBOR-objektet `apple-appattest`, och kedjan till **Apple App Attestation Root CA**. Roten är fäst, och
    fingeravtrycket `1cb9823b…c932` är **verifierat**: certifikatet hämtades i Actions 44166819406, och ett test
    läser det riktiga certifikatet.
  - Noncen i certifikatets tillägg (1.2.840.113635.100.8.2) = SHA-256(authData ‖ SHA-256(utmaningen)).
  - Nyckel-id = SHA-256 av nyckeln och lika med authDatas credential id, appens id (rpIdHash av
    `<TEAMID>.com.rsolutions.lumen`), räknaren 0 och miljön `appattest` (`appattestdevelop` bara med
    `APP_ATTEST_DEVELOPMENT=1`).
  - Krediterna ges **en gång per konto och en gång per nyckel**, med två unika transaktions-id i `credit_ledger`
    (kind welcome). En nyckel hör till ett konto.
- `{"action":"invite_code"}` → `{code, url, app_url}`, samma kod varje gång.
- `{"action":"invite_claim","code"}`: det nya kontot måste ha en egen kontrollerad nyckel. Det nekas för eget konto,
  samma nyckel som den som bjöd in, en andra inbjudan och en kod som inte finns.
- Vid den inbjudnas **första Starta prov eller Spela** (`/drill start`) får den som bjöd in 2 000 krediter (kind invite).
  Det sker en gång per inbjuden och högst 10 per kalendermånad. Det stoppar aldrig svaret.
- Siffrorna ligger i `drill_settings`: `welcome_credits` 5000, `invite_credits` 2000 och `invite_month_max` 10.
- Krediterna räknas som köpta krediter i plånboken (`purchased` i quota). Veckotakets reservvärde i koden är nu
  20 000 (D224), och inställningen är redan 20 000 (Deangelo).

## Viktiga gränser (läs innan det kallas "en gång per telefon")
- **App Attest-nyckeln hör till en installation av appen, inte till telefonen.** Den som raderar appen och installerar
  om får en ny nyckel. Med ett nytt konto kan den då få välkomstkrediterna igen. Det som App Attest stoppar är skript,
  simulatorer och ändrade appar, alltså massvis med falska konton utan riktiga telefoner. **"En gång per telefon"
  även efter ominstallation kräver Apples DeviceCheck** (två bitar per telefon som Apple sparar). Det behöver en
  DeviceCheck-nyckel (.p8) som Aron skapar i developer.apple.com och lägger som hemlighet. Det är inte byggt. Säg till,
  så bygger jag den delen när nyckeln finns.
- **Två konton i samma installation** (logga ut och skapa ett nytt) får samma nyckel, och då ger inbjudan inget.
  Två installationer på samma telefon (ominstallation) ser ut som två telefoner.
- **Team ID saknas** i projektet (`DEVELOPMENT_TEAM` är tom). Servern behöver hemligheten `APPLE_TEAM_ID` (Arons
  10 tecken i developer.apple.com, Membership). Utan den svarar `welcome` med 503 `attest_unconfigured` och ger
  ingenting. Inbjudningskoderna fungerar ändå, men belöningen kräver att den inbjudna har en kontrollerad nyckel.

## Migreringar som väntar (Deangelo kör ordagrant)
1. `20261117220001_k98_ledger_kinds.sql` (`credit_ledger` tillåter welcome och invite)
2. `20261117220002_k98_attest.sql`
3. `20261117220003_k98_invites.sql`
4. `20261117220004_k98_settings.sql`

## Övrigt i samma omgång
- `get` och `status` ger nu ordtider (`audio.text.words` och `audio.long.words`, `[[start_ms, end_ms], …]` per uppläst
  ord) till "Skriv i takt" (D220, Angela Fables fråga).

## Tester (alla med en falsk kedja som skapas vid körningen, inga nycklar i repot)
- App Attest: godkänd, och nekad vid fel utmaning, fel app, utvecklingsnyckel i produktion, räknare, annan rot,
  fel nyckel-id, fel nonce och trasig CBOR. Apples riktiga rot är fäst.
- Välkomst: en gång per konto, en nyckel ger bara ett konto, en använd utmaning nekas och en falsk kontroll nekas.
- Inbjudan: samma kod, ingen enhet, redan använd, eget konto, fel kod, en gång per inbjuden, månadstaket och samma installation.

## Inte testat
- En riktig App Attest från en iPhone (görs i appen, A141, och kräver Team ID). Apples exakta CBOR-format följer
  Apples dokumentation (**untested assumption** för riktiga data).
