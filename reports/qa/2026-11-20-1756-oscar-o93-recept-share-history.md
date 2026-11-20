# O93: Kevins rättning av recept och däck live, och appens share_history, Oscar (moln)

**Resultat:**
- **Däcket är rättat:** 71 ord, börjar med första steget, ingen upprepad mening, inget källprat, och källan clasohlson.com finns kvar.
- **Köttbullarna når nu stekningen**, men svaret **sökte (`web_searches: 1`) och kom utan källa** (`done.source` saknas). Det är kort, 31 ord, och allmänt ("en knippe finhackad lök"). Det är en ny brist: kl. 16:45 hade samma fråga ica.se. Fynd till Kevin.
- **`share_history`:** appen skickar fältet bara när Dela historik är på (**verifierat i kod**, Angelas 4 tester lästa). Servern loggar bara med exakt `true`, nu också vid `save` med `start: true` och aldrig vid `cost` (**verifierat i test**, mitt holdout 6/6).
  - Live med testkonto går det inte att skilja på och av, eftersom testkonton alltid loggas (D247) och Actions alltid räknas som test.

0 ElevenLabs, webb 2 enheter, Claude cirka 0,02 USD. Körning: Actions 44777463175, 16:51 UTC, main 1df09b27. Den markerades röd på grund av köttbullarnas källa, inte på grund av ett skriptfel.

## 1. Recept och däck (**verifierat live**)
| Fråga | Ord | Sökte / källa | Första meningen | Upprepning | Källprat | Tillagning |
|---|---|---|---|---|---|---|
| hur byter man däck | 71 | 1 / clasohlson.com | "Parkera på plant och stabilt underlag, lägg i parkeringsbromsen och säkra bilen med hjulklossar." (ett steg) | ingen | inget | – |
| recept på köttbullar | 31 | **1 / ingen** | "Till köttbullar behövs cirka femhundra gram blandfärs, en deciliter ströbröd, en deciliter mjölk, ett ägg och en knippe finhackad lök." | ingen | inget | **ja**, "Blanda allt, forma bollar, stek i smör tills de är genomstekta." |

- **Däcket:** steget som upprepades kl. 15:45 ("lyft tills hjulet precis går fritt" två gånger) är borta. Sammanfattningen först är också borta. Slutar med "Kontrollera däcktrycket."
- **Köttbullarna (fynd O93-1, medel):**
  - Svaret sökte, men det har ingen källa, varken i `done.source` eller i texten. Det är kort och allmänt, inte ICA:s recept som kl. 15:45 (ica.se, 75 ord). "En knippe finhackad lök" ser dessutom fel ut; lök räknas inte i knippen.
  - Troligen svarade modellen ur minnet efter sökningen, eller så hittades ingen pålitlig källa (untested assumption, en körning).
  - K108 sa att ett sökt svar ska ange det källan säger. Ett sökt svar utan källa borde säga "jag hittade ingen källa" eller ange källan.
- **Kevins egen körning** gav köttbullarna 73 ord. Svaret varierar alltså mellan körningar. Nattens eval i morgon kör praktiskt-04 en gång till utan extra kostnad (påminnelse 10:50 UTC).

## 2. share_history i appen (Angela Schrute, main 5a301006)
**I koden (verifierat i kod, inte på enhet):**
- `DrillCloudClient.sharesHistory` läser `share.isSharing` (Inställningar › Feedback och förslag › Dela historik) **vid varje sparning** (`AppContainer.swift` rad 170).
- `sharing(_:on:)` lägger till `share_history: true` bara när reglaget är på. Annars skickas inget fält.
- Det gäller både `save` (rad 508) och `save` med `start: true` (rad 536, Säg i AirPods).
- `cost` (rad 553–557) får inget fält. Det behövs inte, eftersom servern returnerar före loggningen vid `cost` (`handler.ts` rad 969 före rad 997).
- Appen skickar ingen `stats`.
- Angelas `LumenTests/K113ShareHistoryTests.swift` har 4 tester: av (inget fält, också med start), på (`true` vid save och start), att det följer reglaget vid varje sparning, och att inget annat i kroppen ändras. Jag har läst dem men inte kört dem; de körs i iOS-bygget, som är grönt (44766429356).

**På servern (verifierat i test):** `scripts/qa/o92_k113_holdout.py` 6/6. Nytt fall 6: `cost` med `share_history: true` loggar inget, och `save` med `start: true` loggar bara med `true`.

**Live:** går inte att skilja på och av med ett testkonto, eftersom alla testkonton loggas enligt D247, och en vanlig användare kan inte köras från Actions. Det som återstår är ett prov med ett riktigt konto på en telefon: Dela historik av ska ge 0 rader i `qa_log`, och på ska ge rader. Det kräver Aron, eller att Deangelo läser `qa_log` efter ett prov (SQL nedan).

```sql
select created_at, mode, persona, left(question, 60) from qa_log where mode = 'repetition' and created_at > now() - interval '1 hour' order by created_at desc limit 20;
```

## Avbockat och kvar
- Kevins 17:10-rad: däcket är löst, receptet når stekningen men saknar källa (ny rad till Kevin).
- Angelas 17:26-rad: verifierat i kod och test; live med riktigt konto återstår (Aron eller Deangelos SQL).
- Min 16:49-rad i kevin.md (receptet och upprepningen) bockas av; köttbullarnas källa är en ny rad.
- I morgon 10:50 UTC: nattens eval (praktiskt-03/04, sånger, webbfrågorna).
