# K43: privat lagring av testljud (D140) (Kevin, 2026-11-11 20:48)

## Gjort (driftsatt i `ad95e9f`, migrationen körd)
1. **Lagring:**
   - Den privata bucketen `debug_audio` tar ljud på högst 2 MB per fil.
   - Tabellerna `debug_turns` och `debug_testers` kan bara läsas med service role. RLS är på, och klienterna har inga rättigheter.
2. **`/debug-audio`** (`verify_jwt` är av, och koden kontrollerar själv användarens JWT):
   - `GET`: `{"debug_audio": bool}`, flaggan till appen. Den är på för Arons konto (OWNER_EMAIL, inloggad med e-post) och för testare som har slagit på testläget.
   - `POST ?action=opt_in|opt_out`: en testare slår på eller av testläget själv. Det kräver inloggning med e-post, och anonyma användare får aldrig testläge.
   - `POST {turn}`: en tur med ljud (`audio_b64` och `audio_mime`, högst 1,5 MB), Scribes text med ordtider (`words`), `decision`, `answer`, `meta`, `mode` och `turn_id`. Siffror maskeras som i `qa_log`. Fungerar bara i testläge. Gränser: 60 per minut och 3000 per dag.
   - `GET ?view=owner`: de 200 senaste turerna med signerade ljudlänkar som gäller en timme. Bara för Aron.
   - `POST ?action=purge`: kräver ingen inloggning och tar bara bort datummappar som är äldre än 14 dagar.
3. **Rensning efter 14 dagar:**
   - pg_cron `purge-debug-turns` tar bort raderna (varje timme, minut 23).
   - `purge-debug-audio` anropar funktionens rensning via pg_net (minut 27). Storage tillåter inte borttagning direkt i SQL.
4. **Arons sida** (`backend/webtest/qa.html`) har en ny del, "Testljud", med knappen "Visa testljud". Varje tur visar en ljudspelare, vad Lumen hörde (med ordtider och säkerhet), beslutet och svaret.
5. Flaggan till appen kommer från `GET /debug-audio`. Det finns ingen `/me`.

## Tester
- `deno task test`: **499 gröna** (`debug-audio/handler_test.ts`).
  - En anonym användare kan inte lagra något och kan inte slå på testläget.
  - En testare slår på testläget, turen lagras med maskerade siffror, och avstängning stoppar lagringen.
  - Ägaren ser turerna med länkar.
  - Fel ljudtyp, för stor fil och tom tur avvisas.
  - Rensningen tar bara bort mappar äldre än 14 dagar.
- `check` är ren.
- **Live** (anonym användare):

| Anrop | Resultat |
|---|---|
| Flagga | false |
| Uppladdning | 403 |
| `opt_in` | 403 |
| Arons vy | 403 |
| Utan inloggning | 401 |
| Rensning | `{"removed":0}` |

- **SQL:** bucketen är privat, de två cron-jobben finns och RLS är på.
- **Inte testat live:** uppladdningen till Storage och de signerade länkarna. De kräver ett e-postkonto, och jag har inget sådant (**untested assumption**). Det första riktiga testet blir Arons konto när Angela har byggt A76.

## Kostnad (uppskattning)
- AAC i mono med 32 kbit/s är ungefär 14 MB per timme ljud, och WAV med 16 kHz är ungefär 115 MB per timme.
- På 14 dagar med 10 testtimmar blir det högst cirka 1,2 GB i WAV, vilket ryms i Supabase Pro-planens 100 GB som ingår. Extra lagring kostar cirka 0,02 USD per GB och månad.
- **Rekommendation till Angela:** AAC (m4a).

## Till Angela (A76)
- Hämta flaggan med `GET /debug-audio` och skicka `POST /debug-audio` per tur, enligt formatet ovan.
- Testarens knapp anropar `?action=opt_in` eller `?action=opt_out`.
- Visa i lyssningsindikatorn när testläget spelar in (D140).

## Concerns
- **Ljud från andra:** testljudet fångar också röster från lärare och andra elever, ofta minderåriga, som inte har samtyckt.
- **Föreslag:**
  - Testare bör bara spela in där de som hörs vet om det.
  - Testläget bör aldrig vara på i en vanlig lektion utan att läraren vet.
  - Det bör stå i texten när testläget slås på.
- Tekniken håller sig inom D140: testläget är frivilligt, syns i indikatorn, lagras privat och raderas efter 14 dagar. Beslutet om villkoren är Architects eller Arons.

## Till Aron
Inget behöver göras nu. Testläget blir på för ditt konto när appen har A76.
