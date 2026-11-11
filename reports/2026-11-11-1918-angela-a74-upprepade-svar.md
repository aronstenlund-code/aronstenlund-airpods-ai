# A74 – Svaren upprepas när Aron ställer en ny fråga (telefontest 18:58)

Angela, 2026-11-11. Kö: `prompts/queue/angela.md` A74 (Deangelo). Underlag: `reports/2026-11-11-1905-deangelo-telefontest.md`.

## Vad som är gjort
1. **Orsaken** är inte säker, eftersom appens logg från Arons telefon inte finns i repot. Mitt spår är samma som i
   A72: en fråga som väntar, eller en sen final från Scribe, skickas igen. A70 och A72 loggar det nu. **Ej verifierad
   bedömning.**
2. **Spärr** (`RepeatGuard`, ren och testad):
   - En fråga i Standardläge (`auto`) som har minst 80 % av innehållsorden gemensamma med en fråga från de senaste
     60 s skickas inte igen. Loggraden är "Auto: the same question as … within 60 s, not asked again (A74)".
   - "igen", "upprepa" och "en gång till" släpper alltid igenom.
   - En ny fråga om samma sak släpps också igenom. "De fem största sjöarna i världen" efter "de största sjöarna" har
     50 % gemensamt.
   - Yttranden med färre än två innehållsord räknas inte ("ja", "Nilen"), och inte heller Provläget, där samma korta
     svar kan komma två gånger.
3. **Till Kevin (K42.5):**
   - `utterance_seconds` skickas i `/answer`. Det är tiden från första hörda ordet till sista ändringen av orden, i
     appens Scribe-väg.
   - **Scribes säkerhet (`confidence`) finns inte** i den anslutning appen använder. Den kräver
     `include_timestamps`, som ändrar meddelandena och kan ge dubbla finaler. Det slås inte på i kväll utan prov.
     **Ej verifierat** i ElevenLabs dokumentation.
   - Fältets namn är mitt förslag. Kevin bestämmer.

## Testresultat
- **Enhetstester:** `LumenTests/A74Tests.swift` har 3 tester:
  - samma fråga stoppas;
  - en annan fråga, en fråga efter 60 s och "igen" släpps igenom;
  - `utterance_seconds` går genom `clamped` och kroppen.
- **iOS-bygge och enhetstester:** CI 43076491531 (9791ce0, A72 och A74) är **grön**: device-bygget, alla enhetstester och `Lumen-unsigned.ipa`.
- **Ej verifierat:** Toby provar i T16. På telefon är inget provat.
