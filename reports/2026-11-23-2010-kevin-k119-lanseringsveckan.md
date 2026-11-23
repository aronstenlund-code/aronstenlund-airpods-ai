# K119 (D259): lanseringsveckan på servern

Kevin (moln), 2026-11-23.

- Inga modellanrop och **0 ElevenLabs**. Krediterna är slut och fylls inte på (D258).
- Inga riktiga köp: kedjan i testerna är falsk (`testpki.ts`).
- **Tester:** **853/853**.
- **Commit:** 2d2fe549, deployad av deploy-backend.

## 1. Inställningen `launch_offer`
- **Läses utan inloggning:** `GET /purchase` (funktionen är redan `verify_jwt = false`). Den behöver varken nyckel eller konto och fungerar från sajten (CORS).
- **Svaret medan veckan pågår:**
  ```json
  {"launch_offer": {"starts_at": "2026-12-01T09:00:00.000Z", "ends_at": "2026-12-08T09:00:00.000Z", "percent": 65, "product_suffix": ".launch"}}
  ```
- **Före start, efter slut och tills den startas:** `{"launch_offer": null}`.
- **Cache:** 60 s i webbläsaren (`cache-control: public, max-age=60`) och 60 s i funktionen.
- **Var den lagras:** tre rader i `drill_settings` (nyckel och heltal): `launch_starts_at`, `launch_ends_at` (Unix-sekunder) och `launch_percent`. I dag finns inga rader, så erbjudandet är tomt.
- **Starta veckan.** Agenterna kör detta med apply_migration eller Supabase SQL, inte Aron. Det börjar gälla inom en minut.
  ```sql
  insert into public.drill_settings (key, value) values
    ('launch_starts_at', extract(epoch from now())::int),
    ('launch_ends_at',   extract(epoch from now() + interval '7 days')::int),
    ('launch_percent',   65)
  on conflict (key) do update set value = excluded.value;
  ```
- **Stoppa i förtid:** `update public.drill_settings set value = extract(epoch from now())::int where key = 'launch_ends_at';`
  - Köp som redan gjorts får sin dags marginal.
- **Ta bort helt:** `delete from public.drill_settings where key in ('launch_starts_at','launch_ends_at','launch_percent');`

## 2. Lanseringsprodukterna i köpverifieringen
- **Vad de ger:** `com.rsolutions.lumen.credits.<n>.launch` ger samma krediter som `com.rsolutions.lumen.credits.<n>`, gånger antal. Det betyder `.100.launch`, `.500.launch` och `.2000.launch`, eftersom de vanliga packen är 100, 500 och 2000.
  - Ingen ny rad behövs i `store_products`; servern läser det ordinarie packet.
  - Kontoboken sparar det köpta produkt-id:t (med `.launch`).
- **Bara inom veckan:** köpets `purchaseDate` ska ligga mellan `starts_at` och `ends_at` plus en dygn. Annars blir det 422 `launch_offer_over` ("Lanseringserbjudandet gäller inte längre.", `reason: launch_window`). Det gäller också när ingen vecka är satt.
- **Undantag som alltid gäller:**
  - Ett köp som redan krediterats och skickas igen (en återställning) ger "added 0" och nekas aldrig.
  - En återbetalning tar alltid tillbaka krediterna, också efter veckan.
- **Bara kreditpack:** endast kreditpack har lanseringsversioner. `sub.week.launch` och okända pack blir "Okänd produkt." som förut.
- **Verifierat i test** (`purchase/k119_test.ts`, 5 fall). LIVE

## Concerns
- **En betald produkt kan nekas.** Om lanseringsprodukterna ligger kvar till försäljning i App Store efter veckan kan någon betala och sedan få nej av servern. Pengarna kommer då tillbaka först via Apples återbetalning.
- **Därför ska Aron:** ta bort `.launch`-produkterna från försäljning i App Store Connect när veckan slutar, eller sätta deras tillgänglighet till lanseringsveckan. Exakta klick: App Store Connect › Apparna › EarMind › Monetarisering › In-app-köp › välj produkten › Tillgänglighet › ta bort från försäljning.
- **Appen ska bara visa lanseringsprodukterna** medan `launch_offer` inte är null.

## Till andra
- **Angela Fable (A161)** och **Kelly (Ke88)** har fått fältnamnen i sina köer.
- **D257 läst:** i `/answer` vinner `language`, och inget ändras. k118-live och o97-live vilar tills krediterna fylls på (D258).
