# K93, K94 (servern), K95 och K96: admin, köp, "Hur ska det låta?" och röster (Kevin, moln)

2026-11-17 21:15 UTC. 0 ElevenLabs-genereringar och inga riktiga köp. `deno task test`: **688 av 688 gröna**.
Allt är pushat till main (driftsätts med deploy-backend). En del migreringar väntar på Deangelo (se listan sist).

## K93 (D216): Arons konto har alltid krediter
- `credit_admins` (bara service_role) och `is_credit_admin`: körda av Deangelo. Arons konto
  `6da712ad-5c8e-4272-8697-a996adee2c35` är inlagt. Jag kontrollerade först att det är det enda kontot med det
  prefixet och att det har hans fyra "HISTORIA"-texter. Det är ett **anonymt konto** (ingen e-post): installerar
  Aron om appen eller byter telefon får han ett nytt konto som inte är admin. Det bör lösas med inloggning (risk).
- För en admin dras inga krediter, och 402 kommer aldrig. `quota`, `list.quota`, `cost` och `/exam`-kvoten svarar
  `unlimited: true` (med `remaining` som ett stort tal för äldre appar). `charged_chars` blir 0, så inget betalas
  heller tillbaka. Ett enhetstest finns. **Livetest inte klart:** körningarna 44155928272 och 44157549710 skapade
  testkonton (`bb1a5096…`, `4eeed012…`) och väntade på att bli admin, men raden lades aldrig in, eftersom jag inte
  kan skriva i databasen när godkännandekortet inte syns. Raderna för det står sist.

## K94 (D218, D214): köp på servern (gjort i dag: servern; inte appen)
- `POST /purchase {"action":"verify","jws"}` (inloggad): verifierar StoreKit 2:s signerade transaktion med **bara
  WebCrypto** (egen DER/X.509, inga tredjepartsbibliotek):
  - kedjan x5c består av leaf, mellanled och rot, och roten måste vara **Apple Root CA - G3**, fäst via SHA-256
    `63343abf…3e9179`. Det är **verifierat**: certifikatet hämtades i Actions (44157863130), fingeravtrycket
    stämmer, och ett test läser det riktiga certifikatet och kontrollerar dess egen signatur;
  - Apples markör-OID:er (leaf 1.2.840.113635.100.6.11.1, mellanled …6.2.1) finns, alla certifikat gäller vid
    signeringstiden och signaturen stämmer (ES256);
  - bundle-id stämmer (`com.rsolutions.lumen`), och produkten finns i `store_products`. Produkterna ligger i
    databasen, inte i koden.
  - Kreditpaket läggs i `credit_ledger` med `transaction_id` som unik nyckel, så samma köp räknas en gång. Prenumerationen
    läggs i `store_subscriptions` till och med utgångsdatumet, och en äldre transaktion flyttar aldrig slutdatumet bakåt.
    Ett köp som hör till ett annat konto (via transaktionen eller `appAccountToken`) ger 409.
- `POST /purchase {"signedPayload"}` (App Store Server Notifications v2, utan användare, och signaturen är kontrollen):
  förnyelse förlänger, återbetalning tar tillbaka köpta krediter en gång eller avslutar prenumerationen, och
  utgång avslutar den. En okänd transaktion ignoreras, och en felaktig signatur ger 422.
- **Plånboken** (`_shared/wallet.ts`, samma i `/drill`, `/exam` och `/help`): admin först, sedan
  prenumerationsveckan (`subscription_week_chars`, 40 000, ISO-vecka i svensk tid), sedan månadens gratiskrediter och
  sist köpta krediter. Räcker de inte tillsammans nekas köpet, och ingenting räknas. Svaren har nu
  `monthly_free`, `purchased` och `subscription: {active, until, week_used, week_limit}`, och de gamla fälten finns kvar.
- Tester: 10 med en falsk kedja som skapas vid körningen (`purchase/testpki.ts`, inga nycklar i repot). Produktionen
  godtar bara Apples rot (ett test visar att den falska kedjan nekas med `root`).
