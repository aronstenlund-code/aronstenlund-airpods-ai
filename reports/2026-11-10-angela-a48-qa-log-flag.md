# A48 – `qa_log: true` med samtycke version 5 (Angela, 2026-11-10)

Det här är en stående uppgift enligt `docs/PLAN.md` 2b och har en egen punkt i kön. Underlaget är Arons beslut D116 och
Kevins K30 (`a88445c`). K30 loggar fråga och svar till Arons privata logg **bara när appen skickar `qa_log: true`**.
Appens halva saknades. **Det här är kod och enhetstester. Det är inte provat mot servern från en telefon.**

## Vad som gjordes
- Varje anrop till `/answer` har nu `qa_log: true` när samtycket med D116:s text är godkänt. Det är version 5, A41:s
  svenska samtycke, som säger "Frågor och svar skickas till oss".
- Utan det samtycket, till exempel med en gammal post (version 4) eller utan samtycke, finns nyckeln inte alls i
  anropet. Då loggar servern inget.
- Flaggan sätts på samma ställe som `session_end` (`ListeningModel.context(for:)`). Den följer därför med alla frågor
  som går till `/answer`, också svaren som hämtas i förväg. Servern loggar aldrig ett svar som dras tillbaka (K30).

**Kod:**
- `ConsentPolicy.qaLogVersion` (5) och `allowsQALog(_:)`;
- `AnswerContext.qaLog`;
- `qa_log` i `CloudAnswerProvider.encodeBody`.

## Tester
`LumenTests/A48Tests.swift`:
- bara version 5 eller senare tillåter loggen;
- samtycket som visas i dag har D116:s text;
- flaggan skickas bara när loggen är tillåten och saknas annars.

## Concerns
Loggen kan innehålla andras ord, eftersom Lumen hör omgivningen. Samtycket (A41) säger det, och K30 maskerar
personnummer, kort- och kontonummer. Krissvar loggas aldrig.

Det här följer D116 och de dokumenterade skydden, så jag fortsätter. Jag noterar ändå att eleverna kan vara under 18.

## CI
- **Första körningen var röd** (42884455758). `AnswerContext.clamped` bygger om sammanhanget innan det skickas, och den
  tappade den nya flaggan. A48Tests fångade det, och utan testet hade loggen aldrig fått något.
- Rättningen (`49cc6aa`) är grön i CI: iOS build 42887425466. Bygget för enhet räknar varningar som fel, och alla
  LumenTests är gröna, A48Tests inräknade.

## Till Kevin
Appen skickar `qa_log: true` som en nyckel på toppnivå i `/answer`, bredvid `session_end`.
