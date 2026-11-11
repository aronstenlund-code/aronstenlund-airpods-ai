# K42: Arons telefontest 18:58, Standardläge (Kevin, 2026-11-11 20:11)

Underlag: Deangelos rapport `reports/2026-11-11-1905-deangelo-telefontest.md`, med fynd **verifierade på enhet** (Arons iPhone).

**Status:**
- **Klart:** alla fem delarna är driftsatta och testade live mot backend.
- **Väntar på appen:** K42.5 kräver att appen skickar data (Angela A74).
- **Kostnad:** cirka 0,9 USD (live-körningar och två regressioner).

## 1. Namnet: "Jag heter Earmind" (D128)
- **Kod:** `self.ts` har ett nytt ämne, `name`, för frågorna "vad heter du", "vad är ditt namn", "har du ett namn", "vad ska jag kalla dig", "vem är du" och "hur heter du". Alla självsvar säger nu Earmind i stället för Lumen.
- **Systemprompten** (alla lägen utom personas) har en ny rad: heter Earmind och säger aldrig att den saknar namn.
- **Väckningsordet:** appen kan skicka `assistant_name`, med standardvärdet Earmind. Väckningsordet "Lumen" fungerar fortfarande.
- **Live:** 10/10 fraser svarar "Jag heter Earmind …", och inget svar saknar namnet.

## 2. Faktafel ("Vättern är Sveriges största sjö")
- `scripts/k42-live.py facts` innehåller 21 svenska fakta: största, näst största, tredje största, längsta, högsta, huvudstäder, årtal och antal.
- **Före ändringen** (Haiku, Auto): 19/21. Svaren "tredje största stad är Helsingborg" och "största nationalpark är Stora Sjöfallet" var fel. Vänern/Vättern var rätt i den körningen, men Arons telefon fick fel svar.
- **Ändring:** en kort fråga om rangordning (`isRankQuestion`: största, minsta, längsta, högsta, äldsta, näst, tredje …) och "hur många" om Sverige, Europa eller världen går till Sonnet, som Provläget redan använder. Kostnaden blir cirka 0,01 USD per sådan fråga i stället för 0,001.
- **Efter:** 20/21 ("hur många landskap" gav tjugoett). Med "hur många" tillagt: **21/21**.

## 3. Uttalad längd (`asklength.ts`)
- Längden läses i kod:
  - "N ord", med eller utan "minst", "ungefär", "cirka", "högst" eller "eller mer" (talord och siffror);
  - "i/med N meningar";
  - "kort", "kortfattat", "säg kort";
  - "utförligt", "detaljerat", "ingående".
- **Effekt:**
  - Modellen får en längdanteckning som går före alla andra längdregler.
  - Två-nivåsvaret (kort först, sedan "Mer?") stängs av. Det var troligen därför som "hundra ord eller mer" gav cirka 50 ord på telefonen. Det är **ett antagande**, eftersom appen använder `two_level` i Standardläge.
  - Token- och teckengränserna följer längden.
  - "Ungefär N ord" och "högst N ord" klipps vid det sista meningsslutet inom 1,2 N.
- **Live,** 10 fall (hundra ord eller mer, ungefär hundra, cirka hundrafemtio, femtio, trettio, minst åttio, en mening, två meningar, kort, utförligt):
  - Första versionen: 8/10.
  - Efter meningsbudget och klippning: **10/10 två gånger i rad**. Kravet är 10/10 inom ±20 %.
  - En körning dessförinnan, med taket 1,1 N, gav 8/10. Felen var att femtio ord klipptes till 32, och att "kort" gav 31 ord.

## 4. Klagomål på appen (`complaint.ts`)
- Klagomål som "varför upprepar du", "varför svarar du inte", "du lyssnar inte", "sluta upprepa" och "du hörde fel" besvaras i kod, utan modellanrop:
  - Med `qa_log`-samtycke: "Det låter som ett fel. Jag har sparat det så att det kan rättas."
  - Utan samtycke: "Det låter som ett fel. Skriv gärna det i appens feedback, så kan det rättas."
- Svaret lovar aldrig en ändring.
- **Markering:** `done.complaint: true`. Turen får `kind = 'complaint'` i `qa_log` (migration `20261111200000_qa_log_kind.sql`, körd). Arons sida (`backend/webtest/qa.html`) visar "⚠️ KLAGOMÅL", och CSV-filen har en ny kolumn, "typ".
- **Live:** 3/3 rätt text och markering.
- **Inte verifierat i tabellen:** jag har inte läst raden i `qa_log` live, eftersom en anonym testanvändare inte har samtycke i appen. Testet `k42_test.ts` visar att raden får `kind`.

## 5. "jaha" hördes som "utveckla" (`lonecmd.ts`)
- **Regel:** ett ensamt kommandoord (högst 2 ord, utan "Lumen") direkt efter ett svar utförs bara när `context.stt_confidence` är minst 0,85 och `context.utterance_ms` är minst den tid ordet tar att säga (cirka 120 ms per stavelse, minst 250 ms). Annars blir det tystnad (`done.lone_command_weak`).
- **Utan fälten från appen** fungerar allt som förut.
- **Test** (`k42_test.ts`): 20 kombinationer av osäkert eller kort ger **0/20 som kommando**. Ett riktigt "utveckla" (säkerhet 0,86–0,99, 420–800 ms) ger **20/20 utfört**.
- **Live:** säkerhet 0,6 och 300 ms ger tystnad, och 0,95 och 650 ms ger det utvecklade svaret.
- **Antagande, inte testat:** att Scribes säkerhet faktiskt är låg när "jaha" hörs som "utveckla". Det behöver mätas på telefon när A74 är klar.

## Tester
- `deno task test`: **491 gröna** (nya: `k42_test.ts` och delar av `k_standing16_test.ts`). `check` är ren.
- **Regressioner:** 90,5 % (`172244f`), 100 % (`3129b54`), 85,7 % (`d153ba0`). Alla ligger inom 81–100 %. De tre missarna i den sista är innehållsfel i modellen (Napoleon, andraderivata, "Et dockhem") och har inget med längden att göra.
- **Rådata:** `reports/eval/*-k42-live-*.json`.

## Till Angela (A74)
- Skicka `context.stt_confidence` (Scribes säkerhet, 0–1) och `context.utterance_ms` (yttrandets längd) med varje `/answer`.
- Skicka gärna `assistant_name`, om väckningsordet ändras.
- Med `two_level` kommer ett svar med uttalad längd nu i ett stycke, utan `done.more`.

## Till Aron
- **Ingen åtgärd behövs.** Rangordningsfrågor kostar nu cirka 10 gånger mer per fråga, eftersom de går till Sonnet, men de är få.
- Teströsten i logoröstningen (från K41) finns kvar. Vill du att den raderas?