- **Inte klart:** appen (A134), produkterna i App Store Connect och avtalet för betalda appar (Aron, TILL-ARON #27).
  Adressen för notifieringarna ska in i App Store Connect: `https://xjczbzfkmbjdebwlccki.supabase.co/functions/v1/purchase`.
  **Untested assumption:** det exakta innehållet i Apples riktiga transaktioner (fältnamnen följer Apples
  dokumentation för JWSTransactionDecodedPayload, men inget riktigt köp har testats).

## K95 (D220): "Hur ska det låta?"
- `drill.style` (fri text, högst 80 tecken) på Säg-texter och prov. Med en stil görs ljudet med **eleven_v3**, och
  Haiku lägger in v3-taggar och pauser i rösttexten, men **bara för filer som görs nya**. **Orden kontrolleras i
  kod:** taggarna tas bort och texten måste vara identisk med rösttexten, annars används den otaggade. Bara taggar
  från vitlistan behålls (lugnt, långsamt, snabbt, tydligt, varmt, glatt, entusiastiskt, nyfiket, allvarligt,
  mjukt, viskar, suckar, skrattar, kort paus, paus, lång paus, betonat). Inga accent- eller dialekttaggar (D220 punkt 3).
- **Stilen ingår i ljudets hash**, inte den taggade texten. Samma text och stil återanvänds därför och kostar 0 utan
  ett nytt Haiku-anrop, och `cost` (K92) räknar med stilen utan Haiku. Meningsgränser och var det korta svaret slutar
  flyttas till rätt plats i den taggade texten, och en tagg räknas aldrig som ett ord i ordtiderna.
- Ett prov som redan har en annan röstmodell kan inte få en stil (409, D151).
- **Verifierat i ElevenLabs sidor (via sökning, sidan kunde inte öppnas härifrån):** v3 läser taggar inom
  hakparentes, med små bokstäver; [whispers], [excited], [curious], [sighs], [laughs] och [shouts] finns i ElevenLabs
  egna sidor; v3 stöder inte SSML (`<break>`); taggarna beror på röst och sammanhang; accenter görs med taggar som
  [British accent]. **Inte verifierat:** [calm], [short pause] med flera av vitlistans ord (de är skrivna i samma
  stil, men jag har inte sett dem på en sida), att v3 läser svenska väl, om tidsstämplarna innehåller taggarnas
  tecken, och om dialekt som skånska fungerar. Det kräver Arons ja till ett A/B-test (TILL-ARON #28).

## K96 (D220): fler röster
- `drill.voice_id` vid första sparningen: rösten måste finnas i `voice_catalog` (aktiverad), och sedan är den låst
  för det provet (409 om en annan skickas). Provets filer görs med den rösten och sparas per röst i hashen.
- `GET /voices` svarar som förut, plus `catalog: [{voice_id, name, gender, age, accent, language, preview_url,
  description}]`. `GET /voices?library=1&search=&accent=&gender=` söker i ElevenLabs röstbibliotek (`language=sv`).
  Det kostar inga krediter, och en röst därifrån är `selectable: false` tills den finns i katalogen.
- **Verifierat (ElevenLabs hjälpsida, via sökning):** röster som sparas från röstbiblioteket tar **ingen** plats av
  de anpassade röstplatserna (Starter har 10 för Voice Design och kloner). Listningen är `GET /v1/shared-voices` med
  `page_size` högst 100 och filter för språk, accent och kön. **Inte verifierat:** om en biblioteksröst måste läggas
  till på kontot innan text till tal fungerar med den. Katalogen är därför tom tills Aron (eller jag på hans ja)
  lägger in 12–20 röster som redan finns på kontot.
- Ett provljud via `preview_url` kostar inga krediter (ElevenLabs egen fil).

## Migreringar som väntar (Deangelo kör dem ordagrant ur filerna)
1. `20261117200003_k94_products.sql`
2. `20261117200004_k94_week.sql`
3. `20261117200005_k94_balance.sql`
4. `20261117200006_k94_use_purchased.sql`
5. `20261117200007_k94_use_week.sql`
6. `20261117210002_k96_voice_catalog.sql`
Körda: `credit_admins` (Deangelo), `k94_ledger` (jag), `k94_subscriptions` och `k95_k96_drill_cols` (Deangelo).
Koden fungerar innan de körs: en tabell eller funktion som saknas räknas som tom, aldrig som admin eller köpt.

## K93-livetestet: så görs det
Kör `kevin-live.yml` med `k93-live.py`. När loggen visar `K93_USER_ID <id>` (inom 1 minut), lägg in kontot:
`insert into public.credit_admins (user_id, note) values ('<id>', 'K93 livetest, tas bort');`
Efter `K93_ADMIN_DONE` (cirka 1 minut senare), ta bort det:
`delete from public.credit_admins where note = 'K93 livetest, tas bort';`

## Nästa
- Deangelo: migreringarna ovan och K93-livetestet.
- Angela Fable: A133, A134 och A136 (fälten nedan). Oscar: O78 och O80.
